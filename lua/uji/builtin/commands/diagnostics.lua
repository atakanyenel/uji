local text = require("ito").text
local ui = require("uji.core.ui")

uji.command.add("diagnostics", {
    desc = "show the errors uji ran into",
    handler = function()
        local entries = uji.diagnostics.list()
        if #entries == 0 then
            uji.notify("no diagnostics yet")
            return
        end
        local entry = uji.ui.pick({
            title = "Diagnostics",
            items = entries,
            label = function(item)
                return item.time .. "  " .. item.source .. "  " .. (text.lines(item.text)[1] or "")
            end,
            preview = function(item)
                return text.lines(item.text)
            end,
        })
        if entry then
            ui:copy(entry.time .. " " .. entry.source .. "\n" .. entry.text)
        end
    end,
})
