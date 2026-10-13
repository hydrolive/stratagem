-- Route.lua: one leveling route per faction, plus Level 60 BiS and attunements.
-- Quest ids, bosses, and drop chances come from the loaded catalog and the
-- Naowh journal. Nothing here invents a quest, an item, a boss, or a percent.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Route = SG.Route or {}

-- Stay in a zone for quests that are not past the next quest in another zone.
-- A higher quest here waits, and the route comes back for it.

-- Race ids: human 1, orc 2, dwarf 3, night elf 4, undead 5, tauren 6, gnome 7, troll 8.
-- Humans have no starter writeup in this addon, so their route begins at the first catalog quest.
local STARTER = {
    H = { [6] = "h-mulgore", [2] = "h-durotar", [8] = "h-durotar", [5] = "h-tirisfal" },
    A = { [4] = "a-teldrassil", [3] = "a-dunmorogh", [7] = "a-dunmorogh" },
}

local ROUTE_BLURB = "One route for your faction. It follows your level and sends you to the zone whose next quest is the better piece. The ride is not treated as a cost. It leaves a zone when another zone still has a lower quest, and it comes back when a later quest here is next. Each catalog quest brings the earlier quests in its journal chain, and those steps are finished before the dungeon. A quest that continues an earlier one shows a chain marker. Mouse over it for those earlier quests. A dungeon is then every pickup, one clear, and one turn-in at a time. The level on that block is the journal difficulty, so an easier dungeon comes first. The bundled catalog still ends in the mid 30s, so this is not every side quest in a zone. A line marked (Optional) is a dungeon farm, a gear quest that was not on the written route, or the skyborne island. Mark it done to skip it."

local BIS_SLOTS = {
    { id = 1, name = "Head" },
    { id = 2, name = "Neck" },
    { id = 3, name = "Shoulder" },
    { id = 15, name = "Back" },
    { id = 5, name = "Chest" },
    { id = 9, name = "Wrist" },
    { id = 10, name = "Hands" },
    { id = 6, name = "Waist" },
    { id = 7, name = "Legs" },
    { id = 8, name = "Feet" },
    { id = 11, name = "Finger 1" },
    { id = 12, name = "Finger 2" },
    { id = 13, name = "Trinket 1" },
    { id = 14, name = "Trinket 2" },
    { id = 16, name = "Weapon" },
    { id = 17, name = "Off Hand" },
    { id = 18, name = "Ranged" },
}

local function FindGuide(id)
    local data = SG.GuideData or {}
    for i = 1, #data do
        if data[i].id == id then return data[i] end
    end
    return nil
end

local function Namespace()
    return SG.BiS and SG.BiS.ns or nil
end

local function ItemName(itemID)
    if not itemID then return nil end
    if GetItemInfo then
        local name = GetItemInfo(itemID)
        if type(name) == "string" and name ~= "" then return name end
    end
    local ItemDB = _G.ItemDB
    if ItemDB and ItemDB.name then
        local name = ItemDB.name(itemID)
        if type(name) == "string" and name ~= "" then return name end
    end
    return "item " .. tostring(itemID)
end

local function ClassGear(quest)
    if not quest or type(quest.rewards) ~= "table" then return 99 end
    local items = SG.BiS and SG.BiS.items
    local specs = SG.Specs and SG.Specs.ForClass(SG.classToken)
    if not items or not specs then return 99 end
    local best = 99
    for r = 1, #quest.rewards do
        local bucket = items[quest.rewards[r]]
        if bucket then
            for s = 1, #specs do
                local row = bucket[specs[s].key]
                if row and row.rank and row.rank < best then best = row.rank end
            end
        end
    end
    return best
end

local function Better(a, b)
    if a.level ~= b.level then return a.level < b.level end
    -- Same level: finish the lead-in before the dungeon it unlocks.
    local ap = a.dungeon and 1 or 0
    local bp = b.dungeon and 1 or 0
    if ap ~= bp then return ap < bp end
    if a.gear ~= b.gear then return a.gear < b.gear end
    return a.order < b.order
end

-- Segment titles the route already uses. A chain quest is grouped by where it starts.
local MAP_ZONE = {
    [1411] = "Valley of Trials & Durotar",
    [1412] = "Camp Narache & Mulgore",
    [1413] = "The Barrens",
    [1420] = "Tirisfal Glades",
    [1421] = "Silverpine Forest",
    [1424] = "Hillsbrad Foothills",
    [1426] = "Dun Morogh",
    [1438] = "Teldrassil",
    [1439] = "Darkshore",
    [1440] = "Ashenvale",
    [1441] = "Thousand Needles",
    [1442] = "Stonetalon Mountains",
    [1456] = "Thunder Bluff",
    [1458] = "Undercity",
    [2521] = "Zephras Isle",
}

local function ZoneKey(map, fallback)
    if map and MAP_ZONE[map] then return MAP_ZONE[map] end
    return fallback
end

local function Journal()
    local ns = Namespace()
    return ns and ns.Journal or nil
end

local function JournalQuestRow(journal, id)
    local data = journal and journal.QuestData
    if type(data) ~= "table" then return nil end
    for d = 1, #data do
        local quests = data[d].quests
        if type(quests) == "table" then
            for q = 1, #quests do
                local row = quests[q]
                if type(row) == "table" and row[1] == id then return row end
            end
        end
    end
    return nil
end

local function JournalRowLevel(journal, id)
    local row = JournalQuestRow(journal, id)
    if row and type(row[3]) == "number" and row[3] > 0 then return row[3] end
    return nil
end

-- The low end of the journal bracket is the difficulty used to order dungeons.
local function DungeonBand(name)
    local journal = Journal()
    if not journal or type(journal.QuestData) ~= "table" or type(name) ~= "string" then return nil end
    local want = name:lower()
    for d = 1, #journal.QuestData do
        local block = journal.QuestData[d]
        if type(block) == "table" and type(block.name) == "string" and block.name:lower() == want then
            local levels = block.levels
            if type(levels) == "table" and type(levels[1]) == "number" and levels[1] > 0 then
                return levels[1]
            end
        end
    end
    return nil
end

local function DungeonName(journal, title)
    if not journal or type(journal.QuestData) ~= "table" or type(title) ~= "string" then return nil end
    local want = title:lower()
    for d = 1, #journal.QuestData do
        local block = journal.QuestData[d]
        if type(block) == "table" and type(block.name) == "string" and block.name:lower() == want then
            return block.name
        end
    end
    return nil
end

local function ContainsId(step, id)
    if step == id then return true end
    if type(step) ~= "table" then return false end
    for i = 1, #step do
        if ContainsId(step[i], id) then return true end
    end
    return false
end

-- A quest that only appears in another quest's follow-up list is done after
-- that dungeon, not accepted before the clear. A journal row of the dungeon
-- itself is not a follow-up.
local function FollowUpDungeon(journal, id)
    if not journal or type(journal.QuestData) ~= "table" or not id then return nil end
    local fallback
    for d = 1, #journal.QuestData do
        local block = journal.QuestData[d]
        local list = type(block) == "table" and block.quests or nil
        if type(list) == "table" then
            local primary, follow = false, false
            for q = 1, #list do
                local row = list[q]
                if type(row) == "table" then
                    if row[1] == id then primary = true end
                    if row[1] ~= id and type(row.steps) == "table" and ContainsId(row.steps, id) then
                        follow = true
                    end
                end
            end
            if primary then return nil end
            if follow and not fallback then fallback = block.name end
        end
    end
    return fallback
