local _, FCT = ...

-- Reads this character's cooldowns from the game and stores them through FCT.Timers.
-- Running cooldowns are read live (C_Spell.GetSpellCooldown / C_Container.GetItemCooldown), so ones that
-- were started before the addon was installed are picked up at login. A cast seen with
-- UNIT_SPELLCAST_SUCCEEDED starts the timer at once, then a rescan corrects it from the live cooldown.
local Scanner = {}
FCT.Scanner = Scanner
local T = FCT.Timers

local WRAP = 2 ^ 32 / 1000 -- Classic quirk: long cooldowns started before a PC reboot report a wrapped start

local function secret(v) return issecretvalue and issecretvalue(v) end

-- Seconds left on a (start, duration) pair from the cooldown APIs, or nil when nothing long is running.
function Scanner.Remaining(start, duration, nowUptime)
    if not start or not duration or secret(start) or secret(duration) then return nil end
    if duration <= 60 or start == 0 then return nil end -- not running, or just the global cooldown
    if start > nowUptime then start = start - WRAP end
    local left = start + duration - nowUptime
    if left <= 0 or left > duration + 1 then return nil end
    return left
end

local function spellCooldown(id)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(id)
        if info then return info.startTime, info.duration end
    elseif GetSpellCooldown then
        return GetSpellCooldown(id)
    end
end

local function itemCooldown(id)
    local fn = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
    if fn then return fn(id) end
end

local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

local function knowsSpell(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) then return true end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    return false
end

local function ownsItem(id)
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    return fn and (fn(id, true) or 0) > 0
end

function Scanner.CharKey()
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "?"
    return UnitName("player") .. "-" .. realm
end

local function store(def, left, label)
    T.Record(FCT.db, Scanner.CharKey(), def.key, math.floor(time() + left + 0.5), label, time())
end

function Scanner.Scan()
    if not FCT.db or (InCombatLockdown and InCombatLockdown()) then return end
    local _, class = UnitClass("player")
    local charKey = Scanner.CharKey()
    T.Char(FCT.db, charKey, class)
    local up = GetTime()
    for _, def in ipairs(T.DEFS) do
        local left, known
        if def.item then
            known = ownsItem(def.item)
            local start, duration = itemCooldown(def.item)
            left = Scanner.Remaining(start, duration, up)
        else
            for _, id in ipairs(def.spells) do
                if knowsSpell(id) then known = true end
                local start, duration = spellCooldown(id)
                local l = Scanner.Remaining(start, duration, up)
                if l and (not left or l > left) then left = l end
            end
        end
        if left then
            store(def, left) -- label is kept from the cast, if any
        elseif known then
            T.MarkKnown(FCT.db, charKey, def.key)
        end
    end
end

-- Which of our cooldowns a cast belongs to, if any.
function Scanner.Match(spellID, name)
    for _, def in ipairs(T.DEFS) do
        if def.namePrefix then
            if name and name:sub(1, #def.namePrefix) == def.namePrefix then return def end
        else
            if name == def.name then return def end
            for _, id in ipairs(def.spells) do if id == spellID then return def end end
        end
    end
end

function Scanner.OnCast(spellID)
    if secret(spellID) then return end
    local name = spellName(spellID)
    local def = Scanner.Match(spellID, name)
    if not def then return end
    local label = def.namePrefix and T.LabelFromSpellName(name) or nil
    store(def, def.fallback, label)
    C_Timer.After(1, Scanner.Scan) -- replace the guess with the real cooldown once the game has it
    if FCT.Launcher then FCT.Launcher.Refresh() end
end

-- Throttle: SPELL_UPDATE_COOLDOWN fires a lot.
local pending = false
function Scanner.Soon()
    if pending then return end
    pending = true
    C_Timer.After(2, function() pending = false; Scanner.Scan() end)
end
