local ito = require("ito")

return ito.view(function(props)
    local ctx = ito.theme()
    local separator = " " .. ctx.symbols.compacting .. " "
    local pieces = { "esc cancels" }
    if props.messages then
        pieces[#pieces + 1] = props.messages .. " earlier messages"
    end
    pieces[#pieces + 1] = props.elapsed .. "s"
    local detail = separator .. table.concat(pieces, separator)
    return ito.HStack({
        ito.Text(props.frame):style(ctx.styles.accent):padding({ trailing = 1 }),
        ito.Text(ctx.text.compacting):style(ctx.styles.accent),
        ito.Text(detail):style(ctx.styles.muted),
    })
end)
