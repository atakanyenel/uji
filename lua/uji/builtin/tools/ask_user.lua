uji.tool.add("ask_user", {
    description = "Ask the person a question and wait for their answer. Use it when a change or a setup needs "
        .. "something only they know, such as which backend, which url, or which of two files. Pass options when the "
        .. "answer is one of a few choices, and leave them out when the person should type the answer.",
    subject = function(args)
        return type(args) == "table" and type(args.question) == "string" and args.question or "a question"
    end,
    policy = "allow",
    parameters = {
        type = "object",
        properties = {
            question = { type = "string", description = "The question to put to the person, short and specific." },
            options = {
                type = "array",
                items = { type = "string" },
                description = "The answers to choose between. Leave it out when the person types the answer.",
            },
        },
        required = { "question" },
        additionalProperties = false,
    },
    run = function(args)
        local question = type(args) == "table" and args.question or nil
        if type(question) ~= "string" or question == "" then
            return "error: ask_user needs a question"
        end
        local options = type(args.options) == "table" and args.options or nil
        if options and #options > 0 then
            local chosen = uji.ui.select({ title = question, items = options })
            if chosen == nil then
                return "the person closed the question without choosing"
            end
            return "the person chose: " .. chosen
        end
        local answer = uji.ui.prompt({ title = question })
        if answer == nil then
            return "the person closed the question without answering"
        end
        return "the person answered: " .. answer
    end,
})
