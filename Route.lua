-- Route.lua: one leveling route per faction, plus Level 60 BiS and attunements.
-- Quest ids, bosses, and drop chances come from the loaded catalog and the
-- Naowh journal. Nothing here invents a quest, an item, a boss, or a percent.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Route = SG.Route or {}

-- Stay in a zone long enough to finish the quests that opened with this visit,
-- then leave when another zone's quest is the next one by level.
local BAND = 3

-- Race ids: human 1, orc 2, dwarf 3, night elf 4, undead 5, tauren 6, gnome 7, troll 8.
-- Humans have no starter writeup in this addon, so their route begins at the first catalog quest.
local STARTER = {
    H = { [6] = "h-mulgore", [2] = "h-durotar", [8] = "h-durotar", [5] = "h-tirisfal" },
    A = { [4] = "a-teldrassil", [3] = "a-dunmorogh", [7] = "a-dunmorogh" },
}

local ROUTE_BLURB = "One route for your faction. It follows your level and sends you to the zone whose next quest is the better piece. The ride is not treated as a cost, so the route leaves a zone and comes back when a later quest there is the next upgrade. The steps are the starting-zone path plus the BiS quests in the loaded catalog. The bundled catalog ends in the mid 30s, so this is not every quest in a zone. A line marked (Optional) is a dungeon farm or a gear quest that was not on the written route. Mark it done to skip it."

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
    if a.gear ~= b.gear then return a.gear < b.gear end
    return a.order < b.order
end

local function UnitsFrom(def, seq)
    local units = {}
    local segments = def.segments or {}
    for s = 1, #segments do
        local segment = segments[s]
        local key = segment.title
        local function push(level, gear, plain, questId, dungeon)
            seq = seq + 1
            units[#units + 1] = {
                level = level or 1,
                gear = gear or 99,
                key = key,
                zone = segment.zone or key,
                arrive = segment.arrive,
                plain = plain,
                questId = questId,
                dungeon = dungeon,
                order = seq,
            }
        end
        local plain = segment.plain or {}
        for p = 1, #plain do
            local quest = plain[p]
            push(quest.level, 99, quest, nil, nil)
        end
        local quests = segment.quests or {}
        for q = 1, #quests do
            local id = quests[q]
            if type(id) == "number" then
                local quest = SG.BiS.Quest(id)
                if quest then
                    push(quest.level, ClassGear(quest), nil, id, quest.dungeon)
                end
            end
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

local function Visit(batch, seen)
    local first = batch[1]
    local key = first.key
    local dungeon
    for i = 1, #batch do
        if batch[i].dungeon and batch[i].dungeon == key then dungeon = key end
    end
    local plain, quests = {}, {}
    for i = 1, #batch do
        local unit = batch[i]
        if unit.plain then
            plain[#plain + 1] = unit.plain
        elseif unit.questId then
            quests[#quests + 1] = unit.questId
        end
    end
    local arrive = first.arrive
    local text = (arrive and arrive.text) or ("Continue in " .. key .. ".")
    if seen[key] then
        text = "Return to " .. key .. " for the quests at this level. " .. text
    end
    return {
        title = key,
        travel = key,
        zone = first.zone or key,
        dungeon = dungeon,
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

function SG.Route.Leveling(side)
    local race = SG.raceID
    local starterId = STARTER[side] and STARTER[side][race]
    local starter = starterId and FindGuide(starterId)
    if starter and starter.side ~= side then starter = nil end
    local pool = {}
    local seq = 0
    local data = SG.GuideData or {}
    for i = 1, #data do
        local def = data[i]
        if def.weave and def.side == side and def.id ~= starterId then
            local units
            units, seq = UnitsFrom(def, seq)
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
    local unused = {}
    for i = 1, #pool do unused[i] = pool[i] end
    local seen = {}
    while true do
        local anchor
        for i = 1, #unused do
            local unit = unused[i]
            if unit and (not anchor or Better(unit, anchor)) then anchor = unit end
        end
        if not anchor then break end
        local cap = anchor.level + BAND
        local batch = {}
        for i = 1, #unused do
            local unit = unused[i]
            if unit and unit.key == anchor.key and unit.level <= cap then
                batch[#batch + 1] = unit
                unused[i] = false
            end
        end
        table.sort(batch, function(a, b) return a.order < b.order end)
        segments[#segments + 1] = Visit(batch, seen)
        seen[anchor.key] = true
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
    local specs = SG.Specs and SG.Specs.ForClass(SG.classToken)
    local items = SG.BiS and SG.BiS.items
    if not specs or not items then
        missing.text = "(Optional) Run " .. dungeonName .. " until a drop upgrades a slot. No spec ranking is loaded for your class, so the boss and the percent are not listed. Mark this done to skip it."
        return { missing }
    end
    local specSet = {}
    for i = 1, #specs do specSet[specs[i].key] = true end
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
                            local bucket = items[itemID]
                            if bucket then
                                local rank, slot
                                for key, row in pairs(bucket) do
                                    if specSet[key] and row.rank and (not rank or row.rank < rank) then
                                        rank = row.rank
                                        slot = row.slot
                                    end
                                end
                                if rank and slot then
                                    local trash = boss.trash and true or false
                                    local chance = 0
                                    if not trash and type(boss.chance) == "table" and boss.chance[i] then
                                        chance = boss.chance[i]
                                    end
                                    local prev = best[slot]
                                    if not prev or rank < prev.rank or (rank == prev.rank and chance > prev.chance) then
                                        best[slot] = {
                                            itemID = itemID,
                                            rank = rank,
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
    end
    local slots = {}
    for slot in pairs(best) do slots[#slots + 1] = slot end
    table.sort(slots)
    if #slots == 0 then
        missing.text = "(Optional) Run " .. dungeonName .. " until a drop upgrades a slot. The journal lists no ranked piece for your class in this dungeon. Mark this done to skip it."
        return { missing }
    end
    local steps = {}
    for i = 1, #slots do
        local row = best[slots[i]]
        local name = ItemName(row.itemID)
        local slotName = (SG.SLOT_NAME and SG.SLOT_NAME[row.slot]) or "slot"
        local drop = { boss = row.boss, chance = row.chance, trash = row.trash, dungeon = dungeonName }
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
            title = "(Optional) " .. slotName .. ": " .. name,
            text = string.format(
                "(Optional) Run %s until %s drops from %s (%s). Mark this done to skip it.",
                dungeonName, name, row.boss, ChanceText(drop)
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
                step.title = "(Optional) " .. slotName .. ": " .. name
                step.text = string.format(
                    "(Optional) Run %s until %s drops from %s (%s). Mark this done to skip it.",
                    place, name, boss, ChanceText(drop)
                )
                step.baseText = step.text
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
