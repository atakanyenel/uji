local agent = require("support.agent")
local app = require("uji.core.app")
local paths = require("uji.core.paths")
local sandbox = require("support.sandbox")
local sys = require("uji.sys")

local TOOL = "reload_config"

local function offered()
    return require("uji.core.tool").get(TOOL) ~= nil
end

local function arrived(directory)
    uji.tool.remove(TOOL)
    app.session.directory = directory
    uji.emit("session_resumed", {})
    return offered()
end

local function called()
    return require("uji.core.tool").get(TOOL).run({}, {})
end

local function told()
    local text = {}
    for _, message in ipairs(agent.messages()) do
        if message.type == "context" then
            text[#text + 1] = message.text
        end
    end
    return table.concat(text, "\n")
end

local function has(value, part)
    return value ~= nil and value:find(part, 1, true) ~= nil
end

it("is offered only when uji runs in the config folder", function()
    local config = paths.config()
    assert.is_false(offered(), "this session runs in its work folder")
    assert.is_true(arrived(config), "a session in the config folder has it")
    assert.is_true(sys.fs.mkdir(config .. "/lua"))
    assert.is_true(arrived(config .. "/lua"), "and so has one in a folder inside it")
    assert.is_false(arrived(sandbox.work), "a session anywhere else does not")
    app.command = "run"
    assert.is_false(arrived(config), "uji run has no screen to restart")
end)

it("reloads when the turn ends and tells the model how the config loaded", function()
    if not sys.os.carry then
        assert.is_true(arrived(paths.config()))
        sandbox.write(paths.config() .. "/plugin/broken.lua", 'error("the theme is misspelt", 0)\n')
        assert.is_true(has(called(), "uji reloads when this turn ends"))
        assert.equal("", told(), "nothing happens while the turn runs")
        uji.emit("turn_finished", {})
        return
    end
    local report = told()
    assert.is_true(has(report, "uji reloaded and read the config again."), report)
    assert.is_true(has(report, "broken.lua: the theme is misspelt"), report)
    assert.is_true(has(report, "An error in the config is yours to fix"), report)
end)

it("says so when the config loaded without a notice", function()
    if not sys.os.carry then
        assert.is_true(arrived(paths.config()))
        called()
        uji.emit("turn_finished", {})
        return
    end
    assert.is_true(has(told(), "Loading it raised no notice."), told())
end)

it("stays with a session that /setup started, across the reload", function()
    if not sys.os.carry then
        require("uji.builtin.tools.reload_config").grant()
        assert.is_true(offered(), "setup hands it over wherever uji runs")
        called()
        uji.emit("turn_finished", {})
        return
    end
    assert.is_true(offered(), "the reload carried it over")
end)
