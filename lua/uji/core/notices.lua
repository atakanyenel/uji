local diagnostics = require("uji.core.diagnostics")
local event = require("uji.core.event")

local M = { pending = {}, delivering = false }

function M.push(message)
    message = tostring(message)
    M.pending[#M.pending + 1] = message
    if M.delivering then
        return
    end
    M.delivering = true
    local ok, err = pcall(event.emit, "notice", { text = message })
    M.delivering = false
    if not ok then
        diagnostics.report("notice", diagnostics.capture(err))
    end
end

function M.take()
    local taken = M.pending
    M.pending = {}
    return taken
end

return M
