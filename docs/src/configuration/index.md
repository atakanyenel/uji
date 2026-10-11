# Configuration

uji reads `~/.config/uji`, or the directory in `UJI_CONFIG_DIR`.

```text
~/.config/uji/
  init.lua        runs first
  plugin/*.lua    runs after init.lua, sorted by file name
  lua/            modules for require()
```

`init.lua` replaces the default config. Start it with
`require("uji.builtin.defaults")` to keep the default screen.

```lua
require("uji.builtin.defaults")

uji.keymap.add("normal", "<C-p>", { command = "models" })
```

## Starting a config

Until you have an `init.lua`, `/setup` writes one for you. Sign in with
`/login` first, because the model does the asking.

`/setup` does three things.

1. It writes an `init.lua` that keeps the defaults, adds the
   [uji-plugins](../plugins/index.md) pack and turns on
   [skills](../plugins/skills.md). An `init.lua` you already have is left as
   it is.
2. It writes the `uji-config` skill to `.agents/skills/uji-config` in the
   config directory. The skill holds a guide to changing the config and a copy
   of this book for your version of uji.
3. It asks what you want, one question at a time: what uji may run without
   asking, which plugins to turn on, the theme and the keys. It writes each
   answer into `init.lua` as you give it, which you approve like any other
   change, and reloads so that you see it take effect.

Text after the command says what you want up front, such as
`/setup only a dark theme and the status line`.

`/setup` is gone once you have a config, and the skill takes over: ask uji in
plain words to change its own setup.

## Changing the config from inside uji

Start uji in the config directory and ask for the change. There the model has
the `reload_config` tool. After it edits the config, uji restarts on the same
conversation when the turn ends and tells the model which notices loading the
config raised, so it can fix an error it made and carry on.

Anywhere else the model cannot restart uji, and you run `/reload` yourself.
