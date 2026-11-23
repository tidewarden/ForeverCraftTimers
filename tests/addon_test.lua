local T = ...
local fake = require("fake_wow")

-- Loads every addon file (no libraries, so no minimap icon) and runs login and the slash commands.
T.test("addon_login_and_slash_commands", function()
    _G.issecretvalue = nil
    _G.GetTime = function() return 10000 end
    _G.time = function() return 1000000000 end
    _G.UnitName = function() return "Alc" end
    _G.UnitClass = function() return "Mage", "MAGE" end
    _G.GetNormalizedRealmName = function() return "Realm" end
    _G.InCombatLockdown = function() return false end
    local later = {}
    _G.C_Timer = { After = function(_, fn) later[#later + 1] = fn end, NewTicker = function() end }
    _G.C_Spell = { GetSpellCooldown = function() return { startTime = 0, duration = 0 } end, GetSpellName = function() end }
    _G.C_Container = { GetItemCooldown = function() return 0, 0, 1 end }
    _G.C_Item = { GetItemCount = function() return 0 end }
    _G.IsPlayerSpell = function() return false end
    local shown = {}
    _G.RaidWarningUtil = { AddMessage = function(text) shown[#shown + 1] = text end }

    local FCT, world = fake.fresh(T.root, { files = { "Settings.lua", "Timers.lua", "Scanner.lua", "Alerts.lua",
        "Launcher.lua", "Widgets.lua", "Options.lua", "ForeverCraftTimers.lua" } })
    FCT.Options.Register = function() end -- the panel needs real font strings
    local events
    for _, f in ipairs(world.frames) do if f._events.ADDON_LOADED then events = f end end
    local onEvent = events:GetScript("OnEvent")
    onEvent(events, "ADDON_LOADED", "ForeverCraftTimers")
    onEvent(events, "PLAYER_LOGIN")

    -- An alt's Mooncloth ran out while offline: announced at login.
    FCT.Timers.Record(FCT.db, "Tailor-Realm", "mooncloth", 999999000, nil, 0)
    SlashCmdList.FOREVERCRAFTTIMERS("set transmute 1d2h")
    T.eq(FCT.db.chars["Alc-Realm"].cds.transmute.expires, 1000000000 + 26 * 3600)
    for _, fn in ipairs(later) do fn() end
    T.eq(shown[1], "Tailor: Mooncloth is ready")

    world.printed = {}
    SlashCmdList.FOREVERCRAFTTIMERS("")
    local all = table.concat(world.printed, "\n")
    assert(all:find("Alc: Transmute 1d 2h"), all)
    assert(all:find("Tailor: Mooncloth"), all)
    -- Lots due at once: one line plus a count, and nothing while in combat.
    for _, n in ipairs({ "A", "B", "C" }) do FCT.Timers.Record(FCT.db, n .. "-Realm", "mooncloth", 999999000, nil, 0) end
    shown = {}
    _G.InCombatLockdown = function() return true end
    FCT.Alerts.Check(); T.eq(#shown, 0)
    _G.InCombatLockdown = function() return false end
    FCT.Alerts.Check()
    T.eq(#shown, 2); T.eq(shown[1], "A: Mooncloth is ready"); T.eq(shown[2], "and 2 more are ready (see the minimap button)")
    SlashCmdList.FOREVERCRAFTTIMERS("forget Tailor")
    T.eq(FCT.db.chars["Tailor-Realm"], nil)
end)

-- Forever reports an empty realm, so keys end in "-": the dash must not show.
T.test("short_name_drops_empty_realm", function()
    local FCT = require("fake_wow").fresh(T.root, { files = { "Timers.lua", "Alerts.lua" } })
    _G.GetNormalizedRealmName = function() return "Realm" end
    T.eq(FCT.Alerts.ShortName("Suhx-"), "Suhx")
    T.eq(FCT.Alerts.ShortName("Log-Realm"), "Log")
    T.eq(FCT.Alerts.ShortName("Alt-Other"), "Alt-Other")
end)
