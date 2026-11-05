-- EzAcquaintances window (Book / Recent faces tabs, search, tag filter, detail pane, options) and the
-- launcher icon. Own flat frames only: Blizzard menus crash in combat on Forever, and the window itself is
-- never protected, so it stays usable in combat (right-click targeting is a separate secure button).
-- Whispering only opens a box on them (chat's, or EzAccent's/EzOOC's/EzTongues' own); you type and send it yourself.
local _, ns = ...

local W, H = 600, 400
local PAD, GAP = 8, 6
local TOP_H = 22
local LIST_W, ROW_H = 220, 20
local BODY_TOP = -(PAD + TOP_H + GAP)
local LIST_ROWS = math.floor((H + BODY_TOP - PAD) / ROW_H)
local DETAIL_X = PAD + LIST_W + GAP + 4
local LABEL_W = 82
local MAX_OTHERS = 3 -- other characters' meetings listed in the detail pane

local WHITE = "Interface\\Buttons\\WHITE8x8"
local FLAT = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }

local function Skin(f, alpha)
    f:SetBackdrop(FLAT)
    f:SetBackdropColor(0.05, 0.05, 0.06, alpha or 0.92)
    f:SetBackdropBorderColor(1, 1, 1, 0.08)
end

local function Text(parent, font)
    return parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
end

local function Hover(f, alpha)
    local hl = f:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, alpha or 0.08)
end

-- Flat button with a centered label.
local function TextButton(parent, label, width)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, 20)
    Skin(b, 0.6)
    Hover(b)
    b.text = Text(b)
    b.text:SetPoint("LEFT", 6, 0)
    b.text:SetPoint("RIGHT", -6, 0)
    b.text:SetWordWrap(false)
    b.text:SetText(label)
    return b
end

-- Text box with grey placeholder text that shows while it's empty.
local function SingleLineBox(parent, placeholder, inset)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetHeight(TOP_H)
    Skin(e, 0.5)
    e:SetFontObject("GameFontHighlightSmall")
    e:SetTextInsets(inset or 6, 6, 0, 0)
    e:SetAutoFocus(false)
    e.placeholder = Text(e, "GameFontDisableSmall")
    e.placeholder:SetPoint("LEFT", (inset or 6) + 1, 0)
    e.placeholder:SetText(placeholder)
    e:SetScript("OnTextChanged", function(self) self.placeholder:SetShown(self:GetText() == "") end)
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    return e
end

-- Flat check box with a label; get/set read and write the setting.
local function Check(parent, label, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(260, 18)
    Hover(b, 0.04)
    b.box = CreateFrame("Frame", nil, b, "BackdropTemplate")
    b.box:SetSize(12, 12)
    b.box:SetPoint("LEFT", 2, 0)
    Skin(b.box, 0.6)
    b.mark = b.box:CreateTexture(nil, "ARTWORK")
    b.mark:SetPoint("TOPLEFT", 3, -3)
    b.mark:SetPoint("BOTTOMRIGHT", -3, 3)
    b.mark:SetColorTexture(unpack(ns.COLORS.accent))
    b.text = Text(b)
    b.text:SetPoint("LEFT", b.box, "RIGHT", 6, 0)
    b.text:SetText(label)
    b.Update = function() b.mark:SetShown(get() and true or false) end
    b:SetScript("OnClick", function()
        set(not get())
        b.Update()
    end)
    return b
end

-- Remembers where frame is in EzAcquaintancesDB[field].
local function Movable(frame, field)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        EzAcquaintancesDB[field] = { "TOPLEFT", "BOTTOMLEFT", self:GetLeft(), self:GetTop() }
    end)
end
ns.Movable = Movable

-- Puts frame where EzAcquaintancesDB[field] says, or at the default anchor.
local function Place(frame, field, ...)
    local p = EzAcquaintancesDB[field]
    frame:ClearAllPoints()
    if p then
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint(...)
    end
end
ns.PlaceFrame = Place

---------------------------------------------------------------------------
-- Popup list (relationship, tags, tag filter)
---------------------------------------------------------------------------
local popup = CreateFrame("Frame", "EzAcquaintancesPopup", UIParent, "BackdropTemplate")
popup:SetFrameStrata("FULLSCREEN_DIALOG")
popup:SetClampedToScreen(true)
popup:EnableMouse(true)
Skin(popup, 0.97)
popup:Hide()
popup.rows = {}

local newTag = SingleLineBox(popup, "New tag...")
newTag:SetHeight(18)
newTag:SetMaxLetters(32)

