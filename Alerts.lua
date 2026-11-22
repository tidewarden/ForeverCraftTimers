local _, FCT = ...

-- Big centre-screen text when any character's cooldown runs out, on whichever character you're playing.
-- Notified flags are saved, so cooldowns that ran out while you were offline are announced at login.
local Alerts = {}
FCT.Alerts = Alerts
local T = FCT.Timers

local COLOR = { r = 0.20, g = 1.00, b = 0.40 }

local function shortName(charKey)
    local name, realm = charKey:match("^(.-)%-(.+)$")
    if not name then return charKey end
    local mine = GetNormalizedRealmName and GetNormalizedRealmName()
    return (realm == mine) and name or charKey
end
Alerts.ShortName = shortName

function Alerts.Text(item)
    local def = T.BY_KEY[item.cd]
    local what = def and def.name or item.cd
    if item.label and item.cd == "transmute" then what = what .. " (" .. item.label .. ")" end
    return shortName(item.char) .. ": " .. what .. " is ready"
end

function Alerts.Show(text)
    if RaidWarningUtil and RaidWarningUtil.AddMessage then
        RaidWarningUtil.AddMessage(text, COLOR, 8)
    elseif RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, text, COLOR, 8)
    else
        UIErrorsFrame:AddMessage(text, COLOR.r, COLOR.g, COLOR.b)
    end
end

-- The raid warning frame only shows two lines at once, so a pile of alerts (a login after a few days off)
-- becomes one line plus a count.
function Alerts.Lines(due)
    if #due <= 2 then
        local lines = {}
        for i, item in ipairs(due) do lines[i] = Alerts.Text(item) end
        return lines
    end
    return { Alerts.Text(due[1]), ("and %d more are ready (see the minimap button)"):format(#due - 1) }
end

function Alerts.Check()
    if not FCT.db then return end
    if InCombatLockdown and InCombatLockdown() then return end -- wait for the fight to end
    local due = T.TakeDue(FCT.db, FCT.Now())
    if FCT.Launcher then FCT.Launcher.Refresh() end
    if not FCT.Settings.Get("alerts") then return end
    for _, line in ipairs(Alerts.Lines(due)) do Alerts.Show(line) end
end

function Alerts.Start()
    C_Timer.After(6, Alerts.Check) -- login: after the loading screen, so the text is seen
    C_Timer.NewTicker(15, Alerts.Check)
end
