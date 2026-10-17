local list = require("uji.utils.list")

uji.provider.add({
    id = "llamacpp",
    name = "llama.cpp",
    api = uji.api.openai(),
    base_url = "http://127.0.0.1:8080/v1",
    auth_env = {},
    models = function(provider)
        local url = provider.base_url .. "/models"
        local response, err = uji.http.request({ url = url, timeout = 5 })
        if not response then
            error(err, 0)
        end
        if response.status ~= 200 then
            error(url .. " answered " .. response.status, 0)
        end
        local entries = uji.json.decode(response.body, { nulls = false }).data or {}
        return list.mapped(entries, function(entry)
            return entry.id
        end)
    end,
})