-- Shows items ({ label, checked, onClick }) under anchor; keepOpen leaves it up after a click (tags).
-- onNew adds a box at the bottom for a tag of your own, passed to onNew.
local function OpenPopup(anchor, items, keepOpen, onNew)
    if popup:IsShown() and popup.anchor == anchor then return popup:Hide() end
    popup.anchor = anchor
    local width = math.max(anchor:GetWidth(), 150)
    for i, item in ipairs(items) do
        local b = popup.rows[i]
        if not b then
            b = CreateFrame("Button", nil, popup)
            b:SetHeight(18)
            Hover(b)
            b.mark = b:CreateTexture(nil, "ARTWORK")
            b.mark:SetSize(6, 6)
            b.mark:SetPoint("LEFT", 6, 0)
            b.mark:SetColorTexture(unpack(ns.COLORS.accent))
            b.text = Text(b)
            b.text:SetPoint("LEFT", 18, 0)
            b.text:SetPoint("RIGHT", -6, 0)
            b.text:SetJustifyH("LEFT")
            popup.rows[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 18)
        b:SetPoint("RIGHT", -2, 0)
        b.text:SetText(item.label)
        b.mark:SetShown(item.checked and true or false)
        b:SetScript("OnClick", function()
            item.onClick()
            if keepOpen then
                item.checked = not item.checked
                b.mark:SetShown(item.checked)
            else
                popup:Hide()
            end
        end)
        b:Show()
    end
    for i = #items + 1, #popup.rows do popup.rows[i]:Hide() end
    local h = 4 + #items * 18
    newTag:SetShown(onNew ~= nil)
    if onNew then
        newTag:ClearAllPoints()
        newTag:SetPoint("TOPLEFT", 4, -h - 2)
        newTag:SetPoint("RIGHT", -4, 0)
        newTag:SetText("")
        newTag:SetScript("OnEnterPressed", function(self)
            local text = self:GetText()
            self:SetText("")
            self:ClearFocus()
            popup:Hide()
            onNew(text)
        end)
        h = h + 24
    end
    popup:SetSize(width, h)
    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    popup:Show()
end

