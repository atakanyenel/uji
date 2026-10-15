local paths = require("uji.core.paths")
local sys = require("uji.sys")

local M = {}

local NAME = "auth.env"
local EXPORT = "^export%s+"
local PAIR = "^([%w_]+)%s*=%s*(.*)$"
local COMMENT = "%s+#.*$"

function M.path(set)
    return sys.os.expand(sys.os.env("UJI_AUTH_FILE") or set or sys.fs.join(paths.config(), NAME))
end

local function unquoted(value)
    local quote = value:sub(1, 1)
    if quote ~= '"' and quote ~= "'" then
        return (value:gsub(COMMENT, ""))
    end
    if #value < 2 or value:sub(-1) ~= quote then
        return nil
    end
    return value:sub(2, -2)
end

function M.values(path)
    if not sys.fs.stat(path) then
        return {}
    end
    local text, err = sys.fs.read(path)
    if not text then
        return nil, tostring(err)
    end
    local values = {}
    local number = 0
    for line in (text .. "\n"):gmatch("(.-)\n") do
        number = number + 1
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
            local name, value = trimmed:gsub(EXPORT, ""):match(PAIR)
            value = name and unquoted(value)
            if value == nil then
                return nil, "line " .. number .. " is not a NAME=value line"
            end
            values[name] = value
        end
    end
    return values
end

return M
