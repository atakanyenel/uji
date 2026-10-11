local oauth = require("uji.core.auth.oauth")
local sys = require("uji.sys")
local task = require("uji.core.task")

local TIMEOUT = 900
local REQUEST_TIMEOUT = 30
local DEFAULT_INTERVAL = 5

local M = {}

local function post(url, body)
    local response, err = sys.net.request({
        method = "POST",
        url = url,
        headers = { ["Content-Type"] = "application/json" },
        body = sys.json.encode(body),
        timeout = REQUEST_TIMEOUT,
    })
    if not response then
        error("device sign-in request failed: " .. tostring(err), 0)
    end
    return response
end

local function parsed(response, endpoint)
    if response.status < 200 or response.status >= 300 then
        error(endpoint .. " returned " .. response.status, 0)
    end
    local ok, body = pcall(sys.json.decode, response.body, { nulls = false })
    if not ok or type(body) ~= "table" then
        error(endpoint .. " returned an unexpected body", 0)
    end
    return body
end

local function text(value)
    return type(value) == "string" and value ~= ""
end

function M.start(config)
    local response = post(config.device.code_url, { client_id = config.client_id })
    if response.status == 404 then
        error("device code sign-in is unavailable; enable it in ChatGPT security settings or use browser sign-in", 0)
    end
    local body = parsed(response, "device code request")
    local code = body.user_code or body.usercode
    local interval = body.interval == nil and DEFAULT_INTERVAL or tonumber(body.interval)
    if not text(body.device_auth_id) or not text(code) or not interval or interval ~= interval or interval == math.huge or interval < 0 then
        error("device code request returned an unexpected body", 0)
    end
    return {
        id = body.device_auth_id,
        code = code,
        url = config.device.verification_url,
        interval = math.max(1, interval),
        expires_at = sys.os.clock() + TIMEOUT,
    }
end

function M.login(config, flow)
    local remaining = flow.expires_at - sys.os.clock()
    if remaining <= 0 then
        error("device code expired after 15 minutes; start sign-in again", 0)
    end
    local finished, credential = task.timeout(remaining, function()
        while true do
            local response = post(config.device.poll_url, { device_auth_id = flow.id, user_code = flow.code })
            if response.status ~= 403 and response.status ~= 404 then
                local body = parsed(response, "device sign-in")
                if not text(body.authorization_code) or not text(body.code_verifier) then
                    error("device sign-in returned an unexpected body", 0)
                end
                return oauth.exchange(config, body.authorization_code, config.device.redirect_uri, body.code_verifier)
            end
            sys.sleep(flow.interval)
        end
    end)
    if not finished then
        error("device code expired after 15 minutes; start sign-in again", 0)
    end
    return credential
end

return M
