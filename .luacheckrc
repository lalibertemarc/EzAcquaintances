std = "lua51"
max_line_length = false
self = false

globals = {
    "EzAcquaintancesDB",
    "EzAcquaintancesCharDB",
    "EzAcquaintances_Toggle",
    "EzAcquaintancesAPI",
    "SLASH_EZACQUAINTANCES1",
    "SLASH_EZACQUAINTANCES2",
    "SlashCmdList",
    "BINDING_HEADER_EZACQUAINTANCES",
    "BINDING_NAME_EZACQUAINTANCES_TOGGLE",
}

read_globals = {
    -- Lua / WoW utility
    "strtrim", "strlower", "wipe", "tinsert", "date", "time", "hooksecurefunc",
    -- Frames & UI
    "CreateFrame", "InCombatLockdown", "UIParent", "UISpecialFrames", "GameTooltip", "DEFAULT_CHAT_FRAME", "ChatFrame1", "TargetFrame",
    "RAID_CLASS_COLORS", "TooltipDataProcessor", "Enum",
    -- Namespaced APIs
    "C_Timer", "C_CVar", "issecretvalue",
    -- Global APIs
    "GetBuildInfo", "GetTime", "GetRealmName", "GetRealZoneText", "GetZoneText", "GetSubZoneText",
    "UnitExists", "UnitIsPlayer", "UnitName", "UnitRace", "UnitClass", "UnitLevel", "GetPlayerInfoByGUID",
    "IsInGroup", "IsInRaid", "GetNumGroupMembers", "GetNumSubgroupMembers", "StartDuel",
    "UnitGUID", "CombatLogGetCurrentEventInfo", "_G",
    "UnitInParty", "UnitInRaid", "UnitIsUnit", "UnitIsConnected", "UnitIsVisible", "GetRaidRosterInfo", "C_Map",
}