popup:SetScript("OnShow", function(self) pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
popup:SetScript("OnHide", function(self) pcall(self.UnregisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
popup:SetScript("OnEvent", function(self)
    -- A click anywhere else closes it (the anchor's own click toggles it).
    if not (self:IsMouseOver() or (self.anchor and self.anchor:IsMouseOver())) then self:Hide() end
end)

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------
local book = CreateFrame("Frame", "EzAcquaintancesFrame", UIParent, "BackdropTemplate")
book:SetSize(W, H)
Skin(book)
book:SetFrameStrata("HIGH")
book:EnableMouse(true)
Movable(book, "framePos")
book:Hide()
tinsert(UISpecialFrames, "EzAcquaintancesFrame") -- Esc closes it
local Uncover -- defined with the list
book:SetScript("OnHide", function()
    popup:Hide()
    Uncover()
end)

local selected, offset, keys = nil, 0, {}
local filterTag
local mode = "list" -- "list" | "options"
local extraTabs = {} -- tabs other addons added (EzAcquaintancesAPI.AddTab): key -> { def, panel }
local Refresh, ShowDetail -- defined below

local close = TextButton(book, "x", TOP_H)
close:SetHeight(TOP_H)
close:SetPoint("TOPRIGHT", -PAD, -PAD)
close.text:SetJustifyH("CENTER")
close:SetScript("OnClick", function() book:Hide() end) -- not HideUIPanel, so it works in combat too

local gear = CreateFrame("Button", nil, book)
gear:SetSize(TOP_H, TOP_H)
gear:SetPoint("RIGHT", close, "LEFT", -4, 0)
gear.tex = gear:CreateTexture(nil, "ARTWORK")
gear.tex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
gear.tex:SetSize(14, 14)
gear.tex:SetPoint("CENTER")
gear.tex:SetAlpha(0.6)
gear:SetScript("OnEnter", function(self) self.tex:SetAlpha(1) end)
gear:SetScript("OnLeave", function(self) self.tex:SetAlpha(0.6) end)
gear:SetScript("OnClick", function()
    mode = mode == "options" and "list" or "options"
    Refresh()
end)

-- Tabs, left to right; each is sized to its label in Refresh.
local tabs, lastTab = {}, nil
local function Tab(key)
    local b = CreateFrame("Button", nil, book)
    b:SetSize(80, TOP_H)
    if lastTab then b:SetPoint("LEFT", lastTab, "RIGHT", 2, 0) else b:SetPoint("TOPLEFT", PAD, -PAD) end
    lastTab = b
    Hover(b, 0.05)
    b.text = Text(b, "GameFontNormalSmall")
    b.text:SetPoint("CENTER")
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetColorTexture(unpack(ns.COLORS.accent))
    b.bar:SetHeight(2)
    b.bar:SetPoint("BOTTOMLEFT", 6, 0)
    b.bar:SetPoint("BOTTOMRIGHT", -6, 0)
    b:SetScript("OnClick", function()
        EzAcquaintancesDB.tab, offset, mode = key, 0, "list"
        Refresh()
    end)
    tabs[key] = b
    return b
end
Tab("book")
Tab("recent")

local search = SingleLineBox(book, "Search names, notes, places", 6)
search:HookScript("OnTextChanged", function()
    offset = 0
    Refresh()
end)
search:SetScript("OnEscapePressed", function(self)
    if self:GetText() ~= "" then self:SetText("") else self:ClearFocus() end
end)

local tagFilter = TextButton(book, "All tags", 110)
tagFilter:SetHeight(TOP_H)
tagFilter:SetPoint("RIGHT", gear, "LEFT", -6, 0)
tagFilter:SetScript("OnClick", function(self)
    local items = { { label = "All tags", checked = not filterTag, onClick = function() filterTag = nil Refresh() end } }
    for _, tag in ipairs(ns.AllTags()) do
        items[#items + 1] = { label = tag, checked = filterTag == tag, onClick = function()
            filterTag, offset = tag, 0
            Refresh()
        end }
    end
    OpenPopup(self, items)
end)

-- The search box fills the bar between the last tab and the tag filter.
local function PlaceSearch()
    search:ClearAllPoints()
    search:SetPoint("LEFT", lastTab, "RIGHT", 8, 0)
    search:SetPoint("RIGHT", tagFilter, "LEFT", -6, 0)
end
PlaceSearch()

---------------------------------------------------------------------------
-- List
---------------------------------------------------------------------------
local list = CreateFrame("Frame", nil, book)
list:SetPoint("TOPLEFT", PAD, BODY_TOP)
list:SetSize(LIST_W, LIST_ROWS * ROW_H)
list:EnableMouseWheel(true)

local divider = book:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(1, 1, 1, 0.06)
divider:SetWidth(1)
divider:SetPoint("TOPLEFT", PAD + LIST_W + GAP / 2, BODY_TOP)
divider:SetPoint("BOTTOMLEFT", PAD + LIST_W + GAP / 2, PAD)

local empty = Text(list, "GameFontDisableSmall")
empty:SetPoint("TOPLEFT", 8, -8)
empty:SetPoint("RIGHT", -8, 0)
empty:SetJustifyH("LEFT")

local rows = {}
for i = 1, LIST_ROWS do
    local b = CreateFrame("Button", nil, list)
    b:SetSize(LIST_W, ROW_H)
    b:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    Hover(b, 0.05)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints()
    b.sel:SetColorTexture(1, 0.82, 0.3, 0.12)
    b.name = Text(b)
    b.name:SetPoint("LEFT", 6, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.info = Text(b, "GameFontDisableSmall")
    b.info:SetPoint("RIGHT", -6, 0)
    b.info:SetJustifyH("RIGHT")
    b.info:SetWordWrap(false)
    b.name:SetPoint("RIGHT", b.info, "LEFT", -6, 0)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    -- Out of combat the target button below covers the row and takes its clicks.
    b:SetScript("OnClick", function(self, button)
        selected = self.key
        Refresh(true)
        if button == "MiddleButton" then return ns.Whisper(self.key) end
        if button == "RightButton" and InCombatLockdown() then ns.Print("Can't target from the book in combat.") end
    end)
    rows[i] = b
end

-- Ways to whisper someone: the chat box, or another addon's own box on a whisper to them. Each takes the full
-- "First Surname" (a first name alone doesn't reach them on Forever). The one you pick is EzAcquaintancesDB.whisperWith.
local SendTell = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
local function Api(name)
    local api = _G[name]
    return type(api) == "table" and type(api.Whisper) == "function" and api.Whisper or nil
end
local WAYS = {
    { key = "chat", label = "Chat", button = "Whisper", get = function() return SendTell end },
    { key = "accent", label = "In your accent (EzAccent)", button = "Whisper: accent",
        get = function() return Api("EzAccentAPI") end },
    { key = "ooc", label = "Out of character (EzOOC)", button = "Whisper: OOC", get = function() return Api("EzOOCAPI") end },
    { key = "tongue", label = "In a tongue (EzTongues)", button = "Whisper: tongue",
        get = function() return Api("EzTonguesAPI") end },
}

-- The way you picked, or chat when its addon isn't loaded.
local function WhisperWay()
    for _, w in ipairs(WAYS) do
        if w.key == EzAcquaintancesDB.whisperWith and w.get() then return w end
    end
    return WAYS[1]
end

-- The ways that work here (chat plus the box addons that are loaded).
local function WhisperWays()
    local ways = {}
    for _, w in ipairs(WAYS) do if w.get() then ways[#ways + 1] = w end end
    return ways
end

function ns.Whisper(key, way)
    local p = key and ns.Person(key)
    local open = p and (way or WhisperWay()).get()
    if open then open((p.name:gsub("%c", ""))) end
end

local function Scroll(delta)
    offset = math.max(0, math.min(offset - delta * 3, #keys - LIST_ROWS))
    Refresh()
end
list:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)

-- Right-click a row to target them. Targeting by name needs a secure macro (/targetexact: Forever gives
-- addons no friendly nameplates), and secure frames can't change in combat. So the rows stay plain and,
-- out of combat, one secure button covers the row under the mouse (left-click still selects). It sits on
-- UIParent, placed by coordinates: inside or anchored to the book, it would lock the book in combat.
local targetButton = CreateFrame("Button", "EzAcquaintancesTargetButton", UIParent, "SecureActionButtonTemplate")
targetButton:SetFrameStrata("HIGH")
targetButton:RegisterForClicks("LeftButtonUp", "MiddleButtonUp",
    C_CVar.GetCVarBool("ActionButtonUseKeyDown") and "RightButtonDown" or "RightButtonUp")
targetButton:SetAttribute("type2", "macro")
targetButton:EnableMouseWheel(true)
targetButton:Hide()

-- Full name first, then the first name alone, which is what the unit is called (as in EzMark). No
-- /cleartarget: when they aren't in view, you keep your target.
local function TargetMacro(name)
    name = name:gsub("%c", "")
    local first = name:match("^%S+") or name
    if first == name then return "/targetexact " .. name end
    return "/targetexact " .. name .. "\n/targetexact " .. first
end

function Uncover()
    if targetButton.row then targetButton.row:UnlockHighlight() end
    targetButton.row = nil
    if not InCombatLockdown() then targetButton:Hide() end
end

-- Puts the target button over row b and points it at b's person.
local function Cover(b)
    if InCombatLockdown() then return end
    local p = b:IsVisible() and b.key and ns.Person(b.key)
    if not p then return Uncover() end
    if targetButton.row and targetButton.row ~= b then targetButton.row:UnlockHighlight() end
    local ratio = b:GetEffectiveScale() / targetButton:GetEffectiveScale()
    targetButton:ClearAllPoints()
    targetButton:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", b:GetLeft() * ratio, b:GetTop() * ratio)
    targetButton:SetSize(b:GetWidth() * ratio, b:GetHeight() * ratio)
    targetButton:SetFrameLevel(b:GetFrameLevel() + 5)
    targetButton:SetAttribute("macrotext2", TargetMacro(p.name))
    targetButton.row, targetButton.key, targetButton.name = b, b.key, p.name
    b:LockHighlight()
    targetButton:Show()
end

for _, b in ipairs(rows) do b:SetScript("OnEnter", Cover) end

-- The macro has run by now; if they aren't the target, /targetexact didn't find them.
targetButton:SetScript("PostClick", function(self, button)
    local key, name = self.key, self.name
    selected = key
    Refresh(true)
    if button == "MiddleButton" then return ns.Whisper(key) end
    if button ~= "RightButton" then return end
    local info = ns.UnitInfo("target")
    if not (info and ns.Key(info.name) == key) then ns.Print(name .. " isn't close enough to target.") end
end)
targetButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Right-click: target them if they're nearby", 0.8, 0.8, 0.8)
    local way = WhisperWay()
    GameTooltip:AddLine("Middle-click: whisper them" .. (way.key == "chat" and "" or " (" .. way.label .. ")"),
        0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
targetButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
    if not self:IsMouseOver() then Uncover() end
end)
targetButton:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
targetButton:RegisterEvent("PLAYER_REGEN_DISABLED") -- last moment it can still be hidden
targetButton:SetScript("OnEvent", Uncover)

local function Matches(p, query)
    if filterTag and not (p.tags and p.tags[filterTag]) then return false end
    if query == "" then return true end
    local hay = strlower(table.concat({
        p.name or "", p.alias or "", p.note or "", p.rel or "", p.race or "", p.className or "",
        ns.Place(p.first.zone, p.first.sub), ns.Place(p.lastZone, p.lastSub), table.concat(ns.TagList(p), " "),
    }, " "))
    return hay:find(query, 1, true) ~= nil
end

local function Collect()
    local tab, query = EzAcquaintancesDB.tab, strlower(strtrim(search:GetText()))
    local people = EzAcquaintancesCharDB.people
    local counts = { book = 0, recent = 0 }
    wipe(keys)
    for key, p in pairs(people) do
        local t = p.book and "book" or "recent"
        counts[t] = counts[t] + 1
        if t == tab and Matches(p, query) then keys[#keys + 1] = key end
    end
    if tab == "book" then
        table.sort(keys, function(a, b) return strlower(people[a].name) < strlower(people[b].name) end)
    else
        table.sort(keys, function(a, b) return (people[a].last or 0) > (people[b].last or 0) end)
    end
    return counts
end

local function RowInfo(p)
    if not p.book then return ns.Ago(p.last) end
    local tags = ns.TagList(p)
    return (p.rel and p.rel ~= "" and p.rel) or tags[1] or ""
end

---------------------------------------------------------------------------
-- Detail pane
---------------------------------------------------------------------------
local detail = CreateFrame("Frame", nil, book)
detail:SetPoint("TOPLEFT", DETAIL_X, BODY_TOP)
detail:SetPoint("BOTTOMRIGHT", -PAD, PAD)

local nameText = Text(detail, "GameFontNormalLarge")
nameText:SetPoint("TOPLEFT", 0, -2)
nameText:SetPoint("RIGHT")
nameText:SetJustifyH("LEFT")
nameText:SetWordWrap(false)

local classText = Text(detail)
classText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)
classText:SetPoint("RIGHT")
classText:SetJustifyH("LEFT")

local labels = {}
local function Label(text, y)
    local l = Text(detail, "GameFontNormalSmall")
    labels[#labels + 1] = l
    l:SetPoint("TOPLEFT", 0, y)
    l:SetWidth(LABEL_W)
    l:SetJustifyH("LEFT")
    l:SetText(text)
    return l
end

local function Current()
    return selected and ns.Person(selected)
end

-- Typing saves straight away; only real typing (userInput), since SetText and first show report changes too.
Label("Known as", -48)
local alias = SingleLineBox(detail, "an alias, a title, \"the Red\"")
alias:SetPoint("TOPLEFT", LABEL_W, -44)
alias:SetPoint("RIGHT")
alias:SetHeight(20)
alias:SetMaxLetters(ns.ALIAS_MAX)
alias:HookScript("OnTextChanged", function(self, userInput)
    local p = Current()
    if not (userInput and p) then return end
    local text = strtrim(self:GetText())
    p.alias = text ~= "" and text or nil
    if ns.UpdateBadge then ns.UpdateBadge() end
end)

Label("Relationship", -74)
local rel = TextButton(detail, "", 150)
rel:SetPoint("TOPLEFT", LABEL_W, -70)
rel.text:SetJustifyH("LEFT")
rel:SetScript("OnClick", function(self)
    local p = Current()
    if not p then return end
    local items = {}
    for _, r in ipairs(ns.RELATIONSHIPS) do
        items[#items + 1] = { label = r == "" and "(none)" or r, checked = (p.rel or "") == r, onClick = function()
            p.rel = r ~= "" and r or nil
            ns.Changed(selected)
        end }
    end
    OpenPopup(self, items)
end)

Label("Tags", -100)
local tagsButton = TextButton(detail, "", 10)
tagsButton:SetPoint("TOPLEFT", LABEL_W, -96)
tagsButton:SetPoint("RIGHT")
tagsButton.text:SetJustifyH("LEFT")
tagsButton:SetScript("OnClick", function(self)
    local p, key = Current(), selected
    if not p then return end
    local items = {}
    for _, tag in ipairs(ns.AllTags()) do
        items[#items + 1] = { label = tag, checked = p.tags and p.tags[tag], onClick = function()
            ns.ToggleTag(key, tag)
        end }
    end
    OpenPopup(self, items, true, function(text)
        local tag = ns.Tag(text)
        if tag and not (p.tags and p.tags[tag]) then ns.ToggleTag(key, tag) end
    end)
end)

Label("Note", -126)
local noteBox = CreateFrame("Frame", nil, detail, "BackdropTemplate")
noteBox:SetPoint("TOPLEFT", 0, -142)
noteBox:SetPoint("RIGHT")
noteBox:SetHeight(96)
Skin(noteBox, 0.5)

local noteScroll = CreateFrame("ScrollFrame", nil, noteBox)
noteScroll:SetPoint("TOPLEFT", 6, -5)
noteScroll:SetPoint("BOTTOMRIGHT", -6, 5)

local note = CreateFrame("EditBox", nil, noteScroll)
note:SetMultiLine(true)
note:SetAutoFocus(false)
note:SetFontObject("GameFontHighlightSmall")
note:SetMaxLetters(ns.NOTE_MAX)
note:SetWidth(W - DETAIL_X - PAD - 12)
noteScroll:SetScrollChild(note)
note:SetScript("OnEscapePressed", note.ClearFocus)
note.placeholder = Text(noteBox, "GameFontDisableSmall")
note.placeholder:SetPoint("TOPLEFT", 7, -6)
note.placeholder:SetText("Who are they? What happened? What do they owe you?")
note:SetScript("OnTextChanged", function(self, userInput)
    self.placeholder:SetShown(self:GetText() == "")
    local p = Current()
    if not (userInput and p) then return end
    local text = self:GetText()
    p.note = strtrim(text) ~= "" and text or nil
end)
-- Keeps the cursor in view while typing.
note:SetScript("OnCursorChanged", function(_, _, y, _, h)
    local top, height = noteScroll:GetVerticalScroll(), noteScroll:GetHeight()
    y = -y
    if y < top then
        noteScroll:SetVerticalScroll(y)
    elseif y + h > top + height then
        noteScroll:SetVerticalScroll(y + h - height)
    end
end)
noteScroll:EnableMouseWheel(true)
noteScroll:SetScript("OnMouseWheel", function(self, delta)
    local v = self:GetVerticalScroll() - delta * 14
    self:SetVerticalScroll(math.max(0, math.min(v, self:GetVerticalScrollRange())))
end)
noteBox:EnableMouse(true)
noteBox:SetScript("OnMouseDown", function() note:SetFocus() end)

local facts = Text(detail)
facts:SetPoint("TOPLEFT", noteBox, "BOTTOMLEFT", 0, -8)
facts:SetPoint("RIGHT")
facts:SetJustifyH("LEFT")
facts:SetJustifyV("TOP")
facts:SetSpacing(2)

-- Bottom buttons: Recent "Add to book" / "Dismiss"; Book "Move to recent" / "Forget".
local primary = TextButton(detail, "", 100)
primary:SetPoint("BOTTOMLEFT")
primary.text:SetJustifyH("CENTER")
local forget = TextButton(detail, "", 100)
forget:SetPoint("LEFT", primary, "RIGHT", 6, 0)
forget.text:SetJustifyH("CENTER")

-- Whisper: left-click opens your usual way, right-click lists the ways (picking one opens it and makes it your usual).
local whisper = TextButton(detail, "Whisper", 10)
whisper:SetPoint("LEFT", forget, "RIGHT", 6, 0)
whisper:SetPoint("RIGHT")
whisper.text:SetJustifyH("CENTER")
whisper:RegisterForClicks("LeftButtonUp", "RightButtonUp")
local function WhisperTip(self)
    local ways = WhisperWays()
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Whisper them: " .. WhisperWay().label)
    GameTooltip:AddLine("Opens it on them; you write and send the line.", 0.8, 0.8, 0.8)
    if #ways > 1 then GameTooltip:AddLine("Right-click: whisper another way", 0.8, 0.8, 0.8) end
    GameTooltip:Show()
end
whisper:SetScript("OnClick", function(self, button)
    local ways = WhisperWays()
    if button ~= "RightButton" or #ways < 2 then
        popup:Hide()
        return ns.Whisper(selected)
    end
    local items, current = {}, WhisperWay()
    for _, w in ipairs(ways) do
        items[#items + 1] = { label = w.label, checked = w == current, onClick = function()
            EzAcquaintancesDB.whisperWith = w.key
            ns.Whisper(selected, w)
            Refresh()
        end }
    end
    OpenPopup(self, items)
end)
whisper:SetScript("OnEnter", WhisperTip)
whisper:SetScript("OnLeave", function() GameTooltip:Hide() end)

primary:SetScript("OnClick", function()
    local p = Current()
    if not p then return end
    if p.book then ns.Demote(selected) else ns.Promote(selected) end
end)
-- Forgetting a Book entry takes a second click.
forget:SetScript("OnClick", function(self)
    local p = Current()
    if not p then return end
    if p.book and self.armed ~= selected then
        self.armed = selected
        self.text:SetText("|cffff6060Click again|r")
        return
    end
    self.armed = nil
    local i = 0
    for n, k in ipairs(keys) do if k == selected then i = n end end
    ns.Forget(selected)
    selected = keys[i] or keys[i - 1] -- Changed already rebuilt keys without them
    Refresh(true)
end)

local blank = Text(detail, "GameFontDisableSmall")
blank:SetPoint("TOPLEFT", 0, -4)
blank:SetPoint("RIGHT")
blank:SetJustifyH("LEFT")

local detailParts = { nameText, classText, alias, rel, tagsButton, noteBox, facts, primary, forget, whisper }

local function ShowParts(on)
    for _, f in ipairs(detailParts) do f:SetShown(on) end
    for _, l in ipairs(labels) do l:SetShown(on) end
    blank:SetShown(not on)
end

-- Fills the pane for the selected person. force: the selection changed, so the edit boxes are reset too;
-- otherwise a box you're typing in keeps its text.
function ShowDetail(force)
    local p = Current()
    ShowParts(p ~= nil)
    if not p then
        blank:SetText(EzAcquaintancesDB.tab == "book" and "Pick someone, or add a face from Recent."
            or "People you group, trade, duel or whisper with land here.")
        return
    end
    nameText:SetText(p.name)
    classText:SetText(ns.ClassText(p) or "|cff888888Race and class unknown: target them once.|r")
    if force or not alias:HasFocus() then alias:SetText(p.alias or "") end
    if force or not note:HasFocus() then
        note:SetText(p.note or "")
        if force then noteScroll:SetVerticalScroll(0) end
    end
    rel.text:SetText(p.rel or "|cff888888(none)|r")
    local tags = ns.TagList(p)
    tagsButton.text:SetText(#tags > 0 and table.concat(tags, ", ") or "|cff888888click to add tags|r")

    local lines = {
        "|cffaaaaaaFirst met|r " .. ns.FirstMetLine(p),
        ("|cffaaaaaaLast seen|r %s, |cffaaaaaamet|r %d time%s"):format(ns.LastSeenLine(p), p.met or 1,
            (p.met or 1) == 1 and "" or "s"),
    }
    local others = ns.OtherChars(selected)
    for i, o in ipairs(others) do
        if i > MAX_OTHERS then
            lines[#lines + 1] = ("|cffaaaaaa...and %d more of your characters (/acq who)|r"):format(#others - MAX_OTHERS)
            break
        end
        lines[#lines + 1] = "|cffaaaaaaYour|r " .. ns.OtherCharLine(o)
    end
    if not p.book then
        lines[#lines + 1] = ("|cff888888Forgotten in %d days unless you add them.|r"):format(
            math.max(0, ns.INBOX_DAYS - math.floor((time() - (p.last or 0)) / 86400)))
    end
    facts:SetText(table.concat(lines, "\n"))

    primary.text:SetText(p.book and "Move to recent" or "Add to book")
    whisper.text:SetText(WhisperWay().button)
    if forget.armed ~= selected then
        forget.armed = nil
        forget.text:SetText(p.book and "Forget" or "Dismiss")
    end
end

---------------------------------------------------------------------------
-- Options
---------------------------------------------------------------------------
local options = CreateFrame("Frame", nil, book)
options:SetPoint("TOPLEFT", PAD + 4, BODY_TOP - 4)
options:SetPoint("BOTTOMRIGHT", -PAD, PAD)
options:Hide()

local checks = {}
local function Option(label, field, y, after)
    local c = Check(options, label, function() return EzAcquaintancesDB[field] end, function(v)
        EzAcquaintancesDB[field] = v
        if after then after() end
    end)
    c:SetPoint("TOPLEFT", 0, y)
    checks[#checks + 1] = c
end
Option("Show your note on their tooltip", "tooltip", 0)
Option("Show a badge by the target frame", "badge", -20, function() if ns.UpdateBadge then ns.UpdateBadge() end end)
Option("Announce new faces in chat", "announce", -40)
local iconCheck = Check(options, "Show the launcher icon",
    function() return not EzAcquaintancesDB.hideIcon end,
    function(v) EzAcquaintancesDB.hideIcon = not v ns.UpdateIcon() end)
iconCheck:SetPoint("TOPLEFT", 0, -60)
checks[#checks + 1] = iconCheck

local heading = Text(options, "GameFontNormalSmall")
heading:SetPoint("TOPLEFT", 0, -92)
heading:SetText("Log someone in Recent faces when they...")
for i, key in ipairs(ns.TRIGGER_ORDER) do
    local c = Check(options, ns.TRIGGERS[key].label,
        function() return ns.TriggerOn(key) end,
        function(v) EzAcquaintancesDB.triggers[key] = v end)
    c:SetPoint("TOPLEFT", 0, -92 - i * 20)
    checks[#checks + 1] = c
end

local hint = Text(options, "GameFontDisableSmall")
hint:SetPoint("TOPLEFT", 0, -112 - #ns.TRIGGER_ORDER * 20 - 8)
hint:SetPoint("RIGHT", -8, 0)
hint:SetJustifyH("LEFT")
hint:SetText(("Recent faces you don't add to the book are forgotten after %d days. Each character keeps its "
    .. "own book; your other characters' meetings show in the detail pane. /acq help lists the commands.")
    :format(ns.INBOX_DAYS))

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
-- force: the selection changed (resets the edit boxes).
function Refresh(force)
    if not book:IsShown() then return end
    if not tabs[EzAcquaintancesDB.tab] then EzAcquaintancesDB.tab = "book" end -- its addon isn't loaded
    local counts = Collect()
    tabs.book.text:SetText(("Book (%d)"):format(counts.book))
    tabs.recent.text:SetText(("Recent (%d)"):format(counts.recent))
    for key, x in pairs(extraTabs) do tabs[key].text:SetText(x.def.label()) end
    for key, b in pairs(tabs) do
        local on = mode == "list" and key == EzAcquaintancesDB.tab
        b.bar:SetShown(on)
        b.text:SetTextColor(on and 1 or 0.6, on and 0.82 or 0.6, on and 0.3 or 0.6)
        b:SetWidth(math.max(64, b.text:GetStringWidth() + 20))
    end
    tagFilter.text:SetText(filterTag or "All tags")

    local own = mode == "list" and extraTabs[EzAcquaintancesDB.tab]
    local isList = mode == "list" and not own
    list:SetShown(isList)
    detail:SetShown(isList)
    divider:SetShown(isList)
    search:SetShown(isList)
    tagFilter:SetShown(isList)
    options:SetShown(mode == "options")
    for _, x in pairs(extraTabs) do x.panel:SetShown(x == own) end
    if not isList then
        Uncover()
        if own then return own.def.refresh(own.panel) end
        for _, c in ipairs(checks) do c.Update() end
        return
    end

    -- Keep a selection on this tab: the old one if it's still listed, else the first.
    local listed = false
    for _, k in ipairs(keys) do if k == selected then listed = true end end
    if not listed then
        selected, force = keys[1], true
    end
    offset = math.max(0, math.min(offset, #keys - LIST_ROWS))

    local people = EzAcquaintancesCharDB.people
    for i, b in ipairs(rows) do
        local key = keys[offset + i]
        local p = key and people[key]
        b:SetShown(p ~= nil)
        if p then
            b.key = key
            b.name:SetText(p.alias and p.alias ~= "" and ('%s |cff888888"%s"|r'):format(p.name, p.alias) or p.name)
            b.info:SetText(RowInfo(p))
            b.sel:SetShown(key == selected)
        end
    end
    empty:SetShown(#keys == 0)
    empty:SetText((search:GetText() ~= "" or filterTag) and "Nobody matches."
        or EzAcquaintancesDB.tab == "book" and "Your book is empty. Add faces from Recent, or /acq add <name>."
        or "No recent faces yet.")
    if targetButton.row then Cover(targetButton.row) end -- the list moved under it
    ShowDetail(force)
end

function ns.OnChanged()
    Refresh()
end

-- Opens the book (at key, when given) or closes it.
function ns.ToggleBook(key)
    if book:IsShown() and not key then return book:Hide() end
    local p = key and ns.Person(key)
    if p then
        EzAcquaintancesDB.tab, selected, mode = p.book and "book" or "recent", key, "list"
        search:SetText("")
        filterTag = nil
    end
    book:Show()
    Refresh(true)
end

function EzAcquaintances_Toggle()
    ns.ToggleBook()
end

-- For other addons: a tab of their own in the book (EzMinion's graduates). AddTab{ key, label = function()
-- -> tab text, build = function(panel) once, refresh = function(panel) each time the book refreshes on
-- that tab }. The panel fills the body under the tabs (api.ROWS rows of api.ROW_H); the helpers give it
-- the book's look.
EzAcquaintancesAPI = {
    AddTab = function(def)
        if tabs[def.key] then return end
        Tab(def.key)
        PlaceSearch()
        local panel = CreateFrame("Frame", nil, book)
        panel:SetPoint("TOPLEFT", PAD, BODY_TOP)
        panel:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        panel:Hide()
        def.build(panel)
        extraTabs[def.key] = { def = def, panel = panel }
    end,
    Refresh = function() Refresh() end,
    ShowTab = function(key)
        EzAcquaintancesDB.tab, mode = key, "list"
        book:Show()
        Refresh(true)
    end,
    -- This character's record of name, or nil.
    Person = function(name) return ns.Person(ns.Key(name)) end,
    -- Opens the book at name; false when they aren't in it.
    ShowPerson = function(name)
        if not ns.Person(ns.Key(name)) then return false end
        ns.ToggleBook(ns.Key(name))
        return true
    end,
    ClassText = function(p) return ns.ClassText(p) end,
    ROW_H = ROW_H, ROWS = LIST_ROWS, LIST_W = LIST_W,
    Skin = Skin, Text = Text, Hover = Hover, TextButton = TextButton, SingleLineBox = SingleLineBox,
}

---------------------------------------------------------------------------
-- Launcher icon
---------------------------------------------------------------------------
local icon = CreateFrame("Button", "EzAcquaintancesIcon", UIParent, "BackdropTemplate")
icon:SetSize(24, 24)
icon:SetFrameStrata("MEDIUM")
Movable(icon, "iconPos")
icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
icon:SetBackdrop(FLAT)
icon:SetBackdropColor(0, 0, 0, 0.6)
icon:SetBackdropBorderColor(0, 0, 0, 1)
icon:SetAlpha(0.7)
icon.tex = icon:CreateTexture(nil, "ARTWORK")
icon.tex:SetPoint("TOPLEFT", 1, -1)
icon.tex:SetPoint("BOTTOMRIGHT", -1, 1)
icon.tex:SetTexture(ns.ICON)
icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

icon:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        mode = "options"
        if not book:IsShown() then book:Show() end
        Refresh()
    else
        ns.ToggleBook()
    end
end)
icon:SetScript("OnEnter", function(self)
    self:SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("EzAcquaintances")
    GameTooltip:AddLine("Click: your book", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: options", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: move", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
icon:SetScript("OnLeave", function(self)
    self:SetAlpha(0.7)
    GameTooltip:Hide()
end)

function ns.UpdateIcon()
    icon:SetShown(not EzAcquaintancesDB.hideIcon)
end

function ns.ApplyPositions()
    Place(icon, "iconPos", "BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", -28, 28)
    Place(book, "framePos", "CENTER", UIParent, "CENTER", 0, 60)
    if ns.PlaceBadge then ns.PlaceBadge() end
end

function ns.OnLogin()
    ns.ApplyPositions()
    ns.UpdateIcon()
    if ns.InitTooltip then ns.InitTooltip() end
    if ns.UpdateBadge then ns.UpdateBadge() end
end
