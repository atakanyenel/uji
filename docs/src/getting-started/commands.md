# Commands

## Running uji

| Run | Does |
|---|---|
| `uji`, `uji new` | Starts a new session. |
| `uji resume` | Resumes the latest session in the current directory. |
| `uji resume --id <ID>` | Resumes the session with that id. |
| `uji list` | Opens a picker of the sessions in the current directory. |
| `uji delete <ID>` | Deletes a session. |
| `uji run <PROMPT>` | Sends one prompt without the screen and prints the answer. See [Running without the screen](run.md). |
| `uji --help` | Prints the usage. |
| `uji --version` | Prints the version. |

Any of them takes these options. [Where uji keeps its files](../configuration/files.md)
lists the environment variables that do the same.

| Option | Sets |
|---|---|
| `--config-dir <DIR>` | The config directory. |
| `--data-dir <DIR>` | The data directory. |
| `--db <FILE>` | The session database. |

## Slash commands

| Command | Does |
|---|---|
| `/login` | Adds a provider. |
| `/setup` | Writes a starter config, then asks what you want in it. It is there until you have a config. See [Configuration](../configuration/index.md#starting-a-config). |
| `/models` | Picks the model. |
| `/effort` | Sets the reasoning effort, from the levels the current model accepts. |
| `/thinking` | Shows or hides the model's reasoning. |
| `/compact` | Summarises earlier messages to free context. |
| `/list` | Lists the sessions in this directory. Enter starts uji again in the one you pick. |
| `/resume` | Starts uji again in the latest session here, or `/resume <ID>` in that one. |
| `/sync` | Updates installed packs and reloads. |
| `/reload` | Starts uji again with your current config and files, keeping the conversation and your draft. |
| `/help` | Lists every command, including the ones plugins add. |
| `/jobs` | Opens the background jobs list under the input, finished ones included, and closes it when run again. It picks the first job: Enter opens it, ↑ and ↓ pick another, `x` stops or drops one, Esc closes the list. |
| `/diagnostics` | Lists the errors uji ran into while drawing the screen, newest first, with the details of each. |
| `/quit` | Quits. |

## Keys

[Default bindings](../api/keymap.md#default-bindings) lists every key uji
binds, and [uji.keymap](../api/keymap.md) changes them.
