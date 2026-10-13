local app = require("uji.core.app")
local Custom = require("uji.core.ui.transcript.custom")
local host = require("uji.core.ui.host")
local ito = require("ito")
local Queued = require("uji.core.ui.transcript.queued")
local Running = require("uji.core.ui.transcript.running")

return ito.view(function()
    local ui = host.Host.current
    local gap = ito.theme().limits.section_gap
    local rows = {}
    local running = ui.running
    if running then
        rows[#rows + 1] = ito.Spacer():height(gap)
        rows[#rows + 1] = Running({ name = running.name, line = running.line })
    end
    local queued = app.agent and app.agent.queue or {}
    if #queued > 0 then
        rows[#rows + 1] = ito.Spacer():height(gap)
        for _, item in ipairs(queued) do
            rows[#rows + 1] = Custom({ payload = { type = "queued", text = item.text }, fallback = Queued({ text = item.text }) })
        end
    end
    return ito.VStack(rows)
end)
