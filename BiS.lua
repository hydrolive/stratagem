-- BiS.lua: reads Naowh Forever when it is loaded, and falls back to the bundled snapshot.
-- Quest rows follow the Dungeon Journal layout:
--   { id, name, level, side, shareable, where, map, x, y, class = , races = }
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.BiS = {
    quests = {},
    byId = {},
    items = {},
    source = "snapshot",
    itemSource = "snapshot",
}

-- Same race bits the BiS list uses (ChrRaces.PlayableRaceBit).
local RACE_BITS = {
    [1] = 0, [2] = 1, [3] = 2, [4] = 3, [5] = 4, [6] = 5, [7] = 6, [8] = 7,
    [95] = 32, [96] = 33,
}

local ADDON_NAMES = {
    "NaowhForever",
    "NaowhForever_BiS",
    "NaowhForever_DungeonJournal",
    "NaowwahForever_BiS",
    "NaowwahForever",
}

local function AddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name) and true or false
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(name) and true or false
    end
    return false
end

local function Namespace()
    if type(_G.NaowhForever) == "table" then return _G.NaowhForever end
    if type(_G.NaowwahForever) == "table" then return _G.NaowwahForever end
    return nil
end

local function CopyRewards(src)
    local out = {}
    if type(src) ~= "table" then return out end
    for i = 1, #src do
        out[i] = src[i]
    end
    return out
end

local function ZoneFromWhere(where)
    if type(where) ~= "string" then return nil end
    if where:find("not known yet", 1, true) then return nil end
    return where:match("^(.-) %-")
end

local function CoordsFromWhere(where)
    if type(where) ~= "string" then return nil end
    local x, y = where:match("%(([%d%.]+)%s*,%s*([%d%.]+)%)")
    if not x then return nil end
    return tonumber(x), tonumber(y)
end

local function Normalize(quest)
    if not quest.zone then quest.zone = ZoneFromWhere(quest.where) end
    if not quest.x then
        local x, y = CoordsFromWhere(quest.where)
        if x then quest.x, quest.y = x, y end
    end
    if not quest.rewards then quest.rewards = {} end
    return quest
end

local function ReadJournal(ns)
    local journal = ns and ns.Journal
    local data = journal and journal.BiSQuestData
    if type(data) ~= "table" or type(data.quests) ~= "table" or #data.quests == 0 then
        return nil
    end
    local rewards = journal.BiSQuestRewards or {}
    local choices = journal.BiSQuestChoices or {}
    local zones = journal.BiSQuestZones or {}
    local list = {}
    for i = 1, #data.quests do
        local row = data.quests[i]
        if type(row) == "table" and row[1] then
            local id = row[1]
            list[#list + 1] = Normalize({
                id = id,
                name = row[2] or ("Quest " .. tostring(id)),
                level = row[3] or 1,
                side = row[4] or "B",
                where = row[6],
                map = row[7],
                x = row[8],
                y = row[9],
                class = row.class,
                races = row.races,
                zone = zones[id],
                rewards = CopyRewards(rewards[id]),
                choice = choices[id] == true,
                dungeon = nil,
            })
        end
    end
    -- Dungeon tags live only on the snapshot. Copy them onto live rows by quest id
    -- so the dungeon category still groups when the journal is the source.
    local tags = {}
    local bundled = SG.BundledQuests or {}
    for i = 1, #bundled do
        if bundled[i].dungeon then tags[bundled[i].id] = bundled[i].dungeon end
    end
    for i = 1, #list do
        list[i].dungeon = tags[list[i].id]
    end
    return list
end

local function IndexItems(data)
    if type(data) ~= "table" or type(data.specs) ~= "table" then return nil end
    local items = {}
    for i = 1, #data.specs do
        local spec = data.specs[i]
        if type(spec) == "table" and spec.key and type(spec.slots) == "table" then
            for slot, list in pairs(spec.slots) do
                if type(list) == "table" then
                    for rank = 1, #list do
                        local itemID = list[rank]
                        local bucket = items[itemID]
                        if not bucket then
                            bucket = {}
                            items[itemID] = bucket
                        end
                        local prev = bucket[spec.key]
                        if not prev or rank < prev.rank then
                            bucket[spec.key] = { rank = rank, slot = slot }
                        end
                    end
                end
            end
        end
    end
    return items
