local _, FCT = ...
local Options = {}
FCT.Options = Options

local W = FCT.Widgets
local NAME = "ForeverCraftTimers"

local function build()
    local S = FCT.Settings
    local panel = CreateFrame("Frame")
    panel.name = NAME
    local items = {}

    local title = W.text(panel, "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(NAME)
    local blurb = W.text(panel, "GameFontNormalSmall", unpack(W.MUTED))
    blurb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    blurb:SetText("Tracks Transmute, Mooncloth and Salt Shaker cooldowns across all your characters.")

    local alerts = W.toggle(panel, "Alert when a cooldown is ready (any character)", function() return S.Get("alerts") end, function(v) S.Set("alerts", v) end)
    alerts:SetPoint("TOPLEFT", 16, -70)
    items[#items + 1] = alerts

    local minimap = W.toggle(panel, "Show minimap button", function() return S.Get("minimap") end, function(v) S.Set("minimap", v) end)
    minimap:SetPoint("TOPLEFT", 16, -100)
    items[#items + 1] = minimap

    local test = W.button(panel, "Show a test alert", function() FCT.Command("test") end, 180)
    test:SetPoint("TOPLEFT", 16, -140)

    local reset = W.button(panel, "Reset to defaults", function()
        S.Reset()
        for _, item in ipairs(items) do item:Refresh() end
    end, 180)
    reset:SetPoint("TOPLEFT", 16, -180)

    panel:SetScript("OnShow", function() for _, item in ipairs(items) do item:Refresh() end end)
    return panel
end

function Options.Register()
    local panel = build()
    if Settings and Settings.RegisterCanvasLayoutCategory then -- the game's Settings, not ours
        local category = Settings.RegisterCanvasLayoutCategory(panel, NAME)
        Settings.RegisterAddOnCategory(category)
        Options.categoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        Options.panel = panel
    end
end

function Options.Open()
    if Options.categoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(Options.categoryID)
    elseif Options.panel and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(Options.panel) -- the first call only opens the frame
        InterfaceOptionsFrame_OpenToCategory(Options.panel)
    else
        FCT.Print("options are unavailable on this client")
    end
end
