local ito = require("ito")
local url = require("uji.utils.url")
local Wrapped = require("uji.core.ui.transcript.wrapped")

return ito.view(function(props)
    local ctx = ito.theme()
    return Wrapped({ text = url.spans(props.text), mark = ctx.symbols.notice, style = ctx.styles.notice })
end)
