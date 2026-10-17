-- ProfPath.lua: 1-300 steps for each profession this character has.
-- Zones come from loaded lists only: Glimmer herb and ore spots, FishingLevels,
-- and RecipeData trainers, vendors, drops, and quest givers. No route is invented.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.ProfPath = {}

local PREFIX = "prof-path-"
local sideCache
local gatherCache

local function Namespace()
    return SG.BiS and SG.BiS.ns or _G.NaowhForever or _G.NaowwahForever
end

local function Side()
    if SG.playerSide == "A" or SG.playerSide == "H" then return SG.playerSide end
    if SG.PlayerSide then
        local side = SG.PlayerSide()
        if side == "A" or side == "H" then return side end
    end
    return "H"
end

local function SpellLabel(spell)
    if type(spell) ~= "number" then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spell)
        if type(name) == "string" and name ~= "" then return name end
    end
    if GetSpellInfo then
        local name = GetSpellInfo(spell)
        if type(name) == "string" and name ~= "" then return name end
    end
    return nil
end

local function ItemLabel(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then return nil end
    if SG.ItemName then
        local name = SG.ItemName(itemID)
        if type(name) == "string" and name ~= "" then return name end
    end
    return nil
end

local function SpellKnown(spell)
    if type(spell) ~= "number" then return false end
    if IsPlayerSpell and IsPlayerSpell(spell) then return true end
    if IsSpellKnown and IsSpellKnown(spell) then return true end
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, spell)
        if ok and type(info) == "table" and info.learned then return true end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spell)
        if ok and known then return true end
    end
    return false
end

local function QuestDone(questID)
    if type(questID) ~= "number" or not SG.QuestState then return false end
    local completed = SG.QuestState(questID)
    return completed and true or false
end

