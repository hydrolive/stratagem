-- Collectibles.lua: mounts, pets, and toys the character has not collected.
-- Names, places, vendors, quests, and drop chances come from QuestieDB, the
-- dungeon journal, or the client mount, pet, and toy journals. A missing
-- source stays missing. Nothing in this file invents a zone, a vendor, a
-- quest, a drop rate, or a collection process.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Collectibles = {}

local GUIDE_ID = "collect-all"
local maps

local PREFIX = {
    vendor = "Vendor",
    drop = "Drop",
    quest = "Quest",
    reputation = "Vendor",
    world = "Drop",
}

local function Call(fn, id)
    if type(fn) ~= "function" or type(id) ~= "number" then return nil end
    local ok, value = pcall(fn, id)
    if not ok then return nil end
    return value
end

local function Side()
    if SG.playerSide == "A" or SG.playerSide == "H" then return SG.playerSide end
    if SG.PlayerSide then
        local side = SG.PlayerSide()
        if side == "A" or side == "H" then return side end
    end
    return "H"
end

local function Journal()
    local ns = _G.NaowhForever or _G.NaowwahForever
    return ns and ns.Journal
end

local function MiscClass()
    local n = _G.LE_ITEM_CLASS_MISCELLANEOUS
    if type(n) == "number" then return n end
    return 15
end

local function PetSub()
    local n = _G.LE_ITEM_MISCELLANEOUS_COMPANION_PET
    if type(n) == "number" then return n end
    return 2
end

local function MountSub()
    local n = _G.LE_ITEM_MISCELLANEOUS_MOUNT
    if type(n) == "number" then return n end
    return 5
end

local function ItemName(itemID)
    local db = _G.ItemDB
    if not db or not db.name then return nil end
    local name = Call(db.name, itemID)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

local function NpcName(npcID)
    local db = _G.NpcDB
    if not db or not db.name then return nil end
    local name = Call(db.name, npcID)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

local function QuestName(questID)
    local db = _G.QuestDB
    if not db or not db.name then return nil end
    local name = Call(db.name, questID)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

local function ObjectName(objectID)
    local db = _G.ObjectDB
    if not db or not db.name then return nil end
    local name = Call(db.name, objectID)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

local function AreaName(area)
    if type(area) ~= "number" or not C_Map or not C_Map.GetAreaInfo then return nil end
    local ok, name = pcall(C_Map.GetAreaInfo, area)
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end

local function MapTitle(map)
    if type(map) ~= "number" or not C_Map or not C_Map.GetMapInfo then return nil end
    local info = C_Map.GetMapInfo(map)
    if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
        return info.name
    end
    return nil
end

local function Percent(chance)
    local text = string.format("%.1f", chance)
    if text == "0.0" then text = string.format("%.2f", chance) end
    if text:sub(-2) == ".0" then text = text:sub(1, -3) end
    return text
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

local function StandingLabel(reaction)
    if type(reaction) ~= "number" then return nil end
    local journal = Journal()
    local rep = journal and journal.Reputation
    if rep and rep.Label then
        local ok, label = pcall(rep.Label, reaction)
        if ok and type(label) == "string" and label ~= "" then return label end
    end
    if GetText then
        local sex = UnitSex and UnitSex("player") or nil
        local ok, label = pcall(GetText, "FACTION_STANDING_LABEL" .. reaction, sex)
        if ok and type(label) == "string" and label ~= "" then return label end
    end
    return nil
end

local function LoadMapTable(value)
    if type(value) == "table" then return value end
    if type(value) ~= "string" or value == "" or not loadstring then return nil end
    local fn = loadstring(value)
    if type(fn) ~= "function" then return nil end
    local ran, parsed = pcall(fn)
    if ran and type(parsed) == "table" then return parsed end
    return nil
end

local function UiMap(area)
    if type(area) ~= "number" then return nil end
    if maps == nil then
        maps = false
        local lib = _G.LibQuestieDB
        local support = lib and lib.Support
        local get = support and support.Get
        if get then
            local ok, zone = pcall(get, "ZoneDB")
            local private = ok and type(zone) == "table" and zone.private or nil
            if type(private) == "table" then
                local base = LoadMapTable(private.areaIdToUiMapId)
                local over = LoadMapTable(private.areaIdToUiMapIdOverride)
                if type(base) == "table" or type(over) == "table" then
                    maps = { base = base, over = over }
                end
            end
        end
    end
    if type(maps) ~= "table" then return nil end
    local id = maps.over and maps.over[area]
    if type(id) ~= "number" then id = maps.base and maps.base[area] end
    if type(id) ~= "number" or id <= 0 then return nil end
    return id
end

local function DropHidden(npcID, side)
    local db = _G.NpcDB
    if not db or not db.friendlyToFaction then return false end
    local fac = Call(db.friendlyToFaction, npcID)
    if type(fac) ~= "string" or fac == "" then return false end
    return string.find(fac, side, 1, true) ~= nil
