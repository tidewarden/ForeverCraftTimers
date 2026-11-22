-- ForeverCraftTimers
-- Tracks Transmute, Mooncloth and Salt Shaker cooldowns across all your characters.

local ADDON, FCT = ...
local T = FCT.Timers

function FCT.Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33e5ffForeverCraftTimers|r: " .. msg) end

local HELP = {
    "/fct - list every character's cooldowns",
    "/fct set <transmute|mooncloth|salt> <time|ready> - set this character's timer by hand, e.g. /fct set mooncloth 2d5h",
    "/fct forget <Name or Name-Realm> - remove a character",
    "/fct scan - re-read this character's cooldowns",
    "/fct test - show a test alert",
    "/fct debug - show what the game reports for each watched spell and item",
    "/fct options",
}

function FCT.Command(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "" or cmd == "list" then
        FCT.Scanner.Scan()
        FCT.Launcher.PrintList()
    elseif cmd == "set" then
        local which, amount = rest:match("^(%S+)%s+(.+)$")
        local key = T.Resolve(which)
        local seconds = amount and (amount:lower() == "ready" and 0 or T.ParseDuration(amount))
        if not key or not seconds then FCT.Print(HELP[2]); return end
        T.Record(FCT.db, FCT.Scanner.CharKey(), key, FCT.Now() + seconds, nil, FCT.Now(), "manual")
        FCT.Print(T.BY_KEY[key].name .. ": " .. T.Format(seconds))
        FCT.Launcher.Refresh()
    elseif cmd == "forget" and rest ~= "" then
        FCT.Print(T.Forget(FCT.db, rest) and ("forgot " .. rest) or ("no single character matches " .. rest))
        FCT.Launcher.Refresh()
    elseif cmd == "scan" then
        FCT.Scanner.Scan()
        FCT.Launcher.PrintList()
    elseif cmd == "test" then
        FCT.Alerts.Show(FCT.Alerts.Text({ char = FCT.Scanner.CharKey(), cd = "transmute", label = "Arcanite" }))
    elseif cmd == "debug" then
        FCT.Scanner.Debug()
    elseif cmd == "options" then
        FCT.Options.Open()
    else
        for _, line in ipairs(HELP) do FCT.Print(line) end
    end
end

SLASH_FOREVERCRAFTTIMERS1 = "/fct"
SlashCmdList.FOREVERCRAFTTIMERS = FCT.Command

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, a1, _, a3)
    if event == "ADDON_LOADED" and a1 == ADDON then
        ForeverCraftTimersDB = ForeverCraftTimersDB or {}
        FCT.db = ForeverCraftTimersDB
    elseif event == "PLAYER_LOGIN" then
        FCT.Options.Register()
        FCT.Launcher.Install()
        events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        events:RegisterEvent("BAG_UPDATE_COOLDOWN")
        for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE" }) do pcall(events.RegisterEvent, events, e) end
        FCT.Scanner.Scan()
        C_Timer.After(5, FCT.Scanner.Scan) -- profession cooldowns can arrive a moment after login
        FCT.Alerts.Start()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        FCT.Scanner.OnCast(a3)
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" or event:match("^TRADE_SKILL_") then
        FCT.Scanner.Soon()
    end
end)
