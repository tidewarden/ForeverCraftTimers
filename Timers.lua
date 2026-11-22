local _, FCT = ...

-- The saved per-character cooldown records, and the pure logic around them (no game API here, so it is
-- all testable). Times are epoch seconds from time(), so they stay valid across logouts and alts.
--
-- FCT.db.chars["Name-Realm"] = {
--     class = "MAGE",
--     cds = { transmute = { expires = 1790000000, label = "Arcanite", notified = false }, ... },
-- }
-- A record with expires <= now means "ready". A character only gets a record for a cooldown once we
-- know it has it (knows the recipe, owns the Salt Shaker, or the cooldown was seen running).
local Timers = {}
FCT.Timers = Timers

-- Spell and item IDs are the Classic ones. fallback is only used when the game reports no cooldown
-- right after a cast; the live cooldown always wins once it is readable.
Timers.DEFS = {
    {
        key = "transmute", name = "Transmute", icon = "Interface\\Icons\\INV_Misc_StoneTablet_05",
        -- All Classic transmutes share one cooldown. Arcanite first: it names the timer by default.
        spells = { 17187, 11479, 11480, 17559, 17560, 17561, 17562, 17563, 17564, 17565, 17566, 25146 },
        namePrefix = "Transmute", fallback = 2 * 86400,
    },
    {
        key = "mooncloth", name = "Mooncloth", icon = "Interface\\Icons\\INV_Fabric_Moonrag_01",
        spells = { 18560 }, fallback = 4 * 86400,
    },
    {
        key = "saltshaker", name = "Salt Shaker", icon = "Interface\\Icons\\INV_Egg_05",
        item = 15846, spells = { 19566 }, fallback = 3 * 86400,
    },
}
Timers.BY_KEY = {}
for _, def in ipairs(Timers.DEFS) do Timers.BY_KEY[def.key] = def end

local ALIASES = { transmute = "transmute", tm = "transmute", arcanite = "transmute", mooncloth = "mooncloth",
                  moon = "mooncloth", salt = "saltshaker", saltshaker = "saltshaker", shaker = "saltshaker" }
function Timers.Resolve(word) return ALIASES[(word or ""):lower()] end

local function chars(db)
    db.chars = db.chars or {}
    return db.chars
end

function Timers.Char(db, charKey, class)
    local all = chars(db)
    local c = all[charKey]
    if not c then c = { cds = {} }; all[charKey] = c end
    c.cds = c.cds or {}
    if class then c.class = class end
    return c
end

-- A running cooldown was seen (or set by hand). Moving the end time re-arms the alert.
function Timers.Record(db, charKey, cdKey, expires, label, now)
    local c = Timers.Char(db, charKey)
    local r = c.cds[cdKey] or {}
    c.cds[cdKey] = r
    if r.expires ~= expires then
        r.expires = expires
        r.notified = expires <= now -- setting a cooldown to "ready" by hand shouldn't fire an alert
    end
    if label then r.label = label end
    return r
end

-- The character has this cooldown but the game shows it not running. Never shortens a stored timer:
-- profession cooldowns can read as 0 before the game has loaded them, and a hand-set timer must stick.
function Timers.MarkKnown(db, charKey, cdKey)
    local c = Timers.Char(db, charKey)
    if not c.cds[cdKey] then c.cds[cdKey] = { expires = 0, notified = true } end
end

-- Cooldowns that have run out and haven't been announced yet. Marks them announced.
function Timers.TakeDue(db, now)
    local due = {}
    for charKey, c in pairs(chars(db)) do
        for cdKey, r in pairs(c.cds or {}) do
            if not r.notified and (r.expires or 0) <= now then
                r.notified = true
                due[#due + 1] = { char = charKey, cd = cdKey, label = r.label }
            end
        end
    end
    table.sort(due, function(a, b) return a.char == b.char and a.cd < b.cd or a.char < b.char end)
    return due
end

function Timers.Forget(db, charKey)
    local all = chars(db)
    if all[charKey] then all[charKey] = nil; return true end
    -- Allow just the name when it's unambiguous.
    local found
    for key in pairs(all) do
        if key:lower():match("^([^-]+)") == charKey:lower() then
            if found then return false end
            found = key
        end
    end
    if found then all[found] = nil; return true end
    return false
end

-- Every character with at least one cooldown, sorted, current character first. Each row:
-- { char, class, cds = { { key, name, label, remaining } ... in DEFS order } }
function Timers.Rows(db, now, currentChar)
    local rows = {}
    for charKey, c in pairs(chars(db)) do
        local row = { char = charKey, class = c.class, cds = {} }
        for _, def in ipairs(Timers.DEFS) do
            local r = c.cds and c.cds[def.key]
            if r then
                row.cds[#row.cds + 1] = { key = def.key, name = def.name, label = r.label,
                                          remaining = math.max(0, (r.expires or 0) - now) }
            end
        end
        if #row.cds > 0 then rows[#rows + 1] = row end
    end
    table.sort(rows, function(a, b)
        if (a.char == currentChar) ~= (b.char == currentChar) then return a.char == currentChar end
        return a.char < b.char
    end)
    return rows
end

function Timers.Format(seconds)
    if seconds <= 0 then return "Ready" end
    local d = math.floor(seconds / 86400)
    local h = math.floor(seconds % 86400 / 3600)
    local m = math.floor(seconds % 3600 / 60)
    if d > 0 then return ("%dd %dh"):format(d, h) end
    if h > 0 then return ("%dh %dm"):format(h, m) end
    if m > 0 then return ("%dm"):format(m) end
    return "<1m"
end

-- "2d5h", "3h 20m", "45m", "90" (minutes) -> seconds; nil if unreadable.
function Timers.ParseDuration(text)
    text = (text or ""):lower():gsub("%s+", "")
    if text == "" then return nil end
    if text:match("^%d+$") then return tonumber(text) * 60 end
    local total, rest = 0, text
    local units = { d = 86400, h = 3600, m = 60, s = 1 }
    while rest ~= "" do
        local n, u, tail = rest:match("^(%d+)([dhms])(.*)$")
        if not n then return nil end
        total = total + tonumber(n) * units[u]
        rest = tail
    end
    return total
end

-- The transmute product from a spell name: "Transmute: Arcanite" -> "Arcanite".
function Timers.LabelFromSpellName(name)
    if not name then return nil end
    return name:match("^[^:]+:%s*(.+)$")
end
