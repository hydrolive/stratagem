-- Recipes.lua: where to buy, earn, or loot a recipe for a profession this character has.
-- Trainer recipes stay with the trainer. This list does not invent a vendor, a quest, a drop, a rate, or a price.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Recipes = {}

local GUIDE_ID = "prof-recipes"

local function Namespace()
    return SG.BiS and SG.BiS.ns or _G.NaowhForever or _G.NaowwahForever
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

local function Side()
    if SG.playerSide == "A" or SG.playerSide == "H" then return SG.playerSide end
    if SG.PlayerSide then
        local side = SG.PlayerSide()
        if side == "A" or side == "H" then return side end
    end
    return "H"
end

-- nil, "-", "B", and "AH" sell to both. "A" and "H" are one faction.
local function FactionOK(faction, side)
    if faction == nil or faction == "" or faction == "-" or faction == "B" or faction == "AH" then
        return true
    end
    if type(faction) ~= "string" then return true end
    return faction == side
end

local function ProfessionIds()
    local order, seen = {}, {}
    if not GetProfessions or not GetProfessionInfo then return order end
    local function add(index)
        if not index then return end
        local _, _, _, _, _, _, skillLine = GetProfessionInfo(index)
        if type(skillLine) == "number" and skillLine > 0 and not seen[skillLine] then
            seen[skillLine] = true
            order[#order + 1] = skillLine
        end
    end
    local first, second, arch, fish, cook = GetProfessions()
    add(first)
    add(second)
    add(arch)
    add(fish)
    add(cook)
    return order
end

local function DataKey()
    local ns = Namespace()
    local loaded = (ns and type(ns.RecipeData) == "table") and "1" or "0"
    local journal = ns and ns.Journal
    local jbit = (journal and journal.Factions) and "J1" or "J0"
    local qbit = (_G.ItemDB and _G.ItemDB.teachesSpell) and "Q1" or "Q0"
    local ids = ProfessionIds()
    local bits = { loaded, jbit, qbit }
    for i = 1, #ids do bits[#bits + 1] = tostring(ids[i]) end
    return table.concat(bits, ",")
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

-- Bind is the client field. 2 is bind on equip. Unknown is not treated as bind on equip.
local function ItemBind(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then return nil end
    local function read(ok, name, link, _, _, _, _, _, _, _, _, _, _, bind)
        if ok and type(name) == "string" and name ~= "" and type(link) == "string" and type(bind) == "number" then
            return bind
        end
        return nil
    end
    if C_Item and C_Item.GetItemInfo then
        local bind = read(pcall(C_Item.GetItemInfo, itemID))
        if type(bind) == "number" then return bind end
    end
    if GetItemInfo then
        local name, _, _, _, _, _, _, _, _, _, _, _, _, bind = GetItemInfo(itemID)
        if type(name) == "string" and name ~= "" and type(bind) == "number" then return bind end
    end
    return nil
end

local function AskRecipe(itemID)
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    elseif RequestLoadItemDataByID then
        pcall(RequestLoadItemDataByID, itemID)
    end
end

-- Auctionator's public price is copper from the last scan. Nil means it has no row.
local function AuctionSentence(itemID)
    local bind = ItemBind(itemID)
    if bind == nil then
        AskRecipe(itemID)
        return nil
    end
    if bind ~= 2 then return "" end
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    local get = api and api.GetAuctionPriceByItemID
    if type(get) ~= "function" then
        return " Auctionator is not loaded, so this BoE recipe has no auction price."
    end
    local ok, price = pcall(get, "Stratagem", itemID)
    local shown = ok and type(price) == "number" and PriceText(price) or nil
    if shown then return " Auctionator last scanned this BoE recipe at " .. shown .. ".", shown end
    return " Auctionator has no scanned auction price for this BoE recipe."
end

local function TrimPercent(chance)
    local text = string.format("%.1f", chance)
    if text == "0.0" then text = string.format("%.2f", chance) end
    if text:sub(-2) == ".0" then text = text:sub(1, -3) end
    return text
end

local function AreaName(area)
    if type(area) ~= "number" then return nil end
    if C_Map and C_Map.GetAreaInfo then
        local name = C_Map.GetAreaInfo(area)
        if type(name) == "string" and name ~= "" then return name end
    end
    return nil
end

local function ZoneName(map)
    if type(map) ~= "number" or not C_Map or not C_Map.GetMapInfo then return nil end
    local info = C_Map.GetMapInfo(map)
    if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
        return info.name
    end
    return nil
end

local function Pin(map, x, y)
    if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil, nil, nil
    end
    return map, x, y
end

local function VendorSpots(recipe, side)
    local rows = recipe.vendors
    local spots = {}
    local function unnamed()
        spots[#spots + 1] = {
            text = "The recipe comes from a vendor. The list does not name them.",
            tag = "Vendors",
            order = 1,
        }
    end
    if type(rows) ~= "table" then
        unnamed()
        return spots
    end
    local other = false
    for i = 1, #rows do
        local row = rows[i]
        if type(row) == "table" and FactionOK(row[3], side) then
            local name = row[2]
            local bits = {}
            if type(name) == "string" and name ~= "" then
                bits[#bits + 1] = "Buy the recipe from " .. name .. "."
            else
                bits[#bits + 1] = "Buy the recipe from a vendor. The list does not name them."
            end
            local price = PriceText(row[7])
            if price then bits[#bits + 1] = "The list prices it at " .. price .. "." end
            if type(recipe.rep) == "string" and recipe.rep ~= "" then
                bits[#bits + 1] = "The list requires " .. recipe.rep .. "."
            end
            local map, x, y = Pin(row[4], row[5], row[6])
            local place = ZoneName(map)
            if place then bits[#bits + 1] = "The list places that in " .. place .. "." end
            spots[#spots + 1] = {
                text = table.concat(bits, " "),
                map = map,
                x = x,
                y = y,
                place = place,
                tag = "Vendors",
                order = 1,
            }
        elseif type(row) == "table" and type(row[3]) == "string" and not FactionOK(row[3], side) then
            other = true
        end
    end
    if #spots > 0 then return spots end
    if other then return nil end
    unnamed()
    return spots
end

local function QuestTitle(quest)
    local name = quest.name
    if type(name) == "string" and name ~= "" then return name end
    local id = quest.id
    if type(id) ~= "number" or not C_QuestLog or not C_QuestLog.GetTitleForQuestID then return nil end
    local ok, title = pcall(C_QuestLog.GetTitleForQuestID, id)
    if ok and type(title) == "string" and title ~= "" then return title end
    return nil
end

local function QuestSpots(recipe, side)
    local quests = recipe.quests
    if type(quests) ~= "table" then return nil end
    local spots = {}
    for i = 1, #quests do
        local quest = quests[i]
        if type(quest) == "table" and FactionOK(quest.side, side) then
            local title = QuestTitle(quest)
            local npc = quest.npc
            local giver = type(npc) == "table" and type(npc[2]) == "string" and npc[2] ~= "" and npc[2] or nil
            local map, x, y
            if type(npc) == "table" then map, x, y = Pin(npc[4], npc[5], npc[6]) end
            local place = ZoneName(map)
            local bits = {}
            if title then
                bits[#bits + 1] = "The recipe is a reward from " .. title .. "."
            else
                bits[#bits + 1] = "The recipe is a quest reward. The list does not name the quest."
            end
            if giver then bits[#bits + 1] = giver .. " gives that quest." end
            if place then bits[#bits + 1] = "The list places that in " .. place .. "." end
            local level = quest.level
            if type(level) == "number" and level > 0 then
                bits[#bits + 1] = "The list marks it level " .. level .. "."
            end
            spots[#spots + 1] = {
                text = table.concat(bits, " "),
                map = map,
                x = x,
                y = y,
                place = place,
                tag = "Quests",
                order = 2,
            }
        end
    end
    if #spots == 0 then return nil end
    return spots
end

local function DropTail(recipe)
    local extra = {}
    if recipe.chests then extra[#extra + 1] = "chests" end
    if recipe.fished then extra[#extra + 1] = "fishing" end
    if recipe.pickpocket then extra[#extra + 1] = "pickpocketing" end
    if #extra == 0 then return "" end
    return " The list also names " .. table.concat(extra, ", ") .. "."
end

local function PointText(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    if x < 0 or x > 100 or y < 0 or y > 100 then return nil end
    return TrimPercent(x) .. ", " .. TrimPercent(y)
end

local function MobPhrase(mob)
    local name = mob[1]
    local pct = mob[2]
    local tag = mob[4]
    local who = type(name) == "string" and name ~= "" and name or nil
    local spot = PointText(mob[5], mob[6])
    if who and spot then who = who .. " near " .. spot end
    local rate = type(pct) == "number" and (TrimPercent(pct) .. "%") or nil
    if tag == "s" then
        if who and rate then return who .. " (seen, classic list " .. rate .. ")" end
        if who then return who .. " (seen, no percent)" end
        return "an unnamed creature (seen, no percent)"
    end
    if tag == "q" then
        if who then return who .. " (Questie, no percent)" end
        return nil
    end
    if who and rate then return who .. " (classic list " .. rate .. ")" end
    if who then return who .. " (no percent)" end
    return nil
end

local function MapName(map)
    if type(map) ~= "number" or not C_Map or not C_Map.GetMapInfo then return nil end
    local info = C_Map.GetMapInfo(map)
    if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
        return info.name
    end
    return nil
end

-- entrance marks an instance whose map point is the door, not the zone that door sits in.
local function ZoneTitle(row)
    local stored = row[1]
    local named = type(stored) == "string" and stored ~= "" and stored or nil
    if row.entrance and named then return named end
    local client = MapName(row[2])
    if client then return client end
    return named
end

local function ShownMobs(mobs, side)
    local out = {}
    if type(mobs) ~= "table" then return out end
    for i = 1, #mobs do
        local mob = mobs[i]
        local fac = type(mob) == "table" and mob[3] or nil
        if type(mob) == "table" and (type(fac) ~= "string" or fac == "" or not string.find(fac, side, 1, true)) then
            out[#out + 1] = mob
        end
    end
    return out
end

local function GuideLine(row, shown, place)
    local bits = {}
    for i = 1, #shown do
        local phrase = MobPhrase(shown[i])
        if phrase then bits[#bits + 1] = phrase end
    end
    if #bits == 0 then return nil end
    local line
    if place then
        line = "In " .. place .. ", Forever Guide lists " .. table.concat(bits, ", ") .. "."
    else
        line = "Forever Guide lists " .. table.concat(bits, ", ") .. "."
    end
    local more = row[5]
    if type(more) == "number" and more > 0 then
        line = line .. " It lists " .. more .. " more mobs there."
    end
    local zones = row[6]
    if type(zones) == "number" and zones > 0 then
        line = line .. " It lists " .. zones .. " more zones."
    end
    if row.entrance then
        local door = MapName(row[2])
        local at = PointText(row[3], row[4])
        if door and at then
            line = line .. " Its entrance is in " .. door .. " near " .. at .. "."
        elseif at then
            line = line .. " Its entrance is near " .. at .. "."
        end
    end
    return line
end

local function ShortMob(shown)
    local mob = shown[1]
    if type(mob) ~= "table" then return nil end
    local name = mob[1]
    if type(name) ~= "string" or name == "" then return nil end
    if type(mob[2]) == "number" then return name .. " " .. TrimPercent(mob[2]) .. "%" end
    return name
end

-- Forever Guide does not export its item search. Data/RecipeDrops.lua is that lookup:
-- mob, classic percent, and zone or instance for recipe items. A blank percent was blank there.
local function GuideSpots(itemID)
    local book = SG.RecipeDrops
    local rows = book and book[itemID]
    if type(rows) ~= "table" then return nil end
    local side = Side()
    local spots = {}
    local rest = rows.rest
    for i = 1, #rows do
        local row = rows[i]
        if type(row) == "table" then
            local shown = ShownMobs(row[7], side)
            local place = ZoneTitle(row)
            local text = GuideLine(row, shown, place)
            if text then
                local pin = type(row[2]) == "number" and type(row[3]) == "number" and type(row[4]) == "number"
                    and row[3] >= 0 and row[3] <= 100 and row[4] >= 0 and row[4] <= 100
                spots[#spots + 1] = {
                    text = text,
                    place = place,
                    tag = "World Drops",
                    order = 3,
                    line = ShortMob(shown),
                    map = pin and row[2] or nil,
                    x = pin and row[3] or nil,
                    y = pin and row[4] or nil,
                }
            end
        end
    end
    if #spots == 0 then return nil end
    if type(rest) == "table" and type(rest[1]) == "number" and type(rest[2]) == "number" and rest[2] > 0 then
        spots[#spots].text = spots[#spots].text .. " The classic list also names " .. rest[2] .. " more mobs at " .. TrimPercent(rest[1]) .. "%."
    end
    return spots
end

local function AreaTitle(area)
    if type(area) ~= "number" or not C_Map or not C_Map.GetAreaInfo then return nil end
    local name = C_Map.GetAreaInfo(area)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

local function NpcHidden(id, side)
    local db = _G.NpcDB
    if not db or not db.friendlyToFaction then return false end
    local ok, fac = pcall(db.friendlyToFaction, id)
    if not ok or type(fac) ~= "string" or fac == "" then return false end
    return string.find(fac, side, 1, true) ~= nil
end

-- Questie spawn points are 0-100. The first point in the mob's own zone is the one named.
local function FirstSpawn(id)
    local db = _G.NpcDB
    if not db or not db.spawns then return nil end
    local ok, list = pcall(db.spawns, id)
    if not ok or type(list) ~= "table" then return nil end
    local function take(spots)
        if type(spots) ~= "table" then return nil end
        local spot = spots[1]
        if type(spot) ~= "table" then return nil end
        local x, y = spot[1], spot[2]
        if type(x) ~= "number" or type(y) ~= "number" then return nil end
        if x < 0 or x > 100 or y < 0 or y > 100 then return nil end
        return x, y
    end
    local prefer
    if db.zoneID then
        local known, area = pcall(db.zoneID, id)
        if known then prefer = list[area] end
    end
    local x, y = take(prefer)
    if x then return x, y end
    for _, spots in pairs(list) do
        x, y = take(spots)
        if x then return x, y end
    end
    return nil
end

-- QuestieDB wowhead rows are quest-objective items. Use one only when Forever Guide has no recipe row.
local function DropListSpots(itemID)
    if not SG.Gear or not SG.Gear.DropTable then return nil end
    local book = SG.Gear.DropTable()
    local row = type(book) == "table" and book[itemID] or nil
    if type(row) ~= "table" then return nil end
    local ranked = {}
    for npc, pct in pairs(row) do
        if type(npc) == "number" and type(pct) == "number" and pct > 0 then
            ranked[#ranked + 1] = { npc, pct }
        end
    end
    if #ranked == 0 then return nil end
    table.sort(ranked, function(a, b)
        if a[2] ~= b[2] then return a[2] > b[2] end
        return a[1] < b[1]
    end)
    local db = _G.NpcDB
    local side = Side()
    local groups, order = {}, {}
    local limit = #ranked > 6 and 6 or #ranked
    for i = 1, limit do
        local npc = ranked[i][1]
        if not NpcHidden(npc, side) and db and db.name then
            local ok, got = pcall(db.name, npc)
            local place = ""
            if ok and type(got) == "string" and got ~= "" then
                if db.zoneID then
                    local known, area = pcall(db.zoneID, npc)
                    if known then place = AreaTitle(area) or "" end
                end
                local bucket = groups[place]
                if not bucket then
                    bucket = {}
                    groups[place] = bucket
                    order[#order + 1] = place
                end
                local sx, sy = FirstSpawn(npc)
                bucket[#bucket + 1] = { got, ranked[i][2], sx, sy }
            end
        end
    end
    if #order == 0 then return nil end
    local spots = {}
    local extra = #ranked - limit
    for i = 1, #order do
        local place = order[i]
        local bucket = groups[place]
        local bits = {}
        for m = 1, #bucket do
            local phrase = bucket[m][1]
            local at = PointText(bucket[m][3], bucket[m][4])
            if at then phrase = phrase .. " near " .. at end
            bits[#bits + 1] = phrase .. " (" .. TrimPercent(bucket[m][2]) .. "%)"
        end
        local where = place ~= "" and place or nil
        local text = "The drop list names " .. table.concat(bits, ", ")
        if where then text = text .. " in " .. where end
        text = text .. "."
        if i == #order and extra > 0 then
            text = text .. " It names " .. extra .. " more mobs."
        end
        spots[#spots + 1] = {
            text = text,
            place = where,
            tag = "World Drops",
            order = 3,
            line = bucket[1][1] .. " " .. TrimPercent(bucket[1][2]) .. "%",
        }
    end
    return spots
end

-- ItemDB.npcDrops names mobs and has no percent. Use it only for a short list.
local function QuestieSpots(itemID)
    local db = _G.ItemDB
    if not db or not db.npcDrops then return nil end
    local ok, list = pcall(db.npcDrops, itemID)
    if not ok or type(list) ~= "table" then return nil end
    local side = Side()
    local npcs = _G.NpcDB
    local ids = {}
    local count = 0
    for _, id in pairs(list) do
        if type(id) == "number" and not NpcHidden(id, side) then
            count = count + 1
            if count <= 8 then ids[#ids + 1] = id end
        end
    end
    if count == 0 then return nil end
    if count > 8 then
        return {
            {
                text = "Questie names " .. count .. " mobs and has no percent.",
                tag = "World Drops",
                order = 3,
            },
        }
    end
    table.sort(ids)
    local groups, order = {}, {}
    for i = 1, #ids do
        local name
        if npcs and npcs.name then
            local known, got = pcall(npcs.name, ids[i])
            if known and type(got) == "string" and got ~= "" then name = got end
        end
        if name then
            local place = ""
            if npcs.zoneID then
                local known, area = pcall(npcs.zoneID, ids[i])
                if known then place = AreaTitle(area) or "" end
            end
            local bucket = groups[place]
            if not bucket then
                bucket = {}
                groups[place] = bucket
                order[#order + 1] = place
            end
            local sx, sy = FirstSpawn(ids[i])
            bucket[#bucket + 1] = { name, sx, sy }
        end
    end
    if #order == 0 then return nil end
    local spots = {}
    for i = 1, #order do
        local place = order[i]
        local where = place ~= "" and place or nil
        local names = {}
        local grouped = groups[place]
        for m = 1, #grouped do
            local phrase = grouped[m][1]
            local at = PointText(grouped[m][2], grouped[m][3])
            if at then phrase = phrase .. " near " .. at end
            names[#names + 1] = phrase
        end
        local text = "Questie names " .. table.concat(names, ", ") .. "."
        if where then text = text .. " It places that in " .. where .. "." end
        text = text .. " It has no percent."
        spots[#spots + 1] = {
            text = text,
            place = where,
            tag = "World Drops",
            order = 3,
            line = groups[place][1][1],
        }
    end
    return spots
end

local function AppendTail(spots, recipe)
    local tail = DropTail(recipe)
    if tail ~= "" and spots[1] then
        spots[#spots].text = spots[#spots].text .. tail
    end
end

local function HasNamedMob(recipe)
    local bosses = recipe.bosses
    if type(bosses) == "table" and type(bosses[1]) == "table" and type(bosses[1][1]) == "string" and bosses[1][1] ~= "" then
        return true
    end
    local drops = recipe.drops
    if type(drops) ~= "table" then return false end
    for i = 1, #drops do
        local row = drops[i]
        if type(row) == "table" and type(row[1]) == "string" and row[1] ~= "" then return true end
    end
    return false
end

local function DropText(recipe)
    local tail = DropTail(recipe)
    local bosses = recipe.bosses
    if type(bosses) == "table" and type(bosses[1]) == "table" then
        local boss = bosses[1]
        local who = type(boss[1]) == "string" and boss[1] ~= "" and boss[1] or nil
        local place = AreaName(boss[2])
        local line
        if who and place then
            line = "The recipe drops from " .. who .. ". The list places that in " .. place .. "."
        elseif who then
            line = "The recipe drops from " .. who .. "."
        else
            line = "The recipe drops. The list does not name the mob."
        end
        if #bosses > 1 then
            line = line .. " The list names " .. #bosses .. " mobs."
        end
        return line .. tail, place
    end
    if type(recipe.world) == "number" then
        if recipe.world > 1 then
            return "The recipe is a world drop from mobs around level " .. recipe.world .. ". The list does not name a mob." .. tail, nil
        end
        return "The recipe is a world drop. The list does not name a mob." .. tail, nil
    end
    local drops = recipe.drops
    if type(drops) == "table" and #drops > 0 then
        local best, bestAt = nil, 1
        for i = 1, #drops do
            local row = drops[i]
            local chance = type(row) == "table" and row[5] or nil
            if type(chance) == "number" and (not best or chance > best) then
                best = chance
                bestAt = i
            end
        end
        local row = drops[bestAt]
        local who = type(row) == "table" and type(row[1]) == "string" and row[1] ~= "" and row[1] or nil
        local place = type(row) == "table" and AreaName(row[2]) or nil
        local line
        if who and type(best) == "number" and place then
            line = string.format("The recipe drops from %s in %s at %s%%.", who, place, TrimPercent(best))
        elseif who and type(best) == "number" then
            line = string.format("The recipe drops from %s at %s%%.", who, TrimPercent(best))
        elseif who then
            line = "The recipe drops from " .. who .. ". The list has no percent."
        else
            line = "The recipe drops. The list does not name the mob."
        end
        if #drops > 1 then
            line = line .. " The list names " .. #drops .. " mobs."
        end
        return line .. tail, place
    end
    if tail ~= "" then
        return "The recipe drops." .. tail, nil
    end
    return "The recipe drops. The list does not name the mob.", nil
end

local function DropPlace(recipe)
    local bosses = recipe.bosses
    if type(bosses) ~= "table" then return nil end
    for i = 1, #bosses do
        local boss = bosses[i]
        local place = type(boss) == "table" and AreaName(boss[2]) or nil
        if place then return place end
    end
    return nil
end

local function DropSpot(recipe)
    local itemID = recipe.recipe
    if type(itemID) == "number" then
        local guided = GuideSpots(itemID)
        if guided then
            AppendTail(guided, recipe)
            return guided
        end
        local listed = DropListSpots(itemID)
        if listed then
            AppendTail(listed, recipe)
            return listed
        end
    end
    local text, named = DropText(recipe)
    local place = DropPlace(recipe) or named
    if type(place) ~= "string" or place == "" then place = nil end
    if type(itemID) == "number" and not HasNamedMob(recipe) then
        local questie = QuestieSpots(itemID)
        if questie then
            AppendTail(questie, recipe)
            return questie
        end
    end
    return {
        {
            text = text,
            place = place,
            tag = "World Drops",
            order = 3,
        },
    }
end

local function Journal()
    local ns = Namespace()
    return ns and ns.Journal
end

local function SkillSet()
    local set = {}
    local ids = ProfessionIds()
    for i = 1, #ids do set[ids[i]] = true end
    return set
end

local function NameRank()
    local rank, slot, seen = {}, 0, {}
    if not GetProfessions or not GetProfessionInfo then return rank end
    local function add(index)
        if not index then return end
        local name, _, _, _, _, _, skillLine = GetProfessionInfo(index)
        if type(skillLine) ~= "number" or skillLine <= 0 or seen[skillLine] then return end
        seen[skillLine] = true
        slot = slot + 1
        if type(name) == "string" and name ~= "" then rank[name] = slot end
    end
    local first, second, arch, fish, cook = GetProfessions()
    add(first)
    add(second)
    add(arch)
    add(fish)
    add(cook)
    return rank
end

-- Client profession name to the skill line. The same walk ProfessionIds uses.
local function ProfessionNames()
    local names, seen = {}, {}
    if not GetProfessions or not GetProfessionInfo then return names end
    local function add(index)
        if not index then return end
        local name, _, _, _, _, _, skillLine = GetProfessionInfo(index)
        if type(skillLine) ~= "number" or skillLine <= 0 or seen[skillLine] then return end
        seen[skillLine] = true
        if type(name) == "string" and name ~= "" then names[name] = skillLine end
    end
    local first, second, arch, fish, cook = GetProfessions()
    add(first)
    add(second)
    add(arch)
    add(fish)
    add(cook)
    return names
end

local function FactionCode(faction)
    if type(faction) ~= "table" then return "B" end
    if faction.side == "Alliance" then return "A" end
    if faction.side == "Horde" then return "H" end
    return "B"
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

local function RecipeSubtype(itemID)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(instant) ~= "function" then return nil end
    local ok, _, _, sub = pcall(instant, itemID)
    if not ok or type(sub) ~= "string" or sub == "" then return nil end
    return sub
end

local function TaughtSpell(itemID)
    local db = _G.ItemDB
    if not db or not db.teachesSpell then return nil end
    local ok, spell = pcall(db.teachesSpell, itemID)
    if ok and type(spell) == "number" and spell > 0 then return spell end
    return nil
end

local function RepPrice(faction, itemID)
    local prices = faction.prices
    if type(prices) ~= "table" then return nil end
    local copper = prices[itemID]
    if type(copper) ~= "number" or copper <= 0 then return nil end
    return copper
end

local function Quartermaster(faction)
    local spot = faction.quartermaster
    local who, map, x, y
    if type(spot) ~= "table" then return nil end
    if type(spot.name) == "string" and spot.name ~= "" then who = spot.name end
    if type(spot.map) == "number" and type(spot.x) == "number" and type(spot.y) == "number"
        and spot.x >= 0 and spot.x <= 100 and spot.y >= 0 and spot.y <= 100 then
        map, x, y = spot.map, spot.x, spot.y
    end
    local zone = ZoneName(map)
    if not zone and type(faction.zone) == "string" and faction.zone ~= "" then zone = faction.zone end
    return who, zone, map, x, y
end

-- Journal tiers are the reputation rewards. The profession name is the client recipe subtype.
-- A subtype that is not one of this character's professions stays off.
local function ReputationRows(side, skills, ranks)
    local rows, items = {}, {}
    local journal = Journal()
    local loot = journal and journal.Loot
    if not journal or not journal.Factions or not loot or not loot.Recipe or not loot.RecipeYours then
        return rows, items
    end
    local ok, list = pcall(journal.Factions, "reputation")
    if not ok or type(list) ~= "table" then return rows, items end
    for i = 1, #list do
        local faction = list[i]
        local code = FactionCode(faction)
        local name = type(faction) == "table" and faction.name or nil
        if type(faction) == "table" and not faction.unreleased and type(name) == "string" and name ~= ""
            and (code == "B" or code == side) and type(faction.tiers) == "table" then
            local who, zone, map, x, y = Quartermaster(faction)
            local seen = {}
            for t = 1, #faction.tiers do
                local tier = faction.tiers[t]
                local bag = tier and tier.items
                local standing = tier and tier.standing
                if type(bag) == "table" and type(standing) == "number" then
                    for n = 1, #bag do
                        local itemID = bag[n]
                        if type(itemID) == "number" and itemID > 0 and not seen[itemID] then
                            local known, subclass = pcall(loot.Recipe, itemID)
                            local yours = false
                            if known and type(subclass) == "number" then
                                local mine, got = pcall(loot.RecipeYours, subclass, { skills = skills })
                                yours = mine and got and true or false
                            end
                            local prof = yours and RecipeSubtype(itemID) or nil
                            if prof and ranks[prof] then
                                seen[itemID] = true
                                items[itemID] = true
                                rows[#rows + 1] = {
                                    itemID = itemID,
                                    standing = standing,
                                    faction = name,
                                    vendor = who,
                                    zone = zone,
                                    map = map,
                                    x = x,
                                    y = y,
                                    price = RepPrice(faction, itemID),
                                    prof = prof,
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    return rows, items
end

local function RepSentence(row)
    local title = ItemLabel(row.itemID) or "the recipe"
    local standing = StandingLabel(row.standing) or ("standing " .. row.standing)
    local bits = {}
    local where = row.zone
    local at = PointText(row.x, row.y)
    if row.vendor and where and at then
        bits[#bits + 1] = "Buy " .. title .. " from " .. row.vendor .. " in " .. where .. ", near " .. at .. "."
    elseif row.vendor and where then
        bits[#bits + 1] = "Buy " .. title .. " from " .. row.vendor .. " in " .. where .. "."
    elseif row.vendor and at then
        bits[#bits + 1] = "Buy " .. title .. " from " .. row.vendor .. " near " .. at .. "."
    elseif row.vendor then
        bits[#bits + 1] = "Buy " .. title .. " from " .. row.vendor .. ". The journal does not name the zone."
    elseif where then
        bits[#bits + 1] = "The journal lists " .. title .. " in " .. where .. " and does not name the vendor."
    else
        bits[#bits + 1] = "The journal lists " .. title .. " and does not name the vendor or the zone."
    end
    bits[#bits + 1] = standing .. " with " .. row.faction .. " is required."
    local price = PriceText(row.price)
    if price then bits[#bits + 1] = "The journal prices it at " .. price .. "." end
    return table.concat(bits, " ")
end

local function RecipeBook(data, profs)
    local book = {}
    if type(data) ~= "table" then return book end
    for p = 1, #profs do
        local prof = data[profs[p]]
        if type(prof) == "table" and type(prof.recipes) == "table" then
            for i = 1, #prof.recipes do
                local recipe = prof.recipes[i]
                local item = type(recipe) == "table" and recipe.recipe or nil
                if type(item) == "number" and not book[item] then book[item] = recipe end
            end
        end
    end
    return book
end

local function AddReputation(found, n, rows, book, ranks)
    local names = ProfessionNames()
    for i = 1, #rows do
        local row = rows[i]
        local known = book[row.itemID]
        local spell = TaughtSpell(row.itemID)
        if not spell and type(known) == "table" and type(known.spell) == "number" then spell = known.spell end
        local skill = 0
        if type(known) == "table" and type(known.skill) == "number" and known.skill > 0 then skill = known.skill end
        local text = RepSentence(row)
        if skill > 0 then text = text .. " It asks for skill " .. skill .. "." end
        local standing = StandingLabel(row.standing) or ("standing " .. row.standing)
        local line = standing
        if row.vendor then line = standing .. " · " .. row.vendor end
        local profId = names[row.prof]
        n = n + 1
        found[#found + 1] = {
            rank = ranks[row.prof] or 50,
            order = 4,
            place = row.faction,
            skill = row.standing,
            spell = spell or row.itemID,
            index = n,
            step = {
                kind = "recipe",
                spell = spell,
                optional = false,
                match = "bis",
                visible = true,
                segment = row.faction .. " - Vendor",
                zone = row.prof,
                profId = profId,
                profName = row.prof,
                level = skill > 0 and skill or 1,
                title = ItemLabel(row.itemID) or SpellLabel(spell) or "Recipe",
                text = text,
                baseText = text,
                map = row.map,
                x = row.x,
                y = row.y,
                itemID = row.itemID,
                rewards = { row.itemID },
                dropLine = line,
            },
        }
    end
    return n
end

local function SpotsFor(recipe, side)
    if type(recipe) ~= "table" then return nil end
    if recipe.source == "vendor" then return VendorSpots(recipe, side) end
    if recipe.source == "quest" then return QuestSpots(recipe, side) end
    if recipe.source == "drop" then return DropSpot(recipe) end
    return nil
end

local function Segment(tag, place)
    if type(place) == "string" and place ~= "" then return tag .. " - " .. place end
    return tag
end

local function MakeStep(recipe, spot, profName, profId)
    local recipeId = recipe.recipe
    local name = ItemLabel(recipeId) or SpellLabel(recipe.spell) or "Recipe"
    local skill = type(recipe.skill) == "number" and recipe.skill or 0
    local text = spot.text or ""
    if skill > 0 then text = text .. " It asks for skill " .. skill .. "." end
    local step = {
        kind = "recipe",
        spell = recipe.spell,
        optional = false,
        match = "bis",
        visible = true,
        segment = Segment(spot.tag, spot.place),
        zone = profName,
        profId = profId,
        profName = profName,
        level = skill > 0 and skill or 1,
        title = name,
        text = text,
        baseText = text,
        map = spot.map,
        x = spot.x,
        y = spot.y,
    }
    if type(spot.line) == "string" and spot.line ~= "" then
        step.dropLine = spot.line
    elseif skill > 0 then
        step.dropLine = "Skill " .. skill
    end
    if spot.tag == "World Drops" then step.worldDrop = true end
    if type(recipeId) == "number" and recipeId > 0 then
        step.rewards = { recipeId }
        step.itemID = recipeId
    end
    return step
end

local function FinderBefore(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    if a.order ~= b.order then return a.order < b.order end
    if a.place ~= b.place then return a.place < b.place end
    if a.skill ~= b.skill then return a.skill < b.skill end
    if a.spell ~= b.spell then return a.spell < b.spell end
    return a.index < b.index
end

local function Fill(steps, note, guide, data, profs, side)
    local rank = {}
    for i = 1, #profs do rank[profs[i]] = i end
    local found = {}
    local n = 0
    local ranks = NameRank()
    local repRows, repItems = ReputationRows(side, SkillSet(), ranks)
    local book = RecipeBook(data, profs)
    for p = 1, #profs do
        local profId = profs[p]
        local prof = data[profId]
        if type(prof) == "table" and type(prof.recipes) == "table" then
            local profName = SpellLabel(prof.skillSpell) or "Profession"
            local here = rank[profId] or 99
            for i = 1, #prof.recipes do
                local recipe = prof.recipes[i]
                local itemID = type(recipe) == "table" and recipe.recipe or nil
                local skipVendor = type(recipe) == "table" and recipe.source == "vendor"
                    and type(itemID) == "number" and repItems[itemID]
                local spots = (not skipVendor) and SpotsFor(recipe, side) or nil
                if spots and type(recipe.spell) == "number" then
                    local skill = type(recipe.skill) == "number" and recipe.skill or 0
                    for s = 1, #spots do
                        local spot = spots[s]
                        n = n + 1
                        found[#found + 1] = {
                            rank = here,
                            order = spot.order or 9,
                            place = (type(spot.place) == "string" and spot.place) or "",
                            skill = skill,
                            spell = recipe.spell,
                            index = n,
                            step = MakeStep(recipe, spot, profName, profId),
                        }
                    end
                end
            end
        end
    end
    n = AddReputation(found, n, repRows, book, ranks)
    table.sort(found, FinderBefore)
    local count = 0
    for i = 1, #found do
        steps[#steps + 1] = found[i].step
        count = count + 1
    end
    if count == 0 then
        note.visible = true
        note.text = "None of your professions have a vendor, quest, world-drop, or reputation recipe on the loaded list."
        note.baseText = note.text
    end
    guide.questCount = count
    guide.visibleQuests = count
end

function SG.Recipes.Build()
    local side = Side()
    local guide = {
        id = GUIDE_ID,
        title = "Recipes",
        group = "Professions",
        category = "professions",
        side = "B",
        place = "Professions",
        blurb = "Recipes a vendor sells, a quest rewards, that drop in the world, or that a reputation quartermaster sells, for a profession this character has. Each profession is its own tab. On that tab the lines are grouped by vendors, quests, or world drops, then the zone or instance. A reputation recipe is grouped as the faction and Vendor. It names the quartermaster, the zone, the map point, and the standing when the journal has them. A world drop names the mob, where that mob stands when Forever Guide stored a point, and the percent when its item search has them. That percent is the classic chance Forever Guide ships, not a Forever Wowhead rate. A sighting with no percent says so. A dungeon names its entrance when that point is stored. A bind-on-equip drop adds Auctionator's last scanned auction price when that addon has one. Trainer recipes stay at the trainer. A learned recipe is marked done and leaves the list. This does not level the profession for you.",
        min = 1,
        max = 60,
        steps = {},
        hiddenQuests = 0,
        questCount = 0,
        visibleQuests = 0,
        empty = false,
        route = false,
        keep = true,
        recipes = true,
        profKey = DataKey(),
    }
    local note = {
        kind = "note",
        recipeNote = true,
        optional = false,
        match = "bis",
        visible = false,
        segment = "Recipes",
        zone = "Recipes",
        level = 1,
        title = "No recipes to find",
        text = "No vendor, quest, world-drop, or reputation recipe is left for a profession you have.",
        baseText = "No vendor, quest, world-drop, or reputation recipe is left for a profession you have.",
    }
    local steps = { note }
    local ns = Namespace()
    local data = ns and ns.RecipeData
    local profs = ProfessionIds()
    if type(data) ~= "table" then
        note.title = "Recipe list missing"
        note.text = "The recipe list loads with NaowhForever_Professions."
        note.baseText = note.text
        note.visible = true
    elseif #profs == 0 then
        note.title = "No profession yet"
        note.text = "Learn a profession. This list then names recipes from vendors, quests, and world drops."
        note.baseText = note.text
        note.visible = true
    else
        Fill(steps, note, guide, data, profs, side)
    end
    for i = 1, #steps do
        steps[i].index = i
        steps[i].guide = guide.id
    end
    guide.steps = steps
    return guide
end

function SG.Recipes.Tabs(guide)
    local tabs, seen = {}, {}
    if not guide or not guide.steps then return tabs end
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        local id = step.profId
        if type(id) == "number" and id > 0 and not seen[id] then
            seen[id] = true
            local name = step.profName
            if type(name) ~= "string" or name == "" then name = "Profession" end
            tabs[#tabs + 1] = { id = id, name = name }
        end
    end
    return tabs
end

function SG.Recipes.Selected(guide)
    local tabs = SG.Recipes.Tabs(guide)
    if #tabs == 0 then return nil end
    local want = SG.db and SG.db.recipeProf
    for i = 1, #tabs do
        if tabs[i].id == want then return want end
    end
    return tabs[1].id
end

function SG.Recipes.Apply(guide)
    if not guide or not guide.recipes or not guide.steps then return end
    local chosen = SG.Recipes.Selected(guide)
    if SG.db and chosen and SG.db.recipeProf ~= chosen then SG.db.recipeProf = chosen end
    local row
    if SG.Engine and SG.Engine.Progress then row = SG.Engine.Progress(guide.id) end
    local any = false
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if not step.recipeNote then
            local known = SpellKnown(step.spell)
            local closed = known or (row and row.done[i] and true or false)
            if known and row and row.hold ~= i then row.done[i] = true end
            if step.worldDrop and type(step.itemID) == "number" then
                local extra, money = AuctionSentence(step.itemID)
                local body = step.baseText or step.text or ""
                if type(extra) == "string" then
                    step.text = body .. extra
                else
                    step.text = body
                end
                if step.baseLine == nil then step.baseLine = step.dropLine or "" end
                if type(money) == "string" and money ~= "" then
                    if step.baseLine ~= "" then
                        step.dropLine = step.baseLine .. " · AH " .. money
                    else
                        step.dropLine = "AH " .. money
                    end
                else
                    step.dropLine = step.baseLine ~= "" and step.baseLine or nil
                end
            end
            local onTab = (not chosen) or step.profId == chosen
            if closed or not onTab then
                step.visible = false
            else
                step.visible = true
                any = true
            end
        end
    end
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.recipeNote then
            local missing = step.title == "Recipe list missing" or step.title == "No profession yet"
            step.visible = missing or not any
        end
    end
end

function SG.Recipes.Install(quiet)
    if not SG.Engine or not SG.Engine.guides or not SG.Engine.byId then return end
    local guide = SG.Recipes.Build()
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
    SG.Recipes.Apply(guide)
    if quiet then return end
    local active = SG.Engine.Active and SG.Engine.Active()
    if active and active.recipes and SG.Engine.PlaceCursor then
        SG.Engine.PlaceCursor(active)
    end
    if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
end

function SG.Recipes.Refresh()
    if SG.Recipes.WatchPrices then SG.Recipes.WatchPrices() end
    local current = SG.Engine and SG.Engine.Get and SG.Engine.Get(GUIDE_ID)
    if not current or current.profKey ~= DataKey() then
        SG.Recipes.Install()
        return
    end
    SG.Recipes.Apply(current)
    local active = SG.Engine.Active and SG.Engine.Active()
    if active and active.recipes and SG.Engine.PlaceCursor then
        SG.Engine.PlaceCursor(active)
    end
    if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
end

function SG.Recipes.WatchPrices()
    if SG.Recipes.priceWatch then return end
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    local reg = api and api.RegisterForDBUpdate
    if type(reg) ~= "function" then return end
    local ok = pcall(reg, "Stratagem", function()
        if SG.Recipes and SG.Recipes.Refresh then SG.Recipes.Refresh() end
    end)
    if ok then SG.Recipes.priceWatch = true end
end

function SG.Recipes.OnItem(itemID)
    if type(itemID) ~= "number" then return end
    if SG.Recipes.itemWait then return end
    local guide = SG.Engine and SG.Engine.Get and SG.Engine.Get(GUIDE_ID)
    if not guide or not guide.steps then return end
    local hit = false
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.itemID == itemID and step.worldDrop then
            hit = true
            break
        end
    end
    if not hit then return end
    SG.Recipes.itemWait = true
    SG.After(0.2, function()
        SG.Recipes.itemWait = false
        local current = SG.Engine and SG.Engine.Get and SG.Engine.Get(GUIDE_ID)
        if current then SG.Recipes.Apply(current) end
        local active = SG.Engine and SG.Engine.Active and SG.Engine.Active()
        if not active or not active.recipes then return end
        if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
        if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
    end)
end