end

local function VendorOk(npcID, side)
    local db = _G.NpcDB
    if not db or not db.friendlyToFaction then return true end
    local fac = Call(db.friendlyToFaction, npcID)
    if type(fac) ~= "string" or fac == "" or fac == "AH" or fac == "B" or fac == "-" then
        return true
    end
    return fac == side
end

local function FirstSpot(list, area)
    if type(list) ~= "table" then return nil end
    local function take(key, spots)
        if type(key) ~= "number" or type(spots) ~= "table" then return nil end
        local spot = spots[1]
        if type(spot) ~= "table" then return nil end
        local x, y = spot[1], spot[2]
        if type(x) ~= "number" or type(y) ~= "number" then return nil end
        if x < 0 or x > 100 or y < 0 or y > 100 then return nil end
        return key, x, y
    end
    local got, x, y = take(area, area and list[area] or nil)
    if x then return got, x, y end
    for key, spots in pairs(list) do
        got, x, y = take(key, spots)
        if x then return got, x, y end
    end
    return nil
end

local function NpcPin(npcID)
    local db = _G.NpcDB
    if not db or not db.spawns then return nil end
    local list = Call(db.spawns, npcID)
    local area = db.zoneID and Call(db.zoneID, npcID) or nil
    local got, x, y = FirstSpot(list, area)
    if not x then return nil end
    return AreaName(got), UiMap(got), x, y
end

local function Prefix(source)
    if type(source) ~= "string" then return nil end
    local head = source:match("^(%a+)%s*:")
    if not head then return nil end
    return PREFIX[head:lower()] or head
end

local function Header(step)
    local kind = step.kindName or "Collectible"
    local place = step.place
    local method = step.method
    local named = type(place) == "string" and place ~= ""
    local how = type(method) == "string" and method ~= ""
    if named and how then return kind .. " - " .. place .. " - " .. method end
    if how then return kind .. " - " .. method end
    if named then return kind .. " - " .. place end
    return kind
end

local function Append(step, extra)
    if type(extra) ~= "string" or extra == "" then return end
    local text = step.text or ""
    if text ~= "" and string.find(text, extra, 1, true) then return end
    if text == "" then
        step.text = extra
    else
        step.text = text .. " " .. extra
    end
end

local function OtherFaction(specific, faction)
    if specific ~= true then return false end
    local groups = _G.PLAYER_FACTION_GROUP
    if type(groups) ~= "table" then return false end
    local named = groups[faction]
    if type(named) ~= "string" or named == "" then return false end
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    if type(mine) ~= "string" then return false end
    return named ~= mine
end

