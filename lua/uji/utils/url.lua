local sys = require("uji.sys")

local M = {}

local MARKS = "()[]{}<>\"'.,;:!?"

local function punctuation(char)
    return MARKS:find(char, 1, true) ~= nil
end

local function separates(code)
    return code <= 32 or code == 127
end

local function trimmed(word)
    local first, last = 1, #word
    while first <= last and punctuation(word:sub(first, first)) do
        first = first + 1
    end
    while last >= first and punctuation(word:sub(last, last)) do
        last = last - 1
    end
    return word:sub(first, last), first - 1
end

function M.spans(text)
    local length = #text
    local out, at, index = {}, 1, 1
    while index <= length do
        if separates(text:byte(index)) then
            index = index + 1
        else
            local start = index
            while index <= length and not separates(text:byte(index)) do
                index = index + 1
            end
            local found, before = trimmed(text:sub(start, index - 1))
            local link = sys.net.url(found)
            if link then
                if start + before > at then
                    out[#out + 1] = { text:sub(at, start + before - 1) }
                end
                out[#out + 1] = { found, link = link.uri }
                at = start + before + #found
            end
        end
    end
    if at <= length then
        out[#out + 1] = { text:sub(at) }
    end
    return out
end

return M
