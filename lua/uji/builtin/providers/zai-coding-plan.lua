local OpenAI = uji.api.openai

local Zai = uji.class(OpenAI)

function Zai:efforts()
    return { "off", "high" }
end

function Zai:thinking(body, request)
    body.thinking = { type = request.effort == "off" and "disabled" or "enabled" }
end

uji.provider.add({
    id = "zai-coding-plan",
    name = "Z.ai Coding Plan",
    api = Zai(),
    base_url = "https://api.z.ai/api/coding/paas/v4",
    auth_env = { "ZAI_API_KEY" },
    models = {
        { id = "glm-5.3", context = 1000000, output = 131072, reasoning = true, images = false },
        { id = "glm-5.3-flash", context = 1000000, output = 131072, reasoning = true, images = true },
        { id = "glm-5.3-highspeed", context = 1000000, output = 131072, reasoning = true, images = false },
        { id = "glm-5.2", context = 1000000, output = 131072, reasoning = true, images = false },
        { id = "glm-5.2-highspeed", context = 1000000, output = 131072, reasoning = true, images = false },
        { id = "glm-5-turbo", context = 200000, output = 131072, reasoning = true, images = false },
        { id = "glm-4.7", context = 204800, output = 131072, reasoning = true, images = false },
    },
})
