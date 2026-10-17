local json = require("uji.utils.json")

local WANTED = { path = "a.rs" }

it("takes the object a reply meant to send", function()
    assert.same(WANTED, json.object('{"path":"a.rs"}'))
    assert.same(WANTED, json.object('{"path":"a.rs"}}'))
    assert.same(WANTED, json.object('{"path":"a.rs"}"'))
    assert.same(WANTED, json.object('{"path":"a.rs"},'))
    assert.same(WANTED, json.object('{"path":"a.rs"} }  '))
    assert.same(WANTED, json.object('{"path":"a.rs"}} " '))
    assert.same({}, json.object(""))
end)

it("says why when nothing complete is there", function()
    local value, problem = json.object('{"path": "a.rs"')
    assert.is_nil(value)
    assert.is_true(tostring(problem):find("EOF", 1, true) ~= nil, tostring(problem))
end)
