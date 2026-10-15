local auth = require("uji.core.auth")
local catalog = require("uji.core.catalog")
local dotenv = require("uji.core.auth.dotenv")
local sandbox = require("support.sandbox")
local sys = require("uji.sys")

local ID = "auth-file-test"
local ENV = "UJI_TEST_AUTH_FILE_KEY"

local function file(name, text)
    local path = sandbox.root .. "/" .. name
    sandbox.write(path, text)
    return path
end

local function missing(name)
    return sandbox.root .. "/" .. name .. ".nope"
end

local function provider(auth_env, auth_file)
    uji.provider.add({
        id = ID,
        name = ID,
        api = uji.api.openai(),
        base_url = "http://127.0.0.1:9",
        auth_env = auth_env or { ENV },
        auth_file = auth_file or "",
        models = {},
    })
    return catalog.get(ID)
end

local function env(overrides, body)
    local os = sys.os
    local real = os.env
    os.env = function(name)
        local override = overrides[name]
        if override == false then
            return nil
        end
        return override or real(name)
    end
    local ok, err = pcall(body)
    os.env = real
    if not ok then
        error(err, 0)
    end
end

local function notices()
    local seen = {}
    uji.on("notice", function(notice)
        seen[#seen + 1] = notice.text
    end)
    return seen
end

it("reads name=value lines, comments, export and quotes", function()
    local path = file(
        "plain.env",
        table.concat({
            "# a comment",
            "",
            "UJI_TEST_AUTH_FILE_KEY=secret",
            "export UJI_TEST_OTHER = spaced ",
            'QUOTED="with # hash"',
            "SINGLE='single'",
            "TRAILING=value # a comment",
            "EMPTY=",
        }, "\n")
    )
    assert.same({
        UJI_TEST_AUTH_FILE_KEY = "secret",
        UJI_TEST_OTHER = "spaced",
        QUOTED = "with # hash",
        SINGLE = "single",
        TRAILING = "value",
        EMPTY = "",
    }, dotenv.values(path))
end)

it("reads a file written with carriage returns, and one with no last newline", function()
    local path = file("crlf.env", "# a comment\r\n" .. ENV .. "=crlf-secret\r\n")
    assert.same({ [ENV] = "crlf-secret" }, dotenv.values(path))

    path = file("no-newline.env", ENV .. "=no-newline")
    assert.same({ [ENV] = "no-newline" }, dotenv.values(path))
end)

it("reports the line it cannot read", function()
    local path = file("broken.env", "GOOD=1\nnot a pair\n")
    local values, err = dotenv.values(path)
    assert.is_nil(values)
    assert.equal("line 2 is not a NAME=value line", err)

    path = file("unbalanced.env", 'QUOTED="secret\n')
    values, err = dotenv.values(path)
    assert.is_nil(values)
    assert.equal("line 1 is not a NAME=value line", err)
end)

it("has nothing to say about a file that is not there", function()
    assert.same({}, dotenv.values(missing("gone")))
end)

it("answers a provider's env names from the file", function()
    local path = file("keys.env", ENV .. "=from-file\n")
    uji.auth.configure({ file = path })
    local credentials = auth.resolve(provider())
    assert.equal("from-file", credentials.key)
    assert.is_true(auth.authenticated(catalog.get(ID)))
end)

it("takes the environment over the file, and a saved key over both", function()
    local path = file("both.env", ENV .. "=from-file\n")
    uji.auth.configure({ file = path })
    env({ [ENV] = "from-env" }, function()
        assert.equal("from-env", auth.resolve(provider()).key)
    end)
    uji.auth.save_key(ID, "from-login")
    assert.equal("from-login", auth.resolve(provider()).key)
    assert.is_true(auth.remove(ID))
    assert.equal("from-file", auth.resolve(provider()).key)
end)

it("looks through every name a provider gives", function()
    local path = file("second.env", ENV .. "=second-name\n")
    uji.auth.configure({ file = path })
    assert.equal("second-name", auth.resolve(provider({ "UJI_TEST_AUTH_FILE_UNSET", ENV })).key)
end)

it("leaves a provider that names no variables alone", function()
    local seen = notices()
    uji.auth.configure({ file = file("never.env", "not a pair\n") })
    local credentials = auth.resolve(provider({}))
    assert.is_nil(credentials.key)
    assert.same({}, seen)
end)

it("points at the file it cannot read, once", function()
    uji.auth.configure({ file = file("reported.env", "GOOD=1\n#\nbad line\n") })
    local seen = notices()
    assert.is_nil(auth.resolve(provider()).key)
    assert.is_nil(auth.resolve(provider()).key)
    assert.equal(1, #seen)
    assert.truthy(seen[1]:find("auth file ", 1, true))
    assert.truthy(seen[1]:find("line 3 is not a NAME=value line", 1, true))
end)

it("takes the file from UJI_AUTH_FILE, with a home in it", function()
    local path = file("pointed.env", ENV .. "=pointed\n")
    uji.auth.configure({ file = file("ignored.env", ENV .. "=configured\n") })
    env({ UJI_AUTH_FILE = path }, function()
        assert.equal(path, dotenv.path(nil))
        assert.equal("pointed", auth.resolve(provider()).key)
    end)
    env({ UJI_AUTH_FILE = "~/uji-pointed.env" }, function()
        assert.equal(sys.os.expand("~/uji-pointed.env"), dotenv.path(nil))
    end)
    uji.auth.configure({ file = missing("nothing") })
end)

it("reads the key out of the file an env name points at", function()
    local path = file("pointed-key", "  secret-key\n")
    uji.auth.configure({ file = missing("nothing") })
    env({ [ENV .. "_FILE"] = path }, function()
        assert.equal("secret-key", auth.resolve(provider()).key)
        assert.is_true(auth.authenticated(catalog.get(ID)))
    end)
end)

it("takes the value over the file it points at, and that over the provider's file", function()
    local path = file("ladder-key", "from-pointed\n")
    uji.auth.configure({ file = file("ladder.env", ENV .. "=from-auth-file\n") })
    local provider_file = file("ladder-provider-key", "from-provider-file\n")
    local found = provider({ ENV }, provider_file)
    env({ [ENV] = "from-env", [ENV .. "_FILE"] = path }, function()
        assert.equal("from-env", auth.resolve(found).key)
    end)
    env({ [ENV] = false, [ENV .. "_FILE"] = path }, function()
        assert.equal("from-pointed", auth.resolve(found).key)
    end)
    env({ [ENV] = false, [ENV .. "_FILE"] = false }, function()
        assert.equal("from-provider-file", auth.resolve(found).key)
    end)
    uji.auth.configure({ file = missing("nothing") })
end)

it("keeps a provider's file quiet when it is not there", function()
    local seen = notices()
    uji.auth.configure({ file = missing("nothing") })
    local found = provider({ ENV }, missing("provider-key"))
    env({ [ENV] = false, [ENV .. "_FILE"] = false }, function()
        assert.is_nil(auth.resolve(found).key)
    end)
    assert.same({}, seen)
end)

it("leaves an empty pointed file unset, and points at one that is missing", function()
    uji.auth.configure({ file = missing("nothing") })
    env({ [ENV .. "_FILE"] = file("blank-key", "  \n") }, function()
        assert.is_nil(auth.resolve(provider()).key)
    end)

    local seen = notices()
    local gone = missing("gone-key")
    env({ [ENV .. "_FILE"] = gone }, function()
        assert.is_nil(auth.resolve(provider()).key)
        assert.is_nil(auth.resolve(provider()).key)
    end)
    assert.equal(1, #seen)
    assert.truthy(seen[1]:find("auth file " .. gone, 1, true))
end)

it("reads the key out of the file the provider names", function()
    local path = file("provider-key", "  provider-secret\r\n")
    uji.auth.configure({ file = missing("nothing") })
    local found = provider({ ENV }, path)
    env({ [ENV] = false, [ENV .. "_FILE"] = false }, function()
        assert.equal("provider-secret", auth.resolve(found).key)
        assert.is_true(auth.authenticated(found))
    end)
end)

it("lets the shipped jev provider take a key or a file", function()
    local jev = catalog.get("jev")
    assert.same({ "TYPESAFE_API_KEY" }, jev.auth_env)
    assert.equal("~/.config/typesafe/api_key", jev.auth_file)

    local path = file("jev-key", "jev-secret\n")
    uji.provider.add({ id = "jev", auth_file = path })
    env({ TYPESAFE_API_KEY = false, TYPESAFE_API_KEY_FILE = false }, function()
        assert.equal("jev-secret", auth.resolve(catalog.get("jev")).key)
    end)
    env({ TYPESAFE_API_KEY = "jev-env" }, function()
        assert.equal("jev-env", auth.resolve(catalog.get("jev")).key)
    end)
    uji.provider.add({ id = "jev", auth_file = "~/.config/typesafe/api_key" })
end)

it("refuses a file that is not a string", function()
    local ok, err = pcall(uji.auth.configure, { file = 5 })
    assert.is_false(ok)
    assert.equal("file must be a string", err)
    assert.is_false(pcall(uji.auth.configure, { unknown = true }))
end)
