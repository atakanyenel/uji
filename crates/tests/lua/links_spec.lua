local notices = require("uji.core.notices")
local screen = require("support.ui")
local ui = require("uji.core.ui")

it("keeps every wrapped login URL fragment attached to the complete destination", { size = { 44, 20 } }, function()
    local url = "https://auth.openai.com/oauth/authorize?client_id=example&state=abcdefghijklmnopqrstuvwxyz0123456789"
    notices.push("opened your browser to sign in - " .. url)
    ui:take_notices()
    local joined, linked = "", 0
    for _, run in ipairs(screen.runs()) do
        if run.link then
            assert.equal(url, run.link)
            assert.is_nil(run.text:find("\27", 1, true))
            joined = joined .. run.text
            linked = linked + 1
        end
    end
    assert.equal(url, joined)
    assert.is_true(linked >= 3)
end)

it("links only the device verification URL and leaves the code readable", { size = { 50, 15 } }, function()
    local url = "https://auth.openai.com/codex/device"
    notices.push("open " .. url .. " and enter code ABCD-EFGH to sign in; expires in 15 minutes")
    ui:take_notices()
    local joined, plain = "", ""
    for _, run in ipairs(screen.runs()) do
        if run.link then
            assert.equal(url, run.link)
            joined = joined .. run.text
        else
            plain = plain .. run.text
        end
    end
    assert.equal(url, joined)
    assert.truthy(plain:find("ABCD-EFGH", 1, true))
end)
