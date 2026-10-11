local packs = require("uji.core.packs")
local sandbox = require("support.sandbox")

local function pack(names)
    local env = sandbox.dir("packs")
    for _, name in ipairs(names) do
        sandbox.write(env.root .. "/lua/" .. name .. "/init.lua", "return {}")
    end
    packs.add_root(env.root)
    return env.root
end

local function ran(line)
    local sent
    local submit = uji.session.submit
    uji.session.submit = function(text)
        sent = text
    end
    require("uji.core.command").run(line)
    uji.session.submit = submit
    return sent
end

local function has(value, part)
    return value ~= nil and value:find(part, 1, true) ~= nil
end

local function turn()
    local _, gathered = require("uji.core.context").gather("")
    local text = {}
    for _, message in ipairs(gathered) do
        text[#text + 1] = message.text
    end
    return table.concat(text, "\n")
end

it("keeps the map out of the chat and gives it to the turn", function()
    local root = pack({ "widget" })
    local sent = ran("setup set up widget with a blue backend")
    assert.equal("set up widget with a blue backend", sent, "the transcript keeps the request alone")
    local briefed = turn()
    assert.is_true(has(briefed, "Their install:"), briefed)
    assert.is_true(has(briefed, root), briefed)
    assert.is_true(has(briefed, "not set up: widget"), briefed)
    assert.is_true(has(briefed, "Request: set up widget with a blue backend"), briefed)
    assert.equal("", turn(), "the map goes with one turn only")
end)

it("offers what a pack has but nothing set up, and sends the choice", function()
    pack({ "widget" })
    local asked
    local select = uji.ui.select
    uji.ui.select = function(opts)
        asked = opts
        return "widget"
    end
    local sent = ran("setup")
    uji.ui.select = select
    assert.equal("review what is set up", asked.items[1])
    assert.is_true(has(table.concat(asked.items, "\n"), "widget"), table.concat(asked.items, ", "))
    assert.equal("Set up widget for me.", sent)
    assert.is_true(has(turn(), "Request: Set up widget for me."))
end)

it("hides a review behind a short line", function()
    pack({})
    local select = uji.ui.select
    uji.ui.select = function()
        return "review what is set up"
    end
    local sent = ran("setup")
    uji.ui.select = select
    assert.equal("Review my setup.", sent)
    assert.is_true(has(turn(), "Change nothing."))
end)

it("asks a question as a choice and reports what the person picked", function()
    local ask = require("uji.core.tool").get("ask_user")
    local asked
    local select = uji.ui.select
    uji.ui.select = function(opts)
        asked = opts
        return "searxng"
    end
    local result = ask.run({ question = "which backend?", options = { "exa", "searxng" } }, {})
    uji.ui.select = select
    assert.equal("which backend?", asked.title)
    assert.same({ "exa", "searxng" }, asked.items)
    assert.equal("the person chose: searxng", result)
end)

it("asks a question that the person types, and reports a closed one", function()
    local ask = require("uji.core.tool").get("ask_user")
    local prompt = uji.ui.prompt
    uji.ui.prompt = function(opts)
        return opts.title == "which url?" and "https://search.example" or nil
    end
    assert.equal("the person answered: https://search.example", ask.run({ question = "which url?" }, {}))
    assert.equal("the person closed the question without answering", ask.run({ question = "which key?" }, {}))
    assert.equal("error: ask_user needs a question", ask.run({}, {}))
    uji.ui.prompt = prompt
end)
