-- EzAcquaintances: what you wrote about someone on their unit tooltip, and a small badge by the target
-- frame while you target someone from your book. Post-hooks only, so neither taints Blizzard's frames.
local _, ns = ...

local NOTE_CHARS = 90 -- note text shown on the tooltip; the rest is in the book

local function Accent(text)
    return "|c" .. ns.COLORS.title .. text .. "|r"
end

-- "the Red - friend [ally, owes me gold]": alias, relationship and tags on one line, or nil.
local function Summary(p)
    local parts = {}
    if p.alias and p.alias ~= "" then parts[#parts + 1] = '"' .. p.alias .. '"' end
    if p.rel and p.rel ~= "" then parts[#parts + 1] = p.rel end
    local tags = ns.TagList(p)
    if #tags > 0 then parts[#parts + 1] = "[" .. table.concat(tags, ", ") .. "]" end
    if #parts > 0 then return table.concat(parts, " - ") end
end

local function ShortNote(p)
    if not p.note or p.note == "" then return end
    local line = p.note:gsub("%s+", " ")
    if #line > NOTE_CHARS then line = line:sub(1, NOTE_CHARS - 3) .. "..." end
    return line
end

-- The record for the player a unit token points at, with its key.
local function PersonFor(unit)
    local info = unit and ns.Readable(unit) and ns.UnitInfo(unit)
    if not info then return end
    local key = ns.KeyFor(info.name)
    return ns.Person(key), key
end

local issecret = issecretvalue or function() return false end

-- true/false for a yes/no unit API answer, nil when it's secret.
local function Check(v)
    if issecret(v) then return nil end
    return v and true or false
end

-- Zone of a group member: the raid roster has it, else the map they're on (works for party members).
local function GroupZone(unit)
    local index = unit:match("^raid(%d+)$") or (IsInRaid() and ns.Readable(UnitInRaid(unit)))
    if index and GetRaidRosterInfo then
        local zone = ns.Readable(select(7, GetRaidRosterInfo(tonumber(index))))
        if zone then return zone end
    end
    local mapID = C_Map and C_Map.GetBestMapForUnit and ns.Readable(C_Map.GetBestMapForUnit(unit))
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and ns.Readable(info.name)
end

-- The zone of a group member out of sight, unless the tooltip already shows it.
local function AddZoneLine(tooltip, unit)
    if not (unit and ns.Readable(unit)) then return end
    if not (Check(UnitInParty(unit)) or Check(UnitInRaid(unit))) then return end
    if Check(UnitIsUnit(unit, "player")) ~= false or Check(UnitIsConnected(unit)) == false then return end
    if Check(UnitIsVisible(unit)) ~= false then return end -- in sight: you can see where they are
    local zone = GroupZone(unit)
    if not zone then return end
    for i = 1, tooltip:NumLines() do
        local line = _G[tooltip:GetName() .. "TextLeft" .. i]
        if line and ns.Readable(line:GetText()) == zone then return end
    end
    tooltip:AddLine(zone, 1, 1, 1)
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
local function OnUnitTooltip(tooltip)
    if tooltip ~= GameTooltip or not EzAcquaintancesDB or not EzAcquaintancesDB.tooltip then return end
    local _, unit = tooltip:GetUnit()
    AddZoneLine(tooltip, unit)
    local p = PersonFor(unit)
    if not p then return end
    if p.book then
        tooltip:AddLine(Accent("Acquaintance") .. (Summary(p) and (": " .. Summary(p)) or ""), 1, 1, 1, true)
        local note = ShortNote(p)
        if note then tooltip:AddLine(note, 0.75, 0.75, 0.75, true) end
    else
        tooltip:AddLine(("Recent face, met %s"):format(ns.Ago(p.first.t)), 0.6, 0.6, 0.6)
    end
end

function ns.InitTooltip()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
    elseif GameTooltip:HasScript("OnTooltipSetUnit") then
        GameTooltip:HookScript("OnTooltipSetUnit", OnUnitTooltip)
    end
end

---------------------------------------------------------------------------
-- Target badge
---------------------------------------------------------------------------
local badge = CreateFrame("Button", "EzAcquaintancesBadge", UIParent, "BackdropTemplate")
badge:SetHeight(18)
badge:SetFrameStrata("MEDIUM")
badge:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
badge:SetBackdropColor(0.05, 0.05, 0.06, 0.8)
badge:SetBackdropBorderColor(1, 0.82, 0.3, 0.35)
badge:Hide()
ns.Movable(badge, "badgePos")
badge.icon = badge:CreateTexture(nil, "ARTWORK")
badge.icon:SetSize(14, 14)
badge.icon:SetPoint("LEFT", 2, 0)
badge.icon:SetTexture(ns.BADGE_ICON)
badge.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
badge.text:SetPoint("LEFT", badge.icon, "RIGHT", 4, 0)
badge.text:SetWordWrap(false)

badge:SetScript("OnClick", function(self) ns.ToggleBook(self.key) end)
badge:SetScript("OnEnter", function(self)
    local p = self.key and ns.Person(self.key)
    if not p then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(ns.Title(p))
    local summary = Summary(p)
    if summary then GameTooltip:AddLine(summary, 1, 0.82, 0.3, true) end
    if p.note and p.note ~= "" then GameTooltip:AddLine(p.note, 0.85, 0.85, 0.85, true) end
    GameTooltip:AddLine("First met " .. ns.FirstMetLine(p), 0.6, 0.6, 0.6, true)
    GameTooltip:AddLine("Click: open in your book. Drag: move.", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)
badge:SetScript("OnLeave", function() GameTooltip:Hide() end)

function ns.PlaceBadge()
    if TargetFrame then
        ns.PlaceFrame(badge, "badgePos", "BOTTOMLEFT", TargetFrame, "TOPLEFT", 24, -6)
    else
        ns.PlaceFrame(badge, "badgePos", "TOP", UIParent, "TOP", 0, -120)
    end
end

function ns.UpdateBadge()
    local p, key
    if EzAcquaintancesDB.badge then p, key = PersonFor("target") end
    if not (p and p.book) then
        badge.key = nil
        return badge:Hide()
    end
    badge.key = key
    local label = (p.alias and p.alias ~= "") and p.alias or p.rel or ns.TagList(p)[1] or "known"
    badge.text:SetText(label)
    badge:SetWidth(math.min(badge.text:GetStringWidth(), 160) + 26)
    badge:Show()
end
