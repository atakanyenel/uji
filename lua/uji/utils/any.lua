local check = require("uji.core.check")
local class = require("uji.core.class")
local sys = require("uji.sys")

local Any = class()

local function pattern(value)
    if #value >= 2 and value:sub(1, 1) == "/" and value:sub(-1) == "/" then
        return sys.regex(value:sub(2, -2))
    end
    if value:find("[%*%?%[]") then
        return sys.glob(value)
    end
    return {
        test = function(_, subject)
            return subject == value
        end,
    }
end

function Any:init(value)
    self.value = value
    local wanted = type(value) == "table" and value.pattern or value
    self.message = type(value) == "table" and value.message or nil
    if type(wanted) == "function" then
        self.handler = wanted
    elseif type(wanted) == "string" then
        self.tests = { pattern(wanted) }
        local expanded = sys.os.expand(wanted)
        if expanded ~= wanted then
            self.tests[2] = pattern(expanded)
        end
    end
end

function Any:valid()
    return self.handler ~= nil or self.tests ~= nil
end

function Any:call(...)
    local value = self.value
    if check.callable(value) then
        return value(...)
    end
    return value
end

function Any:handle(subject)
    local handler = self.handler
    if handler then
        return handler(subject)
    end
    for _, found in ipairs(self.tests or {}) do
        if found:test(subject) then
            return true
        end
    end
    return false
end

return Any
