uji.provider.add({
    id = "cerebras",
    name = "Cerebras",
    api = uji.api.openai(),
    base_url = "https://api.cerebras.ai/v1",
    auth_env = { "CEREBRAS_API_KEY" },
    models = {
        "gemma-4-31b",
        { id = "gpt-oss-120b", context = 131072, output = 40960, reasoning = true, images = false },
        { id = "qwen-3.8-27b", context = 131072, output = 40960, reasoning = true, images = true },
    },
})
