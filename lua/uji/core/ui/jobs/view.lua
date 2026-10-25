local Hints = require("uji.core.ui.views.hints")
local host = require("uji.core.ui.host")
local ito = require("ito")
local jobs = require("uji.core.jobs")
local list = require("uji.utils.list")

local function row(ctx, panel, item)
    local selected = panel.selected == item.id
    local glyph, style = ctx.symbols.done, ctx.styles.call.done
    if item.running then
        glyph, style = ctx.symbols.running, ctx.styles.accent
    elseif item.stopped then
        glyph, style = ctx.symbols.stopped, ctx.styles.warning
    elseif item.failed then
        glyph, style = ctx.symbols.failed, ctx.styles.error
    end
    local line = ito.HStack({
        ito.Text(ctx.symbols.pointer):style(ctx.styles.confirm_selected):padding({ trailing = 1 }):invisible(not selected),
        ito.Text(glyph):style(style):padding({ trailing = 1 }),
        ito.Text(item.name):style(ctx.styles.accent),
        ito.Text("  " .. item.detail):style(ctx.styles.muted):grow(),
        ito.Text(item.elapsed .. "s"):style(ctx.styles.dim),
    })
    if selected then
        line:background(ctx.styles.selected)
    end
    return line:on_tap(function()
        panel.selected = item.id
        panel:open(item)
    end):hover(ctx.styles.selected)
end

return ito.view(function()
    local panel = host.Host.current.jobs
    local ctx = ito.theme()
    if not panel.visible then
        if not panel.hint then
            return nil
        end
        return ito.Text(panel.hint.text):style(ctx.styles.dim):padding({ leading = 1 })
    end
    local words = ctx.text
    local content = {
        ito.VStack(list.mapped(panel.rows, function(item)
            return row(ctx, panel, item)
        end)),
    }
    if panel.more > 0 then
        local left_out = string.format(words.jobs_more, panel.more)
        content[#content + 1] = ito.Text(ctx.symbols.more .. " " .. left_out):style(ctx.styles.dim)
    end
    content[#content + 1] = Hints({
        { words.key_open, words.output },
        { words.key_stop, words.stop },
        { words.key_quit, words.close },
    })
    local count = string.format(words.jobs_count, #jobs.running(), #panel.rows + panel.more)
    return ito.VStack(content)
        :padding({ horizontal = 1 })
        :border(ctx.borders.plain, { color = ctx.colors.accent })
        :title({
            { words.jobs_title, ctx.styles.bold },
            { " " .. ctx.symbols.separator .. " " .. count, ctx.styles.muted },
        })
        :spacing(1)
end)
