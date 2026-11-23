local _, FCT = ...

-- The on-screen notice (Notice.lua) when any character's cooldown runs out, on whichever character you're
-- playing. It comes back at every login or /reload while a cooldown is still ready.
local Alerts = {}
FCT.Alerts = Alerts
local T = FCT.Timers

local function shortName(charKey)
    -- Forever reports an empty realm, so keys look like "Suhx-": show just the name then too.
    local name, realm = charKey:match("^(.-)%-(.*)$")
    if not name then return charKey end
    local mine = GetNormalizedRealmName and GetNormalizedRealmName()
    local c = FCT.db and FCT.db.chars and FCT.db.chars[charKey]
    local full = (c and c.surname) and (name .. " " .. c.surname) or name
    if realm == "" or realm == mine then return full end
    return full .. "-" .. realm
end
Alerts.ShortName = shortName

function Alerts.Text(item)
    local def = T.BY_KEY[item.cd]
    local what = def and def.name or item.cd
    if item.label and item.cd == "transmute" then what = what .. " (" .. item.label .. ")" end
    return shortName(item.char) .. ": " .. what
end

Alerts.MAX_LINES = 5

-- What the notice says for a list of ready cooldowns: title, lines, icon.
function Alerts.Content(ready)
    local first = T.BY_KEY[ready[1].cd]
    local title = #ready == 1 and ((first and first.name or ready[1].cd) .. " ready!")
        or (#ready .. " cooldowns ready!")
    local lines = {}
    for i, item in ipairs(ready) do
        if i == Alerts.MAX_LINES and #ready > Alerts.MAX_LINES then
            lines[i] = ("and %d more (see the minimap button)"):format(#ready - i + 1)
            break
        end
        lines[i] = Alerts.Text(item)
    end
    return title, lines, first and first.icon
end

-- Shows every cooldown that is ready right now, or hides the notice when none is.
function Alerts.ShowReady()
    local ready = T.Ready(FCT.db, FCT.Now())
    if #ready == 0 then return false end
    FCT.Notice.Show(Alerts.Content(ready))
    return true
end

-- At login (and every /reload) the notice comes back while anything is still ready. During play it pops up
-- again when another cooldown runs out. Never in combat: it waits for the fight to end.
local loginPending = false
function Alerts.Check()
    if not FCT.db then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local due = T.TakeDue(FCT.db, FCT.Now())
    if FCT.Launcher then FCT.Launcher.Refresh() end
    local show = loginPending or #due > 0
    loginPending = false
    if show and FCT.Settings.Get("alerts") then Alerts.ShowReady() end
end

function Alerts.Start()
    loginPending = true
    C_Timer.After(6, Alerts.Check) -- login: after the loading screen, so the notice is seen
    C_Timer.NewTicker(15, Alerts.Check)
end

FCT.Settings.OnChange(function(key, value) if key == "alerts" and not value then FCT.Notice.Hide() end end)
