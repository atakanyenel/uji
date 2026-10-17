local ito = require("ito")
local sys = require("uji.sys")

local M = {}

local JUNK = '}]",'

function M.object(raw)
    local text = ito.text.trim(raw)
    if text == "" then
        return {}
    end
    local ok, value = pcall(sys.json.decode, text)
    if ok then
        return value
    end
    local problem = value
    while text ~= "" and JUNK:find(text:sub(-1), 1, true) do
        text = ito.text.trim(text:sub(1, -2))
        local found, decoded = pcall(sys.json.decode, text)
        if found then
            return decoded
        end
    end
    return nil, problem
end

return M
