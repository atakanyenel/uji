local paths = require("uji.core.paths")
local sys = require("uji.sys")

local CANDIDATES = { "AGENTS.override.md", "AGENTS.md", "AGENTS.MD", "CLAUDE.md", "CLAUDE.MD" }

local M = {}

local function read(dir)
    for _, name in ipairs(CANDIDATES) do
        local path = sys.fs.join(dir, name)
        local stat = sys.fs.stat(path)
        if stat and stat.type == "file" then
            local text = sys.fs.read(path)
            if text then
                return { path = path, text = text }
            end
        end
    end
end

function M.files(directory)
    local files, seen = {}, {}
    local function take(dir)
        local file = read(dir)
        if file and not seen[file.path] then
            seen[file.path] = true
            files[#files + 1] = file
        end
    end
    local config = paths.config()
    if config then
        take(config)
    end
    local chain, at = {}, directory or sys.os.cwd()
    while at do
        chain[#chain + 1] = at
        at = sys.fs.parent(at)
    end
    for index = #chain, 1, -1 do
        take(chain[index])
    end
    return files
end

function M.section(directory)
    local files = M.files(directory)
    if #files == 0 then
        return nil
    end
    local rows = { "Project-specific instructions and guidelines:" }
    for _, file in ipairs(files) do
        rows[#rows + 1] = ""
        rows[#rows + 1] = '<project_instructions path="' .. file.path .. '">'
        rows[#rows + 1] = file.text
        rows[#rows + 1] = "</project_instructions>"
    end
    return table.concat(rows, "\n")
end

return M
