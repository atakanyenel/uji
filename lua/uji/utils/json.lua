local sys = require("uji.sys")

local M = {}

local JUNK = { ["}"] = true, ["]"] = true, ['"'] = true, [","] = true }
local ROUNDS = 3

local function trimmed(text)
    return (text:match("^%s*(.-)%s*$"))
end

function M.object(raw)
    local text = trimmed(raw)
    if text == "" then
        return {}
    end
    local ok, value = pcall(sys.json.decode, text)
    if ok then
        return value
    end
    local problem = value
    for _ = 1, ROUNDS do
        if not JUNK[text:sub(-1)] then
            break
        end
        text = trimmed(text:sub(1, -2))
        local tried, found = pcall(sys.json.decode, text)
        if tried then
            return found
        end
    end
    return nil, problem
end

return M
