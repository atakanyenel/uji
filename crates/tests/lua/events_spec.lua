local diagnostics = require("uji.core.diagnostics")
local event = require("uji.core.event")
local notices = require("uji.core.notices")

-- A handler that raises is logged with its traceback and never turned into a
-- notice: a notice reaches the handlers again, which is how a broken notice
-- handler used to report itself until the stack ran out.
it("keeps a handler error out of the notices", function()
    local ran, heard = 0, {}
    local name = event.on("notice", function(notice)
        ran = ran + 1
        heard[#heard + 1] = notice.text
        error("boom", 0)
    end)
    notices.push("hello")
    event.off("notice", name)
    assert.equal(1, ran, "the handler runs for the notice, not for every report of it")
    assert.same({ "hello" }, heard)
    assert.same({}, notices.take(), "the failure is not pushed back at the handlers")
    local entries = diagnostics.list()
    assert.equal(1, #entries)
    assert.equal("notice", entries[1].source)
    assert.is_true(entries[1].text:find("boom", 1, true) ~= nil, entries[1].text)
    assert.is_true(entries[1].text:find("stack traceback", 1, true) ~= nil, entries[1].text)
end)

-- uji's own notice handler takes what is pending as the notices are handed
-- out, so what is left here is the notice the handler pushed for itself: it is
-- kept, and handed out with the next notice rather than from inside this one.
it("takes a notice a handler pushes while the notices are being handed out", function()
    local heard = {}
    local name = event.on("notice", function(notice)
        heard[#heard + 1] = notice.text
        notices.push(notice.text .. " again")
    end)
    notices.push("hello")
    event.off("notice", name)
    assert.same({ "hello" }, heard, "a handler is not handed a notice from inside its own delivery")
    assert.same({ "hello again" }, notices.take())

    local later = {}
    local other = event.on("notice", function(notice)
        later[#later + 1] = notice.text
    end)
    notices.push("next")
    event.off("notice", other)
    assert.same({ "next" }, later, "the notice after that is handed out as usual")
end)
