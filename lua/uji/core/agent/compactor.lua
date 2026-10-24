local list = require("uji.utils.list")
local model = require("uji.core.model")
local sys = require("uji.sys")
local tables = require("uji.core.tables")

local TOOL_RESULT_MAX_CHARS = 2000

local SYSTEM = "You are a context summarization assistant. Your task is to read a conversation "
    .. "between a user and an AI assistant, then produce a structured summary following the exact "
    .. "format specified.\n\nDo NOT continue the conversation. Do NOT respond to any questions in "
    .. "the conversation. ONLY output the structured summary."

local PROMPT =
    [[The messages above are a conversation to summarize. Create a structured context checkpoint summary that another LLM will use to continue the work.

Use this EXACT format:

## Goal
[What is the user trying to accomplish? Can be multiple items if the session covers different tasks.]

## Constraints & Preferences
- [Any constraints, preferences, or requirements mentioned by user]
- [Or "(none)" if none were mentioned]

## Progress
### Done
- [x] [Completed tasks/changes]

### In Progress
- [ ] [Current work]

### Blocked
- [Issues preventing progress, if any]

## Key Decisions
- **[Decision]**: [Brief rationale]

## Next Steps
1. [Ordered list of what should happen next]

## Critical Context
- [Any data, examples, or references needed to continue]
- [Or "(none)" if not applicable]

Keep each section concise. Preserve exact file paths, function names, and error messages.]]

local UPDATE_PROMPT =
    [[The messages above are NEW conversation messages to incorporate into the existing summary provided in <previous-summary> tags.

Update the existing structured summary with new information. RULES:
- PRESERVE all existing information from the previous summary
- ADD new progress, decisions, and context from the new messages
- UPDATE the Progress section: move items from "In Progress" to "Done" when completed
- UPDATE "Next Steps" based on what was accomplished
- PRESERVE exact file paths, function names, and error messages
- If something is no longer relevant, you may remove it

Use this EXACT format:

## Goal
[Preserve existing goals, add new ones if the task expanded]

## Constraints & Preferences
- [Preserve existing, add new ones discovered]

## Progress
### Done
- [x] [Include previously done items AND newly completed items]

### In Progress
- [ ] [Current work - update based on progress]

### Blocked
- [Current blockers - remove if resolved]

## Key Decisions
- **[Decision]**: [Brief rationale] (preserve all previous, add new)

## Next Steps
1. [Update based on current state]

## Critical Context
- [Preserve important context, add new if needed]

Keep each section concise. Preserve exact file paths, function names, and error messages.]]

local PREFIX_PROMPT =
    [[The messages above are earlier context from an ongoing conversation. Later messages are stored separately and do not need to be reconstructed.

Create a concise checkpoint of the user's request and the progress shown above. This checkpoint will be placed before the later messages so the conversation can continue with the necessary context.

## Original Request
[What did the user ask for?]

## Progress So Far
- [Key decisions and work completed in these messages]

## Context Needed to Continue
- [Information from these messages needed to understand the later work]

Only summarize information explicitly present above. Do not infer or recreate later messages.]]

local M = {}

local function truncate(text, max)
    if #text <= max then
        return text
    end
    return text:sub(1, max) .. "\n\n[... " .. (#text - max) .. " more characters truncated]"
end

local function arguments(call)
    local ok, args = pcall(sys.json.decode, call.arguments, { nulls = false })
    if not ok or type(args) ~= "table" then
        return ""
    end
    local fields = list.mapped(tables.keys(args), function(name)
        return name .. "=" .. sys.json.encode(args[name])
    end)
    return table.concat(fields, ", ")
end

local function calls(message)
    return list.mapped(message.tool_calls or {}, function(call)
        return call.name .. "(" .. arguments(call) .. ")"
    end)
end

function M.transcript(messages)
    local parts = {}
    for _, message in ipairs(messages) do
        local kind = message.type
        if kind == "user" or kind == "context" then
            local text = message.text or ""
            if text:find("%S") then
                parts[#parts + 1] = "[User]: " .. text
            end
        elseif kind == "assistant" then
            local reasoning = message.reasoning
            if reasoning and reasoning:find("%S") then
                parts[#parts + 1] = "[Assistant thinking]: " .. reasoning
            end
            local text = message.text or ""
            if text:find("%S") then
                parts[#parts + 1] = "[Assistant]: " .. text
            end
            local listed = calls(message)
            if #listed > 0 then
                parts[#parts + 1] = "[Assistant tool calls]: " .. table.concat(listed, "; ")
            end
        elseif kind == "tool" then
            local text = message.content or ""
            if text:find("%S") then
                parts[#parts + 1] = "[Tool result]: " .. truncate(text, TOOL_RESULT_MAX_CHARS)
            end
        elseif kind == "error" then
            local text = message.text or ""
            if text:find("%S") then
                parts[#parts + 1] = "[Error]: " .. text
            end
        end
    end
    return table.concat(parts, "\n\n")
end

local function retryable(failure)
    return type(failure) == "table"
        and failure.kind == "http"
        and (failure.status == nil or failure.status == 408 or failure.status == 429 or failure.status >= 500)
end

local function complete(text)
    local answer, failure
    for attempt = 1, 2 do
        answer, failure = model.generate({
            system = SYSTEM,
            messages = { { type = "user", text = text } },
            standalone = true,
        })
        if answer or attempt == 2 or not retryable(failure) then
            break
        end
        sys.sleep(1)
    end
    if not answer then
        return nil, failure and tostring(failure.message or failure.kind) or "the model did not answer"
    end
    if answer.hit_limit then
        return nil, "generation hit the token cap and the summary is incomplete"
    end
    local summary = (answer.text or ""):match("^%s*(.-)%s*$")
    if summary == "" then
        return nil, "the model returned an empty summary"
    end
    return summary, answer.usage
end

local function history_prompt(messages, previous)
    local text = "<conversation>\n" .. M.transcript(messages) .. "\n</conversation>\n\n"
    if previous then
        text = text .. "<previous-summary>\n" .. previous .. "\n</previous-summary>\n\n"
    end
    return text .. (previous and UPDATE_PROMPT or PROMPT)
end

local function prefix_prompt(messages)
    return "# Conversation\n" .. M.transcript(messages) .. "\n\n# Instructions\n" .. PREFIX_PROMPT
end

local function summed(left, right)
    local out = tables.copy(left or {})
    for name, value in pairs(right or {}) do
        out[name] = (out[name] or 0) + value
    end
    return out
end

function M.generate(messages, previous, prefix)
    local summary = "No prior history."
    local usage
    if #messages > 0 then
        local done, spent = complete(history_prompt(messages, previous))
        if not done then
            return nil, spent
        end
        summary, usage = done, spent
    end
    if prefix and #prefix > 0 then
        local done, spent = complete(prefix_prompt(prefix))
        if not done then
            return nil, spent
        end
        summary = summary .. "\n\n---\n\n**Turn Context (split turn):**\n\n" .. done
        usage = summed(usage, spent)
    end
    return { summary = summary, usage = usage }
end

return M
