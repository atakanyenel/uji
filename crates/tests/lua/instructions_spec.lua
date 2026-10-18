local app = require("uji.core.app")
local instructions = require("uji.core.instructions")
local notices = require("uji.core.notices")
local sandbox = require("support.sandbox")
local sys = require("uji.sys")

local USER = sandbox.cfg .. "/AGENTS.md"
local ABOVE = sandbox.root .. "/CLAUDE.md"
local AGENTS = sandbox.work .. "/AGENTS.md"
local CLAUDE = sandbox.work .. "/CLAUDE.md"
local OVERRIDE = sandbox.work .. "/AGENTS.override.md"

before_each(function()
    for _, path in ipairs({ USER, ABOVE, AGENTS, CLAUDE, OVERRIDE }) do
        sys.fs.remove(path)
    end
    notices.take()
end)

local function order(directory)
    local paths = {}
    for _, file in ipairs(instructions.files(directory)) do
        paths[#paths + 1] = file.path
    end
    return paths
end

it("reads one file per folder, the first name it finds", function()
    sandbox.write(AGENTS, "- agents rules")
    sandbox.write(CLAUDE, "- claude rules")
    assert.same({ AGENTS }, order(sandbox.work))
    sandbox.write(OVERRIDE, "- override rules")
    assert.same({ OVERRIDE }, order(sandbox.work))
end)

it("reads the config file first, then the folders from the root down", function()
    sandbox.write(USER, "- user rules")
    sandbox.write(ABOVE, "- above rules")
    sandbox.write(AGENTS, "- work rules")
    assert.same({ USER, ABOVE, AGENTS }, order(sandbox.work))
end)

it("puts them in the system prompt, named with the path they came from", function()
    sandbox.write(AGENTS, "- run just test before a commit")
    app.attach(app.session)
    local system = app.agent:prompt("hello")
    assert.is_true(system:find("Project-specific instructions and guidelines:", 1, true) ~= nil)
    assert.is_true(system:find('<project_instructions path="' .. AGENTS .. '">', 1, true) ~= nil)
    assert.is_true(system:find("- run just test before a commit", 1, true) ~= nil)
end)

it("passes over a folder with no instruction file without a word", function()
    assert.equal(0, #instructions.files(sandbox.work))
    assert.is_nil(instructions.section(sandbox.work))
    assert.equal(0, #notices.take())
end)
