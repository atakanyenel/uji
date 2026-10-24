local app = require("uji.core.app")
local check = require("uji.core.check")
local host = require("uji.core.ui.host")
local ito = require("ito")
local jobs = require("uji.core.jobs")
local model = require("uji.core.model")
local sys = require("uji.sys")
local words = require("uji.utils.text")

local CROWDED = 80

return ito.view(function()
    local ui = host.Host.current
    local shown = ui.status_line
    if shown ~= nil then
        if check.callable(shown) then
            return shown()
        end
        return shown
    end
    local session = app.session
    if not session then
        return nil
    end
    local ctx = ito.theme()
    local row = {}
    local function add(view)
        if #row > 0 then
            row[#row + 1] = ito.Text("  " .. ctx.symbols.separator .. "  "):style(ctx.styles.dim)
        end
        row[#row + 1] = view
    end
    add(ito.Text(sys.os.shorten(session.directory)):style(ctx.styles.muted))
    local current = model.current
    if current.model ~= "" then
        add(ito.Text(current.model):style(ctx.styles.accent))
    end
    if current.effort and current.effort ~= "off" then
        add(ito.Text(current.effort):style(ctx.styles.muted))
    end
    local running = #jobs.running()
    if running > 0 then
        add(ito.Text(words.count(running, "job"))
            :style(ctx.styles.accent)
            :on_tap(function()
                ui.jobs:show()
            end)
            :hover(ctx.styles.selected))
    end
    local budget = model.budget()
    local usable = budget and model.usable(budget)
    if usable and usable > 0 then
        local pct = math.floor(session:used_tokens() / usable * 100 + 0.5)
        add(ito.Text(string.format("context %d%%", pct)):style(pct >= CROWDED and ctx.styles.notice or ctx.styles.muted))
    end
    return ito.HStack(row):padding({ horizontal = 1 }):height(1)
end)