end

function SG.Route.DungeonLevel(name)
    return DungeonBand(name)
end

function SG.Route.DungeonEntrance(name)
    local ns = Namespace()
    local journal = ns and ns.Journal
    if not journal or not journal.Dungeons or type(name) ~= "string" then return nil end
    local want = name:lower()
    local list = journal.Dungeons() or {}
    for i = 1, #list do
        local dungeon = list[i]
        local entrance = dungeon and dungeon.entrance
        if dungeon and type(dungeon.name) == "string" and dungeon.name:lower() == want and type(entrance) == "table" then
            if entrance.map and entrance.x and entrance.y then
                return entrance.map, entrance.x, entrance.y
            end
        end
    end
    return nil
end

function SG.Route.TurnIn(id)
    local journal = Journal()
    local turn = journal and journal.QuestTurnIns and journal.QuestTurnIns[id]
    if type(turn) ~= "table" then return nil end
    return turn[1], turn[2], turn[3], turn[4]
end

function SG.Route.StartOf(id)
    local row = JournalQuestRow(Journal(), id)
    if not row then return nil end
    return row[7], row[8], row[9], row[6]
end

-- Same class bits the client uses. Discovery stores a mask, not a token.
local CLASS_BITS = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16,
    SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024,
}

-- NaowhForever_Discovery publishes CompletoQuestData. Stratagem does not
-- copy that list. A missing addon simply leaves the extra lead-in off.
local function DiscoveryRow(id)
    local ns = _G.NaowhForever or _G.NaowwahForever
    local data = ns and ns.CompletoQuestData
    local quests = data and data.Quests
    local row = quests and quests[id]
    if type(row) ~= "table" then return nil end
    return row
end

local function DiscoveryRequires()
    local ns = _G.NaowhForever or _G.NaowwahForever
    local data = ns and ns.CompletoQuestData
    local requires = data and data.Requires
    if type(requires) ~= "table" then return nil end
    return requires
end

local function DiscoverySide(code)
    if code == 1 then return "A" end
    if code == 2 then return "H" end
    if code == 3 or code == 0 or code == nil then return "B" end
    return nil
end

local function DiscoveryAllowed(id, side)
    local row = DiscoveryRow(id)
    if not row then return true end
    local questSide = DiscoverySide(row[4])
    if questSide and questSide ~= "B" and side and questSide ~= side then return false end
    local races = row[5]
    if type(races) == "number" and races ~= 0 and SG.BiS.RaceOK and not SG.BiS.RaceOK({ races = races }, SG.raceID) then
        return false
    end
    local mask = row[6]
    if type(mask) == "number" and mask ~= 0 and SG.classToken then
        local bit = CLASS_BITS[SG.classToken]
        if bit and math.floor(mask / bit) % 2 == 0 then return false end
    end
    return true
end

-- Returns the scheduling level and whether it came from this quest.
-- A level inherited from the chain root is not sourced, so a later step
-- can be lifted to the previous quest instead of sorting at the root minimum.
local function QuestLevelOf(journal, id, rootId, rootLevel)
    local level, sourced
    local known = SG.BiS.Quest(id)
    if known and known.level and known.level > 0 then
        level = known.level
        sourced = true
    end
    if not level then
        local row = JournalQuestRow(journal, id)
        if row and type(row[3]) == "number" and row[3] > 0 then
            level = row[3]
            sourced = true
        end
    end
    if not level and journal and journal.QuestMinLevel and journal.QuestMinLevel[id] then
        level = journal.QuestMinLevel[id]
        sourced = true
    end
    -- Discovery's quest level wins over Questie. Questie can report a minimum
    -- that would pull The Forgotten Pools up into the level 16 visit.
    if not level then
        local disco = DiscoveryRow(id)
        if disco and type(disco[2]) == "number" and disco[2] > 0 then
            level = disco[2]
            sourced = true
        end
    end
    if not level then
        local QuestDB = _G.QuestDB
        if QuestDB and QuestDB.questLevel then
            local questLevel = QuestDB.questLevel(id)
            if type(questLevel) == "number" and questLevel > 0 then
                level = questLevel
                sourced = true
            end
        end
    end
    if not level and rootId and id ~= rootId and journal and journal.QuestMinLevel and journal.QuestMinLevel[rootId] then
        level = journal.QuestMinLevel[rootId]
    end
    if not level then level = rootLevel or 1 end
    local min = journal and journal.QuestMinLevel and journal.QuestMinLevel[id]
    if type(min) == "number" and min > level then
        level = min
        sourced = true
    end
    local disco = DiscoveryRow(id)
    local dmin = disco and disco[3]
    if type(dmin) == "number" and dmin > level then
        level = dmin
        sourced = true
    end
    return level, sourced
end

