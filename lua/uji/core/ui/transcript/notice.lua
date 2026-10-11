local ito = require("ito")
local Wrapped = require("uji.core.ui.transcript.wrapped")

local function linked(text)
    local spans, at = {}, 1
    for first, url, after in text:gmatch("()(https?://[^%s%c]+)()") do
        if first > at then
            spans[#spans + 1] = { text:sub(at, first - 1) }
        end
        spans[#spans + 1] = { url, link = url }
        at = after
    end
    if at == 1 then
        return text
    end
    if at <= #text then
        spans[#spans + 1] = { text:sub(at) }
    end
    return spans
end

return ito.view(function(props)
    local ctx = ito.theme()
    return Wrapped({ text = linked(props.text), mark = ctx.symbols.notice, style = ctx.styles.notice })
end)
