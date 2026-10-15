uji.command.add("jobs", {
    desc = "list background jobs and stop one",
    handler = function()
        uji.jobs.pick()
    end,
})
