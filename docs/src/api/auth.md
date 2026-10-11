# uji.auth

These functions choose where credentials live, save them, and sign in to the
providers that offer a subscription.

## uji.auth.configure(opts)

Chooses where uji keeps API keys and subscription sign-ins.

| Field | Type | Meaning |
|---|---|---|
| `keychain` | boolean | With `true`, uji saves credentials in the system keychain and looks there first. The default is `false`. |

Without the keychain, uji keeps credentials in `auth.toml` in the
[data directory](../configuration/files.md), readable only by you. Each
provider gets a table named by its id, and a provider can also be a plain
string, which uji reads as an API key. A keychain that refuses a save sends
the credential to `auth.toml` as well.

Raises an error for an unknown field, and for a `keychain` that is not a
boolean.

## uji.auth.authenticated(id)

Returns `true` when uji has a saved key or sign-in for the provider `id`, or
finds its key in one of the provider's `auth_env` variables. Raises an error
for an unknown provider.

```lua
if not uji.auth.authenticated("anthropic") then
  uji.notify("run /login to set up Anthropic")
end
```

## uji.auth.save_key(id, key)

Saves an API key for the provider `id` and returns `true`, or `nil` and an
error message when the key could not be saved. Raises an error for an unknown
provider or an empty key.

```lua
local ok, err = uji.auth.save_key("openrouter", os.getenv("MY_OPENROUTER_KEY"))
```

## uji.auth.remove(id)

Deletes the saved key or sign-in of the provider `id`, from the keychain and
from `auth.toml`. Returns `true` when it deleted one, `false` when nothing was
saved, or `nil` and an error message. A key in one of the provider's
`auth_env` variables stays. Raises an error for an unknown provider.

```lua
uji.auth.remove("openrouter")
```

## uji.auth.login(id, opts, on_done)

Signs in to the provider `id` with its subscription. uji opens your browser,
waits for the sign-in to finish, saves it, and gives `true`, or `nil` and an
error message. A provider without `oauth` settings gives an error message
too. Raises an error for an unknown provider.

`opts` is optional. Its `method` is `"browser"` by default, or `"device"`
for device code sign-in. OpenAI supports both. Device sign-in displays a link
and a one-time code, then waits up to 15 minutes. It does not open a browser
or bind a local callback port. Both OpenAI sign-in methods save ChatGPT OAuth
tokens and refresh them when they expire. Model requests use your ChatGPT
subscription; saving an API key instead uses the OpenAI API. Enable device
code login in your ChatGPT security settings or workspace permissions first,
as described in the
[OpenAI authentication guide](https://developers.openai.com/codex/auth/#login-on-headless-devices).

An unsupported sign-in method for a provider returns `nil` and an error
message. An unknown option or a `method` other than `"browser"` or `"device"`
raises an error. With a callback, the function returns a cancellation function.

```lua
uji.auth.login("anthropic", function(ok, err)
  uji.notify(ok and "signed in" or "sign-in failed: " .. err)
end)

local cancel = uji.auth.login("openai", { method = "device" }, function(ok, err)
  uji.notify(ok and "signed in" or "sign-in failed: " .. err)
end)
```
