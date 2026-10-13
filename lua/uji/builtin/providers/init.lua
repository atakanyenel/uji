local NAMESPACE = "uji.builtin.providers"
local PREFIX = NAMESPACE .. "."

local M = {}

local MODULES = uji.modules(NAMESPACE)
local NAMED = {}
for _, module in ipairs(MODULES) do
    NAMED[module:sub(#PREFIX + 1)] = module
end

function M.load(id)
    local module = NAMED[id]
    if not module then
        return false
    end
    require(module)
    return true
end

function M.all()
    for _, module in ipairs(MODULES) do
        require(module)
    end
end

return M
