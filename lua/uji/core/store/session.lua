local class = require("uji.core.class")
local event = require("uji.core.event")
local id = require("uji.core.id")
local ito = require("ito")
local list = require("uji.utils.list")
local sys = require("uji.sys")
local tables = require("uji.core.tables")
local tokens = require("uji.core.agent.tokens")

local PLACEHOLDERS = { [""] = true, untitled = true, new = true, resumed = true }
local PAGE = 200
local ESTIMATES = setmetatable({}, { __mode = "k" })

local RECENT =
    "SELECT id, seq, time_created, data FROM messages WHERE session_id = ? AND seq >= coalesce((SELECT max(seq) FROM messages WHERE session_id = ? AND type = 'compaction'), 0) ORDER BY seq"
local EARLIER =
    "SELECT id, seq, time_created, data FROM (SELECT id, seq, time_created, data FROM messages WHERE session_id = ? AND seq < ? ORDER BY seq DESC LIMIT ?) ORDER BY seq"

local function read(session, sql, params)
    return list.mapped(session.store.db:query(sql, params), function(row)
        return {
            id = row.id,
            seq = row.seq,
            time = row.time_created,
            message = sys.json.decode(row.data, { nulls = false }),
        }
    end)
end

local function usage()
    return { input = 0, output = 0, cache_read = 0, cache_write = 0 }
end

local function summed(into, other)
    return {
        input = into.input + (other.input or 0),
        output = into.output + (other.output or 0),
        cache_read = into.cache_read + (other.cache_read or 0),
        cache_write = into.cache_write + (other.cache_write or 0),
    }
end

local function context_tokens(spent)
    return (spent.input or 0) + (spent.output or 0) + (spent.cache_read or 0) + (spent.cache_write or 0)
end

local function encode(message)
    local copy = tables.copy(message)
    if copy.type == "assistant" and copy.tool_calls and #copy.tool_calls == 0 then
        copy.tool_calls = nil
    end
    if copy.type == "compaction" then
        copy.files = sys.json.array(copy.files or {})
    end
    return sys.json.encode(copy)
end

local Session = class()

function Session:init(store, row)
    self.store = store
    self.id = row.id
    self.title = row.title
    self.directory = row.directory
    self.parent = row.parent
    self.updated = row.time_updated
    self.saved = row.saved ~= false
    self.tally = { usage = usage(), last = usage(), turns = 0 }
    ito.observable(self)
end

function Session:save()
    if self.saved then
        return
    end
    local now = sys.os.now()
    self.store.db:exec(
        "INSERT INTO sessions (id, title, directory, parent, time_created, time_updated) VALUES (?, ?, ?, ?, ?, ?)",
        { self.id, self.title, self.directory, self.parent or sys.db.null, now, now }
    )
    self.saved, self.updated = true, now
end

function Session:entries()
    self.stored = self.stored or read(self, RECENT, { self.id, self.id })
    return self.stored
end

function Session:older(limit)
    local first = self:entries()[1]
    if not first or first.seq <= 1 then
        return false
    end
    local earlier = read(self, EARLIER, { self.id, first.seq, limit or PAGE })
    if #earlier == 0 then
        return false
    end
    self.stored = list.extended(earlier, self.stored)
    ESTIMATES[self] = nil
    return true
end

function Session:messages()
    return list.mapped(self:entries(), function(entry)
        return entry.message
    end)
end

function Session:last_seq()
    local stored = self:entries()
    return #stored > 0 and stored[#stored].seq or 0
end

function Session:append(message)
    local stored = self:entries()
    local now = sys.os.now()
    local entry = { id = id.new(), seq = self:last_seq() + 1, time = now, message = message }
    local db = self.store.db
    local ok, err = pcall(db.transaction, db, function()
        self:save()
        db:exec(
            "INSERT INTO messages (id, session_id, seq, type, time_created, data) VALUES (?, ?, ?, ?, ?, ?)",
            { entry.id, self.id, entry.seq, message.type, now, encode(message) }
        )
        db:exec("UPDATE sessions SET time_updated = ? WHERE id = ?", { now, self.id })
    end)
    self.stored = list.appended(stored, entry)
    ESTIMATES[self] = nil
    event.emit("message_appended", { type = message.type, text = tokens.text(message) })
    if not ok then
        return entry, "failed to persist " .. message.type .. " message: " .. sys.message(err)
    end
    return entry
end

function Session:rename(title)
    self:save()
    self.store.db:exec("UPDATE sessions SET title = ? WHERE id = ?", { title, self.id })
    self.title = title
end

function Session:untitled()
    return PLACEHOLDERS[(self.title or ""):match("^%s*(.-)%s*$")] == true
end

function Session:child(title)
    return self.store:create_session(title or self.title, self.id)
end

function Session:unanswered_calls()
    local stored = self:entries()
    local answered = {}
    for index = #stored, 1, -1 do
        local message = stored[index].message
        if message.type == "tool" then
            answered[message.tool_call_id] = true
        elseif message.type == "assistant" then
            return list.filtered(message.tool_calls or {}, function(call)
                return not answered[call.id]
            end)
        else
            break
        end
    end
    return {}
end

function Session:add_cost(spent)
    local tally = self.tally
    self.tally = { usage = summed(tally.usage, spent), last = tally.last, turns = tally.turns }
end

function Session:add_usage(spent)
    local tally = self.tally
    self.tally = {
        usage = summed(tally.usage, spent),
        last = {
            input = spent.input or 0,
            output = spent.output or 0,
            cache_read = spent.cache_read or 0,
            cache_write = spent.cache_write or 0,
        },
        turns = tally.turns + 1,
    }
end

function Session:used_tokens()
    local stored = self:entries()
    local at = tokens.last_compaction(stored) or 0
    local estimate = ESTIMATES[self]
    if not estimate then
        estimate = tokens.total(stored)
        ESTIMATES[self] = estimate
    end
    for index = #stored, at + 1, -1 do
        local spent = stored[index].message.usage
        if spent then
            return math.max(context_tokens(spent) + tokens.after(stored, stored[index].seq), estimate)
        end
    end
    return estimate
end

Session.encode = encode

return Session
