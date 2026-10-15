local check = require("uji.core.check")
local ito = require("ito")
local jobs = require("uji.core.jobs")
local list = require("uji.utils.list")
local ui = require("uji.core.ui")

local SETTINGS = { wake = "boolean", max = "number", limit = "number" }

local function row(job)
    return { id = job.id, command = job.command, state = job.state, code = job.code, status = job:status(), tail = job:tail() }
end

local function pick()
    local listed = uji.jobs.list()
    if #listed == 0 then
        uji.notify("no background jobs")
        return
    end
    table.sort(listed, function(left, right)
        local live, other = left.state == "running", right.state == "running"
        if live == other then
            return left.id > right.id
        end
        return live
    end)
    local job = uji.ui.pick({
        title = "Jobs",
        items = listed,
        label = function(item)
            return string.format(ui.theme.tokens.text.job, item.id) .. "  " .. item.status .. "  " .. item.command
        end,
        preview = function(item)
            return ito.text.lines(item.tail)
        end,
    })
    if job and job.state == "running" then
        uji.jobs.stop(job.id)
    end
    return job
end

uji.jobs = {
    list = function()
        return list.mapped(jobs.list(), row)
    end,
    stop = function(id)
        return jobs.stop(jobs.get(id))
    end,
    configure = function(opts)
        check.options(opts, "uji.jobs.configure")
        for key, value in pairs(opts) do
            local kind = SETTINGS[key]
            if not kind then
                error("unknown option: " .. tostring(key), 2)
            end
            if type(value) ~= kind or (kind == "number" and value <= 0) then
                error(key .. (kind == "number" and " must be a number above 0" or " must be true or false"), 2)
            end
        end
        jobs.configure(opts)
    end,
    pick = pick,
}
