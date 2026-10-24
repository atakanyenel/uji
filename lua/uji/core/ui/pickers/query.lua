local ito = require("ito")
local typed = require("uji.core.ui.typed")

return ito.view(function(props)
    local ctx = ito.theme()
    local styles = ctx.styles
    return ito.HStack({
        ito.Text(ctx.symbols.prompt):style(styles.accent):padding({ leading = props.indent or 0, trailing = 1 }),
        ito.Text(typed.spans(ctx, props.field, { text = styles.text, cursor = styles.cursor })),
    })
end)
