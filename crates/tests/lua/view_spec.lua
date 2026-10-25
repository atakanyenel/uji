local list = require("uji.utils.list")
local view = require("uji.core.agent.view")

local function entries(messages)
    local out = {}
    for index, message in ipairs(messages) do
        out[index] = { seq = index, message = message }
    end
    return out
end

local function built(messages)
    return view.build(entries(messages))
end

local function kinds(messages)
    return table.concat(
        list.mapped(messages, function(message)
            return message.type
        end),
        ","
    )
end

local call = { id = "c1", name = "run_command", arguments = "{}" }
local other = { id = "c2", name = "read_file", arguments = "{}" }

it("drops a call that no tool message answers", function()
    local messages = built({
        { type = "user", text = "hi" },
        { type = "assistant", text = "", tool_calls = { call } },
        { type = "assistant", text = "carrying on" },
    })
    assert.equal("user,assistant", kinds(messages))
    assert.is_nil(messages[2].tool_calls)
    for _, message in ipairs(messages) do
        assert.is_nil(message.tool_calls, "an unanswered call stays in the request")
    end
end)

it("keeps the calls a tool message answers and drops the rest", function()
    local messages = built({
        { type = "user", text = "hi" },
        { type = "assistant", text = "", tool_calls = { call, other } },
        { type = "tool", tool_call_id = "c2", content = "the file" },
        { type = "user", text = "next" },
    })
    assert.same({ other }, messages[2].tool_calls)
    assert.equal("tool", messages[3].type)
    assert.equal("c2", messages[3].tool_call_id)
end)

it("drops a tool message that answers no call above it", function()
    local messages = built({
        { type = "user", text = "hi" },
        { type = "tool", tool_call_id = "gone", content = "stray" },
        { type = "assistant", text = "done" },
    })
    assert.equal("user,assistant", kinds(messages))
end)

it("keeps a call answered after the job and shell lines the model never sees", function()
    local messages = built({
        { type = "user", text = "hi" },
        { type = "assistant", text = "", tool_calls = { call } },
        { type = "job", id = 1, state = "finished", code = 0 },
        { type = "tool", tool_call_id = "c1", content = "output" },
        { type = "assistant", text = "done" },
    })
    assert.equal(1, #messages[2].tool_calls)
    assert.equal("tool", messages[3].type)
end)

it("keeps the words of a call it repaired", function()
    local messages = built({
        { type = "user", text = "hi" },
        { type = "assistant", text = "let me look", tool_calls = { call } },
        { type = "user", text = "next" },
    })
    assert.equal("let me look", messages[2].text)
    assert.is_nil(messages[2].tool_calls)
end)
