local class = require("uji.core.class")
local dotenv = require("uji.core.auth.dotenv")
local notices = require("uji.core.notices")
local sys = require("uji.sys")

local SERVICE = "uji"
local FILE = "auth.toml"
local PRIVATE = tonumber("600", 8)

local reported = {}

local Credentials = class()

function Credentials:init(directory)
    self.directory = directory
    self.keychain = false
    self.auth_file = nil
end

local function entry(value)
    if type(value) == "string" then
        return { type = "api_key", key = value }
    end
    if type(value) == "table" and value.type then
        return value
    end
end

local function parse(raw)
    local ok, credential = pcall(sys.json.decode, raw, { nulls = false })
    if ok and type(credential) == "table" and credential.type then
        return credential
    end
    return { type = "api_key", key = raw }
end

function Credentials:path()
    return self.directory and sys.fs.join(self.directory, FILE)
end

function Credentials:file()
    local path = self:path()
    local text = path and sys.fs.read(path)
    if not text then
        return {}
    end
    local ok, all = pcall(sys.toml.decode, text)
    if not ok then
        return nil, path .. " could not be read: " .. sys.message(all)
    end
    return all
end

function Credentials:get(provider)
    if self.keychain then
        local raw = sys.keychain.get(SERVICE, provider)
        if raw then
            return parse(raw)
        end
    end
    local all, err = self:file()
    if not all then
        return nil, err
    end
    return entry(all[provider])
end

function Credentials:key(provider)
    local credential = self:get(provider)
    return credential and credential.type == "api_key" and credential.key or nil
end

function Credentials:write_file(all)
    local path = self:path()
    if not path then
        return nil, "no data directory to keep the credential in"
    end
    sys.fs.mkdir(self.directory)
    return sys.fs.write(path, sys.toml.encode(all), { mode = PRIVATE })
end

function Credentials:save(provider, credential)
    if self.keychain and sys.keychain.set(SERVICE, provider, sys.json.encode(credential)) then
        return credential
    end
    local all, err = self:file()
    if not all then
        return nil, err
    end
    all[provider] = credential
    local written, failure = self:write_file(all)
    if not written then
        return nil, failure
    end
    return credential
end

function Credentials:remove(provider)
    local in_keychain = self.keychain and sys.keychain.get(SERVICE, provider) ~= nil
    if in_keychain then
        local deleted, err = sys.keychain.delete(SERVICE, provider)
        if not deleted then
            return nil, err
        end
    end
    local all, err = self:file()
    if not all then
        return nil, err
    end
    local in_file = all[provider] ~= nil
    if in_file then
        all[provider] = nil
        local written, failure = self:write_file(all)
        if not written then
            return nil, failure
        end
    end
    return in_keychain or in_file
end

local function alert(path, err)
    if not reported[path] then
        reported[path] = true
        notices.push("auth file " .. path .. ": " .. err)
    end
end

local function contents(path, quiet)
    if quiet and not sys.fs.stat(path) then
        return nil
    end
    local text, err = sys.fs.read(path)
    if not text then
        alert(path, tostring(err))
        return nil
    end
    local value = (text:gsub("^%s+", ""):gsub("%s+$", ""))
    if value ~= "" then
        return value
    end
end

function Credentials:auth_values()
    local path = dotenv.path(self.auth_file)
    local values, err = dotenv.values(path)
    if not values then
        alert(path, err)
        return nil
    end
    return values
end

local SUFFIX = "_FILE"

local function pointed(name)
    local path = sys.os.env(name .. SUFFIX)
    if path and path ~= "" then
        return contents(sys.os.expand(path))
    end
end

function Credentials:env_key(provider)
    local names = provider.auth_env
    if not names or #names == 0 then
        return nil
    end
    for _, name in ipairs(names) do
        local found = sys.os.env(name) or pointed(name)
        if found then
            return found
        end
    end
    local path = provider.auth_file
    local named = path and path ~= "" and contents(sys.os.expand(path), true)
    if named then
        return named
    end
    local values = self:auth_values()
    for _, name in ipairs(names) do
        local value = values and values[name]
        if value and value ~= "" then
            return value
        end
    end
end

function Credentials:authenticated(provider)
    return self:get(provider.id) ~= nil or self:env_key(provider) ~= nil
end

return Credentials
