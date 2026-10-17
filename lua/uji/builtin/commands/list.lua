uji.command.add("list", {
    desc = "list the sessions in this directory and resume one",
    handler = function()
        local sessions = uji.session.list({ directory = uji.session.info().directory })
        if #sessions == 0 then
            uji.notify("no sessions in this directory")
            return
        end
        local chosen = uji.ui.pick({
            title = "Sessions",
            items = sessions,
            label = function(item)
                return item.title .. "  " .. item.id
            end,
        })
        if chosen then
            uji.session.resume(chosen.id)
        end
    end,
})
