-- The minimap button (drag it around the rim; /acq minimap or the options page hides it) and the entry in
-- Forever's addon drawer (the TOC's AddonCompartmentFunc; Classic Era has no drawer and ignores it). Both do
-- what the launcher icon does: ns.Launch / ns.LauncherTooltip in UI.lua.
local _, ns = ...

local DEFAULT_ANGLE = 225 -- degrees, counterclockwise from the right: lower left
local RIM = 5             -- how far past the minimap's edge the button's center sits

local button = CreateFrame("Button", "EzAcquaintancesMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local border = button:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
local back = button:CreateTexture(nil, "BACKGROUND")
back:SetSize(20, 20)
back:SetPoint("TOPLEFT", 7, -5)
back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
local tex = button:CreateTexture(nil, "ARTWORK")
tex:SetSize(17, 17)
tex:SetPoint("TOPLEFT", 7, -6)
tex:SetTexture(ns.ICON)
tex:SetTexCoord(0.05, 0.95, 0.05, 0.95)

local function Clamp(v) return math.max(-1, math.min(1, v)) end

-- Puts the button on the minimap's rim at the saved angle (corners of a square minimap, when an addon
-- made it one and says so through GetMinimapShape).
function ns.PlaceMinimap()
    local a = math.rad(EzAcquaintancesDB.minimapAngle or DEFAULT_ANGLE)
    local x, y = math.cos(a), math.sin(a)
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then
        x, y = Clamp(x * 1.4142), Clamp(y * 1.4142)
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * (Minimap:GetWidth() / 2 + RIM),
        y * (Minimap:GetHeight() / 2 + RIM))
end

function ns.UpdateMinimap()
    button:SetShown(not EzAcquaintancesDB.hideMinimap)
    ns.PlaceMinimap()
end

local function Drag()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    EzAcquaintancesDB.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
    ns.PlaceMinimap()
end

button:SetScript("OnClick", function(_, which) ns.Launch(which) end)
button:SetScript("OnMouseDown", function() tex:SetPoint("TOPLEFT", 8, -7) end)
button:SetScript("OnMouseUp", function() tex:SetPoint("TOPLEFT", 7, -6) end)
button:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:LockHighlight()
    self:SetScript("OnUpdate", Drag)
end)
button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
    tex:SetPoint("TOPLEFT", 7, -6)
end)
button:SetScript("OnEnter", function(self)
    if self:GetScript("OnUpdate") then return end -- dragging
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    ns.LauncherTooltip(true)
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)
button:Hide() -- until the saved variables are in (ns.OnLogin → ns.UpdateIcon)

-- Addon drawer (named in the TOC). which: "LeftButton" / "RightButton".
function EzAcquaintances_OnAddonCompartmentClick(_, which)
    ns.Launch(which)
end

function EzAcquaintances_OnAddonCompartmentEnter(_, menuButton)
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    ns.LauncherTooltip(false)
end

function EzAcquaintances_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
