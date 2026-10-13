local default = require("uji.themes.default")
local diagnostics = require("uji.core.diagnostics")
local paths = require("uji.core.paths")
local screen = require("support.ui")
local sys = require("uji.sys")
local ui = require("uji.core.ui")
local wait = require("support.wait")

local function has(value, part)
    return tostring(value):find(part, 1, true) ~= nil
end

it("records a broken screen once with its traceback, and shows no notice", { size = { 40, 10 } }, function()
    uji.ui.configure({
        theme = default({
            views = {
                [uji.ui.Screen] = function()
                    return { "a table" }
                end,
            },
        }),
    })
    screen.rows(true)
    screen.rows(true)
    local entries = uji.diagnostics.list()
    assert.equal(1, #entries)
    assert.equal("screen", entries[1].source)
    assert.is_true(has(entries[1].text, "a view must give a view, not a table"))
    assert.is_true(has(entries[1].text, "stack traceback"))
    ui:take_notices()
    assert.same({}, ui.notices)
end)

it("records a broken view once however many messages use it", { size = { 40, 20 } }, function()
    uji.ui.configure({
        theme = default({
            views = {
                [uji.ui.UserMessage] = function()
                    error("no user today", 0)
                end,
            },
        }),
    })
    for index = 1, 5 do
        require("uji.core.app").session:append({ type = "user", text = "hello " .. index })
    end
    screen.rows(true)
    local entries = uji.diagnostics.list()
    assert.equal(1, #entries)
    assert.equal("view", entries[1].source)
    assert.is_true(has(entries[1].text, "no user today"))
end)

it("lists the newest first and shows a whole entry in the preview", function()
    diagnostics.report("render", { text = "older", trace = "stack traceback:\n\tsomewhere" })
    diagnostics.report("modal", { text = "newer\nsecond line" })
    local asked
    uji.ui.pick = function(opts)
        asked = opts
    end
    require("uji.core.command").run("diagnostics")
    assert.equal(2, #asked.items)
    assert.is_true(has(asked.label(asked.items[1]), "modal  newer"))
    assert.is_true(has(asked.label(asked.items[2]), "render  older"))
    assert.same({ "older", "stack traceback:", "\tsomewhere" }, asked.preview(asked.items[2]))
end)

it("says when there is nothing to show", function()
    require("uji.core.command").run("diagnostics")
    ui:take_notices()
    assert.is_true(has(table.concat(ui.notices, "\n"), "no diagnostics yet"))
end)

local function copied_to()
    local copied = {}
    sys.clipboard.set = function(value)
        copied.value = value
        return true
    end
    return copied
end

-- Opens the picker the way `/diagnostics` does and hands back the promise that
-- settles when the command is done, so a test can press keys at it meanwhile.
local function opened()
    local finished = sys.promise()
    sys.task.spawn(function()
        require("uji.core.command").run("diagnostics")
        finished:resolve()
    end)
    wait.eventually(function()
        return ui.modal ~= nil
    end)
    return finished
end

local function entry_text(entry)
    return entry.time .. " " .. entry.source .. "\n" .. entry.text
end

it("copies the entry enter takes out of the picker, and says so", { size = { 60, 12 } }, function()
    diagnostics.report("render", { text = "older", trace = "stack traceback:\n\tsomewhere" })
    local copied = copied_to()
    local finished = opened()
    screen.press("enter")
    finished:await()
    local entry = uji.diagnostics.list()[1]
    assert.equal(entry_text(entry), copied.value, "the whole entry goes to the clipboard")
    assert.equal("copied 4 line(s)", ui.flashed.text, "and the flash counts what went")
    assert.is_nil(ui.modal, "the picker closes")
end)

it("copies the entry the cursor is on, not the newest one", { size = { 60, 12 } }, function()
    diagnostics.report("render", { text = "older" })
    diagnostics.report("screen", { text = "newer" })
    local copied = copied_to()
    local finished = opened()
    screen.press("down")
    screen.press("enter")
    finished:await()
    local entries = uji.diagnostics.list()
    assert.equal(2, #entries)
    assert.equal(entry_text(entries[2]), copied.value, "the second entry is the older one")
    assert.is_true(copied.value:find("older", 1, true) ~= nil, copied.value)
end)

it("copies nothing when esc leaves the picker", { size = { 60, 12 } }, function()
    diagnostics.report("render", { text = "older" })
    local copied = copied_to()
    local finished = opened()
    screen.press("esc")
    finished:await()
    assert.is_nil(copied.value)
    assert.is_nil(ui.modal, "the picker closes")
end)

it("keeps the log to the newest entries", function()
    local big = string.rep("x", 400 * 1024)
    for index = 1, 4 do
        diagnostics.report("render", { text = index .. big })
    end
    local entries = uji.diagnostics.list()
    assert.equal("4", entries[1].text:sub(1, 1))
    assert.is_true(#entries < 4)
    assert.is_true(sys.fs.stat(paths.data() .. "/diagnostics.log").size <= 1024 * 1024)
end)
