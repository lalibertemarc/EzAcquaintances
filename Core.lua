-- EzAcquaintances: logs who you met into Recent faces; you write who they are in the Book.
-- Never sends chat; the only secure action is the book's right-click /targetexact (UI.lua).
local _, ns = ...

BINDING_HEADER_EZACQUAINTANCES = "EzAcquaintances"
BINDING_NAME_EZACQUAINTANCES_TOGGLE = "Open the acquaintance book"

local DAY = 86400

local issecret = issecretvalue or function() return false end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd14dEzAcquaintances|r: " .. msg)
end
ns.Print = Print

-- v, or nil when it's missing, secret (Forever hides names in dungeons and raids) or empty.
local function Readable(v)
    if v == nil or issecret(v) or v == "" then return nil end
    return v
end
ns.Readable = Readable

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------
-- Forever puts a surname where Era puts the realm. First names aren't unique in Forever (two Grims with
-- different surnames, 2026-11-09), so people are keyed by their whole lowercase name there: "grim sharpeye".
-- Era keys by first name (its names are only unique per realm, and chat gives the realm, not a surname).
function ns.Key(name)
    return strlower(ns.CleanName(name) or name)
end

-- The first-name part of a key.
local function FirstOf(key)
    return key:match("^[^%s%-]+") or key
end
ns.FirstOf = FirstOf

-- Key of the record for name: its own; for a first name alone, the one person with that first name (nil
-- second return when two share it); for a full name, a record kept from before its surname was known.
-- Otherwise the key a new record would get.
function ns.KeyFor(name)
    local key = ns.Key(name)
    local people = EzAcquaintancesCharDB.people
    if people[key] or ns.ERA then return key end
    local first = FirstOf(key)
    if first ~= key then
        return people[first] and not (people[first].name or ""):find(" ") and first or key
    end
    local found
    for k in pairs(people) do
        if FirstOf(k) == first then
            if found then return key, true end -- ambiguous
            found = k
        end
    end
    return found or key
end

-- Same person: equal keys, or one is a first name alone and the other's first name.
function ns.SameName(a, b)
    a, b = ns.Key(a), ns.Key(b)
    if a == b then return true end
    local fa, fb = FirstOf(a), FirstOf(b)
    return fa == fb and (fa == a or fb == b)
end

-- Display name from a unit, chat or a slash command: "First Surname" in Forever (chat links put a "-"
-- between them), just "First" in Era (chat says "First-Realm").
function ns.CleanName(name)
    name = Readable(name)
    if type(name) ~= "string" then return end
    name = strtrim(name)
    if ns.ERA then
        name = name:match("^[^%s%-]+") or name
    else
        name = name:gsub("%-", " "):gsub("%s+", " ")
    end
    if name == "" then return end
    return name:sub(1, 1):upper() .. name:sub(2)
end

local function UnitFullName(unit)
    local name, extra = UnitName(unit)
    name, extra = Readable(name), Readable(extra)
    if name and extra and not ns.ERA then return name .. " " .. extra end
    return name
end

-- Name, race, class and level of a player unit, or nil (no unit, not a player, or secret).
function ns.UnitInfo(unit)
    local exists = UnitExists(unit)
    if issecret(exists) or not exists then return end
    local isPlayer = UnitIsPlayer(unit)
    if issecret(isPlayer) or not isPlayer then return end
    local name = UnitFullName(unit)
    if not name then return end
    local className, classFile = UnitClass(unit)
    local level = UnitLevel(unit)
    return {
        name = name,
        race = Readable(UnitRace(unit)),
        className = Readable(className),
        class = Readable(classFile),
        level = not issecret(level) and type(level) == "number" and level > 0 and level or nil,
    }
end

-- Fills race/class/level from a chat event's sender GUID where the game tells us.
local function GuidInfo(guid, info)
    guid = Readable(guid)
    if not (guid and GetPlayerInfoByGUID and guid:find("^Player%-")) then return info end
    local className, classFile, race, _, _, _, _, level = GetPlayerInfoByGUID(guid)
    info.className, info.class, info.race = Readable(className), Readable(classFile), Readable(race)
    if not issecret(level) and type(level) == "number" and level > 0 then info.level = level end
    return info
