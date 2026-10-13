local event = require("uji.core.event")
local notices = require("uji.core.notices")
local screen = require("support.ui")
local sys = require("uji.sys")
local ui = require("uji.core.ui")

it("shows a notice where the copy message goes", { size = { 60, 12 } }, function()
    notices.push("compacted 12 earlier messages")
    ui:take_notices()
    local row = screen.find("compacted 12 earlier messages")
    assert.is_not_nil(row, "the notice is on the screen")
    local styled
    for _, run in ipairs(ui.screen:spans(row)) do
        if run.text:find("compacted", 1, true) then
            styled = run
        end
    end
    assert.same({ "reverse" }, styled.modifiers, "in the words of a flash")
end)

it("keeps the newest notice when several arrive at once", { size = { 60, 12 } }, function()
    notices.push("first")
    notices.push("second")
    ui:take_notices()
    assert.equal("second", ui.flashed.text)
    assert.is_nil(screen.find("first"))
end)

it("drops a notice once its time is up", { size = { 60, 12 } }, function()
    notices.push("short lived")
    ui:take_notices()
    sys.sleep(ui.theme.tokens.limits.flash + 0.1)
    screen.rows(true)
    assert.is_nil(ui.flashed)
end)

it("keeps a notice up for as long as it was pushed for", { size = { 60, 12 } }, function()
    notices.push("a long one", 30)
    ui:take_notices()
    sys.sleep(ui.theme.tokens.limits.flash + 0.1)
    assert.equal("a long one", ui.flashed.text, "it outlives the time a copy message gets")
end)

it("says a copy went through the notices too", { size = { 60, 12 } }, function()
    local heard = {}
    local name = event.on("notice", function(notice)
        heard[#heard + 1] = notice.text
    end)
    sys.clipboard.set = function()
        return true
    end
    ui:copy("one\ntwo")
    ui:take_notices()
    event.off("notice", name)
    assert.same({ "copied 2 line(s)" }, heard)
    assert.equal("copied 2 line(s)", ui.flashed.text)
end)
