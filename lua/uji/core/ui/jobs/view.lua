local host = require("uji.core.ui.host")
local ito = require("ito")
local list = require("uji.utils.list")

return ito.view(function()
    local jobs = host.Host.current.jobs
    local ctx = ito.theme()
    if #jobs.rows == 0 then
        if not jobs.hint then
            return nil
        end
        return ito.Text(jobs.hint.text):style(ctx.styles.dim):padding({ leading = 1 })
    end
    return ito.VStack(list.mapped(jobs.rows, function(row)
        local selected = jobs.selected == row.id
        local glyph, style = ctx.symbols.done, ctx.styles.call.done
        if row.running then
            glyph, style = ctx.symbols.running, ctx.styles.accent
        elseif row.failed then
            glyph, style = ctx.symbols.failed, ctx.styles.error
        end
        return ito.HStack({
            ito.Text(ctx.symbols.pointer):style(ctx.styles.confirm_selected):padding({ trailing = 1 }):invisible(not selected),
            ito.Text(glyph):style(style):padding({ trailing = 1 }),
            ito.Text(row.name):style(ctx.styles.accent),
            ito.Text("  " .. row.detail):style(ctx.styles.muted):grow(),
            ito.Text(row.elapsed .. "s"):style(ctx.styles.dim):padding({ trailing = 1 }),
        })
            :on_tap(function()
                jobs.selected = row.id
                jobs:open(row)
            end)
            :hover(ctx.styles.selected)
    end))
end)
