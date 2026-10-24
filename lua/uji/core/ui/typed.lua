local M = {}

local function masked(ctx, text)
    return (text:gsub("[\1-\127\194-\244][\128-\191]*", ctx.symbols.mask))
end

function M.spans(ctx, field, styles)
    local before = field.text:sub(1, field.cursor)
    local rest = field.text:sub(field.cursor + 1)
    local covered = rest:match("^[^\n][\128-\191]*")
    if covered then
        rest = rest:sub(#covered + 1)
    end
    if field.hidden then
        before, covered, rest = masked(ctx, before), ctx.symbols.mask, masked(ctx, rest)
    elseif not covered then
        covered = " "
    end
    return { { before, styles.text }, { covered, styles.cursor }, { rest, styles.text } }
end

return M
