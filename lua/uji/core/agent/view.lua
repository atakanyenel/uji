local list = require("uji.utils.list")
local sys = require("uji.sys")
local tables = require("uji.core.tables")
local tokens = require("uji.core.agent.tokens")

local SUMMARY_HEADER = "Summary of the earlier part of this conversation:"
local FILES_HEADER = "Files touched so far:"

local M = {}

local TRANSCRIPT_ONLY = { shell = true, job = true }

function M.transcript_only(kind)
    return TRANSCRIPT_ONLY[kind] == true
end

function M.summary_message(summary, files)
    local text = SUMMARY_HEADER .. "\n\n" .. summary
    if files and #files > 0 then
        text = text .. "\n\n" .. FILES_HEADER .. " " .. table.concat(files, ", ")
    end
    return { type = "user", text = text }
end

function M.files_touched(messages)
    local out, seen = {}, {}
    for _, message in ipairs(messages) do
        if message.type == "assistant" then
            for _, call in ipairs(message.tool_calls or {}) do
                local ok, args = pcall(sys.json.decode, call.arguments, { nulls = false })
                local found = ok and type(args) == "table" and args.path
                if type(found) == "string" and not seen[found] then
                    seen[found] = true
                    out[#out + 1] = found
                end
            end
        end
    end
    return out
end

function M.merge_files(into, extra)
    local known = {}
    for _, found in ipairs(into) do
        known[found] = true
    end
    for _, found in ipairs(extra or {}) do
        if not known[found] then
            known[found] = true
            into[#into + 1] = found
        end
    end
    return into
end

local function paired(messages)
    local out, index = {}, 1
    while index <= #messages do
        local message = messages[index]
        local calls = message.type == "assistant" and message.tool_calls or nil
        if calls and #calls > 0 then
            local answered, last = {}, index
            while messages[last + 1] and messages[last + 1].type == "tool" do
                last = last + 1
                answered[messages[last].tool_call_id] = true
            end
            local kept = list.filtered(calls, function(call)
                return answered[call.id] == true
            end)
            local ids = {}
            for _, call in ipairs(kept) do
                ids[call.id] = true
            end
            if #kept > 0 or (message.text or "") ~= "" then
                out[#out + 1] = tables.with(message, "tool_calls", #kept > 0 and kept or nil)
            end
            for at = index + 1, last do
                if ids[messages[at].tool_call_id] then
                    out[#out + 1] = messages[at]
                end
            end
            index = last + 1
        else
            if message.type ~= "tool" then
                out[#out + 1] = message
            end
            index = index + 1
        end
    end
    return out
end

function M.build(stored)
    local at = tokens.last_compaction(stored)
    local out = {}
    if at then
        local marker = stored[at].message
        out[1] = M.summary_message(marker.summary, marker.files)
    end
    for index = (at or 0) + 1, #stored do
        local message = stored[index].message
        local kind = message.type
        if kind == "context" then
            out[#out + 1] = { type = "user", text = message.text }
        elseif kind ~= "compaction" and not M.transcript_only(kind) then
            out[#out + 1] = message
        end
    end
    return paired(out)
end

local CUTS = { user = true, assistant = true, context = true, error = true }
local STARTS = { user = true, context = true }

local function cut_point(message)
    return CUTS[message.type] == true
end

local function turn_start(message)
    return STARTS[message.type] == true
end

function M.cut_index(messages, keep_recent)
    local points = {}
    for index, message in ipairs(messages) do
        if cut_point(message) then
            points[#points + 1] = index
        end
    end
    if #points == 0 then
        return nil
    end
    local cut = points[1]
    local kept = 0
    for index = #messages, 1, -1 do
        kept = kept + tokens.weigh(messages[index])
        if kept >= keep_recent then
            local found
            for _, point in ipairs(points) do
                if point >= index then
                    found = point
                    break
                end
            end
            cut = found or points[#points]
            break
        end
    end
    if cut > 1 then
        return cut
    end
end

function M.find_cut(stored, keep_recent)
    local marker = tokens.last_compaction(stored)
    local offset = marker or 0
    local messages = {}
    for index = offset + 1, #stored do
        messages[#messages + 1] = stored[index].message
    end
    local first_kept = M.cut_index(messages, keep_recent)
    if not first_kept then
        return nil
    end
    local prefix
    if not turn_start(messages[first_kept]) then
        local start
        for index = first_kept - 1, 1, -1 do
            if turn_start(messages[index]) then
                start = index
                break
            end
        end
        if start then
            prefix = { from = offset + start, to = offset + first_kept - 1 }
        end
    end
    return {
        from = marker or 1,
        through = stored[offset + first_kept - 1].seq,
        compacted = offset + first_kept - 1,
        history_to = prefix and prefix.from - 1 or offset + first_kept - 1,
        prefix = prefix,
        span = offset + first_kept - (marker or 1),
    }
end

return M
