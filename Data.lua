-- EzAcquaintances static data: what counts as meeting someone, tags, relationships, limits.
local _, ns = ...

ns.ERA = select(4, GetBuildInfo()) < 16000 -- Classic Era; Forever is 16001

ns.ICON = "Interface\\Icons\\INV_Misc_Book_09"
ns.BADGE_ICON = "Interface\\Icons\\INV_Letter_15"

-- What logs a person into Recent faces. Each one can be switched off on the options page
-- (EzAcquaintancesDB.triggers[key] overrides on). window: seconds both halves must fall within.
ns.TRIGGERS = {
    group   = { label = "Grouped with you", on = true, raid = true },  -- raid: raids count too, not only parties
    whisper = { label = "Whispered both ways", on = true, window = 600 },
    trade   = { label = "Traded with you", on = true },
    duel    = { label = "Dueled you", on = true },
    buff    = { label = "Buffed you (or you thanked them with Buff Me Please or EzMinion)", on = true },
    emote   = { label = "Emoted at you", on = true, custom = true }, -- custom: an /e line naming you counts too
    say     = { label = "Talked in /say while targeted", on = true, window = 60 },
    manual  = { label = "Added by hand", on = true },
}
ns.TRIGGER_ORDER = { "group", "whisper", "trade", "duel", "buff", "emote", "say" } -- options page; manual is always on

-- Short verbs for "first met ... (whispered)".
ns.TRIGGER_VERB = {
    group = "grouped", whisper = "whispered", trade = "traded", duel = "dueled", buff = "buffed you",
    emote = "emoted at you", say = "talked", manual = "added by hand",
}

ns.MEET_GAP = 30 * 60      -- seconds apart before seeing someone again counts as another meeting
ns.SEEN_THROTTLE = 60      -- seconds between "last seen" updates for the same person
ns.INBOX_DAYS = 14         -- Recent faces you never add to the Book are forgotten after this long
ns.INBOX_MAX = 300         -- most Recent faces kept; the oldest go first
ns.INDEX_DAYS = 180        -- account index forgets other characters' unsaved sightings after this long
ns.INDEX_MAX = 3000        -- most people in the account index
ns.NOTE_MAX = 1000         -- letters in a note
ns.ALIAS_MAX = 48

-- Preset tags; your own ones are added to EzAcquaintancesDB.customTags.
ns.TAGS = {
    "ally", "friend", "rival", "enemy", "suspicious", "owes me gold", "I owe them",
    "trustworthy", "liar", "guild", "merchant", "healer", "mentor", "family", "flirt", "mysterious",
}

ns.RELATIONSHIPS = {
    "", "stranger", "acquaintance", "friend", "close friend", "ally", "rival", "enemy",
    "family", "sweetheart", "employer", "employee", "mentor", "student",
}

ns.COLORS = {
    accent = { 1, 0.82, 0.3 },
    title = "ffffd14d",
}
