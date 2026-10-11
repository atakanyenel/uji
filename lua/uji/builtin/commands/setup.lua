local paths = require("uji.core.paths")
local version = require("uji.version")

local REVIEW = "review what is set up"
local REVIEW_VISIBLE = "Review my setup."
local REVIEW_REQUEST = "Review this setup: what is wired, what is available but not set up, and what you would add first. Change nothing."

local PLAYBOOK = [[
You are setting up uji for the person who ran /setup. The map below is their
install: where the config lives, what the packs on disk provide, which plugins
are set up, and how uji is configured now.

Do the work, do not describe it. When the request says what to set up and the
details it needs, make the change in one go: the write goes through uji's
approval, so do not also ask in prose.

Ask for a detail you cannot know - which backend, which url, which of two
plugins - with the ask_user tool, one question at a time, and name the sensible
default in the same question. When the plugin's source answers it, do not ask.

Where things go:
- a pack that is missing joins uji.pack.add({...}) in init.lua, as
  { "user/repo" } or { dir = "~/path" };
- a plugin's setup goes where the person already wires plugins: append to the
  require(...).setup calls in init.lua when that is where they live, otherwise
  write a plugin/<name>.lua. One place per setting, never both;
- a plugin that is already set up needs its options changed, not a second call;
- read the plugin's source in its pack before writing its options, and when the
  source does not say what a value should be, say so instead of guessing.

Never put a key or a token in config: provider keys go through /login, and a
plugin that wants its own key reads it from the environment, so name the
variable to export instead of taking the value in the conversation.

If no pack on disk has the plugin, say so, name what the packs do have, and
stop.

Finish by reading the file back and telling the person to run /reload, or /sync
when you added a pack. Keep the report short.]]

local state = { pending = nil }

local function shown(value)
    return value ~= nil and value ~= "" and tostring(value) or "none"
end

local function joined(values)
    return #values > 0 and table.concat(values, ", ") or "none"
end

local function sorted(set)
    local out = {}
    for name in pairs(set) do
        out[#out + 1] = name
    end
    table.sort(out)
    return out
end

local function plugins_in(root)
    local found = {}
    local pattern = root .. "/" .. paths.MODULE_DIR .. "/*/" .. paths.INIT_FILE
    for _, path in ipairs(uji.fs.glob(pattern) or {}) do
        found[#found + 1] = path:match("([^/]+)/[^/]+$")
    end
    return found
end

local function config_files(config)
    local found = {}
    local pattern = config .. "/" .. paths.PLUGIN_DIR .. "/*.lua"
    for _, path in ipairs(uji.fs.glob(pattern) or {}) do
        found[#found + 1] = path:match("([^/]+)$")
    end
    return found
end

local function loaded()
    local known = {}
    for _, plugin in ipairs(uji.plugin.list()) do
        known[plugin.name] = true
    end
    return known
end

local function set_up()
    local known, wired, unwired = loaded(), {}, {}
    for _, root in ipairs(uji.pack.list()) do
        for _, name in ipairs(plugins_in(root)) do
            local into = known[name] and wired or unwired
            into[name] = true
        end
    end
    return sorted(wired), sorted(unwired)
end

local function sheet()
    local config = paths.config()
    local model = uji.model.current()
    local signed, providers = {}, 0
    for _, provider in ipairs(uji.provider.list()) do
        providers = providers + 1
        if uji.auth.authenticated(provider.id) then
            signed[#signed + 1] = provider.id
        end
    end
    local wired, unwired = set_up()
    local rows = {
        "uji " .. version,
        "config: " .. shown(config),
        "  init.lua: " .. (#(uji.fs.glob(config .. "/" .. paths.INIT_FILE) or {}) > 0 and "yes" or "no"),
        "  plugin/: " .. joined(config_files(config)),
        "data: " .. shown(paths.data()),
        "model: " .. shown(model.provider) .. " " .. shown(model.model) .. ", effort " .. shown(model.effort),
        "providers: " .. providers .. " registered, signed in: " .. joined(signed),
        "tools: " .. joined(uji.tool.list()),
        "set up: " .. joined(wired),
        "not set up: " .. joined(unwired),
        "packs:",
    }
    for _, root in ipairs(uji.pack.list()) do
        rows[#rows + 1] = "  " .. root .. ": " .. joined(plugins_in(root))
    end
    return table.concat(rows, "\n")
end

local function briefed(request)
    return PLAYBOOK .. "\n\nTheir install:\n" .. sheet() .. "\n\nRequest: " .. request
end

uji.context.add("setup", function()
    local text = state.pending
    state.pending = nil
    return text and { at = "turn", text = text } or nil
end, { priority = 21 })

uji.command.add("setup", {
    desc = "set up a plugin or check what is set up",
    handler = function(args)
        local visible, request = args, args
        if args == "" then
            local _, unwired = set_up()
            local items = { REVIEW }
            for _, name in ipairs(unwired) do
                items[#items + 1] = name
            end
            local chosen = uji.ui.select({ title = "Setup", items = items })
            if not chosen then
                return
            end
            if chosen == REVIEW then
                visible, request = REVIEW_VISIBLE, REVIEW_REQUEST
            else
                local asked = "Set up " .. chosen .. " for me."
                visible, request = asked, asked
            end
        end
        state.pending = briefed(request)
        uji.session.submit(visible)
    end,
})
