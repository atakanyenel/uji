local ito = require("ito")

return ito.view(function(props)
    local ctx = ito.theme()
    local styles = ctx.styles
    local children = {}
    for index, entry in ipairs(props) do
        if index > 1 then
            children[#children + 1] = ito.Text(ctx.symbols.separator):style(styles.muted)
        end
        children[#children + 1] = ito.HStack({
            ito.Text(entry[1]):style(styles.highlight),
            ito.Text(entry[2]):style(styles.muted),
        }):spacing(1)
    end
    return ito.HStack(children):spacing(1)
end)
