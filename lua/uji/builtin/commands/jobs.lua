uji.command.add("jobs", {
    desc = "list the background jobs under the input",
    handler = function()
        uji.jobs.show()
    end,
})