end

local myKey, myFirst, myChar, myGUID -- your key, first name, the account index's name for you, your GUID

-- A key that is you: your whole name, or your first name alone (chat or a typed name without the surname).
function ns.IsMe(key)
    return key == myKey or (myFirst ~= nil and key == strlower(myFirst))
end

---------------------------------------------------------------------------
-- Records
---------------------------------------------------------------------------
-- Zone and subzone you stand in; subzone nil when there is none.
local function Where()
    local zone = Readable(GetRealZoneText()) or Readable(GetZoneText())
    local sub = Readable(GetSubZoneText())
    if sub == zone then sub = nil end
    return zone, sub
end

function ns.Person(key)
    return EzAcquaintancesCharDB.people[key]
end

-- Keeps the account index in step with this character's record of key.
local function Index(key, p)
    local seen = EzAcquaintancesDB.seen
    seen[key] = seen[key] or {}
    if not p then
        seen[key][myChar] = nil
        if next(seen[key]) == nil then seen[key] = nil end
        return
    end
    seen[key][myChar] = {
        name = p.name, t = p.last, met = p.first.t, zone = p.first.zone, sub = p.first.sub, book = p.book,
    }
end

-- Moves a record (and its index entry) to another key: a first-name-only record learning its surname,
-- or an old first-name key. Keeps the one already at the new key when there is one.
local function Rekey(old, new)
    local people = EzAcquaintancesCharDB.people
    if old == new or not people[old] then return new end
    if not people[new] then people[new] = people[old] end
    people[old] = nil
    Index(old, nil)
    Index(new, people[new])
    return new
end

