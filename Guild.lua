-- Guild tab: your guild's roster with what your book knows about each member, when they joined (from the
-- "X has joined the guild." line; members already there when the tab first read the roster get no made-up
-- date) and filters. Read-only toward the guild: no promote/kick/invite and no chat. Built with the book's
-- own tab mechanism (EzAcquaintancesAPI.AddTab), so it sits right after Recent.
--
-- Roster: the legacy GetGuildRosterInfo/GetGuildRosterLastOnline (Era's guild window uses them), else
-- C_Club's guild club (what Forever's Communities window reads). Both can hold secret values: every field
-- goes through Readable. Requests go through C_GuildInfo.GuildRoster, at most every ns.GUILD_ASK_GAP s.
local _, ns = ...

local issecret = issecretvalue or function() return false end
local Readable = ns.Readable
local DAY = 86400

local members = {}  -- this guild's members but you, as read last: see Read
local info = { total = 0, online = 0, hidden = 0 } -- counts from the last read
local guildName     -- nil when you aren't in a guild
local myKey

---------------------------------------------------------------------------
-- System message patterns (as EzChronicle's)
---------------------------------------------------------------------------
-- A GlobalStrings format ("%s has joined the guild.") as a Lua pattern; positions (%1$s) are kept.
local function FormatPattern(fmt)
    if type(fmt) ~= "string" then return end
    local order, auto = {}, 0
    local p = fmt:gsub("%%(%d?)%$?([sd])", function(i, c)
        if i ~= "" then
            order[#order + 1] = tonumber(i)
        else
            auto = auto + 1
            order[#order + 1] = auto
        end
        return c == "d" and "\002" or "\001"
    end)
    p = p:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0"):gsub("\001", "(.+)"):gsub("\002", "(%%d+)")
    return { pat = "^" .. p .. "$", order = order }
end

local function Match(f, msg)
    if not f then return end
    local caps = { msg:match(f.pat) }
    if #caps == 0 then return end
    local args = {}
    for i, n in ipairs(f.order) do args[n] = caps[i] end
    return args
end

local JOINED = FormatPattern(_G.ERR_GUILD_JOIN_S or "%s has joined the guild.")

-- The name in a system message's %s: a player link's target, else the text without color codes or brackets.
local function MessageName(s)
    local linked = s:match("|Hplayer:([^|:]+)")
    if linked then return linked end
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[%[%]]", ""))
end

---------------------------------------------------------------------------
-- Saved records: EzAcquaintancesCharDB.guilds[guild name] = { since, baseline, members = { [key] = m } }
-- since: when this character first read that guild's roster. baseline: no complete roster read yet, so
-- everyone seen is someone who was already there. m = { seen = first time in the roster, joined = time of
-- their join line, old = already there at since }.
---------------------------------------------------------------------------
local function Record(name)
    local all = EzAcquaintancesCharDB.guilds
    local g = all[name]
    if not g then
        g = { since = time(), baseline = true, members = {} }
        all[name] = g
    end
    return g
end

local function GuildName()
    if not (IsInGuild and IsInGuild()) then return end
    return Readable((GetGuildInfo("player")))
end

---------------------------------------------------------------------------
-- Roster
---------------------------------------------------------------------------
local function Number(v)
    if v == nil or issecret(v) or type(v) ~= "number" then return nil end
    return v
end

-- Days offline from last-online years/months/days/hours ago; 0 for under an hour.
local function Days(y, m, d, h)
    return (Number(y) or 0) * 365 + (Number(m) or 0) * 30 + (Number(d) or 0) + (Number(h) or 0) / 24
end

-- Legacy roster into out; returns total and online counts, or nil when the API isn't there.
local function ReadLegacy(out)
    if not (GetNumGuildMembers and GetGuildRosterInfo) then return end
    local total, online = GetNumGuildMembers()
    total, online = Number(total), Number(online)
    if not total then return end
    for i = 1, total do
        local name, rank, rankIndex, level, className, zone, note, _, isOnline, _, classFile =
            GetGuildRosterInfo(i)
        name = ns.CleanName(name)
        if name then
            local offline = 0
            if not Readable(isOnline) and GetGuildRosterLastOnline then offline = Days(GetGuildRosterLastOnline(i)) end
            out[#out + 1] = {
                name = name, rank = Readable(rank), rankIndex = Number(rankIndex), level = Number(level),
                className = Readable(className), class = Readable(classFile), zone = Readable(zone),
                note = Readable(note), online = Readable(isOnline) and true or false, offline = offline,
            }
        end
    end
    return total, Number(online) or 0
end

local ONLINE = { [1] = true, [2] = true, [4] = true, [5] = true } -- ClubMemberPresence Online, OnlineMobile, Away, Busy

local function ClassOf(classID)
    classID = Number(classID)
    if not classID then return end
    if C_CreatureInfo and C_CreatureInfo.GetClassInfo then
        local c = C_CreatureInfo.GetClassInfo(classID)
        if type(c) == "table" then return c.className, c.classFile end
    end
    if GetClassInfo then return GetClassInfo(classID) end
end

-- C_Club's guild club into out; same returns as ReadLegacy.
local function ReadClub(out)
    if not (C_Club and C_Club.GetGuildClubId and C_Club.GetClubMembers and C_Club.GetMemberInfo) then return end
    local clubId = C_Club.GetGuildClubId()
    if clubId == nil or issecret(clubId) then return end
    local ids = C_Club.GetClubMembers(clubId)
    if issecret(ids) or type(ids) ~= "table" then return end
    local online = 0
    for _, id in ipairs(ids) do
        local m = not issecret(id) and C_Club.GetMemberInfo(clubId, id)
        local name = type(m) == "table" and not issecret(m) and ns.CleanName(m.name)
        if name then
            local presence = Number(m.presence)
            local on = presence and ONLINE[presence] or false
            if on then online = online + 1 end
            local className, classFile = ClassOf(m.classID)
            out[#out + 1] = {
                name = name, rank = Readable(m.guildRank), rankIndex = Number(m.guildRankOrder),
                level = Number(m.level), className = Readable(className), class = Readable(classFile),
                zone = Readable(m.zone), note = Readable(m.memberNote), online = on,
                offline = on and 0 or Days(m.lastOnlineYear, m.lastOnlineMonth, m.lastOnlineDay, m.lastOnlineHour),
            }
        end
    end
    return #ids, online
end

-- Reads the roster into members and updates the saved record; false when nothing could be read yet.
local function Read()
    guildName = GuildName()
    if not guildName then
        wipe(members)
        info.total, info.online, info.hidden = 0, 0, 0
        return true
    end
    local list = {}
    local total, online = ReadLegacy(list)
    if (not total or #list == 0) then
        local club = {}
        local cTotal, cOnline = ReadClub(club)
        if cTotal and #club > 0 then list, total, online = club, cTotal, cOnline end
    end
    if not total or total == 0 or #list == 0 then return false end -- the roster hasn't arrived yet

    local g, now, present = Record(guildName), time(), {}
    wipe(members)
    for _, m in ipairs(list) do
        m.key = ns.Key(m.name)
        present[m.key] = true
        local rec = g.members[m.key]
        if not rec then
            rec = { seen = now, old = g.baseline or nil }
            g.members[m.key] = rec
        end
        m.rec = rec
        if m.key ~= myKey then members[#members + 1] = m end
    end
    -- A complete read: people missing from it left; and from now on newcomers are really new.
    if #list >= total then
        g.baseline = nil
        for key, rec in pairs(g.members) do
            -- A join line can come before the roster that has them: keep a fresh one.
            if not present[key] and not (rec.joined and now - rec.joined < 600) then g.members[key] = nil end
        end
    end
    info.total, info.online = total, online
    -- Era's roster leaves offline members out while Blizzard's "Show Offline Members" box is unticked.
    local showOffline = not GetGuildRosterShowOffline or GetGuildRosterShowOffline()
    info.hidden = (not showOffline and total > #list) and (total - #list) or 0
    return true
end

local lastAsk = -math.huge
local function AskRoster()
    if not (IsInGuild and IsInGuild()) or GetTime() - lastAsk < ns.GUILD_ASK_GAP then return end
    lastAsk = GetTime()
    local ask = (C_GuildInfo and C_GuildInfo.GuildRoster) or _G.GuildRoster
    if ask then ask() end
end

local readPending = false
local function ReadSoon()
    if readPending then return end
    readPending = true
    C_Timer.After(0.5, function() -- GUILD_ROSTER_UPDATE comes in bursts
        readPending = false
        Read()
        ns.Changed()
    end)
end

-- "X has joined the guild.": the exact day they joined.
local function OnSystem(msg)
    msg = Readable(msg)
    if type(msg) ~= "string" then return end
    local args = Match(JOINED, msg)
    local name = args and args[1] and ns.CleanName(MessageName(args[1]))
    local gname = name and GuildName()
    if not gname then return end
    local key, now = ns.Key(name), time()
    local g = Record(gname)
    local rec = g.members[key] or { seen = now }
    rec.joined, rec.old = now, nil
    g.members[key] = rec
    lastAsk = -math.huge -- show them now
    AskRoster()
end

---------------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------------
local function ShortDate(t) return date("%d %b", t) end

-- Joined column text and tooltip line.
local function JoinedText(m)
    local rec, g = m.rec, guildName and EzAcquaintancesCharDB.guilds[guildName]
    if rec.joined then
        return ShortDate(rec.joined), "Joined " .. ns.Date(rec.joined)
    elseif rec.old and g then
        return "|cff888888before " .. ShortDate(g.since) .. "|r",
            ("Already in the guild when your book first read its roster (%s)"):format(ns.Date(g.since))
    end
    return "|cff888888by " .. ShortDate(rec.seen) .. "|r",
        ("Joined while you were away; first in the roster you saw on %s"):format(ns.Date(rec.seen))
end

-- When they joined, for sorting and "new this week": their join line, else first seen (nil when already there).
local function JoinedAt(m)
    return m.rec.joined or (not m.rec.old and m.rec.seen) or nil
end

local function OfflineText(days)
    if days < 1 / 24 then return "just now" end
    if days < 1 then return ("%d h ago"):format(days * 24) end
    if days < 2 then return "yesterday" end
    if days < 60 then return ("%d days ago"):format(days) end
    if days < 365 then return ("%d months ago"):format(days / 30) end
    return ("%d years ago"):format(days / 365)
end

local function ClassColored(m)
    if not m.className then return "" end
    local c = m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
    return c and ("|c%s%s|r"):format(c.colorStr or "ffffffff", m.className) or m.className
end

-- The longer of the roster's name and the book's ("First Surname" when either has it).
local function FullName(m)
    local p = ns.Person(m.key)
    if p and p.name and #p.name > #m.name then return p.name end
    return m.name
end

---------------------------------------------------------------------------
-- Filters and sorting
---------------------------------------------------------------------------
local FILTERS = {
    { key = "all", label = "Everyone" },
    { key = "online", label = "Online", test = function(m) return m.online end },
    { key = "new", label = "New this week", test = function(m)
        local t = JoinedAt(m)
        return t ~= nil and time() - t < ns.GUILD_NEW_DAYS * DAY
    end },
    { key = "inactive", label = ("Inactive %d+ days"):format(ns.GUILD_INACTIVE_DAYS), test = function(m)
        return not m.online and m.offline >= ns.GUILD_INACTIVE_DAYS
    end },
    { key = "book", label = "In your book", test = function(m)
        local p = ns.Person(m.key)
        return p and p.book
    end },
}

local function ByName(a, b) return a.key < b.key end

-- Column sorts; each falls back to the name. "where" (the default) is online first, then last online.
local SORTS = {
    name = ByName,
    rank = function(a, b)
        if (a.rankIndex or 99) ~= (b.rankIndex or 99) then return (a.rankIndex or 99) < (b.rankIndex or 99) end
        return ByName(a, b)
    end,
    level = function(a, b)
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
        return ByName(a, b)
    end,
    class = function(a, b)
        if (a.className or "~") ~= (b.className or "~") then return (a.className or "~") < (b.className or "~") end
        return ByName(a, b)
    end,
    where = function(a, b)
        if a.online ~= b.online then return a.online end
        if not a.online and a.offline ~= b.offline then return a.offline < b.offline end
        return ByName(a, b)
    end,
    joined = function(a, b)
        local ta, tb = JoinedAt(a) or 0, JoinedAt(b) or 0
        if ta ~= tb then return ta > tb end
        return ByName(a, b)
    end,
}

local function Matches(m, query)
    if query == "" then return true end
    local p = ns.Person(m.key)
    local hay = {
        m.name, m.rank or "", m.className or "", m.zone or "", m.note or "",
    }
    if p then
        hay[#hay + 1] = p.alias or ""
        hay[#hay + 1] = p.rel or ""
        hay[#hay + 1] = p.note or ""
        hay[#hay + 1] = table.concat(ns.TagList(p), " ")
    end
    return strlower(table.concat(hay, " ")):find(query, 1, true) ~= nil
end

---------------------------------------------------------------------------
-- Tab
---------------------------------------------------------------------------
local api = EzAcquaintancesAPI
local filter, sortKey, reverse, query = "all", "where", false, ""
local shown, offset, rows = {}, 0, {}
local search, filterButton, headers, empty, status, ticker

-- Column x offsets and widths inside a row.
local COLS = {
    { key = "name", label = "Name", x = 6, w = 168 },
    { key = "rank", label = "Rank", x = 178, w = 88 },
    { key = "level", label = "Lvl", x = 270, w = 22, right = true },
    { key = "class", label = "Class", x = 300, w = 70 },
    { key = "where", label = "Zone / last on", x = 374, w = 122 },
    { key = "joined", label = "Joined", x = 500, w = 78 },
}

local function Collect()
    wipe(shown)
    local test
    for _, f in ipairs(FILTERS) do if f.key == filter then test = f.test end end
    for _, m in ipairs(members) do
        if (not test or test(m)) and Matches(m, query) then shown[#shown + 1] = m end
    end
    local sort = SORTS[sortKey]
    if reverse then
        table.sort(shown, function(a, b) return sort(b, a) end)
    else
        table.sort(shown, sort)
    end
end

local function Scroll(delta)
    offset = math.max(0, math.min(offset - delta * 3, #shown - #rows))
    api.Refresh()
end

-- Opens them in the book; someone not in it yet lands in Recent faces first, so you can write about them.
local function OpenMember(m)
    if not ns.Person(m.key) then
        local p = ns.Meet({ name = FullName(m), className = m.className, class = m.class, level = m.level,
            place = guildName and ("<" .. guildName .. ">") }, "guild", true)
        if not p then return end
    end
    ns.ToggleBook(m.key)
end

local function Tooltip(row, tip)
    local m = row.member
    if not m then return end
    local p = ns.Person(m.key)
    tip:AddLine(p and ns.Title(p) or m.name, 1, 1, 1)
    local class = ClassColored(m)
    tip:AddLine(("Level %s %s"):format(m.level or "?", class), 0.9, 0.9, 0.9)
    if m.rank then tip:AddLine("Rank: " .. m.rank, 0.9, 0.9, 0.9) end
    tip:AddLine(m.online and ("Online in " .. (m.zone or "?")) or ("Last online " .. OfflineText(m.offline)),
        0.9, 0.9, 0.9)
    local _, joined = JoinedText(m)
    tip:AddLine(joined, 0.9, 0.9, 0.9, true)
    if m.note then tip:AddLine("Guild note: " .. m.note, 0.9, 0.9, 0.9, true) end
    if p then
        if p.rel and p.rel ~= "" then tip:AddLine("Relationship: " .. p.rel, 1, 0.82, 0.3) end
        local tags = ns.TagList(p)
        if #tags > 0 then tip:AddLine("Tags: " .. table.concat(tags, ", "), 1, 0.82, 0.3, true) end
        if p.note and p.note ~= "" then
            local note = p.note:gsub("%s+", " ")
            if #note > 120 then note = note:sub(1, 117) .. "..." end
            tip:AddLine(note, 1, 0.82, 0.3, true)
        end
        tip:AddLine(p.book and "Click: open them in your book" or "Click: open them in Recent faces", 0.8, 0.8, 0.8)
    else
        tip:AddLine("Click: add them to Recent faces and write about them", 0.8, 0.8, 0.8)
    end
end

local function OnPick(row, button)
    if row.member and button ~= "RightButton" then OpenMember(row.member) end
end

local function OnWhisper(row)
    if row.member then ns.WhisperName(FullName(row.member)) end
end

local function RowEnter(self)
    if ns.CoverRow(self) then return end
    -- In combat: no target button, so the row shows its own tooltip.
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    Tooltip(self, GameTooltip)
    GameTooltip:AddLine("Middle-click: whisper them", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function Build(panel)
    local W = api.PANEL_W
    search = api.SingleLineBox(panel, "Search names, ranks, notes, zones", 6)
    search:SetHeight(20)
    search:SetPoint("TOPLEFT")
    search:SetPoint("RIGHT", -132, 0)
    search:HookScript("OnTextChanged", function(self)
        query, offset = strlower(strtrim(self:GetText())), 0
        api.Refresh()
    end)
    search:SetScript("OnEscapePressed", function(self)
        if self:GetText() ~= "" then self:SetText("") else self:ClearFocus() end
    end)

    filterButton = api.TextButton(panel, "", 126)
    filterButton:SetPoint("TOPRIGHT")
    filterButton:SetScript("OnClick", function(self)
        local items = {}
        for _, f in ipairs(FILTERS) do
            items[#items + 1] = { label = f.label, checked = f.key == filter, onClick = function()
                filter, offset = f.key, 0
                api.Refresh()
            end }
        end
        ns.OpenPopup(self, items)
    end)

    headers = {}
    for _, c in ipairs(COLS) do
        local h = CreateFrame("Button", nil, panel)
        h:SetPoint("TOPLEFT", c.x - 2, -26)
        h:SetSize(c.w + 4, 16)
        api.Hover(h, 0.05)
        h.text = api.Text(h, "GameFontNormalSmall")
        h.text:SetPoint("LEFT", 2, 0)
        h.text:SetPoint("RIGHT", -2, 0)
        h.text:SetJustifyH(c.right and "RIGHT" or "LEFT")
        h.text:SetWordWrap(false)
        h:SetScript("OnClick", function()
            if sortKey == c.key then reverse = not reverse else sortKey, reverse = c.key, false end
            api.Refresh()
        end)
        h.col = c
        headers[#headers + 1] = h
    end
    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.06)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -43)
    line:SetPoint("TOPRIGHT", 0, -43)

    local list = CreateFrame("Frame", nil, panel)
    list:SetPoint("TOPLEFT", 0, -46)
    list:SetPoint("BOTTOMRIGHT", 0, 18)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
    local n = math.floor((api.PANEL_H - 46 - 18) / api.ROW_H)
    for i = 1, n do
        local b = CreateFrame("Button", nil, list)
        b:SetSize(W, api.ROW_H)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * api.ROW_H)
        api.Hover(b, 0.05)
        b.mark = b:CreateTexture(nil, "ARTWORK") -- in your book
        b.mark:SetSize(2, api.ROW_H - 6)
        b.mark:SetPoint("LEFT", 1, 0)
        b.mark:SetColorTexture(unpack(ns.COLORS.accent))
        b.cols = {}
        for _, c in ipairs(COLS) do
            local t = api.Text(b)
            t:SetPoint("LEFT", c.x, 0)
            t:SetWidth(c.w)
            t:SetJustifyH(c.right and "RIGHT" or "LEFT")
            t:SetWordWrap(false)
            b.cols[c.key] = t
        end
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
        -- Out of combat the book's target button covers the row and takes its clicks (OnPick etc. below).
        b:SetScript("OnClick", function(self, button)
            if not self.member then return end
            if button == "MiddleButton" then return OnWhisper(self) end
            if button == "RightButton" then return ns.Print("Can't target from the book in combat.") end
            OpenMember(self.member)
        end)
        b:SetScript("OnEnter", RowEnter)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b.onPick, b.onWhisper, b.onWheel, b.tooltip = OnPick, OnWhisper, Scroll, Tooltip
        rows[i] = b
    end

    empty = api.Text(list, "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", 8, -8)
    empty:SetPoint("RIGHT", -8, 0)
    empty:SetJustifyH("LEFT")

    status = api.Text(panel, "GameFontDisableSmall")
    status:SetPoint("BOTTOMLEFT", 2, 2)
    status:SetPoint("RIGHT", -2, 0)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(false)

    -- While the tab is up, ask the server for fresh roster data now and then.
    panel:SetScript("OnShow", function()
        AskRoster()
        if not ticker then ticker = C_Timer.NewTicker(ns.GUILD_ASK_GAP, AskRoster) end
    end)
    panel:SetScript("OnHide", function()
        if ticker then ticker:Cancel() end
        ticker = nil
    end)
end

local function Refresh()
    for _, h in ipairs(headers) do
        local on = h.col.key == sortKey
        h.text:SetText(h.col.label .. (on and (reverse and " ^" or " v") or ""))
        h.text:SetTextColor(on and 1 or 0.6, on and 0.82 or 0.6, on and 0.3 or 0.6)
    end
    for _, f in ipairs(FILTERS) do
        if f.key == filter then filterButton.text:SetText(f.label) end
    end

    if guildName then Collect() else wipe(shown) end
    offset = math.max(0, math.min(offset, #shown - #rows))
    for i, b in ipairs(rows) do
        local m = shown[offset + i]
        b.member = m
        b.fullName = m and FullName(m) or nil
        b:SetShown(m ~= nil)
        if m then
            local p = ns.Person(m.key)
            local alpha = m.online and 1 or 0.55
            b.mark:SetShown(p and p.book or false)
            b.cols.name:SetText(p and p.alias and p.alias ~= "" and ('%s |cff888888"%s"|r'):format(m.name, p.alias)
                or m.name)
            b.cols.rank:SetText(m.rank or "")
            b.cols.level:SetText(m.level or "")
            b.cols.class:SetText(ClassColored(m))
            b.cols.where:SetText(m.online and (m.zone or "online") or ("|cff888888" .. OfflineText(m.offline) .. "|r"))
            b.cols.joined:SetText((JoinedText(m)))
            for _, t in pairs(b.cols) do t:SetAlpha(alpha) end
        end
    end

    empty:SetShown(#shown == 0)
    if not guildName then
        empty:SetText("You're not in a guild. Once you are, your guildmates show up here.")
    elseif #members == 0 then
        empty:SetText("Reading the guild roster...")
    else
        empty:SetText("Nobody matches.")
    end

    if not guildName then
        status:SetText("")
    else
        local g = EzAcquaintancesCharDB.guilds[guildName]
        local text = ("<%s>: %d member%s, %d online."):format(guildName, info.total, info.total == 1 and "" or "s",
            info.online)
        if g then text = text .. (" Join dates from %s."):format(ns.Date(g.since)) end
        if info.hidden > 0 then
            text = text .. (" |cffffd14d%d offline hidden: tick Show Offline Members in the guild window.|r")
                :format(info.hidden)
        end
        status:SetText(text)
    end
end

api.AddTab({
    key = "guild",
    label = function()
        if not guildName or info.total == 0 then return "Guild" end
        return ("Guild (%d/%d)"):format(info.online, info.total)
    end,
    build = Build,
    refresh = Refresh,
})

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_SYSTEM" then return OnSystem(...) end
    if event == "PLAYER_GUILD_UPDATE" then AskRoster() end
    ReadSoon()
end)

-- Called from ns.OnLogin (after the saved variables are set up).
function ns.GuildLogin()
    EzAcquaintancesCharDB.guilds = EzAcquaintancesCharDB.guilds or {}
    myKey = ns.Key(UnitName("player"))
    guildName = GuildName()
    for _, e in ipairs({ "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "CHAT_MSG_SYSTEM" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    C_Timer.After(5, AskRoster) -- a first read, so join dates start from today even if the tab stays shut
end

function ns.ShowGuild()
    api.ShowTab("guild")
end
