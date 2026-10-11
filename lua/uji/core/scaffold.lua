local paths = require("uji.core.paths")
local sys = require("uji.sys")
local version = require("uji.version")

local PLUGINS = "uji-labs/uji-plugins"
local SKILL = "uji-config"
local SKILLS = { ".agents", "skills" }
local GUIDE = "SKILL.md"
local BOOK = "docs"

local INIT = [[
-- uji runs this file when it starts. It replaces the default config, so the
-- next line brings the default keys and tool rules back.
require("uji.builtin.defaults")

-- Packs hold optional features. /sync updates them.
uji.pack.add({ "$PLUGINS" })

-- Skills are folders of instructions the model reads when a task calls for
-- them. The last folder has uji-config, which explains this file and every
-- uji API, so you can ask uji to change its own setup.
require("skills").setup({
    roots = { "~/.agents/skills", ".uji/skills", ".agents/skills", $SKILLS },
})
]]

local GUIDE_TEXT = [[
---
name: $SKILL
description: Change how uji itself works - its config, plugins, themes, keys, tool approval, commands and providers - or look up a uji Lua API. Use it for any request about this uji install rather than the project being worked on.
---

# Configuring uji

uji is configured in Lua, and this install keeps its config in `$CONFIG`.

| File | When it runs |
|---|---|
| `init.lua` | First. It replaces the default config, so it starts with `require("uji.builtin.defaults")`. |
| `plugin/*.lua` | After `init.lua`, sorted by file name. |
| `lua/` | Never on its own. It holds modules for `require()`. |

## Changing the config

1. Read `init.lua` and every `plugin/*.lua` first, so the change fits what is there.
2. Read the reference page for each function you are about to use, and for a plugin, its source in the pack. Do not write an option from memory. When neither says what a value should be, ask the person instead of guessing.
3. Give each setting one place. A plugin that is already set up gets its options changed, not a second `setup` call.
4. Never put a key or a token in the config. Provider keys go through `/login`, and a plugin that wants its own key reads it from the environment, so name the variable to export.
5. Read the file back, then tell the person to run `/reload`. Nothing changes until they do.

A pack that is missing joins the `uji.pack.add({ ... })` list in `init.lua`, as `"user/repo"` or `{ dir = "~/path" }`. uji installs it on the next `/reload`, and `/sync` updates the packs that are installed.

## Reference

`$BOOK/` beside this file is the uji book as of version $VERSION, and `$BOOK/SUMMARY.md` lists every page.

| Page | Covers |
|---|---|
| `$BOOK/api/index.md` | Every `uji.*` function in one table, each with a link to its page. Start here to find an API. |
| `$BOOK/configuration/` | The config directory, packs and themes. |
| `$BOOK/plugins/` | One page for each optional plugin, with its options. |
| `$BOOK/examples/` | Short working configs: a tool, a command, a footer, a provider, an approval rule and the system prompt. |
| `$BOOK/api/tool.md` | Tools and the approval policy. |
| `$BOOK/api/keymap.md` | Keys and the default bindings. |
| `$BOOK/getting-started/commands.md` | The slash commands. |

The book is a copy made when this config was set up. When a page disagrees with how uji behaves, trust uji and say so.
]]

local M = { PLUGINS = PLUGINS }

local function filled(template, values)
    return (template:gsub("%$(%u+)", values))
end

local function saved(path, text)
    local made, failure = sys.fs.mkdir(sys.fs.parent(path))
    if not made then
        return nil, path .. ": " .. tostring(failure)
    end
    local written, problem = sys.fs.write(path, text)
    if not written then
        return nil, path .. ": " .. tostring(problem)
    end
    return true
end

local function init_file()
    local config = paths.config()
    return config and sys.fs.join(config, paths.INIT_FILE)
end

function M.configured()
    local init = init_file()
    local file = init and io.open(init, "rb")
    if file then
        file:close()
    end
    return file ~= nil
end

function M.run()
    local config, init = paths.config(), init_file()
    if not config then
        return nil, "$HOME is not set"
    end
    local skills = sys.fs.join(config, unpack(SKILLS))
    local skill = sys.fs.join(skills, SKILL)
    local guide = sys.fs.join(skill, GUIDE)
    local values = {
        PLUGINS = PLUGINS,
        SKILL = SKILL,
        SKILLS = string.format("%q", sys.os.shorten(skills)),
        CONFIG = sys.os.shorten(config),
        BOOK = BOOK,
        VERSION = version,
    }
    for page, text in pairs(require("uji.docs")) do
        local written, err = saved(sys.fs.join(skill, BOOK, page), text)
        if not written then
            return nil, err
        end
    end
    local written, err = saved(guide, filled(GUIDE_TEXT, values))
    if not written then
        return nil, err
    end
    local started = not M.configured()
    if started then
        written, err = saved(init, filled(INIT, values))
        if not written then
            return nil, err
        end
    end
    return { config = config, init = init, guide = guide, started = started }
end

return M
