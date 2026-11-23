local _, FCT = ...
local S = FCT.Settings

-- The on-screen notice: the ready cooldown's icon near the top of the screen, a line per character and a
-- countdown. Hides itself after NOTICE_SECONDS. /fct unlock shows it with a drag handle; the position is saved.
local Notice = {}
FCT.Notice = Notice

Notice.SECONDS = 60
local LINE_HEIGHT = 16
local frame, ticker, hideAt
local unlocked = false

local function place()
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", S.Get("x"), S.Get("y"))
end

local function build()
    if frame then return end
    frame = CreateFrame("Frame", "ForeverCraftTimersNotice", UIParent)
    frame:SetSize(300, 64)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    -- Always takes the mouse: a left-click hides it, and hovering says so.
    frame:EnableMouse(true)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and not unlocked then GameTooltip:Hide(); Notice.Hide() end
    end)
    frame:SetScript("OnEnter", function(self)
        if unlocked then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Click to hide", 1, 1, 1)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame:SetScript("OnDragStart", function(self) if unlocked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save as an offset from the top centre of the screen, the anchor place() uses.
        S.Set("x", math.floor(self:GetCenter() - UIParent:GetWidth() / 2 + 0.5))
        S.Set("y", math.floor(self:GetTop() - UIParent:GetHeight() + 0.5))
        place()
    end)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(56, 56)
    frame.icon:SetPoint("TOPLEFT", 4, -4)
    frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -6)
    frame.title:SetTextColor(0.2, 1, 0.4)

    frame.timer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.timer:SetPoint("LEFT", frame.title, "RIGHT", 8, 0)

    frame.sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.sub:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
    frame.sub:SetJustifyH("LEFT")

    frame:Hide()
    place()
    S.OnChange(function(key) if key == "x" or key == "y" then place() end end)
end

function Notice.IsShown() return frame ~= nil and frame:IsShown() end

local function tick()
    if unlocked then return end
    local left = math.ceil(hideAt - GetTime())
    if left <= 0 then Notice.Hide(); return end
    frame.timer:SetText(left .. "s")
end

-- title: "Transmute ready!"; lines: one per character; icon: texture path or file ID.
function Notice.Show(title, lines, icon)
    build()
    frame.icon:SetTexture(icon)
    frame.title:SetText(title)
    frame.sub:SetText(table.concat(lines, "\n"))
    frame:SetHeight(math.max(64, 34 + #lines * LINE_HEIGHT))
    hideAt = GetTime() + Notice.SECONDS
    if unlocked then return end
    frame:Show()
    tick()
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(0.25, tick)
end

function Notice.Hide()
    if ticker then ticker:Cancel(); ticker = nil end
    if frame and not unlocked then frame:Hide() end
end

function Notice.ToggleUnlock()
    build()
    unlocked = not unlocked
    if unlocked then
        if ticker then ticker:Cancel(); ticker = nil end
        frame.icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
        frame.title:SetText("Cooldown ready!")
        frame.timer:SetText("")
        frame.sub:SetText("Drag me, then /fct lock")
        frame:SetHeight(64)
        frame:Show()
    else
        frame:Hide()
    end
    return unlocked
end
