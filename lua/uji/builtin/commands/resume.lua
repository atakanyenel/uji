local text = require("ito").text

uji.command.add("resume", {
    desc = "resume a session: the latest one here, or one by id",
    handler = function(rest)
        local id = text.trim(rest)
        if id == "" then
            local latest = uji.session.list({ directory = uji.session.info().directory })[1]
            if not latest then
                uji.notify("no sessions in this directory")
                return
            end
            id = latest.id
        end
        local ok, problem = uji.session.resume(id)
        if not ok then
            uji.notify(problem)
        end
    end,
})