local function AddRecord(steps, itemID, kindName, kindOrder, source, spell, icon, collected)
    local step = {
        kind = "collect",
        optional = false,
        match = "bis",
        visible = true,
        kindName = kindName,
        kindOrder = kindOrder,
        level = 1,
        title = source.title or kindName,
        text = source.text or "",
        method = source.method,
        place = source.place,
        placeName = source.place,
        zone = source.place,
        dropLine = source.line,
        spell = spell,
        icon = icon,
        collected = collected and true or false,
    }
    if type(source.map) == "number" and type(source.x) == "number" and type(source.y) == "number" then
        step.map, step.x, step.y = source.map, source.x, source.y
    end
    if type(itemID) == "number" and itemID > 0 then
        step.itemID = itemID
        step.rewards = { itemID }
    end
    step.segment = Header(step)
    steps[#steps + 1] = step
    return step
end

local function RepMap()
    local map = {}
    local journal = Journal()
    if not journal or not journal.Factions then return map end
    local ok, list = pcall(journal.Factions, "reputation")
    if not ok or type(list) ~= "table" then return map end
    local side = Side()
    for i = 1, #list do
        local faction = list[i]
        if type(faction) == "table" and not faction.unreleased then
            local code = "B"
            if faction.side == "Alliance" then code = "A" end
            if faction.side == "Horde" then code = "H" end
            if code == "B" or code == side then
                local who, pinMap, x, y
                local qm = faction.quartermaster
                if type(qm) == "table" then
                    if type(qm.name) == "string" and qm.name ~= "" then who = qm.name end
                    if type(qm.map) == "number" and type(qm.x) == "number" and type(qm.y) == "number" then
                        pinMap, x, y = qm.map, qm.x, qm.y
                    end
                end
                local place = MapTitle(pinMap)
                if not place and type(faction.zone) == "string" and faction.zone ~= "" then
                    place = faction.zone
                end
                local fname = faction.name
                local tiers = faction.tiers
                if type(fname) == "string" and fname ~= "" and type(tiers) == "table" then
                    for t = 1, #tiers do
                        local tier = tiers[t]
                        local items = tier and tier.items
                        local standing = tier and tier.standing
                        if type(items) == "table" and type(standing) == "number" then
                            for n = 1, #items do
                                local itemID = items[n]
                                local prev = type(itemID) == "number" and map[itemID] or nil
                                if type(itemID) == "number" and itemID > 0 and (not prev or standing < prev.standing) then
                                    local price
                                    local prices = faction.prices
                                    if type(prices) == "table" and type(prices[itemID]) == "number" and prices[itemID] > 0 then
                                        price = prices[itemID]
                                    end
                                    map[itemID] = {
                                        faction = fname,
                                        standing = standing,
                                        who = who,
                                        map = pinMap,
                                        x = x,
                                        y = y,
                                        place = place,
                                        price = price,
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return map
end

local function RepSource(itemID, rep, title)
    local row = rep and rep[itemID]
    if type(row) ~= "table" then return nil end
    local who = row.who or "the quartermaster"
    local stand = StandingLabel(row.standing) or ("standing " .. row.standing)
    local bits = {}
    if row.place then
        bits[#bits + 1] = string.format("Buy %s from %s in %s.", title, who, row.place)
    else
        bits[#bits + 1] = string.format("Buy %s from %s.", title, who)
    end
    bits[#bits + 1] = stand .. " with " .. row.faction .. " is required."
    local cost = PriceText(row.price)
    if cost then bits[#bits + 1] = "The journal price is " .. cost .. "." end
    local line = who
    if row.place then line = who .. " · " .. row.place end
    return {
        method = "Vendor",
        place = row.place,
        map = row.map,
        x = row.x,
        y = row.y,
        text = table.concat(bits, " "),
        line = line,
        title = title,
    }
end

local function EachId(list, fn)
    if type(list) ~= "table" then return end
    if #list > 0 then
        for i = 1, #list do fn(list[i]) end
        return
    end
    for _, id in pairs(list) do fn(id) end
end

local function VendorSource(itemID, title)
    local db = _G.ItemDB
    if not db or not db.vendors then return nil end
    local list = Call(db.vendors, itemID)
    if type(list) ~= "table" then return nil end
    local side = Side()
    local picked, count = nil, 0
    EachId(list, function(id)
        if type(id) == "number" and VendorOk(id, side) then
            count = count + 1
            if not picked then picked = id end
        end
    end)
    if not picked then return nil end
    local who = NpcName(picked) or ("npc " .. picked)
    local place, map, x, y = NpcPin(picked)
    local bits = {}
    if place then
        bits[#bits + 1] = string.format("Buy %s from %s in %s.", title, who, place)
    else
        bits[#bits + 1] = string.format("Buy %s from %s.", title, who)
    end
    if x and y then
        bits[#bits + 1] = string.format("The list places that seller near %.1f, %.1f.", x, y)
    end
    if count > 1 then
        bits[#bits + 1] = "The list names " .. count .. " sellers."
    end
    return {
        method = "Vendor",
        place = place,
        map = map,
        x = map and x or nil,
        y = map and y or nil,
        text = table.concat(bits, " "),
        line = who,
        title = title,
    }
end

local function RepNeed(questID)
    local db = _G.QuestDB
    if not db or not db.requiredMinRep then return nil end
    local pair = Call(db.requiredMinRep, questID)
    if type(pair) ~= "table" or type(pair[1]) ~= "number" then return nil end
    local name
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, data = pcall(C_Reputation.GetFactionDataByID, pair[1])
        if ok and type(data) == "table" and type(data.name) == "string" and data.name ~= "" then
            name = data.name
        end
    end
    if not name then return nil end
    local value = pair[2]
    if type(value) == "number" and value >= 1 and value <= 8 then
        local stand = StandingLabel(value)
        if stand then return stand .. " with " .. name .. " is required." end
    end
    return "It requires reputation with " .. name .. "."
end

local function QuestSource(itemID, title)
    local db = _G.ItemDB
    if not db or not db.questRewards then return nil end
    local list = Call(db.questRewards, itemID)
    if type(list) ~= "table" then return nil end
    local questID
    EachId(list, function(id)
        if not questID and type(id) == "number" then questID = id end
    end)
    if not questID then return nil end
    local qname = QuestName(questID) or ("quest " .. questID)
    local bits = { string.format("%s is a reward from %s.", title, qname) }
    local qdb = _G.QuestDB
    if qdb and qdb.objectivesText then
        local lines = Call(qdb.objectivesText, questID)
        if type(lines) == "table" then
            local shown, extra = 0, 0
            for i = 1, #lines do
                local line = lines[i]
                if type(line) == "string" and line ~= "" then
                    if shown < 8 then
                        bits[#bits + 1] = line
                        shown = shown + 1
                    else
                        extra = extra + 1
                    end
                end
            end
            if extra > 0 then
                bits[#bits + 1] = "The quest lists " .. extra .. " more lines."
            end
        end
    end
    local need = RepNeed(questID)
    if need then bits[#bits + 1] = need end
    local place
    if qdb and qdb.zoneOrSort then
        local zone = Call(qdb.zoneOrSort, questID)
        if type(zone) == "number" and zone > 0 then place = AreaName(zone) end
    end
    if place then bits[#bits + 1] = "The quest list places it in " .. place .. "." end
    return {
        method = "Quest",
        place = place,
        text = table.concat(bits, " "),
        line = qname,
        title = title,
    }
end

local function BestPercent(itemID, side)
    if not SG.Gear or not SG.Gear.DropTable then return nil end
    local book = SG.Gear.DropTable()
    local row = type(book) == "table" and book[itemID] or nil
    if type(row) ~= "table" then return nil end
    local bestId, bestChance, extra = nil, nil, 0
    for npcID, chance in pairs(row) do
        if type(npcID) == "number" and type(chance) == "number" and chance > 0 and not DropHidden(npcID, side) then
            extra = extra + 1
            if not bestChance or chance > bestChance or (chance == bestChance and npcID < bestId) then
                bestChance = chance
                bestId = npcID
            end
        end
    end
    if not bestId then return nil end
    return bestId, bestChance, extra - 1
end

local function DropSource(itemID, title)
    local side = Side()
    local npcID, chance, extra = BestPercent(itemID, side)
    if npcID and chance then
        local who = NpcName(npcID) or ("npc " .. npcID)
        local place, map, x, y = NpcPin(npcID)
        local kills = math.ceil(100 / chance)
        local bits = {
            string.format("The drop list names %s at %s%% (about %d kills).", who, Percent(chance), kills),
        }
        if place then bits[#bits + 1] = "That is in " .. place .. "." end
        if x and y then
            bits[#bits + 1] = string.format("The list places that near %.1f, %.1f.", x, y)
        end
        if extra and extra > 0 then
            bits[#bits + 1] = "The drop list names " .. extra .. " more."
        end
        return {
            method = "Drop",
            place = place,
            map = map,
            x = map and x or nil,
            y = map and y or nil,
            text = table.concat(bits, " "),
            line = who .. " " .. Percent(chance) .. "%",
            title = title,
        }
    end
    local db = _G.ItemDB
    if not db or not db.npcDrops then return nil end
    local list = Call(db.npcDrops, itemID)
    if type(list) ~= "table" then return nil end
    local names, hidden, total, first = {}, 0, 0, nil
    EachId(list, function(id)
        if type(id) ~= "number" then return end
        total = total + 1
        if DropHidden(id, side) then
            hidden = hidden + 1
        elseif not first then
            first = id
            local name = NpcName(id)
            if name then names[#names + 1] = name end
        elseif #names < 8 then
            local name = NpcName(id)
            if name then names[#names + 1] = name end
        end
    end)
    if #names == 0 then
        if hidden > 0 then
            return {
                method = "Drop",
                title = title,
                text = "The list names creatures that drop " .. title .. ", and they are friendly to your faction.",
                line = "Friendly",
            }
        end
        return nil
    end
    local place, map, x, y = NpcPin(first)
    local bits = {
        title .. " drops from " .. table.concat(names, ", ") .. ". The drop list has no percent.",
    }
    if place then bits[#bits + 1] = "That is in " .. place .. "." end
    if x and y then
        bits[#bits + 1] = string.format("The list places that near %.1f, %.1f.", x, y)
    end
    if total > #names + hidden then
        bits[#bits + 1] = "The list names more creatures."
    end
    return {
        method = "Drop",
        place = place,
        map = map,
        x = map and x or nil,
        y = map and y or nil,
        text = table.concat(bits, " "),
        line = names[1],
        title = title,
    }
end

local function ObjectSource(itemID, title)
    local db = _G.ItemDB
    if not db or not db.objectDrops then return nil end
    local list = Call(db.objectDrops, itemID)
    if type(list) ~= "table" then return nil end
    local objectID
    EachId(list, function(id)
        if not objectID and type(id) == "number" then objectID = id end
    end)
    if not objectID then return nil end
    local name = ObjectName(objectID)
    local place, map, x, y
    local odb = _G.ObjectDB
    if odb and odb.spawns then
        local area = odb.zoneID and Call(odb.zoneID, objectID) or nil
        local got, sx, sy = FirstSpot(Call(odb.spawns, objectID), area)
        if sx then
            place = AreaName(got)
            map, x, y = UiMap(got), sx, sy
        end
    end
    local bits = {}
    if name then
        bits[#bits + 1] = title .. " is inside " .. name .. "."
    else
        bits[#bits + 1] = "The list names an object that contains " .. title .. " and does not name the object."
    end
    if place then bits[#bits + 1] = "That is in " .. place .. "." end
    if x and y then
        bits[#bits + 1] = string.format("The list places that near %.1f, %.1f.", x, y)
    end
    return {
        method = "Drop",
        place = place,
        map = map,
        x = map and x or nil,
        y = map and y or nil,
        text = table.concat(bits, " "),
        line = name,
        title = title,
    }
end

local function Describe(itemID, kindName, rep)
    local title = ItemName(itemID) or kindName
    local found = RepSource(itemID, rep, title)
        or VendorSource(itemID, title)
        or QuestSource(itemID, title)
        or DropSource(itemID, title)
        or ObjectSource(itemID, title)
    if found then return found end
    return {
        title = title,
        text = "The list names this " .. kindName:lower() .. " and does not name a vendor, a quest, or a drop.",
    }
end

local function ScanItems(steps, bySpell, byName, seen, rep, info)
    local db = _G.ItemDB
    if not db or not db.GetAllIds or not db.class or not db.subClass then return end
    local ok, ids = pcall(db.GetAllIds)
    if not ok or type(ids) ~= "table" then return end
    local misc, pet, mount = MiscClass(), PetSub(), MountSub()
    local function consider(itemID)
        if type(itemID) ~= "number" or itemID <= 0 or seen[itemID] then return end
        if Call(db.class, itemID) ~= misc then return end
        local sub = Call(db.subClass, itemID)
        local kindName, kindOrder
        if sub == pet then
            kindName, kindOrder = "Pet", 2
        elseif sub == mount then
            kindName, kindOrder = "Mount", 1
        else
            return
        end
        local name = ItemName(itemID)
        if not name then return end
        seen[itemID] = true
        info.items = true
        local spell = Call(db.teachesSpell, itemID)
        if type(spell) ~= "number" or spell <= 0 then spell = nil end
        local source = Describe(itemID, kindName, rep)
        source.title = name
        local step = AddRecord(steps, itemID, kindName, kindOrder, source, spell, nil, false)
        if spell then bySpell[spell] = step end
        byName[name:lower()] = step
    end
    if #ids > 0 then
        for i = 1, #ids do consider(ids[i]) end
    else
        for id in pairs(ids) do consider(id) end
    end
end

local function ReadMount(mountID, steps, bySpell, byName, info)
    local C = _G.C_MountJournal
    if type(mountID) ~= "number" or mountID <= 0 or not C or not C.GetMountInfoByID then return end
    local ok, name, spellID, icon, _, _, _, _, factionSpecific, faction, hideOnChar, collected = pcall(C.GetMountInfoByID, mountID)
    if not ok or type(name) ~= "string" or name == "" then return end
    if hideOnChar == true then return end
    if OtherFaction(factionSpecific, faction) then return end
    local description, source
    if C.GetMountInfoExtraByID then
        local extraOk, _, extraText, src = pcall(C.GetMountInfoExtraByID, mountID)
        if extraOk and type(extraText) == "string" and extraText ~= "" then description = extraText end
        if extraOk and type(src) == "string" and src ~= "" then source = src end
    end
    local spell = type(spellID) == "number" and spellID > 0 and spellID or nil
    local step = (spell and bySpell[spell]) or byName[name:lower()]
    if step then
        if collected == true then step.collected = true end
        if step.icon == nil and icon ~= nil then step.icon = icon end
        Append(step, source)
        Append(step, description)
        if not step.method and source then
            step.method = Prefix(source)
            step.segment = Header(step)
        end
        info.mounts = true
        return
    end
    local text = source or ""
    if description then
        if text == "" then text = description else text = text .. " " .. description end
    end
    if text == "" then
        text = "The mount journal lists " .. name .. " and does not name how to get it."
    end
    local added = AddRecord(steps, nil, "Mount", 1, {
        title = name,
        text = text,
        method = Prefix(source),
        line = Prefix(source),
    }, spell, icon, collected == true)
    if spell then bySpell[spell] = added end
    byName[name:lower()] = added
    info.mounts = true
end

local function WalkDisplayedMounts(steps, bySpell, byName, info)
    local C = _G.C_MountJournal
    if not C or not C.GetNumDisplayedMounts or not C.GetDisplayedMountID then return end
    local saved = {}
    local changed = false
    if C.GetCollectedFilterSetting and C.SetCollectedFilterSetting then
        local names = {
            "LE_MOUNT_JOURNAL_FILTER_COLLECTED",
            "LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED",
            "LE_MOUNT_JOURNAL_FILTER_UNUSABLE",
        }
        for i = 1, #names do
            local id = _G[names[i]]
            if type(id) == "number" then
                local ok, on = pcall(C.GetCollectedFilterSetting, id)
                if ok then
                    saved[#saved + 1] = { id, on and true or false }
                    pcall(C.SetCollectedFilterSetting, id, true)
                    changed = true
                end
            end
        end
    end
    local ok = pcall(function()
        local count = C.GetNumDisplayedMounts() or 0
        for i = 1, count do
            ReadMount(C.GetDisplayedMountID(i), steps, bySpell, byName, info)
        end
    end)
    if changed then
        for i = 1, #saved do
            pcall(C.SetCollectedFilterSetting, saved[i][1], saved[i][2])
        end
    end
    if not ok then return end
end

local function EnrichMounts(steps, bySpell, byName, info)
    local C = _G.C_MountJournal
    if not C or not C.GetMountInfoByID then return end
    if C.GetMountIDs then
        local ok, ids = pcall(C.GetMountIDs)
        if ok and type(ids) == "table" then
            for i = 1, #ids do
                ReadMount(ids[i], steps, bySpell, byName, info)
            end
        end
    end
    WalkDisplayedMounts(steps, bySpell, byName, info)
end

local function CapturePetFilters(C)
    local saved = { sources = {}, types = {} }
    if C.IsFilterChecked and C.SetFilterChecked then
        local collected = _G.LE_PET_JOURNAL_FILTER_COLLECTED
        local missing = _G.LE_PET_JOURNAL_FILTER_NOT_COLLECTED
        if type(collected) == "number" then
            local ok, on = pcall(C.IsFilterChecked, collected)
            if ok then saved.collected = on and true or false end
        end
        if type(missing) == "number" then
            local ok, on = pcall(C.IsFilterChecked, missing)
            if ok then saved.missing = on and true or false end
        end
    end
    local sources = C.GetNumPetSources and C.GetNumPetSources() or 0
    if C.IsPetSourceChecked and C.SetPetSourceChecked and type(sources) == "number" then
        for i = 1, sources do
            local ok, on = pcall(C.IsPetSourceChecked, i)
            if ok then saved.sources[i] = on and true or false end
        end
    end
    local types = C.GetNumPetTypes and C.GetNumPetTypes() or 0
    if C.IsPetTypeChecked and C.SetPetTypeChecked and type(types) == "number" then
        for i = 1, types do
            local ok, on = pcall(C.IsPetTypeChecked, i)
            if ok then saved.types[i] = on and true or false end
        end
    end
    return saved
end

local function WidenPetFilters(C, saved)
    if saved.collected ~= nil then
        pcall(C.SetFilterChecked, _G.LE_PET_JOURNAL_FILTER_COLLECTED, true)
    end
    if saved.missing ~= nil then
        pcall(C.SetFilterChecked, _G.LE_PET_JOURNAL_FILTER_NOT_COLLECTED, true)
    end
    for i = 1, #saved.sources do
        pcall(C.SetPetSourceChecked, i, true)
    end
    for i = 1, #saved.types do
        pcall(C.SetPetTypeChecked, i, true)
    end
end

local function RestorePetFilters(C, saved)
    if saved.collected ~= nil then
        pcall(C.SetFilterChecked, _G.LE_PET_JOURNAL_FILTER_COLLECTED, saved.collected)
    end
    if saved.missing ~= nil then
        pcall(C.SetFilterChecked, _G.LE_PET_JOURNAL_FILTER_NOT_COLLECTED, saved.missing)
    end
    for i = 1, #saved.sources do
        pcall(C.SetPetSourceChecked, i, saved.sources[i])
    end
    for i = 1, #saved.types do
        pcall(C.SetPetTypeChecked, i, saved.types[i])
    end
end

local function ReadPets(C, steps, byName, info)
    local count = C.GetNumPets()
    if type(count) ~= "number" or count <= 0 then return end
    for i = 1, count do
        local _, speciesID, owned, _, _, _, _, speciesName, icon = C.GetPetInfoByIndex(i)
        local source, description
        if type(speciesID) == "number" and C.GetPetInfoBySpeciesID then
            local sName, _, _, _, tip, desc = C.GetPetInfoBySpeciesID(speciesID)
            if type(sName) == "string" and sName ~= "" then speciesName = sName end
            if type(tip) == "string" and tip ~= "" then source = tip end
            if type(desc) == "string" and desc ~= "" then description = desc end
        end
        if type(speciesName) == "string" and speciesName ~= "" then
            info.pets = true
            local step = byName[speciesName:lower()]
            if step then
                if owned == true then step.collected = true end
                if step.icon == nil and icon ~= nil then step.icon = icon end
                Append(step, source)
                Append(step, description)
                if not step.method and source then
                    step.method = Prefix(source)
                    step.segment = Header(step)
                end
            else
                local text = source or ""
                if description then
                    if text == "" then text = description else text = text .. " " .. description end
                end
                if text == "" then
                    text = "The pet journal lists " .. speciesName .. " and does not name how to get it."
                end
                local added = AddRecord(steps, nil, "Pet", 2, {
                    title = speciesName,
                    text = text,
                    method = Prefix(source),
                    line = Prefix(source),
                }, nil, icon, owned == true)
                byName[speciesName:lower()] = added
            end
        end
    end
end

local function ScanPets(steps, byName, info)
    local C = _G.C_PetJournal
    if not C or not C.GetNumPets or not C.GetPetInfoByIndex then return end
    local saved = CapturePetFilters(C)
    WidenPetFilters(C, saved)
    pcall(ReadPets, C, steps, byName, info)
    RestorePetFilters(C, saved)
end

local function RestoreToys(C, saved)
    if saved.collected ~= nil and C.SetCollectedShown then
        pcall(C.SetCollectedShown, saved.collected)
    end
    if saved.uncollected ~= nil and C.SetUncollectedShown then
        pcall(C.SetUncollectedShown, saved.uncollected)
    end
    if saved.unusable ~= nil and C.SetUnusableShown then
        pcall(C.SetUnusableShown, saved.unusable)
    end
    if C.SetSourceTypeFilter then
        for i = 1, #saved.sources do
            pcall(C.SetSourceTypeFilter, i, saved.sources[i])
        end
    end
    if C.SetExpansionTypeFilter then
        for i = 1, #saved.expansions do
            pcall(C.SetExpansionTypeFilter, i, saved.expansions[i])
        end
    end
    if C.SetFilterString then pcall(C.SetFilterString, saved.search or "") end
    if C.ForceToyRefilter then pcall(C.ForceToyRefilter) end
    if ToyBox and ToyBox.IsVisible and ToyBox:IsVisible() then
        if ToyBox_UpdatePages then pcall(ToyBox_UpdatePages) end
        if ToyBox_UpdateButtons then pcall(ToyBox_UpdateButtons) end
    end
end

local function ReadToys(C, steps, seen, rep, info)
    local count = C.GetNumFilteredToys()
    if type(count) ~= "number" or count <= 0 then return end
    for i = 1, count do
        local itemID = C.GetToyFromIndex(i)
        if type(itemID) == "number" and itemID > 0 and not seen[itemID] then
            local _, name, icon = C.GetToyInfo(itemID)
            if type(name) == "string" and name ~= "" then
                seen[itemID] = true
                info.toys = true
                local collected = false
                if PlayerHasToy then
                    local ok, has = pcall(PlayerHasToy, itemID)
                    if ok and has then collected = true end
                end
                local source = Describe(itemID, "Toy", rep)
                source.title = name
                if type(source.text) == "string" and string.find(source.text, "does not name a vendor", 1, true) then
                    source.text = "The toy box lists " .. name .. " and does not name how to get it."
                end
                AddRecord(steps, itemID, "Toy", 3, source, nil, icon, collected)
            end
        end
    end
end

local function ScanToys(steps, seen, rep, info)
    local C = _G.C_ToyBox
    if not C or not C.GetNumFilteredToys or not C.GetToyFromIndex or not C.GetToyInfo then return end
    local saved = { sources = {}, expansions = {}, search = "" }
    if ToyBox and type(ToyBox.searchString) == "string" then saved.search = ToyBox.searchString end
    if C.GetCollectedShown then
        local ok, on = pcall(C.GetCollectedShown)
        if ok then saved.collected = on and true or false end
    end
    if C.GetUncollectedShown then
        local ok, on = pcall(C.GetUncollectedShown)
        if ok then saved.uncollected = on and true or false end
    end
    if C.GetUnusableShown then
        local ok, on = pcall(C.GetUnusableShown)
        if ok then saved.unusable = on and true or false end
    end
    local sources = 0
    if C_PetJournal and C_PetJournal.GetNumPetSources then
        local ok, count = pcall(C_PetJournal.GetNumPetSources)
        if ok and type(count) == "number" then sources = count end
    end
    if C.IsSourceTypeFilterChecked and type(sources) == "number" then
        for i = 1, sources do
            local ok, on = pcall(C.IsSourceTypeFilterChecked, i)
            if ok then saved.sources[i] = on and true or false end
        end
    end
    local expansions = 0
    if GetNumExpansions then
        local ok, count = pcall(GetNumExpansions)
        if ok and type(count) == "number" then expansions = count end
    end
    if C.IsExpansionTypeFilterChecked and type(expansions) == "number" then
        for i = 1, expansions do
            local ok, on = pcall(C.IsExpansionTypeFilterChecked, i)
            if ok then saved.expansions[i] = on and true or false end
        end
    end
    local function widen()
        if saved.collected ~= nil and C.SetCollectedShown then pcall(C.SetCollectedShown, true) end
        if saved.uncollected ~= nil and C.SetUncollectedShown then pcall(C.SetUncollectedShown, true) end
        if saved.unusable ~= nil and C.SetUnusableShown then pcall(C.SetUnusableShown, true) end
        if C.SetSourceTypeFilter then
            for i = 1, #saved.sources do pcall(C.SetSourceTypeFilter, i, true) end
        end
        if C.SetExpansionTypeFilter then
            for i = 1, #saved.expansions do pcall(C.SetExpansionTypeFilter, i, true) end
        end
        if C.SetFilterString then pcall(C.SetFilterString, "") end
        if C.ForceToyRefilter then pcall(C.ForceToyRefilter) end
        ReadToys(C, steps, seen, rep, info)
    end
    pcall(widen)
    RestoreToys(C, saved)
end

local function SortSteps(steps)
    table.sort(steps, function(a, b)
        local ao = a.kindOrder or 9
        local bo = b.kindOrder or 9
        if ao ~= bo then return ao < bo end
        local asg = a.segment or ""
        local bsg = b.segment or ""
        if asg ~= bsg then return asg < bsg end
        return (a.title or "") < (b.title or "")
    end)
end

local function SpellKnown(spell)
    if type(spell) ~= "number" or spell <= 0 then return false end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spell)
        if ok and known then return true end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, spell)
        if ok and known then return true end
    end
    return false
end

local function Known(step)
    if step.collected then return true end
    if SpellKnown(step.spell) then return true end
    if step.kindName == "Toy" and type(step.itemID) == "number" and PlayerHasToy then
        local ok, has = pcall(PlayerHasToy, step.itemID)
        if ok and has then return true end
    end
    return false
end

function SG.Collectibles.Build()
    local steps, bySpell, byName, seen = {}, {}, {}, {}
    local info = {}
    local rep = RepMap()
    ScanItems(steps, bySpell, byName, seen, rep, info)
    EnrichMounts(steps, bySpell, byName, info)
    ScanPets(steps, byName, info)
    ScanToys(steps, seen, rep, info)
    local note
    if #steps == 0 then
        note = "No mounts, pets, or toys were listed. QuestieDB did not list companion pets or mounts, and the journals did not list uncollected entries."
    else
        note = "Collected mounts, pets, and toys stay off this list. Nothing uncollected was left on the lists that loaded."
    end
    steps[#steps + 1] = {
        kind = "note",
        collectNote = true,
        optional = false,
        match = "bis",
        visible = true,
        kindOrder = 9,
        segment = "Collectibles",
        level = 1,
        title = "Nothing listed",
        text = note,
    }
    SortSteps(steps)
    local guide = {
        id = GUIDE_ID,
        title = "Mounts, pets, and toys",
        group = "Collectibles",
        category = "collectibles",
        side = "B",
        place = "Azeroth",
        min = 1,
        max = 60,
        collectibles = true,
        blurb = "Mounts, pets, and toys still missing from this character. A line is shown only when QuestieDB or a journal names it. The description is that source. Collected ones stay off the list.",
        steps = steps,
    }
    for i = 1, #steps do
        steps[i].index = i
        steps[i].guide = guide.id
    end
    return guide
end

function SG.Collectibles.Apply(guide)
    if not guide or type(guide.steps) ~= "table" then return end
    local row = SG.Engine and SG.Engine.Progress and SG.Engine.Progress(guide.id)
    local any = false
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if not step.collectNote then
            local known = Known(step)
            if known and row and row.hold ~= i then row.done[i] = true end
            local closed = known or (row and row.done[i] and true or false)
            if closed then
                step.visible = false
            else
                step.visible = true
                any = true
            end
        end
    end
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.collectNote then step.visible = not any end
    end
end

function SG.Collectibles.Install(quiet)
    if not SG.Engine or not SG.Engine.guides or not SG.Engine.byId then return end
    local guide = SG.Collectibles.Build()
    local list = SG.Engine.guides
    local replaced = false
    for i = 1, #list do
        if list[i].id == guide.id then
            list[i] = guide
            replaced = true
            break
        end
    end
    if not replaced then list[#list + 1] = guide end
    SG.Engine.byId[guide.id] = guide
    if SG.Engine.AlignProgress then SG.Engine.AlignProgress(guide) end
    SG.Collectibles.Apply(guide)
    if quiet then return end
    if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
end

function SG.Collectibles.Refresh()
    SG.Collectibles.Install(false)
end

local function Watch()
    if SG.Collectibles.watching or not SG.eventFrame then return end
    SG.Collectibles.watching = true
    local names = { "COMPANION_LEARNED", "NEW_PET_ADDED", "NEW_TOY_ADDED" }
    for i = 1, #names do
        pcall(SG.eventFrame.RegisterEvent, SG.eventFrame, names[i])
    end
end

local oldInstall = SG.Collectibles.Install
function SG.Collectibles.Install(quiet)
    Watch()
    oldInstall(quiet)
end
