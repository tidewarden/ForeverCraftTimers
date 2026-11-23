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
    if secret(start) or secret(duration) then return nil end -- check first: even a truth test on a secret errors
    if type(start) ~= "number" or type(duration) ~= "number" then return nil end
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

-- Forever's profession window (retail-style Professions UI) reads recipe cooldowns this way:
-- Blizzard_ProfessionsTemplates/Blizzard_Professions.lua:1571 on origin/forever. Seconds left, or nil.
-- Only filled in while the profession's data is loaded, so it is read on TRADE_SKILL_* events too.
local function recipeCooldown(id)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeCooldown) then return nil end
    local ok, cooldown, _, charges, maxCharges = pcall(C_TradeSkillUI.GetRecipeCooldown, id)
    if not ok or secret(cooldown) or type(cooldown) ~= "number" or cooldown <= 60 then return nil end
    if not secret(charges) and type(maxCharges) == "number" and maxCharges > 0 and (charges or 0) > 0 then return nil end
    return cooldown
end
Scanner.recipeCooldown = recipeCooldown

local function itemCooldown(id)
    local fn = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
    if fn then return fn(id) end
end

local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

-- Profession recipes may not count as player spells, so ask the profession data too: the recipe's
-- learned flag (TradeSkillUITypesDocumentation.lua:402 on origin/forever). Filled in once the
-- profession's data is loaded (opening its window), hence the TRADE_SKILL_* rescans.
local function learnedRecipe(id)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo) then return false end
    local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
    if not ok or secret(info) or type(info) ~= "table" or secret(info.learned) then return false end
    return info.learned == true
end

local function knowsSpell(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if learnedRecipe(id) then return true end
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

local function store(def, left, label, source)
    local now = FCT.Now()
    T.Record(FCT.db, Scanner.CharKey(), def.key, math.floor(now + left + 0.5), label, now, source)
end

function Scanner.Scan()
    if not FCT.db or (InCombatLockdown and InCombatLockdown()) then return end
    local _, class = UnitClass("player")
    local charKey = Scanner.CharKey()
    local c = T.Char(FCT.db, charKey, class)
    -- Forever characters can have a surname: UnitName's second return (Blizzard_CombatAudioAlertManager.lua:1259).
    local _, surname = UnitName("player")
    if not secret(surname) and type(surname) == "string" then c.surname = surname ~= "" and surname or nil end
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
                local l = Scanner.Remaining(start, duration, up) or recipeCooldown(id)
                if l and (not left or l > left) then left = l end
            end
        end
        if left then
            store(def, left) -- label is kept from the cast, if any
        elseif known then
            T.MarkKnown(FCT.db, charKey, def.key)
        end
    end
    if FCT.Launcher then FCT.Launcher.Refresh() end
end

-- Which of our cooldowns a cast belongs to, if any.
function Scanner.Match(spellID, name)
    for _, def in ipairs(T.DEFS) do
        -- IDs work in every language; the names catch spells missing from the ID lists (English client).
        for _, id in ipairs(def.spells) do if id == spellID then return def end end
        if def.namePrefix then
            if name and name:sub(1, #def.namePrefix) == def.namePrefix then return def end
        elseif name == def.name then
            return def
        end
    end
end

function Scanner.OnCast(spellID)
    if secret(spellID) then return end
    local name = spellName(spellID)
    local def = Scanner.Match(spellID, name)
    if not def then return end
    local label = def.namePrefix and T.LabelFromSpellName(name) or nil
    store(def, def.fallback, label, "guess")
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

-- /fct debug: what the game reports for every spell and item we watch, to check the IDs in game.
function Scanner.Debug()
    local up = GetTime()
    for _, def in ipairs(T.DEFS) do
        if def.item then
            local start, duration = itemCooldown(def.item)
            FCT.Print(("%s item %d: owned=%s cd=%s/%s left=%s"):format(def.name, def.item, tostring(ownsItem(def.item)),
                tostring(start), tostring(duration), tostring(Scanner.Remaining(start, duration, up))))
        end
        for _, id in ipairs(def.spells) do
            local start, duration = spellCooldown(id)
            FCT.Print(("%s %d %s: known=%s cd=%s/%s left=%s recipe=%s"):format(def.name, id, tostring(spellName(id)),
                tostring(knowsSpell(id)), tostring(start), tostring(duration),
                tostring(Scanner.Remaining(start, duration, up)), tostring(recipeCooldown(id))))
        end
    end
end