end

function SG.BiS.Refresh()
    local ns = Namespace()
    local live = ReadJournal(ns)
    local list
    if live and #live > 0 then
        list = live
        SG.BiS.source = "journal"
    else
        list = {}
        local bundled = SG.BundledQuests or {}
        for i = 1, #bundled do
            list[i] = bundled[i]
            Normalize(list[i])
        end
        SG.BiS.source = "snapshot"
    end
    SG.BiS.quests = list
    SG.BiS.byId = {}
    for i = 1, #list do
        SG.BiS.byId[list[i].id] = list[i]
    end

    local ranked = ns and IndexItems(ns.BiSData)
    if ranked then
        SG.BiS.items = ranked
        SG.BiS.itemSource = "bis"
    else
        SG.BiS.items = SG.BundledItems or {}
        SG.BiS.itemSource = "snapshot"
    end
    SG.BiS.ns = ns
end

function SG.BiS.Quest(id)
    return SG.BiS.byId[id]
end

function SG.BiS.BestReward(quest, specKey)
    if not quest or not specKey then return nil end
    local bestItem, bestRank, bestSlot
    local rewards = quest.rewards or {}
    for i = 1, #rewards do
        local bucket = SG.BiS.items[rewards[i]]
        local row = bucket and bucket[specKey]
        if row and (not bestRank or row.rank < bestRank) then
            bestItem, bestRank, bestSlot = rewards[i], row.rank, row.slot
        end
    end
    return bestItem, bestRank, bestSlot
end

function SG.BiS.RankedForAnyone(quest)
    local rewards = quest and quest.rewards or {}
    for i = 1, #rewards do
        local bucket = SG.BiS.items[rewards[i]]
        if bucket then
            for _ in pairs(bucket) do
                return true
            end
        end
    end
    return false
end

function SG.BiS.RaceOK(quest, raceID)
    local mask = quest and quest.races
    if not mask or not raceID then return true end
    local bit = RACE_BITS[raceID]
    if not bit then return true end
    -- Lua numbers are doubles, so a 2^32 race bit still divides exactly.
    return math.floor(mask / (2 ^ bit)) % 2 == 1
end

-- "hide"  : wrong class, race, or faction. Never shown.
-- "bis"   : ranked for this spec, or a journal BiS quest our top-10 slice
--           does not assign to any spec (kept, so routes do not go empty).
-- "other" : ranked for other specs and not this one. Hidden by "only my spec".
function SG.BiS.Match(quest, guideSide)
    if not quest then return "hide" end
    if quest.class and SG.classToken and quest.class ~= SG.classToken then
        return "hide"
    end
    if not SG.BiS.RaceOK(quest, SG.raceID) then return "hide" end
    if guideSide and guideSide ~= "B" and quest.side and quest.side ~= "B" and quest.side ~= guideSide then
        return "hide"
    end
    local spec = SG.Specs.Selected()
    local _, rank = SG.BiS.BestReward(quest, spec)
    if rank then return "bis" end
    if SG.BiS.RankedForAnyone(quest) then return "other" end
    return "bis"
end

function SG.BiS.LoadedAddons()
    local names = {}
    for i = 1, #ADDON_NAMES do
        if AddonLoaded(ADDON_NAMES[i]) then
            names[#names + 1] = ADDON_NAMES[i]
        end
    end
    return names
end

function SG.BiS.Status()
    local quests = SG.BiS.quests and #SG.BiS.quests or 0
    local from = SG.BiS.source == "journal" and "live Dungeon Journal" or "bundled snapshot"
    local ranks = SG.BiS.itemSource == "bis" and "live spec rankings" or "bundled spec rankings"
    local loaded = SG.BiS.LoadedAddons()
    local extra = ""
    if #loaded == 0 then
        extra = " NaowhForever_BiS is not enabled, so Stratagem is using its own copy."
    end
    return string.format("%d BiS quests from the %s, %s.%s", quests, from, ranks, extra)
end
