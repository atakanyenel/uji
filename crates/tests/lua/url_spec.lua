local url = require("uji.utils.url")

it("reads a link into its parts", function()
    local link = uji.net.url("https://example.com:8443/a/b?c=d#e")
    assert.equal("https", link.scheme)
    assert.equal("example.com", link.host)
    assert.equal(8443, link.port)
    assert.equal("/a/b", link.path)
    assert.equal("c=d", link.query)
    assert.equal("e", link.fragment)
    assert.equal("https://example.com:8443/a/b?c=d#e", link.uri)
end)

it("reads a link that is only a host", function()
    local link = uji.net.url("http://localhost")
    assert.equal("localhost", link.host)
    assert.is_nil(link.port)
    assert.equal("/", link.path)
    assert.is_nil(link.query)
    assert.is_nil(link.fragment)
end)

it("reads a bracketed host and its port", function()
    local link = uji.net.url("http://[::1]:8080/x")
    assert.equal("[::1]", link.host)
    assert.equal(8080, link.port)
    assert.equal("/x", link.path)
end)

it("reads a link that names a user", function()
    local link = uji.net.url("https://user:pass@example.com/y")
    assert.equal("example.com", link.host)
    assert.equal("https://user:pass@example.com/y", link.uri)
end)

it("refuses what is not a link with a host", function()
    for _, text in ipairs({
        "example.com",
        "https://",
        "1https://x",
        "https://x:port",
        "javascript:alert(1)",
        "file:///etc/passwd",
    }) do
        assert.is_nil(uji.net.url(text), text)
    end
end)

it("reads a link that has a slash too many", function()
    local link = uji.net.url("https:///x")
    assert.equal("x", link.host)
    assert.equal("https://x/", link.uri)
end)

it("splits text into its runs and the links in it", function()
    assert.same({
        { "see (" },
        { "https://a.b/c", link = "https://a.b/c" },
        { ") or " },
        { "https://d.e/f", link = "https://d.e/f" },
        { ", or not" },
    }, url.spans("see (https://a.b/c) or https://d.e/f, or not"))
end)

it("keeps the text it found and links what the parser read", function()
    assert.same({ { "https://a.b", link = "https://a.b/" } }, url.spans("https://a.b"))
end)

it("keeps punctuation that is not part of a link", function()
    assert.same({
        { "see ... or " },
        { "https://a.b/x", link = "https://a.b/x" },
        { "!" },
    }, url.spans("see ... or https://a.b/x!"))
end)

it("keeps a link that starts or ends the text", function()
    assert.same({
        { "https://a.b/x", link = "https://a.b/x" },
        { " and " },
        { "https://c.d/e", link = "https://c.d/e" },
    }, url.spans("https://a.b/x and https://c.d/e"))
end)

it("ends a link before a control character", function()
    assert.same({
        { "see " },
        { "https://a.b", link = "https://a.b/" },
        { "\27rest" },
    }, url.spans("see https://a.b\27rest"))
end)