-- Requirements of quests already on the journal chain. This walks upward
-- only, so a side branch that requires a chain quest is not pulled in.
local function PrependAncestors(steps, seen)
    local requires = DiscoveryRequires()
    if not requires then return steps end
    local members = {}
    local function collect(list)
        for i = 1, #list do
            local step = list[i]
            if type(step) == "number" then
                members[#members + 1] = step
            elseif type(step) == "table" then
                collect(step)
            end
        end
    end
    collect(steps)
    local member = {}
    for i = 1, #members do member[members[i]] = true end
    local ancestor = {}
    local function walk(id, depth)
        if depth > 8 then return end
        local req = requires[id]
        if type(req) ~= "table" then return end
        for i = 1, #req do
            local need = req[i]
            if type(need) == "number" and not member[need] and not ancestor[need] then
                local row = DiscoveryRow(need)
                if row and type(row[1]) == "string" and row[1] ~= "" then
                    ancestor[need] = true
                    walk(need, depth + 1)
                end
            end
        end
    end
    for i = 1, #members do walk(members[i], 0) end
    local ordered, placed, visiting = {}, {}, {}
    local function emit(id)
        if placed[id] or not ancestor[id] or visiting[id] then return end
        visiting[id] = true
        local req = requires[id]
        if type(req) == "table" then
            for i = 1, #req do
                if type(req[i]) == "number" then emit(req[i]) end
            end
        end
        visiting[id] = nil
        if not placed[id] then
            placed[id] = true
            ordered[#ordered + 1] = id
            seen[id] = true
        end
    end
    for i = 1, #members do
        local req = requires[members[i]]
        if type(req) == "table" then
            for r = 1, #req do
                if type(req[r]) == "number" then emit(req[r]) end
            end
        end
    end
    if #ordered == 0 then return steps end
    local out = {}
    for i = 1, #ordered do out[#out + 1] = ordered[i] end
    for i = 1, #steps do out[#out + 1] = steps[i] end
    return out
end

local function ChainList(journal, root)
    if not journal then return { root } end
    local steps, seen = {}, {}
    local function add(step)
        if type(step) == "table" then
            local numeric = #step > 0
            for i = 1, #step do
                if type(step[i]) ~= "number" then numeric = false end
            end
            if numeric and #step > 1 then
                local fresh = {}
                for i = 1, #step do
                    if not seen[step[i]] then
                        fresh[#fresh + 1] = step[i]
                        seen[step[i]] = true
                    end
                end
                if #fresh > 0 then steps[#steps + 1] = fresh end
                return
            end
            for i = 1, #step do add(step[i]) end
            return
        end
        if type(step) ~= "number" or seen[step] then return end
        seen[step] = true
        steps[#steps + 1] = step
    end
    local row = JournalQuestRow(journal, root)
    if row and type(row.lead) == "table" then
        for i = 1, #row.lead do add(row.lead[i]) end
    end
    local pre = journal.QuestPrereqs and journal.QuestPrereqs[root]
    local series = journal.QuestChains and journal.QuestChains[root]
    if type(pre) == "table" then
        for i = 1, #pre do add(pre[i]) end
    end
    if type(series) == "table" then
        for i = 1, #series do add(series[i]) end
    end
    add(root)
    -- Follow-ups live on the dungeon row (The Glowing Shard), not in QuestChains.
    if row and type(row.steps) == "table" then add(row.steps) end
    if #steps == 0 then return { root } end
    return PrependAncestors(steps, seen)
end

local function ChainQuest(journal, id, level)
    local known = SG.BiS.Quest(id)
    if known then return known end
    local row = JournalQuestRow(journal, id)
    local start = journal and journal.QuestChainStarts and journal.QuestChainStarts[id]
    local name = journal and journal.QuestChainNames and journal.QuestChainNames[id]
    local where = journal and journal.QuestWhere and journal.QuestWhere[id]
    local map, x, y
    if row then
        name = name or row[2]
        if type(row[3]) == "number" and row[3] > 0 then level = row[3] end
        where = where or row[6]
        map, x, y = row[7], row[8], row[9]
    end
    local hadStart = (type(row) == "table" and row[7]) or (type(start) == "table" and start[1])
    local giver
    if type(start) == "table" then
        map = map or start[1]
        x = x or start[2]
        y = y or start[3]
        giver = start[4]
    end
    if giver and type(where) == "string" and where ~= "" and not where:find(giver, 1, true) then
        where = where .. " - " .. giver
    elseif giver and (not where or where == "") then
        where = giver
    end
    local disco = DiscoveryRow(id)
    local discoSide, discoRaces
    if disco then
        if (not name or name == "") and type(disco[1]) == "string" and disco[1] ~= "" then
            name = disco[1]
        end
        if not map and disco[7] then map = disco[7] end
        if not x and disco[8] then x = disco[8] end
        if not y and disco[9] then y = disco[9] end
        if not giver and type(disco[10]) == "string" and disco[10] ~= "" then giver = disco[10] end
        discoSide = DiscoverySide(disco[4])
        if type(disco[5]) == "number" and disco[5] ~= 0 then discoRaces = disco[5] end
        if map and not hadStart then hadStart = map end
    end
    if not name or name == "" then
        local QuestDB = _G.QuestDB
        if QuestDB and QuestDB.name then
            local qname = QuestDB.name(id)
            if type(qname) == "string" and qname ~= "" then name = qname end
        end
    end
    local turn = journal and journal.QuestTurnIns and journal.QuestTurnIns[id]
    if type(turn) == "table" then
        -- A turn-in pin is not a place to accept the quest. Inside drops keep
        -- an empty start so the dungeon step can point at the entrance.
        if hadStart then
            if not map and turn[1] then map = turn[1] end
            if not x and turn[2] then x = turn[2] end
            if not y and turn[3] then y = turn[3] end
        end
        if (not where or where == "") and type(turn[4]) == "string" and turn[4] ~= "" then
            where = turn[4]
        end
    end
    if type(giver) == "string" and giver ~= "" then
        if type(where) ~= "string" or where == "" then
            local place = ZoneKey(map, nil)
            if place then
                where = place .. " - " .. giver
            else
                where = giver
            end
        elseif not where:find(giver, 1, true) then
            where = where .. " - " .. giver
        end
    end
    if not name or name == "" then return nil end
    return {
        id = id,
        name = name,
        level = level,
        where = where,
        zone = ZoneKey(map, nil),
        map = map,
        x = x,
        y = y,
        rewards = {},
        class = row and row.class,
        races = (row and row.races) or discoRaces,
        side = (row and row[4]) or discoSide,
        inside = not hadStart and true or nil,
    }
end

local function UnitsFrom(def, seq, seen, side)
    local units = {}
    local journal = Journal()
    local afterByDungeon = {}
    local segments = def.segments or {}
    local function allowed(id)
        local known = SG.BiS.Quest(id)
        if known then
            if known.class and SG.classToken and known.class ~= SG.classToken then return false end
            if known.side and known.side ~= "B" and known.side ~= side then return false end
            if known.races and known.races ~= 0 and SG.BiS.RaceOK and not SG.BiS.RaceOK(known, SG.raceID) then
                return false
            end
        end
        local row = JournalQuestRow(journal, id)
        if row then
            local questSide = row[4]
            if questSide and questSide ~= "B" and questSide ~= side then return false end
            if row.class and SG.classToken and row.class ~= SG.classToken then return false end
            if row.races and row.races ~= 0 and SG.BiS.RaceOK and not SG.BiS.RaceOK({ races = row.races }, SG.raceID) then
                return false
            end
        end
        if not DiscoveryAllowed(id, side) then return false end
        return true
    end
    for s = 1, #segments do
        local segment = segments[s]
        local function push(level, gear, plain, entry, dungeon, keyOverride, questLevel, leads, chainPrior, chainRoot, chainPos)
            seq = seq + 1
            local key = keyOverride or segment.title
            if plain and plain.id then seen[plain.id] = true end
            if type(entry) == "number" then seen[entry] = true end
            if type(entry) == "table" and entry.id then seen[entry.id] = true end
            units[#units + 1] = {
                level = level or 1,
                questLevel = questLevel or level or 1,
                gear = gear or 99,
                key = key,
                zone = (type(entry) == "table" and entry.zone) or segment.zone or key,
                arrive = (key == segment.title) and segment.arrive or nil,
                plain = plain,
                entry = entry,
                dungeon = dungeon,
                leads = leads,
                chainPrior = chainPrior,
                chainRoot = chainRoot,
                chainPos = chainPos,
                order = seq,
            }
        end
        local function rememberAfter(id, dungeonName, level)
            local known = SG.BiS.Quest(id)
            local quest = known or ChainQuest(journal, id, level)
            if not quest then return end
            local list = afterByDungeon[dungeonName]
            if not list then
                list = {}
                afterByDungeon[dungeonName] = list
            end
            list[#list + 1] = quest
        end
        local function QuestTitle(id)
            local known = SG.BiS.Quest(id)
            if known and type(known.name) == "string" and known.name ~= "" then return known.name end
            local row = JournalQuestRow(journal, id)
            if row and type(row[2]) == "string" and row[2] ~= "" then return row[2] end
            local named = journal and journal.QuestChainNames and journal.QuestChainNames[id]
            if type(named) == "string" and named ~= "" then return named end
            local disco = DiscoveryRow(id)
            if disco and type(disco[1]) == "string" and disco[1] ~= "" then return disco[1] end
            local QuestDB = _G.QuestDB
            if QuestDB and QuestDB.name then
                local qname = QuestDB.name(id)
                if type(qname) == "string" and qname ~= "" then return qname end
            end
            return nil
        end
        local function expandOne(id, rootId, rootLevel, dungeonName, chainPrior, chainPos, chainRoot, chainFloor)
            if seen[id] then return nil end
            if not allowed(id) then
                seen[id] = true
                return nil
            end
            local level, sourced = QuestLevelOf(journal, id, rootId, rootLevel)
            if not sourced and chainFloor and level < chainFloor then level = chainFloor end
            local rowLevel = JournalRowLevel(journal, id)
            local questLevel = rowLevel or level
            if questLevel < level then questLevel = level end
            local follow = FollowUpDungeon(journal, id)
            if follow then
                seen[id] = true
                rememberAfter(id, follow, questLevel)
                return nil
            end
            local known = SG.BiS.Quest(id)
            local dungeon = nil
            if id == rootId then dungeon = (known and known.dungeon) or dungeonName end
            if known and known.dungeon then dungeon = known.dungeon end
            local rootKnown = rootId and SG.BiS.Quest(rootId)
            local rootDungeon = dungeonName or (rootKnown and rootKnown.dungeon)
            local leads = nil
            if id ~= rootId and rootDungeon and rootDungeon ~= "" and not dungeon then
                leads = rootDungeon
            end
            local key = segment.title
            if id ~= rootId then
                local probe = ChainQuest(journal, id, level)
                key = ZoneKey(probe and probe.map, segment.title)
            end
            -- A dungeon quest stays with that dungeon even when the zone
            -- guide listed the root under Silverpine or another segment.
            -- Lead-ins keep their start map, so the dungeon bracket stays put.
            if dungeon and dungeon ~= "" then key = dungeon end
            local prior = (chainRoot and chainPrior) or nil
            local root = chainRoot
            local pos = chainRoot and chainPos or nil
            if known then
                push(level, ClassGear(known), nil, id, dungeon, key, questLevel, leads, prior, root, pos)
                return level
            end
            local quest = ChainQuest(journal, id, questLevel)
            if not quest then
                seen[id] = true
                return nil
            end
            push(quest.level or level, 99, nil, quest, dungeon, key, questLevel, leads, prior, root, pos)
            return quest.level or level
        end
        local function expand(rootId, dungeonName)
            -- A hand-off is recorded when its parent chain is walked, in that
            -- order. Walking it as its own root would file the parent as a lead-in.
            if FollowUpDungeon(journal, rootId) then return end
            if seen[rootId] then return end
            if not allowed(rootId) then
                seen[rootId] = true
                return
            end
            local rootLevel = QuestLevelOf(journal, rootId, nil, nil)
            local chain = ChainList(journal, rootId)
            local priorOf, posOf = {}, {}
            local namesBefore = {}
            local pos, count = 0, 0
            local function copyPrior(list)
                if #list == 0 then return nil end
                local out = {}
                for i = 1, #list do out[i] = list[i] end
                return out
            end
            for i = 1, #chain do
                local step = chain[i]
                if type(step) == "table" then
                    local prior = copyPrior(namesBefore)
                    pos = pos + 1
                    for n = 1, #step do
                        local id = step[n]
                        if type(id) == "number" then
                            count = count + 1
                            posOf[id] = pos
                            priorOf[id] = prior
                        end
                    end
                    for n = 1, #step do
                        if type(step[n]) == "number" then
                            local title = QuestTitle(step[n])
                            if title then namesBefore[#namesBefore + 1] = title end
                        end
                    end
                elseif type(step) == "number" then
                    count = count + 1
                    pos = pos + 1
                    posOf[step] = pos
                    priorOf[step] = copyPrior(namesBefore)
                    local title = QuestTitle(step)
                    if title then namesBefore[#namesBefore + 1] = title end
                end
            end
            local chainRoot = count > 1 and rootId or nil
            local floorLevel = nil
            local function take(id, chainFloor)
                return expandOne(id, rootId, rootLevel, dungeonName, priorOf[id], posOf[id], chainRoot, chainFloor)
            end
            for i = 1, #chain do
                local step = chain[i]
                if type(step) == "table" then
                    local any = false
                    for n = 1, #step do
                        if seen[step[n]] then any = true end
                    end
                    if not any then
                        local nextFloor = floorLevel
                        for n = 1, #step do
                            local raised = take(step[n], floorLevel)
                            if raised and (not nextFloor or raised > nextFloor) then nextFloor = raised end
                        end
                        floorLevel = nextFloor
                    end
                else
                    local raised = take(step, floorLevel)
                    if raised then floorLevel = raised end
                end
            end
        end
        local plain = segment.plain or {}
        for p = 1, #plain do
            local quest = plain[p]
            if quest and not (quest.id and seen[quest.id]) then
                push(quest.level, 99, quest, nil, nil, segment.title, quest.level, nil)
            end
        end
        local segmentDungeon = DungeonName(journal, segment.title)
        local quests = segment.quests or {}
        for q = 1, #quests do
            local id = quests[q]
            if type(id) == "number" then expand(id, segmentDungeon) end
        end
        if journal and journal.QuestData then
            local want = (segment.title or ""):lower()
            for d = 1, #journal.QuestData do
                local block = journal.QuestData[d]
                if type(block) == "table" and (block.name or ""):lower() == want then
                    local list = block.quests or {}
                    for q = 1, #list do
                        local row = list[q]
                        local id = type(row) == "table" and row[1]
                        if type(id) == "number" then expand(id, segment.title) end
                    end
                end
            end
        end
    end
    local stamped = {}
    for i = 1, #units do
        local name = units[i].dungeon
        if name and not stamped[name] then
            stamped[name] = true
            units[i].afterQuests = afterByDungeon[name]
        end
    end
    return units, seq
end

local function StarterSegments(def)
    local out = {}
    local segments = def.segments or {}
    for s = 1, #segments do
        local segment = segments[s]
        out[#out + 1] = {
            title = def.title,
            travel = segment.title,
            zone = segment.zone or def.place or def.title,
            arrive = segment.arrive,
            quests = segment.quests,
            plain = segment.plain,
        }
    end
    return out
end

local function CopyQuest(entry, level)
    local src = entry
    if type(entry) == "number" then
        src = SG.BiS.Quest(entry)
        if not src then return nil end
    end
    if type(src) ~= "table" then return nil end
    local copy = {}
    for k, v in pairs(src) do copy[k] = v end
    if level then copy.level = level end
    return copy
end

local function Visit(batch, seen)
    local first = batch[1]
    local key = first.key
    local dungeon
    for i = 1, #batch do
        if batch[i].dungeon and batch[i].dungeon == key then dungeon = key end
    end
    local plain, quests = {}, {}
    local after, seenAfter = {}, {}
    for i = 1, #batch do
        local unit = batch[i]
        if unit.plain then
            plain[#plain + 1] = unit.plain
        elseif unit.entry then
            local quest = CopyQuest(unit.entry, unit.level)
            if quest then
                if unit.leads and not unit.dungeon then quest.leadIn = true end
                if type(unit.chainPrior) == "table" and #unit.chainPrior > 0 then
                    quest.chainPrior = unit.chainPrior
                end
                quests[#quests + 1] = quest
            end
        end
        local list = unit.afterQuests
        if type(list) == "table" then
            for a = 1, #list do
                local quest = list[a]
                local id = type(quest) == "table" and quest.id or quest
                if id and not seenAfter[id] then
                    seenAfter[id] = true
                    after[#after + 1] = quest
                end
            end
        end
    end
    local arrive = first.arrive
    -- The segment that owns this group carries the arrival line. A dungeon
    -- quest that was listed on another segment must not rename the block.
    local zone = key
    for i = 1, #batch do
        if batch[i].arrive and batch[i].arrive.text then
            arrive = batch[i].arrive
            if batch[i].zone then zone = batch[i].zone end
            break
        end
    end
    local text = (arrive and arrive.text) or ("Work the quests in " .. key .. " before you move on.")
    if seen[key] then
        text = "Return to " .. key .. " for the quests at this level. " .. text
    end
    return {
        title = key,
        travel = key,
        zone = zone,
        dungeon = dungeon,
        level = first.level,
        after = after,
        arrive = {
            text = text,
            map = arrive and arrive.map,
            x = arrive and arrive.x,
            y = arrive and arrive.y,
        },
        plain = plain,
        quests = quests,
    }
end

-- Skyborne Alliance is race 95. Skyborne Horde is race 96.
local SKYBORNE = { [95] = "a-zephras", [96] = "h-zephras" }

local function MarkStarter(def, used)
    if not def then return end
    local segments = def.segments or {}
    for s = 1, #segments do
        local segment = segments[s]
        local plain = segment.plain or {}
        for p = 1, #plain do
            if plain[p] and plain[p].id then used[plain[p].id] = true end
        end
        local quests = segment.quests or {}
        for q = 1, #quests do
            if type(quests[q]) == "number" then used[quests[q]] = true end
        end
    end
end

local function ZephrasDetour(side)
    if SKYBORNE[SG.raceID] then return nil end
    local guide = FindGuide(side == "A" and "a-zephras" or "h-zephras")
    if not guide or guide.side ~= side then return nil end
    local quests = {}
    local function take(id)
        local quest = type(id) == "number" and SG.BiS.Quest(id) or nil
        if quest and quest.races and quest.races ~= 0 and SG.BiS.RaceOK and SG.BiS.RaceOK(quest, SG.raceID) then
            quests[#quests + 1] = id
        end
    end
    local segments = guide.segments or {}
    for s = 1, #segments do
        local list = segments[s].quests or {}
        for q = 1, #list do take(list[q]) end
    end
    if guide.quests then
        for q = 1, #guide.quests do take(guide.quests[q]) end
    end
    if #quests == 0 then return nil end
    local ship = side == "A" and "the zeppelin from Dalaran" or "the zeppelin from Mulgore"
    return {
        title = "Zephras Isle",
        travel = "Zephras Isle",
        zone = "Zephras Isle",
        detour = true,
        arrive = {
            text = "Optional. Zephras Isle is the skyborne island. Take " .. ship .. " to reach it, and the same ride back. Only the quests your race can accept there are listed. Mark this done to stay on the mainland road.",
            map = 2521,
            x = 43.6,
            y = 44.8,
        },
        quests = quests,
    }
end

-- Dungeon steps use the journal bracket, raised only when a lead-in quest
-- is actually harder than that bracket. A catalog level above the journal
-- row is pulled down so it cannot push Ruins of Lordaeron past Wailing Caverns.
local function ScheduleDungeons(pool)
    local prereq = {}
    for i = 1, #pool do
        local unit = pool[i]
        if unit.leads and not unit.dungeon then
            local qlevel = unit.questLevel or unit.level
            if qlevel and unit.level and qlevel < unit.level then
                unit.level = qlevel
            end
            local name = unit.leads
            local lv = unit.level or 1
            if not prereq[name] or lv > prereq[name] then prereq[name] = lv end
        end
    end
    for i = 1, #pool do
        local unit = pool[i]
        if unit.dungeon then
            local floor = DungeonBand(unit.dungeon) or unit.level or 1
            local pre = prereq[unit.dungeon]
            if pre and pre > floor then floor = pre end
            unit.level = floor
        end
    end
end

function SG.Route.Leveling(side)
    local race = SG.raceID
    local starterId = STARTER[side] and STARTER[side][race]
    local skyId = SKYBORNE[race]
    if skyId then
        local sky = FindGuide(skyId)
        if sky and sky.side == side then starterId = skyId end
    end
    local starter = starterId and FindGuide(starterId)
    if starter and starter.side ~= side then starter = nil end
    local used = {}
    MarkStarter(starter, used)
    local pool = {}
    local seq = 0
    local data = SG.GuideData or {}
    for i = 1, #data do
        local def = data[i]
        local zephras = def.id == "h-zephras" or def.id == "a-zephras"
        if def.weave and def.side == side and def.id ~= starterId and not zephras then
            local units
            units, seq = UnitsFrom(def, seq, used, side)
            for u = 1, #units do
                pool[#pool + 1] = units[u]
            end
        end
    end
    local segments = {}
    if starter then
        local head = StarterSegments(starter)
        for i = 1, #head do segments[#segments + 1] = head[i] end
    end
    local detour = ZephrasDetour(side)
    if detour then segments[#segments + 1] = detour end
    ScheduleDungeons(pool)
    local unused = {}
    for i = 1, #pool do unused[i] = pool[i] end
    local seen = {}
    -- A later chain step stays out of the picker until the earlier one has
    -- been placed. A dungeon quest is not held, so the clear still forms.
    local function ChainWaiting(unit, cap, key)
        if not unit or not unit.chainRoot or not unit.chainPos or unit.dungeon then return false end
        for i = 1, #unused do
            local prev = unused[i]
            if prev and prev.chainRoot == unit.chainRoot and prev.chainPos and prev.chainPos < unit.chainPos and not prev.dungeon then
                local alongside = key and prev.key == key and cap and prev.level <= cap
                if not alongside then return true end
            end
        end
        return false
    end
    local function Take(unit)
        for i = 1, #unused do
            if unused[i] == unit then unused[i] = false end
        end
    end
    -- Keep a same-level chain tail together when the next step starts in
    -- another zone. A higher step waits for the level weaver.
    local function EmitChainTail(batch)
        local guard = 0
        local current = batch
        while current and guard < 24 do
            guard = guard + 1
            local nxt, fromLevel
            for b = 1, #current do
                local unit = current[b]
                if unit.chainRoot and unit.chainPos and unit.leads and not unit.dungeon then
                    for i = 1, #unused do
                        local cand = unused[i]
                        if cand and cand.leads and not cand.dungeon and cand.chainRoot == unit.chainRoot and cand.chainPos == unit.chainPos + 1 then
                            if cand.level <= unit.level and (not nxt or cand.chainPos < nxt.chainPos) then
                                nxt = cand
                                fromLevel = unit.level
                            end
                        end
                    end
                end
            end
            if not nxt then return end
            local run = {}
            local key = nxt.key
            local pos = nxt.chainPos
            local levelCap = fromLevel
            while nxt and nxt.key == key and nxt.chainPos == pos and nxt.level <= levelCap do
                run[#run + 1] = nxt
                Take(nxt)
                levelCap = nxt.level
                pos = pos + 1
                nxt = nil
                for i = 1, #unused do
                    local cand = unused[i]
                    if cand and cand.leads and not cand.dungeon and cand.chainRoot == run[1].chainRoot and cand.chainPos == pos and cand.key == key then
                        nxt = cand
                    end
                end
            end
            if #run == 0 then return end
            segments[#segments + 1] = Visit(run, seen)
            seen[key] = true
            current = run
        end
    end
    while true do
        local anchor
        for i = 1, #unused do
            local unit = unused[i]
            if unit and not ChainWaiting(unit) and (not anchor or Better(unit, anchor)) then
                anchor = unit
            end
        end
        if not anchor then
            for i = 1, #unused do
                local unit = unused[i]
                if unit and (not anchor or Better(unit, anchor)) then anchor = unit end
            end
        end
        if not anchor then break end
        -- Do not take a higher quest in this zone while another zone still
        -- has something at a lower level. Same-level quests here stay together.
        local other
        for i = 1, #unused do
            local unit = unused[i]
            if unit and unit.key ~= anchor.key and not ChainWaiting(unit) and (not other or Better(unit, other)) then
                other = unit
            end
        end
        local cap = other and other.level or 1000
        local batch = {}
        for i = 1, #unused do
            local unit = unused[i]
            if unit and unit.key == anchor.key and unit.level <= cap and not ChainWaiting(unit, cap, anchor.key) then
                batch[#batch + 1] = unit
                unused[i] = false
            end
        end
        if #batch == 0 then
            batch[1] = anchor
            Take(anchor)
        end
        table.sort(batch, function(a, b)
            if a.chainRoot and a.chainRoot == b.chainRoot and a.chainPos and b.chainPos and a.chainPos ~= b.chainPos then
                return a.chainPos < b.chainPos
            end
            if a.level ~= b.level then return a.level < b.level end
            local aq = a.questLevel or a.level or 0
            local bq = b.questLevel or b.level or 0
            if aq ~= bq then return aq < bq end
            return a.order < b.order
        end)
        segments[#segments + 1] = Visit(batch, seen)
        seen[anchor.key] = true
        EmitChainTail(batch)
    end
    local alliance = side == "A"
    return {
        id = alliance and "route-a" or "route-h",
        title = alliance and "Alliance leveling" or "Horde leveling",
        group = alliance and "Alliance leveling" or "Horde leveling",
        category = "leveling",
        side = side,
        min = 1,
        max = 60,
        place = alliance and "Alliance" or "Horde",
        route = true,
        keep = true,
        blurb = ROUTE_BLURB,
        segments = segments,
    }
end

function SG.Route.ActiveId()
    local side = SG.playerSide
    if SG.FactionFilter then
        local filter = SG.FactionFilter()
        if filter == "A" or filter == "H" then side = filter end
    end
    if side == "A" then return "route-a" end
    return "route-h"
end

-- One scan of the journal loot tables. The result is boss, dungeon, and chance.
-- Trash uses no percent, because the journal stores that as a sentinel, not a rate.
local dropCache

local function DropOf(itemID)
    if not dropCache then dropCache = {} end
    local cached = dropCache[itemID]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end
    local ns = Namespace()
    local journal = ns and ns.Journal
    if not (journal and journal.Dungeons) then
        dropCache[itemID] = false
        return nil
    end
    local found
    local dungeons = journal.Dungeons() or {}
    for d = 1, #dungeons do
        local dungeon = dungeons[d]
        local wings = dungeon.wings or {}
        for w = 1, #wings do
            local bosses = wings[w].bosses or {}
            for b = 1, #bosses do
                local boss = bosses[b]
                local loot = boss.loot
                if type(loot) == "table" then
                    for i = 1, #loot do
                        if loot[i] == itemID then
                            local trash = boss.trash and true or false
                            local chance = 0
                            if not trash and type(boss.chance) == "table" and boss.chance[i] then
                                chance = boss.chance[i]
                            end
                            if not found or (chance > 0 and chance > (found.chance or 0)) then
                                found = {
                                    boss = trash and "Trash" or (boss.name or "a boss"),
                                    dungeon = dungeon.name or "a dungeon",
                                    chance = chance,
                                    trash = trash,
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    dropCache[itemID] = found or false
    return found
end

local function ChanceText(drop)
    if not drop then return "no percent in the journal" end
    if drop.trash then return "trash, no percent in the journal" end
    if drop.chance and drop.chance > 0 then
        return string.format("%d%%", drop.chance)
    end
    return "no percent in the journal"
end

function SG.Route.FarmSteps(dungeonName, segment, zone, level)
    local missing = {
        kind = "farm",
        optional = true,
        pinned = true,
        match = "bis",
        segment = segment,
        zone = zone,
        instance = dungeonName,
        level = level,
        title = "(Optional) " .. dungeonName .. " drop",
        text = "(Optional) Run " .. dungeonName .. " until a drop upgrades a slot. Boss names and drop chances load with NaowhForever_DungeonJournal. Mark this done to skip it.",
    }
    local ns = Namespace()
    local journal = ns and ns.Journal
    if not (journal and journal.Dungeons) then return { missing } end
    local class = SG.classToken
    if not class or not (SG.Gear and SG.Gear.Fact and SG.Gear.Usable) then
        missing.text = "(Optional) Run " .. dungeonName .. " until a drop upgrades a slot. Your class is not known yet, so the item is not listed. Mark this done to skip it."
        return { missing }
    end
    local want = dungeonName:lower()
    local best = {}
    local dungeons = journal.Dungeons() or {}
    for d = 1, #dungeons do
        local dungeon = dungeons[d]
        if (dungeon.name or ""):lower() == want then
            local wings = dungeon.wings or {}
            for w = 1, #wings do
                local bosses = wings[w].bosses or {}
                for b = 1, #bosses do
                    local boss = bosses[b]
                    local loot = boss.loot
                    if type(loot) == "table" then
                        for i = 1, #loot do
                            local itemID = loot[i]
                            local fact = SG.Gear.Fact(itemID)
                            local score = fact and SG.Gear.Usable(class, fact, level or 1)
                            local slot = fact and fact.slot
                            if score and slot then
                                local trash = boss.trash and true or false
                                local chance = 0
                                if not trash and type(boss.chance) == "table" and boss.chance[i] then
                                    chance = boss.chance[i]
                                end
                                local prev = best[slot]
                                local take = not prev
                                if prev and score > prev.score then take = true end
                                if prev and score == prev.score and (fact.ilvl or 0) > (prev.ilvl or 0) then take = true end
                                if prev and score == prev.score and (fact.ilvl or 0) == (prev.ilvl or 0) and chance > (prev.chance or 0) then
                                    take = true
                                end
                                if prev and (prev.chance or 0) > 0 and chance <= 0 and score <= prev.score then
                                    take = false
                                end
                                if take then
                                    best[slot] = {
                                        itemID = itemID,
                                        score = score,
                                        ilvl = fact.ilvl or 0,
                                        slot = slot,
                                        boss = trash and "Trash" or (boss.name or "a boss"),
                                        chance = chance,
                                        trash = trash,
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    local slots = {}
    for slot in pairs(best) do slots[#slots + 1] = slot end
    table.sort(slots)
    if #slots == 0 then
        missing.text = "(Optional) Run " .. dungeonName .. " until a drop upgrades a slot. The journal lists no piece your class can equip in this dungeon. Mark this done to skip it."
        return { missing }
    end
    local steps = {}
    for i = 1, #slots do
        local row = best[slots[i]]
        local name = ItemName(row.itemID)
        local slotName = (SG.SLOT_NAME and SG.SLOT_NAME[row.slot]) or "slot"
        local drop = { boss = row.boss, chance = row.chance, trash = row.trash, dungeon = dungeonName }
        local chance = ChanceText(drop)
        steps[#steps + 1] = {
            kind = "farm",
            optional = true,
            pinned = true,
            match = "bis",
            segment = segment,
            zone = zone,
            instance = dungeonName,
            level = level,
            itemID = row.itemID,
            slot = row.slot,
            rewards = { row.itemID },
            gearName = name,
            dropLine = row.boss .. "  " .. chance,
            title = "(Optional) " .. slotName .. ": " .. name,
            text = string.format(
                "(Optional) Run %s until %s drops from %s (%s). Mark this done to skip it.",
                dungeonName, name, row.boss, chance
            ),
        }
    end
    return steps
end

local function SourceLine(itemID)
    local ns = Namespace()
    if not ns then
        return "The Level 60 list loads with NaowhForever_BiS."
    end
    local src = ns.BiSSource and ns.BiSSource(itemID) or nil
    local kind, target
    local sources = ns.BiS and ns.BiS.Sources
    if sources and sources.Of then
        local ok, a, b = pcall(sources.Of, itemID)
        if ok then
            kind, target = a, b
        end
    end
    local journal = ns.Journal
    local map, x, y
    if kind == "quest" and type(target) == "number" then
        local quest = SG.BiS.Quest(target)
        local name = (quest and quest.name) or (journal and journal.QuestChainNames and journal.QuestChainNames[target]) or ("Quest " .. target)
        local where = (quest and quest.where) or (journal and journal.QuestWhere and journal.QuestWhere[target]) or ""
        if quest and quest.map then
            map, x, y = quest.map, quest.x, quest.y
        end
        local start = journal and journal.QuestChainStarts and journal.QuestChainStarts[target]
        if not map and type(start) == "table" then
            map, x, y = start[1], start[2], start[3]
        end
        local line = "Quest: " .. name .. "."
        if where ~= "" then line = line .. " " .. where end
        return line, map, x, y
    end
    local drop = DropOf(itemID)
    if drop or kind == "dungeon" then
        local boss = drop and drop.boss
        local place = drop and drop.dungeon
        if type(src) == "string" then
            local sep = ns.BiS and ns.BiS.Rankings and ns.BiS.Rankings.SOURCE_SEP
            if sep then
                local who, where = src:match("^(.-)" .. sep .. "(.+)$")
                if who and who ~= "" then boss = boss or who end
                if where and where ~= "" then place = place or where end
            end
        end
        local line = "Drops from " .. (boss or "a boss")
        if place then line = line .. " in " .. place end
        line = line .. " (" .. ChanceText(drop) .. ")."
        return line, map, x, y
    end
    if type(src) == "string" and src ~= "" then
        local low = src:lower()
        if low:find("auction", 1, true) then
            return "Buy it on the auction house. " .. src .. "."
        end
        if low:find("world drop", 1, true) then
            return "Source: World drop. The list does not say it is on the auction house."
        end
        return "Source: " .. src .. "."
    end
    return "The loaded list does not name a source for this item."
end

local function EnchantLine(slot, slotName)
    local ns = Namespace()
    local enchants = ns and ns.BiS and ns.BiS.Enchants
    if not (enchants and enchants.Advise and ns.BiSEnchants) then
        return "(Optional) Enchant the " .. slotName .. " after you equip it. Enchant advice loads with NaowhForever_BiS. Mark this done to skip it."
    end
    local ok, advice = pcall(enchants.Advise, slot)
    local spell = ok and advice and advice.now
    local row = spell and ns.BiSEnchants[spell]
    if not row then
        return "(Optional) Enchant the " .. slotName .. " after you equip it. Naowh has no enchant for the item in that slot. Mark this done to skip it."
    end
    local name = row.text or row.enchant or ("spell " .. tostring(spell))
    local source = ""
    if row.source and row.source ~= "" then source = " Source: " .. row.source .. "." end
    return "(Optional) Enchant the " .. slotName .. " with " .. tostring(name) .. "." .. source .. " This is for the item you have equipped. Mark this done to skip it."
end

local function ScoreText(spec)
    local ns = Namespace()
    local Score = ns and ns.NaowhScore
    if not (Score and Score.Unit and Score.Of and Score.Link) then
        return "Gear score loads with NaowhForever_BiS."
    end
    local current = Score.Unit("player")
    local missing = false
    local function read(slot)
        local itemID = spec and spec.slots and spec.slots[slot] and spec.slots[slot][1]
        local link
        if itemID and GetItemInfo then
            link = select(2, GetItemInfo(itemID))
        end
        if itemID and not link then missing = true end
        if not link then link = GetInventoryItemLink("player", slot) end
        if not link then return nil end
        return Score.Link(link)
    end
    local ideal = Score.Of(read)
    local function num(value)
        if Score.Text and type(value) == "number" then return Score.Text(value) end
        if type(value) == "number" then return string.format("%.1f", value) end
        return "?"
    end
    local line = "Gear score " .. num(current) .. " now. Ideal " .. num(ideal) .. " after these pieces."
    if missing then line = line .. " Some items are still loading." end
    return line
end

local function FindSpec()
    local ns = Namespace()
    local data = ns and ns.BiSData
    if not (data and type(data.specs) == "table") then return nil end
    local key = SG.Specs and SG.Specs.Selected()
    for i = 1, #data.specs do
        if data.specs[i].key == key then return data.specs[i] end
    end
    return nil
end

function SG.Route.Endgame()
    local steps = {}
    local function add(fields)
        fields.visible = true
        fields.match = fields.match or "bis"
        fields.optional = fields.optional and true or false
        fields.segment = "Level 60 BiS"
        fields.zone = "Level 60 BiS"
        fields.guide = "bis-60"
        steps[#steps + 1] = fields
        fields.index = #steps
    end
    add({
        kind = "note",
        optional = true,
        role = "score",
        title = "Gear score",
        text = "Gear score loads with NaowhForever_BiS.",
        level = 60,
    })
    for i = 1, #BIS_SLOTS do
        local slot = BIS_SLOTS[i]
        add({
            kind = "gear",
            role = "item",
            slot = slot.id,
            slotName = slot.name,
            level = 60,
            title = slot.name,
            text = "The rank 1 piece for " .. slot.name .. " loads with NaowhForever_BiS.",
        })
        add({
            kind = "gear",
            role = "enchant",
            optional = true,
            slot = slot.id,
            slotName = slot.name,
            level = 60,
            title = "(Optional) Enchant " .. slot.name,
            text = "(Optional) Enchant the " .. slot.name .. ". Mark this done to skip it.",
        })
    end
    return {
        id = "bis-60",
        title = "Level 60 BiS",
        group = "Level 60 BiS",
        category = "bis",
        side = "B",
        place = "Azeroth",
        blurb = "Rank 1 in every slot for your spec, from the Naowh list. A quest source names where to pick it up. A world drop is not treated as an auction listing unless the list says auction. Enchant lines follow the item you have equipped and are marked (Optional).",
        min = 60,
        max = 60,
        steps = steps,
        hiddenQuests = 0,
        questCount = 0,
        visibleQuests = #BIS_SLOTS,
        empty = false,
        keep = true,
        scoreText = "",
    }
end

function SG.Route.PaintGuide(guide)
    if not guide or not guide.steps then return end
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.kind == "farm" and step.itemID then
            local name = ItemName(step.itemID)
            local slotName = (SG.SLOT_NAME and step.slot and SG.SLOT_NAME[step.slot]) or "slot"
            if name ~= ("item " .. tostring(step.itemID)) or not step.named then
                local drop = DropOf(step.itemID)
                local boss = drop and drop.boss or "a boss"
                local place = step.instance or (drop and drop.dungeon) or "the dungeon"
                local chance = ChanceText(drop)
                step.title = "(Optional) " .. slotName .. ": " .. name
                step.text = string.format(
                    "(Optional) Run %s until %s drops from %s (%s). Mark this done to skip it.",
                    place, name, boss, chance
                )
                step.baseText = step.text
                step.gearName = name
                step.rewards = { step.itemID }
                step.dropLine = boss .. "  " .. chance
                if name ~= ("item " .. tostring(step.itemID)) then step.named = true end
            end
        end
    end
    if guide.id ~= "bis-60" then return end
    local spec = FindSpec()
    guide.scoreText = ScoreText(spec)
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.role == "score" then
            step.text = guide.scoreText
            step.baseText = step.text
            step.title = "Gear score"
        elseif step.role == "item" then
            local itemID = spec and spec.slots and spec.slots[step.slot] and spec.slots[step.slot][1]
            step.itemID = itemID
            if itemID then
                local name = ItemName(itemID)
                local line, map, x, y = SourceLine(itemID)
                step.title = step.slotName .. ": " .. name
                step.text = line
                step.map, step.x, step.y = map, x, y
            else
                step.title = step.slotName
                step.text = "The loaded list has no rank 1 item for " .. step.slotName .. "."
                step.map, step.x, step.y = nil, nil, nil
            end
            step.baseText = step.text
        elseif step.role == "enchant" then
            step.text = EnchantLine(step.slot, step.slotName)
            step.baseText = step.text
            step.title = "(Optional) Enchant " .. step.slotName
        end
    end
end

function SG.Route.Paint()
    dropCache = nil
    local guides = SG.Engine and SG.Engine.guides or {}
    for i = 1, #guides do
        SG.Route.PaintGuide(guides[i])
    end
end

local function JournalRow(journal, id)
    local data = journal and journal.QuestData
    if type(data) ~= "table" then return nil end
    for d = 1, #data do
        local quests = data[d].quests
        if type(quests) == "table" then
            for q = 1, #quests do
                local row = quests[q]
                if type(row) == "table" and row[1] == id then return row end
            end
        end
    end
    return nil
end

local function ChainIds(journal, root)
    if not journal then return nil end
    local steps, seen = {}, {}
    local function add(step)
        if type(step) == "table" then
            local numeric = #step > 0
            for i = 1, #step do
                if type(step[i]) ~= "number" then numeric = false end
            end
            if numeric and #step > 1 then
                local fresh = {}
                for i = 1, #step do
                    if not seen[step[i]] then
                        fresh[#fresh + 1] = step[i]
                        seen[step[i]] = true
                    end
                end
                if #fresh > 0 then steps[#steps + 1] = fresh end
                return
            end
            for i = 1, #step do add(step[i]) end
            return
        end
        if type(step) ~= "number" or seen[step] then return end
        seen[step] = true
        steps[#steps + 1] = step
    end
    local pre = journal.QuestPrereqs and journal.QuestPrereqs[root]
    local series = journal.QuestChains and journal.QuestChains[root]
    if type(pre) == "table" then
        for i = 1, #pre do add(pre[i]) end
    end
    if type(series) == "table" then
        for i = 1, #series do add(series[i]) end
    end
    add(root)
    if #steps == 0 then return nil end
    return steps
end

local function ChainEntry(journal, id)
    if SG.BiS.Quest(id) then return id end
    local row = JournalRow(journal, id)
    local start = journal.QuestChainStarts and journal.QuestChainStarts[id]
    local name, level, where, map, x, y
    if row then
        name = row[2]
        level = row[3]
        where = row[6]
        map, x, y = row[7], row[8], row[9]
    end
    if not name and journal.QuestChainNames then name = journal.QuestChainNames[id] end
    if not level and journal.QuestMinLevel then level = journal.QuestMinLevel[id] end
    if not where and journal.QuestWhere then where = journal.QuestWhere[id] end
    if not map and type(start) == "table" then
        map, x, y = start[1], start[2], start[3]
    end
    return {
        id = id,
        name = name or ("Quest " .. id),
        level = level,
        where = where,
        map = map,
        x = x,
        y = y,
        rewards = {},
    }
end

local function Attune(id, title, side, root, place)
    local journal = Namespace()
    journal = journal and journal.Journal
    local blurb = "Steps are the Dungeon Journal chain for this attunement. A quest the journal does not list is not added."
    if not journal then
        return {
            id = id,
            title = title,
            group = "Attunements",
            category = "attune",
            side = side,
            min = 1,
            max = 60,
            place = place,
            keep = true,
            blurb = blurb .. " Enable NaowhForever_DungeonJournal and reload to fill the steps.",
            segments = {
                {
                    title = title,
                    zone = place,
                    arrive = { text = "Attunement steps load from NaowhForever_DungeonJournal." },
                    extras = {
                        {
                            kind = "note",
                            optional = true,
                            pinned = true,
                            title = "Journal required",
                            text = "Enable NaowhForever_DungeonJournal, then /reload. Stratagem does not invent the chain.",
                        },
                    },
                },
            },
        }
    end
    local ids = ChainIds(journal, root) or { root }
    local quests, extras = {}, {}
    for i = 1, #ids do
        local step = ids[i]
        if type(step) == "table" then
            local names = {}
            for n = 1, #step do
                local entry = ChainEntry(journal, step[n])
                local label = type(entry) == "table" and entry.name or ("Quest " .. tostring(step[n]))
                names[#names + 1] = label
            end
            extras[#extras + 1] = {
                kind = "note",
                optional = false,
                pinned = true,
                title = "Complete one of these",
                text = "The journal lists these as alternatives. Complete one, then mark this done: " .. table.concat(names, ", ") .. ".",
            }
        else
            quests[#quests + 1] = ChainEntry(journal, step)
        end
    end
    local first = quests[1]
    local map, x, y
    if type(first) == "table" then
        map, x, y = first.map, first.x, first.y
    elseif type(first) == "number" then
        local known = SG.BiS.Quest(first)
        if known then map, x, y = known.map, known.x, known.y end
    end
    return {
        id = id,
        title = title,
        group = "Attunements",
        category = "attune",
        side = side,
        min = 1,
        max = 60,
        place = place,
        keep = true,
        blurb = blurb,
        segments = {
            {
                title = title,
                zone = place,
                arrive = {
                    text = "Follow the journal chain in order. Each quest is accept, complete, then turn in.",
                    map = map, x = x, y = y,
                },
                quests = quests,
                extras = extras,
            },
        },
    }
end

function SG.Route.Attunements()
    return {
        Attune("attune-onyxia-a", "Onyxia Attunement", "A", 6502, "Onyxia's Lair"),
        Attune("attune-onyxia-h", "Onyxia Attunement", "H", 6602, "Onyxia's Lair"),
        Attune("attune-mc", "Molten Core Attunement", "B", 7848, "Molten Core"),
    }
end