local function ApplyInfo(p, info)
    -- Only a longer form of the same name (its surname): never another person's.
    if info.name and (not p.name or (#info.name > #p.name and ns.SameName(info.name, p.name))) then
        p.name = info.name
    end
    p.race = info.race or p.race
    p.className = info.className or p.className
    p.class = info.class or p.class
    p.level = info.level or p.level
end

local function Changed(key)
    if ns.OnChanged then ns.OnChanged(key) end
    if ns.UpdateBadge then ns.UpdateBadge() end
end
ns.Changed = Changed

function ns.TriggerOn(via)
    local o = EzAcquaintancesDB.triggers[via]
    if o == nil then return ns.TRIGGERS[via].on end
    return o
end

local function Announce(names, via)
    if not EzAcquaintancesDB.announce or #names == 0 then return end
    Print(("New face%s: |cffffffff%s|r (%s). |cffaaaaaa/acq|r to add them to your book."):format(
        #names > 1 and "s" or "", table.concat(names, ", "), ns.TRIGGER_VERB[via]))
end

-- A meaningful contact with someone. Returns their record, key and whether they're new; nil when the name
-- can't be read, it's you, or that trigger is off. quiet: the caller announces new faces itself.
-- info.place: where a new face is first met, instead of where you stand (the Guild tab: "<Guild>").
function ns.Meet(info, via, quiet)
    local name = info and ns.CleanName(info.name)
    if not name then return end
    local key = ns.Key(name)
    if ns.IsMe(key) or key == "" or not ns.TriggerOn(via) then return end
    info.name = name
    if FirstOf(key) == key then key = ns.KeyFor(name) else key = Rekey(ns.KeyFor(name), key) end
    local people, now = EzAcquaintancesCharDB.people, time()
    local p, isNew = people[key], false
    if not p then
        local zone, sub = Where()
        if info.place then zone, sub = info.place, nil end
        p = { first = { t = now, zone = zone, sub = sub }, via = via, met = 1, tags = {} }
        people[key], isNew = p, true
    elseif now - (p.last or 0) >= ns.MEET_GAP then
        p.met = (p.met or 1) + 1
    elseif now - (p.last or 0) < ns.SEEN_THROTTLE then
        ApplyInfo(p, info)
        return p, key, false
    end
    ApplyInfo(p, info)
    p.last, p.lastVia = now, via
    p.lastZone, p.lastSub = Where()
    Index(key, p)
    if isNew and not quiet and via ~= "manual" then Announce({ p.name }, via) end
    Changed(key)
    return p, key, isNew
end

-- Someone you already know crossed your path (target, mouseover): last seen and what we can read.
function ns.Seen(info)
    local name = info and ns.CleanName(info.name)
    local key = name and ns.KeyFor(name)
    local p = key and EzAcquaintancesCharDB.people[key]
    if not p then return end
    info.name = name
    ApplyInfo(p, info)
    local now = time()
    if now - (p.last or 0) < ns.SEEN_THROTTLE then return end
    p.last = now
    p.lastZone, p.lastSub = Where()
    Index(key, p)
    Changed(key)
end

function ns.Promote(key)
    local p = ns.Person(key)
    if not p or p.book then return end
    p.book, p.added = true, time()
    Index(key, p)
    Changed(key)
end

-- Back to Recent faces; counts as seen now, so it doesn't expire straight away.
function ns.Demote(key)
    local p = ns.Person(key)
    if not p or not p.book then return end
    p.book, p.last = nil, time()
    Index(key, p)
    Changed(key)
end

function ns.Forget(key)
    EzAcquaintancesCharDB.people[key] = nil
    Index(key, nil)
    Changed(key)
end

-- Key and record for a name or "known as" alias you typed; nil, nil, true when a first name alone fits
-- more than one person.
function ns.Find(name)
    name = strtrim(name or "")
    if name == "" then return end
    local key, ambiguous = ns.KeyFor(name)
    local people = EzAcquaintancesCharDB.people
    if people[key] then return key, people[key] end
    local lower = strlower(name)
    for k, p in pairs(people) do
        if p.alias and strlower(p.alias) == lower then return k, p end
    end
    return nil, nil, ambiguous
end

---------------------------------------------------------------------------
-- Tags
---------------------------------------------------------------------------
function ns.AllTags()
    local list, have = {}, {}
    for _, src in ipairs({ ns.TAGS, EzAcquaintancesDB.customTags }) do
        for _, tag in ipairs(src) do
            if not have[strlower(tag)] then
                have[strlower(tag)] = true
                list[#list + 1] = tag
            end
        end
    end
    return list
end

-- The tag as the list spells it ("I owe them" for "i owe them"); a new one becomes a custom tag.
function ns.Tag(text)
    text = strtrim(text or ""):gsub("%s+", " ")
    if text == "" then return end
    local lower = strlower(text)
    for _, tag in ipairs(ns.AllTags()) do
        if strlower(tag) == lower then return tag end
    end
    table.insert(EzAcquaintancesDB.customTags, text)
    return text
end

-- Toggles tag on key; returns true when it's now on.
function ns.ToggleTag(key, tag)
    local p = ns.Person(key)
    if not p then return end
    p.tags = p.tags or {}
    p.tags[tag] = not p.tags[tag] or nil
    Changed(key)
    return p.tags[tag]
end

function ns.TagList(p)
    local list = {}
    for tag in pairs(p.tags or {}) do list[#list + 1] = tag end
    table.sort(list, function(a, b) return strlower(a) < strlower(b) end)
    return list
end

---------------------------------------------------------------------------
-- Formatting (shared by /acq who, the detail pane and the tooltip)
---------------------------------------------------------------------------
function ns.Date(t)
    return t and date("%Y-%m-%d", t) or "?"
end

function ns.Ago(t)
    if not t then return "never" end
    local s = time() - t
    if s < 120 then return "just now" end
    if s < 3600 then return ("%d min ago"):format(s / 60) end
    if s < DAY then return ("%d h ago"):format(s / 3600) end
    if s < 2 * DAY then return "yesterday" end
    return ("%d days ago"):format(s / DAY)
end

function ns.Place(zone, sub)
    if zone and sub then return sub .. ", " .. zone end
    return zone or sub or "somewhere"
end

-- "Human Paladin 20", class-colored, or nil when nothing is known.
function ns.ClassText(p)
    local parts = {}
    if p.race then parts[#parts + 1] = p.race end
    if p.className then
        local c = p.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.class]
        parts[#parts + 1] = c and ("|c%s%s|r"):format(c.colorStr or "ffffffff", p.className) or p.className
    end
    if p.level then parts[#parts + 1] = tostring(p.level) end
    if #parts > 0 then return table.concat(parts, " ") end
end

-- Display name with its alias: 'Sephrina Gam "the Red"'.
function ns.Title(p)
    if p.alias and p.alias ~= "" then return ('%s "%s"'):format(p.name, p.alias) end
    return p.name
end

-- Your other characters who met key: { { char = "Bob", rec = {...} }, ... }, newest first.
function ns.OtherChars(key)
    local list = {}
    for char, rec in pairs(EzAcquaintancesDB.seen[key] or {}) do
        if char ~= myChar then list[#list + 1] = { char = char:match("^[^%-]+"), rec = rec } end
    end
    table.sort(list, function(a, b) return (a.rec.t or 0) > (b.rec.t or 0) end)
    return list
end

function ns.OtherCharLine(o)
    return ("%s met them %s in %s%s"):format(o.char, ns.Date(o.rec.met), ns.Place(o.rec.zone, o.rec.sub),
        o.rec.book and " (in their book)" or "")
end

function ns.FirstMetLine(p)
    return ("%s in %s (%s)"):format(ns.Date(p.first.t), ns.Place(p.first.zone, p.first.sub),
        ns.TRIGGER_VERB[p.via] or p.via or "?")
end

function ns.LastSeenLine(p)
    return ("%s in %s"):format(ns.Ago(p.last), ns.Place(p.lastZone, p.lastSub))
end

---------------------------------------------------------------------------
-- Triggers
---------------------------------------------------------------------------
local clock = GetTime
local whisperIn, whisperOut = {}, {} -- key -> GetTime() of the last whisper each way
local targeted, saidBy = {}, {}     -- key -> { t, info } when you targeted them; key -> GetTime() of their /say
local mySay = -math.huge

-- Drops entries older than window from a key -> time (or { t }) table.
local function Expire(tbl, window)
    local t0 = clock() - window
    for k, v in pairs(tbl) do
        if (type(v) == "table" and v.t or v) < t0 then tbl[k] = nil end
    end
end

local function OnWhisper(mine, theirs, name, guid)
    name = ns.CleanName(name)
    if not name then return end
    local key, window = ns.Key(name), ns.TRIGGERS.whisper.window
    Expire(theirs, window)
    mine[key] = clock()
    if theirs[key] then ns.Meet(GuidInfo(guid, { name = name }), "whisper") end
end

-- What you knew about key when you targeted them within the window (or now, if they're still your target).
local function Targeted(key, window)
    local tg = targeted[key]
    if tg and clock() - tg.t <= window then return tg.info end
    for k, other in pairs(targeted) do -- chat may give a first name alone
        if clock() - other.t <= window and ns.SameName(k, key) then return other.info end
    end
    local info = ns.UnitInfo("target")
    if info and ns.SameName(info.name, key) then return info end
end

local function Copy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

local function OnSay(name, guid)
    name = ns.CleanName(name)
    if not name then return end
    local key, window = ns.Key(name), ns.TRIGGERS.say.window
    if ns.IsMe(key) then
        mySay = clock()
        Expire(saidBy, window)
        for k in pairs(saidBy) do
            local info = Targeted(k, window)
            if info then ns.Meet(Copy(info), "say") end
        end
    else
        saidBy[key] = clock()
        local info = clock() - mySay <= window and Targeted(key, window)
        if info then ns.Meet(GuidInfo(guid, Copy(info)), "say") end
    end
end

-- Whole-word match of you in an emote: "you" (game emotes) or your first name (custom /e lines too).
local function NamesMe(text, custom)
    text = Readable(text)
    if type(text) ~= "string" then return false end
    local lower = strlower(text)
    if not custom and lower:find("%f[%a]you%f[%A]") then return true end
    return lower:find("%f[%a]" .. strlower(myFirst):gsub("%p", "%%%0") .. "%f[%A]") ~= nil
end

local function OnEmote(text, name, guid, custom)
    if custom and not ns.TRIGGERS.emote.custom then return end
    if NamesMe(text, custom) then ns.Meet(GuidInfo(guid, { name = name }), "emote") end
end

-- A buff landing on you: UNIT_AURA's added auras name the caster's unit when the game has one for them
-- (your target, group, mouseover), as when you target someone and ask with Buff Me Please or EzMinion. In Forever the
-- aura data can be secret (combat), so every field is read through Readable.
local function OnAura(unit, info)
    if unit ~= "player" or not ns.TriggerOn("buff") or type(info) ~= "table" or issecret(info) then return end
    local added = info.addedAuras
    if type(added) ~= "table" or issecret(added) then return end
    for _, a in ipairs(added) do
        local src = not issecret(a) and Readable(a.isHelpful) and Readable(a.sourceUnit)
        if src and src ~= "player" then ns.Meet(ns.UnitInfo(src), "buff") end
    end
end

-- Era only (the combat log is restricted in Forever): anyone in range who buffs you, targeted or not.
local function OnCombatLog()
    local _, sub, _, srcGUID, srcName, _, _, dstGUID, _, _, _, _, _, _, auraType = CombatLogGetCurrentEventInfo()
    if sub ~= "SPELL_AURA_APPLIED" or auraType ~= "BUFF" or dstGUID ~= myGUID or srcGUID == myGUID then return end
    if type(srcGUID) == "string" and srcGUID:find("^Player%-") then
        ns.Meet(GuidInfo(srcGUID, { name = srcName }), "buff")
    end
end

local groupPending = false
local function ScanGroup()
    groupPending = false
    if not IsInGroup() then return end
    local raid = IsInRaid()
    if raid and not ns.TRIGGERS.group.raid then return end
    local prefix, n = raid and "raid" or "party", raid and GetNumGroupMembers() or GetNumSubgroupMembers()
    local new = {}
    for i = 1, n do
        local p, _, isNew = ns.Meet(ns.UnitInfo(prefix .. i), "group", true)
        if isNew then new[#new + 1] = p.name end
    end
    Announce(new, "group")
end

local function OnTarget()
    local info = ns.UnitInfo("target")
    if info then
        Expire(targeted, ns.TRIGGERS.say.window)
        targeted[ns.Key(ns.CleanName(info.name) or info.name)] = { t = clock(), info = info }
        ns.Seen(Copy(info))
    end
    if ns.UpdateBadge then ns.UpdateBadge() end
end

---------------------------------------------------------------------------
-- Saved variables and pruning
---------------------------------------------------------------------------
local ACCOUNT_DEFAULTS = { tooltip = true, badge = true, hideIcon = false, hideMinimap = false, announce = true,
    tab = "book", whisperWith = "chat" }

local function InitDB()
    EzAcquaintancesDB = EzAcquaintancesDB or {}
    local db = EzAcquaintancesDB
    for k, v in pairs(ACCOUNT_DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    db.seen = db.seen or {}
    db.triggers = db.triggers or {}
    db.customTags = db.customTags or {}
    EzAcquaintancesCharDB = EzAcquaintancesCharDB or {}
    EzAcquaintancesCharDB.people = EzAcquaintancesCharDB.people or {}
end

-- Forgets Recent faces past INBOX_DAYS (and the oldest past INBOX_MAX), stale index sightings of your other
-- characters, and caps the index. Book entries are only removed by hand.
-- Records and index sightings kept under a key their name no longer gives (first-name keys from before
-- 2026-11-09) move to their own. Cheap and idempotent, so it runs at every login rather than once.
local function Migrate()
    local people, seen = EzAcquaintancesCharDB.people, EzAcquaintancesDB.seen
    local move = {}
    for key, p in pairs(people) do
        local new = type(p.name) == "string" and ns.Key(p.name)
        if new and new ~= "" and new ~= key then move[key] = new end
    end
    for old, new in pairs(move) do Rekey(old, new) end
    local sightings = {} -- collected first: new keys can't be added to seen while walking it
    for key, chars in pairs(seen) do
        for char, r in pairs(chars) do
            local new = type(r.name) == "string" and ns.Key(r.name)
            if new and new ~= "" and new ~= key then sightings[#sightings + 1] = { key, char, new } end
        end
    end
    for _, s in ipairs(sightings) do
        local key, char, new = s[1], s[2], s[3]
        local r = seen[key][char]
        seen[key][char] = nil
        if next(seen[key]) == nil then seen[key] = nil end
        seen[new] = seen[new] or {}
        if not seen[new][char] then seen[new][char] = r end
    end
end

local function Prune()
    Migrate()
    local t, people, seen = time(), EzAcquaintancesCharDB.people, EzAcquaintancesDB.seen
    local inbox = {}
    for key, p in pairs(people) do
        if not p.book and t - (p.last or 0) > ns.INBOX_DAYS * DAY then
            people[key] = nil
        elseif not p.book then
            inbox[#inbox + 1] = key
        end
    end
    if #inbox > ns.INBOX_MAX then
        table.sort(inbox, function(a, b) return (people[a].last or 0) < (people[b].last or 0) end)
        for i = 1, #inbox - ns.INBOX_MAX do people[inbox[i]] = nil end
    end

    local keys = {}
    for key, chars in pairs(seen) do
        chars[myChar] = nil -- rebuilt below from this character's records
        local newest, book = 0, false
        for char, r in pairs(chars) do
            if not r.book and t - (r.t or 0) > ns.INDEX_DAYS * DAY then
                chars[char] = nil
            else
                newest, book = math.max(newest, r.t or 0), book or r.book
            end
        end
        if next(chars) == nil then
            seen[key] = nil
        elseif not book then
            keys[#keys + 1] = { key = key, t = newest }
        end
    end
    for key, p in pairs(people) do Index(key, p) end

    local total = 0
    for _ in pairs(seen) do total = total + 1 end
    if total > ns.INDEX_MAX then
        table.sort(keys, function(a, b) return a.t < b.t end)
        for i = 1, math.min(#keys, total - ns.INDEX_MAX) do
            if not people[keys[i].key] then seen[keys[i].key] = nil end
        end
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
-- '"First Surname" rest' or 'First rest' -> name, rest.
local function SplitName(s)
    local quoted, rest = s:match('^"([^"]+)"%s*(.*)$')
    if quoted then return quoted, rest end
    return s:match("^(%S+)%s*(.*)$")
end

-- Your target when it's them (for race/class/level), else just the name.
local function InfoFor(name)
    local t = ns.UnitInfo("target")
    if not name then return t end
    if t and ns.SameName(t.name, name) then return t end
    return { name = name }
end

-- "Can't add that name.", or how to tell two people with one first name apart.
local function CantAdd(name, ambiguous)
    if ambiguous then
        return Print(('More than one person is called %s: write the full name in quotes, "%s Surname".')
            :format(name, name))
    end
    Print("Can't add that name.")
end

-- Record for a typed name, made (and put in the Book) when it's someone new.
local function Ensure(name)
    local key, p, ambiguous = ns.Find(name)
    if p then return key, p end
    local info = InfoFor(name)
    if not info or (ambiguous and info.name == name) then return nil, nil, ambiguous end -- your target settles it
    p, key = ns.Meet(info, "manual")
    if p then ns.Promote(key) end
    return key, p
end

local function PrintWho(name)
    local key, p, ambiguous = ns.Find(name)
    if ambiguous then return CantAdd(name, true) end
    key = key or ns.Key(name)
    if p then
        local rel = p.rel and p.rel ~= "" and (" - " .. p.rel) or ""
        local tags = ns.TagList(p)
        Print(("|cffffffff%s|r%s%s%s"):format(ns.Title(p), rel, #tags > 0 and (" [" .. table.concat(tags, ", ") .. "]") or "",
            p.book and "" or " |cffaaaaaa(recent face)|r"))
        local class = ns.ClassText(p)
        if class then Print("  " .. class) end
        Print(("  First met %s. Last seen %s. Met %d time%s."):format(ns.FirstMetLine(p), ns.LastSeenLine(p),
            p.met or 1, (p.met or 1) == 1 and "" or "s"))
        if p.note and p.note ~= "" then Print("  Note: " .. p.note) end
    end
    local others = ns.OtherChars(key)
    for _, o in ipairs(others) do Print("  Your " .. ns.OtherCharLine(o) .. ".") end
    if not p and #others == 0 then Print(("You don't know anyone called %s."):format(name)) end
end

local HELP = {
    "/acq - open or close the book",
    "/acq add [name] [note] - add someone (or your target) to the book",
    "/acq note <name> <text> - set their note (empty clears it)",
    "/acq tag <name> <tag> - toggle a tag (new words become your own tags)",
    "/acq forget <name> - remove them completely",
    "/acq who <name> - what you know about them",
    "/acq guild - your guild's roster, with join dates and what your book knows",
    "/acq icon | minimap | badge | tooltip | quiet - toggle the launcher icon, minimap button, target badge,"
        .. " tooltip line, new-face messages",
    "/acq reset - reset window, icon, minimap button and badge positions",
    'Names with a surname go in quotes: /acq note "Sephrina Gam" owes me 5g',
}

local function Toggle(field, on, off)
    EzAcquaintancesDB[field] = not EzAcquaintancesDB[field]
    Print(EzAcquaintancesDB[field] and on or off)
    Changed()
    if ns.UpdateIcon then ns.UpdateIcon() end
end

local COMMANDS = {
    add = function(rest)
        local name, note = SplitName(rest)
        local info = InfoFor(name)
        if not info then return Print("Usage: /acq add <name> [note], or target someone first.") end
        local ambiguous = select(3, ns.Find(info.name))
        if ambiguous then return CantAdd(info.name, true) end
        local p, key = ns.Meet(info, "manual")
        if not p then return CantAdd(info.name) end
        ns.Promote(key)
        if note and note ~= "" then p.note = note:sub(1, ns.NOTE_MAX) end
        Changed(key)
        Print(("Added |cffffffff%s|r to your book."):format(p.name))
    end,
    note = function(rest)
        local name, text = SplitName(rest)
        if not name then return Print("Usage: /acq note <name> <text>") end
        local key, p, ambiguous = Ensure(name)
        if not p then return CantAdd(name, ambiguous) end
        ns.Promote(key)
        p.note = text ~= "" and text:sub(1, ns.NOTE_MAX) or nil
        Changed(key)
        Print(p.note and ("Note saved for |cffffffff%s|r."):format(p.name) or ("Note cleared for %s."):format(p.name))
    end,
    tag = function(rest)
        local name, text = SplitName(rest)
        local tag = ns.Tag(text)
        if not (name and tag) then return Print("Usage: /acq tag <name> <tag>") end
        local key, p, ambiguous = Ensure(name)
        if not p then return CantAdd(name, ambiguous) end
        ns.Promote(key)
        local on = ns.ToggleTag(key, tag)
        Print(("%s |cffffffff%s|r %s %s."):format(on and "Tagged" or "Untagged", p.name, on and "as" or "from", tag))
    end,
    forget = function(rest)
        local name = SplitName(rest)
        local key, p, ambiguous = ns.Find(name)
        if ambiguous then return CantAdd(name, true) end
        if not p then return Print(("You don't know anyone called %s."):format(rest)) end
        ns.Forget(key)
        Print(("Forgot %s."):format(p.name))
    end,
    who = function(rest)
        local name = SplitName(rest) or (ns.UnitInfo("target") or {}).name
        if not name then return Print("Usage: /acq who <name>") end
        PrintWho(name)
    end,
    guild = function()
        if ns.ShowGuild then ns.ShowGuild() end
    end,
    icon = function()
        EzAcquaintancesDB.hideIcon = not EzAcquaintancesDB.hideIcon
        Print(EzAcquaintancesDB.hideIcon and "Icon hidden. Use the key binding or /acq." or "Icon shown.")
        if ns.UpdateIcon then ns.UpdateIcon() end
    end,
    minimap = function()
        EzAcquaintancesDB.hideMinimap = not EzAcquaintancesDB.hideMinimap
        Print(EzAcquaintancesDB.hideMinimap and "Minimap button hidden." or "Minimap button shown.")
        if ns.UpdateIcon then ns.UpdateIcon() end
    end,
    badge = function() Toggle("badge", "Target badge on.", "Target badge off.") end,
    tooltip = function() Toggle("tooltip", "Tooltip line on.", "Tooltip line off.") end,
    quiet = function() Toggle("announce", "New faces are announced in chat.", "New faces are logged quietly.") end,
    reset = function()
        EzAcquaintancesDB.framePos, EzAcquaintancesDB.iconPos, EzAcquaintancesDB.badgePos = nil, nil, nil
        EzAcquaintancesDB.minimapAngle = nil
        if ns.ApplyPositions then ns.ApplyPositions() end
        Print("Positions reset.")
    end,
    help = function()
        for _, line in ipairs(HELP) do Print(line) end
    end,
}

SLASH_EZACQUAINTANCES1 = "/acq"
SLASH_EZACQUAINTANCES2 = "/ezacq"
SlashCmdList.EZACQUAINTANCES = function(msg)
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.*)$")
    cmd = strlower(cmd)
    if cmd == "" then return ns.ToggleBook() end
    local fn = COMMANDS[cmd]
    if fn then return fn(rest) end
    COMMANDS.help()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local HANDLERS = {
    GROUP_ROSTER_UPDATE = function()
        if groupPending or not ns.TriggerOn("group") then return end
        groupPending = true
        C_Timer.After(2, ScanGroup) -- the roster fires in bursts
    end,
    CHAT_MSG_WHISPER = function(_, name, ...)
        OnWhisper(whisperIn, whisperOut, name, select(10, ...))
    end,
    CHAT_MSG_WHISPER_INFORM = function(_, name, ...)
        OnWhisper(whisperOut, whisperIn, name, select(10, ...))
    end,
    CHAT_MSG_SAY = function(_, name, ...)
        OnSay(name, select(10, ...))
    end,
    CHAT_MSG_TEXT_EMOTE = function(text, name, ...)
        OnEmote(text, name, select(10, ...), false)
    end,
    CHAT_MSG_EMOTE = function(text, name, ...)
        OnEmote(text, name, select(10, ...), true)
    end,
    TRADE_SHOW = function()
        ns.Meet(ns.UnitInfo("NPC"), "trade") -- the trade window's unit for the other player
    end,
    DUEL_REQUESTED = function(name)
        ns.Meet({ name = name }, "duel")
    end,
    DUEL_TO_THE_DEATH_REQUESTED = function(name) -- Forever only
        ns.Meet({ name = name }, "duel")
    end,
    UNIT_AURA = OnAura,
    PLAYER_TARGET_CHANGED = OnTarget,
    UPDATE_MOUSEOVER_UNIT = function()
        ns.Seen(ns.UnitInfo("mouseover"))
    end,
}
if ns.ERA then HANDLERS.COMBAT_LOG_EVENT_UNFILTERED = OnCombatLog end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, ...)
    if event ~= "PLAYER_LOGIN" then return HANDLERS[event](...) end
    InitDB()
    myFirst = UnitName("player")
    myKey = ns.Key(UnitFullName("player") or myFirst)
    myChar = ns.ERA and (myFirst .. "-" .. GetRealmName()) or myFirst
    myGUID = UnitGUID("player")
    Prune()
    for name in pairs(HANDLERS) do
        pcall(ev.RegisterEvent, ev, name) -- an event this client doesn't have is skipped
    end
    if StartDuel then
        -- You challenging someone (target menu, /duel): post-hook only, the duel itself runs untouched.
        hooksecurefunc("StartDuel", function(unit)
            if type(unit) == "string" then ns.Meet(ns.UnitInfo(unit), "duel") end
        end)
    end
    -- Buff Me Please's and EzMinion's thanks buttons (click or key binding): thanking your target counts as
    -- being buffed, even when the game didn't say who cast the buff. Plain buttons, so a post-hook taints
    -- nothing. No OnClick means that addon stood down on this character (Buff Me Please on a warlock with
    -- EzMinion, EzMinion on anyone but a warlock).
    for _, name in ipairs({ "BuffMePleaseThanksButton", "EzMinionThanksButton" }) do
        local thanks = _G[name] -- nil when that addon isn't loaded
        if thanks and thanks:GetScript("OnClick") then
            thanks:HookScript("OnClick", function() ns.Meet(ns.UnitInfo("target"), "buff") end)
        end
    end
    if ns.OnLogin then ns.OnLogin() end
end)
