local _, FCT = ...

-- Minimap button (LibDataBroker + LibDBIcon, vendored in Libs/). The tooltip lists every character and
-- what's left on each cooldown. Left-click prints the same list to chat, right-click opens the options.
local Launcher = {}
FCT.Launcher = Launcher
local T = FCT.Timers

local NAME = "ForeverCraftTimers"
local LibDBIcon, object

local function classColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function cdText(cd)
    local name = cd.name
    if cd.key == "transmute" and cd.label then name = name .. " (" .. cd.label .. ")" end
    return name, T.Format(cd.remaining)
end

local function rows() return T.Rows(FCT.db, time(), FCT.Scanner.CharKey()) end

function Launcher.FillTooltip(tooltip)
    tooltip:AddLine("ForeverCraftTimers")
    local list = rows()
    if #list == 0 then
        tooltip:AddLine("No cooldowns yet. Log in on each crafter once.", 1, 1, 1, true)
    end
    for _, row in ipairs(list) do
        tooltip:AddLine(" ")
        tooltip:AddLine(FCT.Alerts.ShortName(row.char), classColor(row.class))
        for _, cd in ipairs(row.cds) do
            local name, left = cdText(cd)
            if cd.remaining <= 0 then
                tooltip:AddDoubleLine("  " .. name, left, 1, 1, 1, 0.2, 1, 0.4)
            else
                tooltip:AddDoubleLine("  " .. name, left, 1, 1, 1, 1, 0.82, 0)
            end
        end
    end
    tooltip:AddLine(" ")
    tooltip:AddLine("Left-click: print to chat   Right-click: options", 0.6, 0.6, 0.6)
end

function Launcher.PrintList()
    local list = rows()
    if #list == 0 then FCT.Print("no cooldowns recorded yet"); return end
    for _, row in ipairs(list) do
        local parts = {}
        for _, cd in ipairs(row.cds) do
            local name, left = cdText(cd)
            parts[#parts + 1] = name .. " " .. (cd.remaining <= 0 and "|cff33ff66Ready|r" or left)
        end
        FCT.Print(FCT.Alerts.ShortName(row.char) .. ": " .. table.concat(parts, ", "))
    end
end

-- Icon text for broker displays: how many cooldowns are ready right now.
function Launcher.Refresh()
    if not object or not FCT.db then return end
    local ready, total = 0, 0
    for _, row in ipairs(rows()) do
        for _, cd in ipairs(row.cds) do
            total = total + 1
            if cd.remaining <= 0 then ready = ready + 1 end
        end
    end
    object.text = ("%d/%d ready"):format(ready, total)
end

function Launcher.ApplyShown()
    if not LibDBIcon then return end
    if FCT.Settings.Get("minimap") then LibDBIcon:Show(NAME) else LibDBIcon:Hide(NAME) end
end

function Launcher.Install()
    local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
    LibDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if not (ldb and LibDBIcon) then LibDBIcon = nil; return end
    FCT.db.minimapIcon = FCT.db.minimapIcon or {}
    object = ldb:GetDataObjectByName(NAME) or ldb:NewDataObject(NAME, {
        type = "data source",
        text = "",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        OnClick = function(_, button)
            if button == "RightButton" then FCT.Options.Open() else Launcher.PrintList() end
        end,
        OnTooltipShow = function(tooltip) Launcher.FillTooltip(tooltip) end,
    })
    LibDBIcon:Register(NAME, object, FCT.db.minimapIcon)
    Launcher.ApplyShown()
    Launcher.Refresh()
    FCT.Settings.OnChange(function(key) if key == "minimap" then Launcher.ApplyShown() end end)
end