local function PriceText(copper)
    if type(copper) ~= "number" or copper <= 0 then return nil end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local rest = copper % 100
    local bits = {}
    if gold > 0 then bits[#bits + 1] = gold .. "g" end
    if silver > 0 then bits[#bits + 1] = silver .. "s" end
    if rest > 0 or #bits == 0 then bits[#bits + 1] = rest .. "c" end
    return table.concat(bits, " ")
end

local function FactionOK(faction, side)
    if faction == nil or faction == "" or faction == "-" or faction == "B" or faction == "AH" then
        return true
    end
    if type(faction) ~= "string" then return true end
    return faction == side
end

local function ZoneName(map)
    if type(map) ~= "number" or not C_Map or not C_Map.GetMapInfo then return nil end
    local info = C_Map.GetMapInfo(map)
    if type(info) ~= "table" or type(info.name) ~= "string" or info.name == "" then return nil end
    local kind = info.mapType
    local cosmic = Enum and Enum.UIMapType and Enum.UIMapType.Cosmic
    local world = Enum and Enum.UIMapType and Enum.UIMapType.World
    if cosmic and kind == cosmic then return nil end
    if world and kind == world then return nil end
    return info.name
end

local function AreaName(area)
    if type(area) ~= "number" then return nil end
    if C_Map and C_Map.GetAreaInfo then
        local name = C_Map.GetAreaInfo(area)
        if type(name) == "string" and name ~= "" then return name end
    end
    return nil
end

local function ProfessionRows()
    local rows = {}
    if not GetProfessions or not GetProfessionInfo then return rows end
    local first, second, third, fourth, fifth = GetProfessions()
    local indexes = { first, second, third, fourth, fifth }
    local seen = {}
    for i = 1, #indexes do
        local index = indexes[i]
        if index then
            local name, _, skill, _, _, _, skillLine = GetProfessionInfo(index)
            if type(skillLine) == "number" and skillLine > 0 and not seen[skillLine] then
                seen[skillLine] = true
                local label = name
                if type(label) ~= "string" or label == "" then label = "Profession " .. skillLine end
                local rank = skill
                if type(rank) ~= "number" then rank = 0 end
                rows[#rows + 1] = { id = skillLine, name = label, skill = rank }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return rows
end

local function FishingLine()
    if not GetProfessions or not GetProfessionInfo then return nil end
    local _, _, _, fishing = GetProfessions()
    if not fishing then return nil end
    local _, _, _, _, _, _, skillLine = GetProfessionInfo(fishing)
    if type(skillLine) == "number" and skillLine > 0 then return skillLine end
    return nil
end

local function GatherCat(line)
    local ns = Namespace()
    local map = ns and ns.Glimmer and ns.Glimmer.C and ns.Glimmer.C.PROFESSION_OF
    if type(map) ~= "table" then return nil end
    for cat, id in pairs(map) do
        if id == line and (cat == "herb" or cat == "ore") then return cat end
    end
    return nil
end

local function DataKey()
    local ns = Namespace()
    local bits = {
        (ns and type(ns.RecipeData) == "table") and "R" or "r",
        (ns and type(ns.FishingLevels) == "table") and "F" or "f",
        (ns and type(ns.GlimmerSpots) == "table") and "G" or "g",
    }
    local rows = ProfessionRows()
    for i = 1, #rows do bits[#bits + 1] = tostring(rows[i].id) end
    return table.concat(bits, ",")
end

local function JoinList(names, limit)
    if type(names) ~= "table" or #names == 0 then return "" end
    local cap = limit or #names
    if cap > #names then cap = #names end
    if cap < 1 then return "" end
    local shown = {}
    for i = 1, cap do shown[i] = names[i] end
    local text = table.concat(shown, ", ")
    local more = #names - cap
    if more > 0 then text = text .. ", and " .. more .. " more" end
    return text
end

local function MapSides()
    if sideCache then return sideCache end
    local sides = {}
    local ns = Namespace()
    local data = ns and ns.RecipeData
    if type(data) == "table" then
        for _, prof in pairs(data) do
            local trainers = type(prof) == "table" and prof.trainers or nil
            if type(trainers) == "table" then
                for i = 1, #trainers do
                    local row = trainers[i]
                    local map = type(row) == "table" and row[4] or nil
                    local fac = type(row) == "table" and row[3] or nil
                    if type(map) == "number" then
                        local cur = sides[map]
                        if fac == "A" or fac == "H" then
                            if cur and cur ~= fac and cur ~= "B" then sides[map] = "B"
                            elseif not cur then sides[map] = fac end
                        elseif not cur then
                            sides[map] = "B"
                        end
                    end
                end
            end
        end
    end
    sideCache = sides
    return sides
end

local function ZoneRank(zone, side, sides)
    local fac = sides and sides[zone.map]
    if fac == nil or fac == "B" or fac == side then return 0 end
    return 1
end

local function SortZones(zones, side, sides)
    table.sort(zones, function(a, b)
        local ar, br = ZoneRank(a, side, sides), ZoneRank(b, side, sides)
        if ar ~= br then return ar < br end
        if (a.count or 0) ~= (b.count or 0) then return (a.count or 0) > (b.count or 0) end
        if a.name ~= b.name then return a.name < b.name end
        return (a.map or 0) < (b.map or 0)
    end)
end

local function ShortPlaces(zones)
    local cap = #zones
    if cap > 3 then cap = 3 end
    if cap < 1 then return "Zones" end
    local names = {}
    for i = 1, cap do names[i] = zones[i].name end
    return table.concat(names, " / ")
end

local function PlaceLines(zones, limit)
    local names = {}
    for i = 1, #zones do names[i] = zones[i].name end
    return JoinList(names, limit or 8)
end

local function LoadSpots()
    local ns = Namespace()
    if not ns then return nil end
    if type(ns.GlimmerSpots) == "table" then return ns.GlimmerSpots end
    local glimmer = ns.Glimmer
    if glimmer and glimmer.Spots and glimmer.Spots.Load then glimmer.Spots.Load() end
    if type(ns.GlimmerSpots) == "table" then return ns.GlimmerSpots end
    return nil
end

local function ScanGathers()
    if gatherCache ~= nil then
        if gatherCache == false then return nil end
        return gatherCache
    end
    local ns = Namespace()
    local glimmer = ns and ns.Glimmer
    local nodes = glimmer and glimmer.NODES
    local spots = LoadSpots()
    if type(nodes) ~= "table" or type(spots) ~= "table" then
        gatherCache = false
        return nil
    end
    local scale = glimmer.C and glimmer.C.SPOT_SCALE or 1000
    if type(scale) ~= "number" or scale <= 0 then scale = 1000 end
    local store = {}
    for map, list in pairs(spots) do
        if type(map) == "number" and type(list) == "table" then
            for i = 1, #list, 3 do
                local node = nodes[list[i]]
                local cat = node and node[1]
                local need = node and node[2]
                local name = node and node[3]
                if (cat == "herb" or cat == "ore") and type(need) == "number" and need >= 1 and need < 300
                    and type(name) == "string" and name ~= "" then
                    local rows = store[cat]
                    if not rows then
                        rows = {}
                        store[cat] = rows
                    end
                    local row = rows[need]
                    if not row then
                        row = { byMap = {} }
                        rows[need] = row
                    end
                    local zone = row.byMap[map]
                    if not zone then
                        zone = { count = 0, names = {} }
                        row.byMap[map] = zone
                    end
                    zone.count = zone.count + 1
                    zone.names[name] = true
                    if not zone.x then
                        local rawX, rawY = list[i + 1], list[i + 2]
                        if type(rawX) == "number" and type(rawY) == "number" then
                            local x, y = rawX / scale * 100, rawY / scale * 100
                            if x >= 0 and x <= 100 and y >= 0 and y <= 100 then
                                zone.x, zone.y = x, y
                            end
                        end
                    end
                end
            end
        end
    end
    gatherCache = store
    return store
end

local function NodeNames(row)
    local set = {}
    local byMap = row and row.byMap
    if type(byMap) == "table" then
        for _, info in pairs(byMap) do
            local names = info.names
            if type(names) == "table" then
                for name in pairs(names) do set[name] = true end
            end
        end
    end
    local list = {}
    for name in pairs(set) do list[#list + 1] = name end
    table.sort(list)
    return list
end

local function ZoneArray(row, side, sides)
    local zones = {}
    local byMap = row and row.byMap
    if type(byMap) ~= "table" then return zones end
    for map, info in pairs(byMap) do
        local name = ZoneName(map)
        if name then
            zones[#zones + 1] = {
                map = map, name = name, count = info.count or 0, x = info.x, y = info.y,
            }
        end
    end
    SortZones(zones, side, sides)
    return zones
end

local function Step(fields)
    fields.kind = "prof"
    fields.optional = false
    fields.match = "bis"
    fields.visible = true
    fields.level = fields.skillFrom or 1
    fields.baseText = fields.text
    return fields
end

local function AddGather(steps, cat, side)
    local store = ScanGathers()
    local rows = store and store[cat]
    if type(rows) ~= "table" then return end
    local skills = {}
    for need in pairs(rows) do
        if type(need) == "number" then skills[#skills + 1] = need end
    end
    if #skills == 0 then return end
    table.sort(skills)
    local sides = MapSides()
    for i = 1, #skills do
        local from = skills[i]
        local to = skills[i + 1] or 300
        if to > 300 then to = 300 end
        if from < to then
            local zones = ZoneArray(rows[from], side, sides)
            if #zones > 0 then
                local names = NodeNames(rows[from])
                local what = JoinList(names, 8)
                if what == "" then what = "the nodes on the list" end
                local pin = zones[1]
                local text = "Gather " .. what .. " from skill " .. from .. " until " .. to
                    .. ". The list places them in " .. PlaceLines(zones, 12) .. "."
                if pin.name then text = text .. " The pin is in " .. pin.name .. "." end
                local made = Step({
                    profTrack = "gather",
                    profOrder = 1,
                    skillFrom = from,
                    skillTo = to,
                    segment = ShortPlaces(zones),
                    zone = pin.name,
                    title = from .. "-" .. to,
                    text = text,
                    dropLine = JoinList(names, 4),
                    placeName = pin.name,
                })
                if type(pin.x) == "number" and type(pin.y) == "number" then
                    made.map, made.x, made.y = pin.map, pin.x, pin.y
                end
                steps[#steps + 1] = made
            end
        end
    end
end

local function AddFish(steps, side)
    local ns = Namespace()
    local levels = ns and ns.FishingLevels
    if type(levels) ~= "table" then return end
    local groups, keys = {}, {}
    for map, range in pairs(levels) do
        if type(map) == "number" and type(range) == "table" then
            local low, high = range[1], range[2]
            if type(low) == "number" and type(high) == "number" and low >= 1 and low < 300 and high > low then
                local key = low .. ":" .. high
                local bucket = groups[key]
                if not bucket then
                    bucket = { from = low, high = high, zones = {} }
                    groups[key] = bucket
                    keys[#keys + 1] = key
                end
                local name = ZoneName(map)
                if name then
                    bucket.zones[#bucket.zones + 1] = { map = map, name = name, count = 1 }
                end
            end
        end
    end
    if #keys == 0 then return end
    local sides = MapSides()
    for i = 1, #keys do
        local bucket = groups[keys[i]]
        if #bucket.zones > 0 then
            local to = bucket.high
            local past = false
            if to > 300 then
                to = 300
                past = true
            end
            if bucket.from < to then
                SortZones(bucket.zones, side, sides)
                local pin = bucket.zones[1]
                local text = "Fish from skill " .. bucket.from .. " until " .. to
                    .. ". The list says no fish gets away at " .. bucket.high
                    .. ". " .. PlaceLines(bucket.zones, 12) .. "."
                if past then text = text .. " The list goes past 300. This guide stops at 300." end
                steps[#steps + 1] = Step({
                    profTrack = "fish",
                    profOrder = 1,
                    skillFrom = bucket.from,
                    skillTo = to,
                    segment = ShortPlaces(bucket.zones),
                    zone = pin.name,
                    title = bucket.from .. "-" .. to,
                    text = text,
                    dropLine = "Fish",
                    placeName = pin.name,
                })
            end
        end
    end
end

local function NpcOK(row, side)
    if type(row) ~= "table" or not FactionOK(row[3], side) then return false end
    if type(row[4]) ~= "number" or type(row[5]) ~= "number" or type(row[6]) ~= "number" then return false end
    return ZoneName(row[4]) ~= nil
end

local function FirstNpc(rows, side)
    if type(rows) ~= "table" then return nil end
    for i = 1, #rows do
        if NpcOK(rows[i], side) then return rows[i] end
    end
    return nil
end

local function IndexedTrainer(trainers, indexes, side)
    if type(trainers) ~= "table" or type(indexes) ~= "table" then return nil end
    for i = 1, #indexes do
        local row = trainers[indexes[i]]
        if NpcOK(row, side) then return row end
    end
    return nil
end

local function RankQuest(rank, side)
    local quest = rank.quest
    if type(quest) == "number" then return quest end
    if type(quest) == "table" and type(quest[side]) == "number" then return quest[side] end
    return nil
end

local function AddRanks(steps, prof, side)
    local ranks = prof.ranks
    if type(ranks) ~= "table" then return end
    for i = 1, #ranks do
        local rank = ranks[i]
        local skill = type(rank) == "table" and rank.skill or nil
        local name = type(rank) == "table" and rank.name or nil
        if type(skill) == "number" and skill >= 1 and skill < 300 and type(name) == "string" and name ~= "" then
            local npc, how
            if type(rank.teachers) == "table" then
                npc = FirstNpc(rank.teachers, side)
                how = "teacher"
            end
            if not npc and type(rank.vendors) == "table" then
                npc = FirstNpc(rank.vendors, side)
                how = "vendor"
            end
            if not npc then
                npc = IndexedTrainer(prof.trainers, rank.t, side) or FirstNpc(prof.trainers, side)
                how = "trainer"
            end
            local zone = npc and ZoneName(npc[4]) or nil
            local who = npc and npc[2] or nil
            local verb = "Train "
            if how == "vendor" then verb = "Buy " end
            local text = verb .. name .. "."
            local questName = rank.questName
            if type(questName) == "string" and questName ~= "" then
                text = text .. " The list names the quest " .. questName .. "."
            end
            local price = PriceText(rank.cost) or (npc and PriceText(npc[7]))
            if price then text = text .. " The list prices it at " .. price .. "." end
            if type(who) == "string" and who ~= "" and zone then
                text = text .. " " .. who .. " is in " .. zone .. ". The pin is one place the list names."
            elseif zone then
                text = text .. " The list places this in " .. zone .. "."
            else
                text = text .. " The list does not name where."
            end
            local made = Step({
                profRank = true,
                profOrder = 0,
                skillFrom = skill,
                skillTo = skill,
                spell = rank.spell,
                profQuest = RankQuest(rank, side),
                segment = zone or "Train",
                zone = zone or "Train",
                title = name,
                text = text,
                dropLine = how == "vendor" and "Buy the rank" or "Train",
                placeName = zone,
            })
            if npc and zone then made.map, made.x, made.y = npc[4], npc[5], npc[6] end
            steps[#steps + 1] = made
        end
    end
end

local function Edges(ranks)
    local edges = { 1 }
    local seen = { [1] = true }
    if type(ranks) == "table" then
        for i = 1, #ranks do
            local skill = ranks[i].skill
            if type(skill) == "number" and skill > 1 and skill < 300 and not seen[skill] then
                seen[skill] = true
                edges[#edges + 1] = skill
            end
        end
    end
    if not seen[300] then edges[#edges + 1] = 300 end
    table.sort(edges)
    return edges
end

local function Bracket(edges, skill)
    for i = 1, #edges - 1 do
        if skill >= edges[i] and skill < edges[i + 1] then return edges[i], edges[i + 1] end
    end
    return 1, 300
end

local function TrainerHits(trainers, indexes, side)
    local hits, seen = {}, {}
    if type(trainers) ~= "table" or type(indexes) ~= "table" then return hits end
    for i = 1, #indexes do
        local row = trainers[indexes[i]]
        if NpcOK(row, side) and not seen[row[4]] then
            seen[row[4]] = true
            hits[#hits + 1] = row
        end
    end
    return hits
end

local function DropPlace(recipe)
    local bosses = recipe.bosses
    if type(bosses) ~= "table" or type(bosses[1]) ~= "table" then return nil end
    local place = AreaName(bosses[1][2])
    if not place then return nil end
    return nil, nil, nil, place, "drop", false
end

local function QuestPlace(recipe, side)
    local quests = recipe.quests
    if type(quests) ~= "table" then return nil end
    local pick
    for i = 1, #quests do
        local quest = quests[i]
        if type(quest) == "table" then
            local qside = quest.side
            if qside == side or qside == "B" or qside == nil or qside == "-" then
                if not pick or qside == side then pick = quest end
            end
        end
    end
    if not pick or not NpcOK(pick.npc, side) then return nil end
    local npc = pick.npc
    return npc[4], npc[5], npc[6], ZoneName(npc[4]), "quest", false
end

local function TrainerSpot(prof, recipe, side, pinned)
    local hits = TrainerHits(prof.trainers, recipe.t, side)
    if #hits == 1 then
        local npc = hits[1]
        return npc[4], npc[5], npc[6], ZoneName(npc[4]), "trainer", false
    end
    if not pinned then return nil end
    local zone = ZoneName(pinned[4])
    if not zone then return nil end
    return pinned[4], pinned[5], pinned[6], zone, "trainer", true
end

local function RecipePlace(recipe, prof, side, pinned)
    if type(recipe) ~= "table" then return nil end
    if recipe.source == "vendor" then
        local npc = FirstNpc(recipe.vendors, side)
        if not npc then return nil end
        return npc[4], npc[5], npc[6], ZoneName(npc[4]), "vendor", false
    end
    if recipe.source == "drop" then return DropPlace(recipe) end
    if recipe.source == "quest" then return QuestPlace(recipe, side) end
    if recipe.source == "trainer" then return TrainerSpot(prof, recipe, side, pinned) end
    return nil
end

local function CraftVerb(tag)
    if tag == "vendor" then return "Buy and craft the recipes sold" end
    if tag == "drop" then return "Craft the recipes that drop" end
    if tag == "quest" then return "Craft the recipes from a quest" end
    return "Craft the trainer recipes"
end

local function CraftOrder(tag)
    if tag == "vendor" then return 3 end
    if tag == "drop" or tag == "quest" then return 4 end
    return 2
end

local function AddCraft(steps, prof, side)
    local recipes = prof.recipes
    if type(recipes) ~= "table" then return end
    local edges = Edges(prof.ranks)
    local pinned = FirstNpc(prof.trainers, side)
    local groups, order = {}, {}
    for i = 1, #recipes do
        local recipe = recipes[i]
        local skill = type(recipe) == "table" and recipe.skill or nil
        if type(skill) == "number" and skill >= 1 and skill < 300 then
            local map, x, y, zone, tag, wide = RecipePlace(recipe, prof, side, pinned)
            if zone and tag then
                local from, to = Bracket(edges, skill)
                local key = from .. ":" .. to .. ":" .. tag .. ":" .. tostring(map or 0) .. ":" .. zone
                local group = groups[key]
                if not group then
                    group = {
                        from = from, to = to, map = map, x = x, y = y, zone = zone,
                        tag = tag, wide = wide and true or false, names = {}, count = 0,
                    }
                    groups[key] = group
                    order[#order + 1] = group
                elseif wide then
                    group.wide = true
                end
                group.count = group.count + 1
                if #group.names < 8 then
                    local label = SpellLabel(recipe.spell) or ItemLabel(recipe.item)
                    if type(label) == "string" and label ~= "" then
                        group.names[#group.names + 1] = label
                    end
                end
            end
        end
    end
    for i = 1, #order do
        local group = order[i]
        table.sort(group.names)
        local text = CraftVerb(group.tag) .. " in " .. group.zone
            .. " from skill " .. group.from .. " until " .. group.to .. "."
        local named = JoinList(group.names, 8)
        if named ~= "" then
            text = text .. " " .. named .. "."
            if group.count > #group.names then
                text = text .. " The list has " .. (group.count - #group.names) .. " more in this range."
            end
        else
            text = text .. " The list has " .. group.count .. " in this range. The client has not named them yet."
        end
        if group.wide then
            text = text .. " The pin is one trainer for your faction."
        end
        local line = "Trainer"
        if group.tag == "vendor" then line = "Vendor"
        elseif group.tag == "drop" then line = "Drop"
        elseif group.tag == "quest" then line = "Quest" end
        local made = Step({
            profTrack = "craft",
            profOrder = CraftOrder(group.tag),
            skillFrom = group.from,
            skillTo = group.to,
            segment = group.zone,
            zone = group.zone,
            title = group.from .. "-" .. group.to,
            text = text,
            dropLine = line,
            placeName = group.zone,
        })
        if type(group.map) == "number" and type(group.x) == "number" and type(group.y) == "number" then
            made.map, made.x, made.y = group.map, group.x, group.y
        end
        steps[#steps + 1] = made
    end
end

local function Note(name)
    local text = "Nothing on the loaded list names a zone for " .. name
        .. ". Herb and ore spots and fishing waters load with NaowhForever_QoL."
        .. " Trainers and recipes load with NaowhForever_Professions."
    return {
        kind = "note",
        profNote = true,
        optional = false,
        match = "bis",
        visible = true,
        segment = name,
        zone = name,
        level = 1,
        skillFrom = 0,
        skillTo = 0,
        title = "No zone on the list",
        text = text,
        baseText = text,
    }
end

local function Before(a, b)
    if a.profNote ~= b.profNote then return not a.profNote end
    local af, bf = a.skillFrom or 0, b.skillFrom or 0
    if af ~= bf then return af < bf end
    local ao, bo = a.profOrder or 9, b.profOrder or 9
    if ao ~= bo then return ao < bo end
    local at, bt = a.skillTo or 0, b.skillTo or 0
    if at ~= bt then return at > bt end
    local aseg, bseg = a.segment or "", b.segment or ""
    if aseg ~= bseg then return aseg < bseg end
    return (a.title or "") < (b.title or "")
end

local function Blank(row)
    return {
        id = PREFIX .. row.id,
        title = row.name .. " 1-300",
        group = "Professions",
        category = "professions",
        side = Side(),
        place = row.name,
        blurb = "Where to take " .. row.name .. " from 1 to 300. Each step is a skill range and the zones the loaded list names for it. Earlier ranges are marked done once your skill moves on.",
        min = 1,
        max = 60,
        steps = {},
        hiddenQuests = 0,
        questCount = 0,
        visibleQuests = 0,
        empty = false,
        route = false,
        profPath = true,
        profLine = row.id,
        profSkill = row.skill or 0,
    }
end

local function BuildOne(row, fishLine)
    local steps = {}
    local cat = GatherCat(row.id)
    local ns = Namespace()
    local data = ns and ns.RecipeData
    local prof = (type(data) == "table") and data[row.id] or nil
    local side = Side()
    if cat then AddGather(steps, cat, side) end
    if fishLine and row.id == fishLine then AddFish(steps, side) end
    if type(prof) == "table" then
        AddRanks(steps, prof, side)
        AddCraft(steps, prof, side)
    end
    if #steps == 0 then steps[1] = Note(row.name) end
    table.sort(steps, Before)
    local guide = Blank(row)
    for i = 1, #steps do
        steps[i].index = i
        steps[i].guide = guide.id
    end
    guide.steps = steps
    guide.questCount = #steps
    guide.visibleQuests = #steps
    return guide
end

local function LiveSkill(line)
    local rows = ProfessionRows()
    for i = 1, #rows do
        if rows[i].id == line then return rows[i].skill or 0 end
    end
    return 0
end

local function IsPath(id)
    return type(id) == "string" and id:sub(1, #PREFIX) == PREFIX
end

function SG.ProfPath.Apply(guide)
    if not guide or not guide.profPath or not guide.steps then return end
    local skill = LiveSkill(guide.profLine)
    guide.profSkill = skill
    local row
    if SG.Engine and SG.Engine.Progress then row = SG.Engine.Progress(guide.id) end
    local best = {}
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        local track = step.profTrack
        local from = step.skillFrom or 0
        if track and not step.profNote and from <= skill and (best[track] == nil or from > best[track]) then
            best[track] = from
        end
    end
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.profNote then
            step.visible = true
        else
            step.visible = true
            local passed
            if step.profRank then
                passed = SpellKnown(step.spell) or QuestDone(step.profQuest)
            else
                local track = step.profTrack
                local from = step.skillFrom or 0
                local higher = track and best[track] ~= nil and best[track] > from
                passed = skill >= 300 or skill >= (step.skillTo or 301) or higher
            end
            if passed and row and row.hold ~= i then row.done[i] = true end
        end
    end
end

function SG.ProfPath.Current(guide)
    if not guide or not guide.profPath or not guide.steps then return nil end
    local skill = guide.profSkill or 0
    local rankAt, workAt, workFrom, craftAt, craftFrom
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.visible and not step.profNote and not SG.Engine.IsDone(guide, i) then
            local from = step.skillFrom or 0
            if from <= skill then
                if step.profRank then
                    if not rankAt then rankAt = i end
                elseif step.profTrack == "craft" then
                    if not craftAt or from > craftFrom then craftAt, craftFrom = i, from end
                elseif not workAt or from > workFrom then
                    workAt, workFrom = i, from
                end
            end
        end
    end
    return rankAt or workAt or craftAt
end

local function BuildAll()
    local rows = ProfessionRows()
    local fishLine = FishingLine()
    local built = {}
    for i = 1, #rows do built[i] = BuildOne(rows[i], fishLine) end
    return built
end

function SG.ProfPath.Install(quiet)
    if not SG.Engine or not SG.Engine.guides or not SG.Engine.byId then return end
    sideCache = nil
    gatherCache = nil
    local built = BuildAll()
    local list = SG.Engine.guides
    local i = 1
    while i <= #list do
        if IsPath(list[i].id) then
            SG.Engine.byId[list[i].id] = nil
            table.remove(list, i)
        else
            i = i + 1
        end
    end
    local at = #list + 1
    for n = 1, #list do
        if list[n].category == "professions" then
            at = n
            break
        end
    end
    for n = 1, #built do
        local guide = built[n]
        table.insert(list, at, guide)
        SG.Engine.byId[guide.id] = guide
        at = at + 1
        if SG.Engine.AlignProgress then SG.Engine.AlignProgress(guide) end
        SG.ProfPath.Apply(guide)
    end
    SG.ProfPath.key = DataKey()
    if quiet then return end
    local active = SG.Engine.Active and SG.Engine.Active()
    if active and active.profPath and SG.Engine.PlaceCursor then
        active = SG.Engine.Get(active.id) or active
        SG.Engine.PlaceCursor(active)
    end
    if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
end

function SG.ProfPath.Refresh()
    if not SG.Engine then return end
    LoadSpots()
    if SG.ProfPath.key ~= DataKey() then
        SG.ProfPath.Install()
        return
    end
    local list = SG.Engine.guides or {}
    for i = 1, #list do
        if list[i].profPath then SG.ProfPath.Apply(list[i]) end
    end
    local active = SG.Engine.Active and SG.Engine.Active()
    if active and active.profPath and SG.Engine.PlaceCursor then
        active = SG.Engine.Get(active.id) or active
        SG.Engine.PlaceCursor(active)
    end
    if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
end

function SG.ProfPath.Prepare(id)
    if not SG.Engine then return end
    LoadSpots()
    if SG.ProfPath.key ~= DataKey() then SG.ProfPath.Install(true) end
    local guide = SG.Engine.Get(id)
    if guide and guide.profPath then SG.ProfPath.Apply(guide) end
end
