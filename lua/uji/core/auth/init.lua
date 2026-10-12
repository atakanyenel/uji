local Credentials = require("uji.core.auth.credentials")
local check = require("uji.core.check")
local device = require("uji.core.auth.device")
local notices = require("uji.core.notices")
local oauth = require("uji.core.auth.oauth")
local paths = require("uji.core.paths")
local process = require("uji.core.system.process")

local M = { options = { keychain = false } }

function M.credentials()
    if not M.store then
        M.store = Credentials(paths.data())
        M.store.keychain = M.options.keychain
    end
    return M.store
end

function M.configure(opts)
    check.options(opts, "uji.auth.configure")
    for key, value in pairs(opts) do
        if key ~= "keychain" then
            error("unknown key " .. tostring(key), 2)
        end
        if type(value) ~= "boolean" then
            error("keychain must be a boolean", 2)
        end
        M.options.keychain = value
    end
    if M.store then
        M.store.keychain = M.options.keychain
    end
end

function M.save_key(provider_id, key)
    return M.credentials():save(provider_id, { type = "api_key", key = key })
end

function M.remove(provider_id)
    return M.credentials():remove(provider_id)
end

function M.authenticated(provider)
    return M.credentials():authenticated(provider)
end

local function session_credential(provider, credential)
    if not oauth.expired(credential) then
        return credential
    end
    local refreshed = oauth.refresh(provider.oauth, credential)
    local saved, err = M.credentials():save(provider.id, refreshed)
    if not saved then
        error("refreshed the session but could not save it: " .. tostring(err), 0)
    end
    return refreshed
end

function M.resolve(provider)
    local credentials = M.credentials()
    local stored = credentials:get(provider.id)
    local key = stored and stored.type == "api_key" and stored.key or Credentials.env_key(provider.auth_env)
    local session
    if provider.oauth and stored and stored.type == "oauth" then
        local ok, credential = pcall(session_credential, provider, stored)
        if not ok then
            return nil, { kind = "provider", message = tostring(credential) }
        end
        session = {
            token = credential.access,
            account_id = credential.account_id,
            headers = provider.oauth.request_headers or {},
            identity_prompt = provider.oauth.identity_prompt,
        }
    end
    return { key = key, oauth = session }
end

local function browser_login(config)
    local flow, server = oauth.start(config)
    local url = flow:url()
    process.open(url)
    notices.push("opened your browser to sign in - " .. url)
    return oauth.login(config, flow, server)
end

local function device_login(config)
    local flow = device.start(config)
    notices.push("open " .. flow.url .. " and enter code " .. flow.code .. " to sign in; expires in 15 minutes")
    return device.login(config, flow)
end

local METHODS = { browser = browser_login, device = device_login }

function M.login(provider, opts)
    opts = opts or {}
    check.options(opts, "uji.auth.login")
    for key in pairs(opts) do
        if key ~= "method" then
            error("unknown key " .. tostring(key), 2)
        end
    end
    local method = opts.method or "browser"
    local sign_in = METHODS[method]
    if not sign_in then
        error("uji.auth.login method must be browser or device", 2)
    end
    local config = provider.oauth
    if not config then
        return nil, "this provider does not support subscription sign-in"
    end
    if method == "device" and not config.device then
        return nil, "this provider does not support device code sign-in"
    end
    local signed, grant = pcall(sign_in, config)
    if not signed then
        return nil, tostring(grant)
    end
    local saved, err = M.credentials():save(provider.id, grant)
    if not saved then
        return nil, "signed in but could not save the credential: " .. tostring(err)
    end
    return true
end

return M
