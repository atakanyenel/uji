local agent = require("support.agent")
local app = require("uji.core.app")
local jobs = require("uji.core.jobs")
local keys = require("uji.core.ui.keys")
local list = require("uji.utils.list")
local sandbox = require("support.sandbox")
local screen = require("support.ui")
local server = require("support.server")
local sys = require("uji.sys")
local tool = require("uji.core.tool")
local ui = require("uji.core.ui")
local wait = require("support.wait")

local eventually = wait.eventually

local function has(value, part)
    return tostring(value):find(part, 1, true) ~= nil
end

local function ended()
    local job = uji.jobs.list()[1]
    return job and job.state ~= "running"
end

local function finished(count)
    local done, seen = sys.promise(), 0
    uji.on("turn_finished", function()
        seen = seen + 1
        if seen == count then
            done:resolve()
        end
    end)
    return done
end

local function run(arguments)
    return { "run_command", sys.json.encode(arguments) }
end

local function script(calls)
    return agent.serve(function(round)
        if calls[round + 1] then
            return server.tool_calls(round, { calls[round + 1] })
        end
        return server.text("ok")
    end)
end

local function sent(mock)
    local turns = mock:turns()
    return sys.json.encode(turns[#turns].body.messages)
end

it("starts a background job and wakes the model when it ends", { timeout = 10 }, function()
    local mock = script({ run({ command = "echo built; sleep 0.3; echo done", run_in_background = true }) })
    agent.allow_all()
    local woken = finished(2)
    local result = agent.tool_results(agent.run({ url = mock.url }))[1]
    assert.is_true(has(result, "Started in the background as job 1"), result)
    woken:await()
    assert.is_true(has(sent(mock), "Background job 1 (`echo built; sleep 0.3; echo done`) finished, exit 0"))
    assert.is_true(has(sent(mock), "done"))
    local reported
    for _, message in ipairs(app.session:messages()) do
        if message.type == "job" then
            reported = message
        end
    end
    assert.is_not_nil(reported)
    assert.equal("echo built; sleep 0.3; echo done", reported.command)
    assert.equal("finished, exit 0", reported.status)
    assert.is_true(has(reported.output, "done"), reported.output)
    ui:take_notices()
    assert.is_nil(ui.flashed, "a finished job joins the chat, not the notices")
end)

it("moves a command to the background at its timeout", { timeout = 10 }, function()
    local mock = script({ run({ command = "echo first; sleep 2; echo second", timeout = 1 }) })
    agent.allow_all()
    local woken = finished(2)
    local result = agent.tool_results(agent.run({ url = mock.url }))[1]
    assert.is_true(has(result, "Command did not finish within its 1s timeout and was moved to the background as job 1."), result)
    assert.is_true(has(result, "Output so far:\nfirst"), result)
    woken:await()
    assert.is_true(has(sent(mock), "second"))
end)

it("stops a sleep at its timeout instead of moving it", { timeout = 10 }, function()
    local mock = script({ run({ command = "sleep 3", timeout = 1 }) })
    agent.allow_all()
    local result = agent.tool_results(agent.run({ url = mock.url }))[1]
    assert.equal("error: command timed out after 1s", result)
    assert.same({}, uji.jobs.list())
end)

it("moves the running command to the background with ctrl z", { timeout = 10 }, function()
    local mock = script({ run({ command = "echo go; sleep 1; echo end" }) })
    agent.allow_all()
    local woken = finished(2)
    uji.defer(0, function()
        for _ = 1, 100 do
            if #uji.jobs.list() > 0 then
                return
            end
            ui:key(keys.parse("<C-z>"))
            sys.sleep(0.02)
        end
    end)
    local result = agent.tool_results(agent.run({ url = mock.url }))[1]
    assert.is_true(has(result, "The user moved this command to the background as job 1."), result)
    woken:await()
    assert.is_true(has(sent(mock), "end"))
end)

it("keeps background jobs running when the turn is interrupted", { timeout = 10 }, function()
    local mock = script({
        run({ command = "sleep 1.5; echo later", run_in_background = true }),
        run({ command = "sleep 5" }),
    })
    agent.allow_all()
    local woken = finished(2)
    uji.defer(0, function()
        eventually(function()
            return uji.jobs.list()[1] ~= nil
        end)
        uji.session.interrupt()
    end)
    assert.equal("interrupted", agent.last_error(agent.run({ url = mock.url })))
    assert.equal("running", uji.jobs.list()[1].state)
    woken:await()
    assert.is_true(has(sent(mock), "later"))
end)

it("stops a job with stop_job and refuses one over the limit", { timeout = 10 }, function()
    uji.jobs.configure({ max = 1 })
    local mock = script({
        run({ command = "sleep 5", run_in_background = true }),
        run({ command = "sleep 5", run_in_background = true }),
        { "stop_job", '{"id":1}' },
        { "job_output", '{"id":99}' },
    })
    agent.allow_all()
    local results = agent.tool_results(agent.run({ url = mock.url }))
    assert.is_true(has(results[2], "the background job limit (1) is reached; stop a job with stop_job first"), results[2])
    assert.equal("stopped job 1", results[3])
    assert.equal("error: there is no job 99; use an id run_command gave", results[4])
    eventually(ended)
    assert.equal("stopped", uji.jobs.list()[1].state)
    sys.sleep(0.2)
    assert.equal(5, #mock:turns(), "a stopped job wakes nobody")
end)

it("names jobs in the theme's words and reports a stopped one in the chat", { size = { 60, 12 }, timeout = 10 }, function()
    uji.jobs.configure({ wake = false })
    uji.ui.configure({ theme = require("uji.themes.default")({ text = { job = "run %d" } }) })
    jobs.start({ command = "echo hi; sleep 5", cwd = sandbox.work, background = true })
    eventually(function()
        return uji.jobs.list()[1].tail == "hi"
    end)
    assert.is_nil(screen.find("run 1"), "a running job leaves no row until you open the list")
    assert.equal("run 1", tool.detail(tool.get("stop_job"), { id = 1 }))
    require("uji.core.command").run("jobs")
    assert.equal(1, ui.jobs.selected, "/jobs picks the first job")
    assert.is_not_nil(screen.find("run 1  echo hi; sleep 5"), "the list names the running job")
    screen.press("x")
    eventually(ended)
    assert.equal("stopped", uji.jobs.list()[1].state)
    eventually(function()
        return screen.find("Job(echo hi; sleep 5) stopped") ~= nil
    end)
    ui:take_notices()
    assert.is_nil(ui.flashed, "a stopped job joins the chat, not the notices")
end)

it("opens the jobs list, running ones first and then the newest", { size = { 80, 12 }, timeout = 10 }, function()
    uji.jobs.configure({ wake = false })
    jobs.start({ command = "echo one", background = true })
    jobs.start({ command = "echo two", background = true })
    jobs.start({ command = "sleep 5", background = true })
    eventually(function()
        local listed = uji.jobs.list()
        return listed[1].state == "finished" and listed[2].state == "finished" and listed[3].state == "running"
    end)
    assert.is_nil(screen.find("job 1  echo one"), "a job leaves no row until you open the list")
    require("uji.core.command").run("jobs")
    assert.same(
        { 3, 2, 1 },
        list.mapped(ui.jobs.rows, function(job)
            return job.id
        end)
    )
    assert.equal(3, ui.jobs.selected, "/jobs picks the first job")
    assert.is_not_nil(screen.find("✓ job 2  echo two"), "a job that worked is ticked, not crossed")
    screen.press("esc")
    assert.is_nil(screen.find("job 1  echo one"), "esc closes the list")
    assert.is_nil(screen.find("job 3  sleep 5"), "and takes every row with it")
    require("uji.core.command").run("jobs")
    screen.typing("n")
    assert.is_nil(screen.find("job 1  echo one"), "typing closes the list")
    assert.equal("n", ui.composer:text(), "and the letter goes to the prompt")
end)

it("waits for your next message when waking is off", { timeout = 10 }, function()
    uji.jobs.configure({ wake = false })
    local mock = script({ run({ command = "sleep 0.3; echo quiet", run_in_background = true }) })
    agent.allow_all()
    agent.run({ url = mock.url })
    eventually(ended)
    local before = #mock:turns()
    assert.is_false(app.agent:working())
    local next = finished(1)
    uji.session.submit("anything new?")
    next:await()
    assert.equal(before + 1, #mock:turns())
    assert.is_true(has(sent(mock), "quiet"))
end)

it("binds ctrl z to the background action without taking alt b from word left", function()
    local bound = {}
    for _, row in ipairs(uji.keymap.list()) do
        if row.mode == "normal" then
            bound[row.key] = row.action
        end
    end
    assert.equal("background", bound["<C-z>"])
    assert.equal("word_left", bound["<A-b>"])
end)

it("does not move a command that was just stopped", function()
    local job = jobs.start({ command = "sleep 5", cwd = sandbox.work, timeout = 60, done = function() end })
    jobs.stop(job)
    local moved, err = jobs.background()
    assert.is_nil(moved)
    assert.equal("no command is running", err)
    assert.same({}, uji.jobs.list())
end)

it("stops the server a job started when it stops the job", { timeout = 10 }, function()
    uji.jobs.configure({ wake = false })
    local saved = sandbox.work .. "/server.pid"
    local job = jobs.start({ command = "sleep 30 & echo $! > " .. saved .. "; wait", cwd = sandbox.work, background = true })
    local pid
    eventually(function()
        pid = (sys.fs.read(saved) or ""):match("%d+")
        return pid ~= nil
    end)
    assert.is_true(wait.alive(pid))
    jobs.stop(job)
    eventually(function()
        return not wait.alive(pid)
    end)
end)

it("opens a job from the list, stops it and drops its row", { size = { 80, 12 }, timeout = 10 }, function()
    uji.jobs.configure({ wake = false })
    local job = jobs.start({ command = "echo hi; sleep 1; echo later; sleep 5", cwd = sandbox.work, background = true })
    require("uji.core.command").run("jobs")
    eventually(function()
        return screen.find("job 1  echo hi; sleep 1; echo later; sleep 5") ~= nil
    end)
    assert.equal(job.id, ui.jobs.selected, "the list picks its only job")
    screen.press("enter")
    assert.is_true(ui.modal ~= nil, "enter opens the job's output")
    eventually(function()
        return screen.find("later") ~= nil
    end)
    screen.press("esc")
    assert.is_nil(ui.modal, "esc closes it")
    assert.is_true(ui.jobs.visible, "and leaves the list open")
    screen.press("x")
    eventually(function()
        return uji.jobs.list()[1].state == "stopped"
    end)
    assert.is_not_nil(screen.find("⊘ job 1"), "a stopped job keeps its row")
    screen.press("x")
    assert.is_nil(ui.jobs.selected, "a dropped row is let go")
    eventually(function()
        return screen.find("⊘ job 1") == nil
    end)
    require("uji.core.command").run("jobs")
    assert.is_not_nil(screen.find("⊘ job 1"), "/jobs brings a dropped row back")
end)

it("opens the list with a title that counts and the keys that act", { size = { 80, 12 }, timeout = 10 }, function()
    uji.jobs.configure({ wake = false })
    jobs.start({ command = "sleep 5", cwd = sandbox.work, background = true })
    require("uji.core.command").run("jobs")
    assert.is_not_nil(screen.find("Jobs · 1/1 running"), "the title names the list and counts it")
    assert.is_not_nil(screen.find("enter output · x stop · esc close"), "the list names the keys")
end)

it("opens a job with a tap", { size = { 80, 12 }, timeout = 10 }, function()
    uji.jobs.configure({ wake = false })
    jobs.start({ command = "sleep 5", cwd = sandbox.work, background = true })
    require("uji.core.command").run("jobs")
    eventually(function()
        return screen.find("job 1  sleep 5") ~= nil
    end)
    local row = screen.find("job 1  sleep 5")
    ui:mouse({ kind = "down", button = "left", row = row, col = 6 })
    ui:mouse({ kind = "up", button = "left", row = row, col = 6 })
    screen.pump()
    assert.is_true(ui.modal ~= nil, "a tap opens the job's output")
    assert.equal(1, ui.jobs.selected)
    screen.press("esc")
    assert.is_nil(ui.modal, "esc closes it")
end)

it("lights a job row while the pointer is on it", { size = { 80, 12 }, timeout = 10 }, function()
    uji.jobs.configure({ wake = false })
    jobs.start({ command = "sleep 5", cwd = sandbox.work, background = true })
    require("uji.core.command").run("jobs")
    ui.jobs.selected = nil
    eventually(function()
        return screen.find("job 1  sleep 5") ~= nil
    end)
    local row
    local rows = screen.rows()
    for index = #rows, 1, -1 do
        if rows[index]:find("job 1  sleep 5", 1, true) then
            row = index - 1
            break
        end
    end
    local function painted()
        for _, span in ipairs(ui.screen:spans(row)) do
            if span.text:find("sleep 5", 1, true) then
                return span.bg
            end
        end
    end
    assert.is_nil(painted())
    ui:mouse({ kind = "move", row = row, col = 6 })
    screen.rows()
    assert.equal("#3A3A4A", painted())
    ui:mouse({ kind = "move", row = 0, col = 0 })
    screen.rows()
    assert.is_nil(painted())
end)

it("puts a running jobs button on the status line", { size = { 120, 12 }, timeout = 10 }, function()
    uji.jobs.configure({ wake = false })
    jobs.start({ command = "sleep 5", cwd = sandbox.work, background = true })
    eventually(function()
        return screen.find("1 job") ~= nil
    end)
    local row = screen.find("1 job")
    local col = screen.rows()[row + 1]:find("1 job", 1, true) - 1
    local function painted()
        for _, span in ipairs(ui.screen:spans(row)) do
            if span.text:find("1 job", 1, true) then
                return span.bg
            end
        end
    end
    assert.is_nil(painted())
    ui:mouse({ kind = "move", row = row, col = col })
    screen.rows()
    assert.equal("#3A3A4A", painted())
    ui:mouse({ kind = "down", button = "left", row = row, col = col })
    ui:mouse({ kind = "up", button = "left", row = row, col = col })
    screen.pump()
    assert.equal(1, ui.jobs.selected, "the button opens the list")
    row = screen.find("1 job")
    col = screen.rows()[row + 1]:find("1 job", 1, true) - 1
    ui:mouse({ kind = "down", button = "left", row = row, col = col })
    ui:mouse({ kind = "up", button = "left", row = row, col = col })
    screen.pump()
    assert.is_false(ui.jobs.visible, "a second click closes the list")
    assert.is_nil(ui.jobs.selected)
end)

it("says where a finished job went", { size = { 80, 12 }, timeout = 10 }, function()
    uji.jobs.configure({ wake = false })
    jobs.start({ command = "echo hi", cwd = sandbox.work, background = true })
    eventually(function()
        return screen.find("/jobs to see finished jobs") ~= nil
    end)
    assert.is_nil(screen.find("job 1  echo hi"), "a job that worked leaves no row")
end)

it("leaves the jobs hint to jobs, not to a command that just ran", { size = { 80, 12 }, timeout = 10 }, function()
    local mock = script({ run({ command = "echo hi" }) })
    agent.allow_all()
    agent.run({ url = mock.url })
    eventually(function()
        return screen.find("ok") ~= nil
    end)
    assert.is_nil(screen.find("/jobs to see finished jobs"), "a foreground command is not a job")
end)

it("lists the jobs that ended and lets the screen go still", function()
    local now = sys.os.clock()
    jobs.jobs = {
        { id = 1, state = "finished", code = 1, command = "boom", started = now - 5, ended = now - 1 },
        { id = 2, state = "stopped", command = "stop", started = now - 40, ended = now - 31 },
        { id = 3, state = "finished", code = 0, command = "fine", started = now - 5, ended = now - 1 },
    }
    ui.jobs:refresh()
    assert.same(
        { 3, 2, 1 },
        list.mapped(ui.jobs.rows, function(row)
            return row.id
        end)
    )
    assert.is_false(ui:busy(), "a job that ended leaves the screen still")
end)

it("lists at most five jobs, running ones first, and says how many it hides", { size = { 80, 14 }, timeout = 5 }, function()
    local now = sys.os.clock()
    local started = {}
    for index = 1, 7 do
        started[index] = {
            id = index,
            state = index > 5 and "finished" or "running",
            code = 0,
            command = "job " .. index,
            started = now,
        }
    end
    jobs.jobs = started
    ui.jobs:refresh()
    assert.equal(5, #ui.jobs.rows)
    assert.equal(5, ui.jobs.rows[1].id, "the newest job comes first")
    assert.equal(1, ui.jobs.rows[5].id)
    assert.equal(2, ui.jobs.more, "the list knows what it left out")
    ui.jobs.visible = false
    ui.jobs:show()
    assert.is_not_nil(screen.find("… 2 more"), "the list says how many jobs it hides")
end)

it("keeps the selection on its job when the rows move", { size = { 80, 12 }, timeout = 10 }, function()
    uji.jobs.configure({ wake = false })
    local first = jobs.start({ command = "sleep 5", cwd = sandbox.work, background = true })
    local second = jobs.start({ command = "sleep 1", cwd = sandbox.work, background = true })
    require("uji.core.command").run("jobs")
    assert.equal(second.id, ui.jobs.selected, "the list picks the newest job")
    eventually(function()
        return uji.jobs.list()[2].state == "finished"
    end)
    ui.jobs:refresh()
    assert.equal(second.id, ui.jobs.selected, "the selection follows its job, not its row")
    assert.equal(first.id, ui.jobs.rows[1].id, "the job that still runs comes first")
    assert.equal(second.id, ui.jobs.rows[2].id)
end)

it("lets go of the panel when you type", { size = { 80, 12 }, timeout = 10 }, function()
    uji.jobs.configure({ wake = false })
    jobs.start({ command = "sleep 5", cwd = sandbox.work, background = true })
    require("uji.core.command").run("jobs")
    assert.is_not_nil(ui.jobs.selected)
    screen.press("a")
    assert.is_nil(ui.jobs.selected, "typing gives the prompt back")
    assert.is_false(ui.jobs.visible, "and closes the list")
    assert.equal("a", ui.composer:text())
end)
