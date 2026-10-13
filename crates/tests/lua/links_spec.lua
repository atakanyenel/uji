local screen = require("support.ui")

local function showing(text)
    uji.ui.overlay(function()
        return uji.ui.Notice({ text = text })
    end)
end

it("keeps every wrapped login URL fragment attached to the complete destination", { size = { 44, 20 } }, function()
    local url = "https://auth.openai.com/oauth/authorize?client_id=example&state=abcdefghijklmnopqrstuvwxyz0123456789"
    showing("opened your browser to sign in - " .. url)
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

it("keeps the punctuation around a link out of it", { size = { 60, 15 } }, function()
    local url = "https://auth.openai.com/codex/device"
    showing("(see " .. url .. ").")
    local plain, linked = "", ""
    for _, run in ipairs(screen.runs()) do
        if run.link then
            assert.equal(url, run.link)
            assert.equal(url, run.text)
            linked = linked .. run.text
        else
            plain = plain .. run.text
        end
    end
    assert.equal(url, linked)
    assert.truthy(plain:find("(see", 1, true))
    assert.truthy(plain:find(").", 1, true))
end)

it("links only the device verification URL and leaves the code readable", { size = { 50, 15 } }, function()
    local url = "https://auth.openai.com/codex/device"
    showing("open " .. url .. " and enter code ABCD-EFGH to sign in; expires in 15 minutes")
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
