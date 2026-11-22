local T = ...

-- Fake game: uptime 10000s, epoch 1e9. cds maps spell/item id -> { start, duration } in uptime seconds.
local function fresh(game)
    _G.issecretvalue = nil
    _G.GetTime = function() return 10000 end
    _G.time = function() return 1000000000 end
    _G.UnitName = function() return "Alc" end
    _G.UnitClass = function() return "Mage", "MAGE" end
    _G.GetNormalizedRealmName = function() return "Realm" end
    _G.InCombatLockdown = function() return false end
    _G.C_Timer = { After = function() end }
    _G.C_Spell = {
        GetSpellCooldown = function(id)
            local c = game.spells[id]
            return { startTime = c and c[1] or 0, duration = c and c[2] or 0 }
        end,
        GetSpellName = function(id) return game.names[id] end,
    }
    _G.C_Container = { GetItemCooldown = function(id)
        local c = game.items[id]; if c then return c[1], c[2], 1 end; return 0, 0, 1
    end }
    _G.C_Item = { GetItemCount = function(id) return game.owned[id] or 0 end }
    _G.IsPlayerSpell = function(id) return game.known[id] or false end
    local FCT = { db = {} }
    for _, f in ipairs({ "Timers.lua", "Scanner.lua" }) do assert(loadfile(T.root .. "/" .. f))("ForeverCraftTimers", FCT) end
    return FCT
end

local function game() return { spells = {}, items = {}, names = {}, owned = {}, known = {} } end

T.test("scanner_picks_up_cooldowns_already_running_at_login", function()
    local g = game()
    g.known[18560] = true
    g.spells[18560] = { 10000 - 86400, 4 * 86400 }    -- Mooncloth made a day ago: 3 days left
    g.spells[11479] = { 9000, 2 * 86400 }             -- transmute (any of them) 1000s ago
    g.owned[15846] = 1
    g.items[15846] = { 9500, 3 * 86400 }              -- Salt Shaker used 500s ago
    local FCT = fresh(g)
    FCT.Scanner.Scan()
    local cds = FCT.db.chars["Alc-Realm"].cds
    T.eq(cds.mooncloth.expires, 1000000000 + 3 * 86400)
    T.eq(cds.transmute.expires, 1000000000 + 2 * 86400 - 1000)
    T.eq(cds.saltshaker.expires, 1000000000 + 3 * 86400 - 500)
    T.eq(FCT.db.chars["Alc-Realm"].class, "MAGE")
end)

T.test("scanner_known_but_ready_shows_ready_and_unknown_is_skipped", function()
    local g = game()
    g.known[17187] = true
    local FCT = fresh(g)
    FCT.Scanner.Scan()
    local cds = FCT.db.chars["Alc-Realm"].cds
    T.eq(cds.transmute.expires, 0)
    T.eq(cds.mooncloth, nil); T.eq(cds.saltshaker, nil)
end)

T.test("scanner_zero_reading_keeps_hand_set_timer", function()
    local g = game()
    g.known[18560] = true
    local FCT = fresh(g)
    FCT.Timers.Record(FCT.db, "Alc-Realm", "mooncloth", 1000000000 + 500, nil, 1000000000)
    FCT.Scanner.Scan()
    T.eq(FCT.db.chars["Alc-Realm"].cds.mooncloth.expires, 1000000000 + 500)
end)

T.test("scanner_remaining_ignores_gcd_and_handles_wrapped_start", function()
    local S = fresh(game()).Scanner
    T.eq(S.Remaining(9999, 1.5, 10000), nil)
    T.eq(S.Remaining(0, 0, 10000), nil)
    T.eq(S.Remaining(9000 + 2 ^ 32 / 1000, 86400, 10000), 85400)
end)

T.test("scanner_cast_starts_timer_with_transmute_label", function()
    local g = game()
    g.names[17187] = "Transmute: Arcanite"
    g.names[12345] = "Fireball"
    local FCT = fresh(g)
    FCT.Scanner.OnCast(12345)
    T.eq(FCT.db.chars, nil)
    FCT.Scanner.OnCast(17187)
    local r = FCT.db.chars["Alc-Realm"].cds.transmute
    T.eq(r.label, "Arcanite"); T.eq(r.expires, 1000000000 + 2 * 86400)
end)

T.test("scanner_match_salt_shaker_by_name", function()
    local S = fresh(game()).Scanner
    T.eq(S.Match(99999, "Salt Shaker").key, "saltshaker")
    T.eq(S.Match(99999, "Transmute: Iron to Gold").key, "transmute")
    T.eq(S.Match(99999, "Mooncloth").key, "mooncloth")
end)

T.test("scanner_cast_matches_by_id_in_any_language", function()
    local g = game()
    g.names[18560] = "Mondstoff"
    g.names[17187] = "Transmutieren: Arkanit"
    local FCT = fresh(g)
    FCT.Scanner.OnCast(18560)
    FCT.Scanner.OnCast(17187)
    local cds = FCT.db.chars["Alc-Realm"].cds
    assert(cds.mooncloth and cds.transmute)
    T.eq(cds.mooncloth.guess, true)
end)

T.test("scanner_reads_recipe_cooldown_when_spell_cooldown_is_empty", function()
    local g = game()
    g.known[18560] = true
    local FCT = fresh(g)
    _G.C_TradeSkillUI = { GetRecipeCooldown = function(id) if id == 18560 then return 7200, false, 0, 0 end end }
    FCT.Scanner.Scan()
    _G.C_TradeSkillUI = nil
    T.eq(FCT.db.chars["Alc-Realm"].cds.mooncloth.expires, 1000000000 + 7200)
end)

T.test("scanner_secret_values_are_skipped_not_errors", function()
    local g = game()
    g.known[18560] = true
    local FCT = fresh(g)
    local SECRET = setmetatable({}, { __lt = function() error("secret compare") end })
    _G.issecretvalue = function(v) return v == SECRET end
    _G.C_Spell.GetSpellCooldown = function() return { startTime = SECRET, duration = SECRET } end
    FCT.Scanner.Scan()
    FCT.Scanner.OnCast(SECRET)
    T.eq(FCT.db.chars["Alc-Realm"].cds.mooncloth.expires, 0)
end)

T.test("scanner_skips_in_combat", function()
    local FCT = fresh(game())
    _G.InCombatLockdown = function() return true end
    FCT.Scanner.Scan()
    T.eq(FCT.db.chars, nil)
end)
