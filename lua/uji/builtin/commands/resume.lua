uji.command.add("resume", {
    desc = "resume a session: the latest one here, or one by id",
    handler = function(rest)
        local id = rest:match("^%s*(.-)%s*$")
        if id == "" then
            local latest = uji.session.list({ directory = uji.session.info().directory })[1]
            if not latest then
                uji.notify("no sessions in this directory")
                return
            end
            id = latest.id
        end
        uji.session.resume(id)
    end,
})
