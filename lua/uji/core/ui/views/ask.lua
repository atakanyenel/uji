local class = require("uji.core.class")
local ito = require("ito")
local Modal = require("uji.core.ui.views.modal")

local Ask = class(Modal)

function Ask:init(opts)
    Modal.init(self)
    self.title = opts.title or ""
    self.choices = ito.Choices(opts.choices or {})
        :on_choose(function(item)
            self:settle(item.label)
        end)
        :on_other(function(text)
            self:settle(text)
        end)
        :focused()
end

function Ask:line()
    if self.choices:writing() then
        return self.choices:answer()
    end
end

function Ask:view()
    local styles = ito.theme().styles
    return ito.VStack({
        ito.Spacer():height(1),
        ito.Text(self.title):style(styles.bold):wrap():padding({ leading = 2 }),
        ito.Spacer():height(1),
        self.choices:padding({ leading = 2 }),
    })
end

return Ask
