-- Recipes.lua: where to buy, earn, or loot a recipe for a profession this character has.
-- Trainer recipes stay with the trainer. This list does not invent a vendor, a quest, a drop, or a price.
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
    local ids = ProfessionIds()
    local bits = { loaded }
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

local function MobPhrase(mob)
    local name = mob[1]
    local pct = mob[2]
    local tag = mob[4]
    local who = type(name) == "string" and name ~= "" and name or nil
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

local function ZoneTitle(row)
    local stored = row[1]
    local map = row[2]
    if type(map) == "number" and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(map)
        if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return info.name
        end
    end
    if type(stored) == "string" and stored ~= "" then return stored end
    return nil
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
                bucket[#bucket + 1] = { got, ranked[i][2] }
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
            bits[#bits + 1] = bucket[m][1] .. " (" .. TrimPercent(bucket[m][2]) .. "%)"
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
            bucket[#bucket + 1] = name
        end
    end
    if #order == 0 then return nil end
    local spots = {}
    for i = 1, #order do
        local place = order[i]
        local where = place ~= "" and place or nil
        local text = "Questie names " .. table.concat(groups[place], ", ") .. "."
        if where then text = text .. " It places that in " .. where .. "." end
        text = text .. " It has no percent."
        spots[#spots + 1] = {
            text = text,
            place = where,
            tag = "World Drops",
            order = 3,
            line = groups[place][1],
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

local function SpotsFor(recipe, side)
    if type(recipe) ~= "table" then return nil end
    if recipe.source == "vendor" then return VendorSpots(recipe, side) end
    if recipe.source == "quest" then return QuestSpots(recipe, side) end
    if recipe.source == "drop" then return DropSpot(recipe) end
    return nil
end

local function Segment(profName, tag, place)
    local head = profName .. " - " .. tag
    if type(place) == "string" and place ~= "" then return head .. " - " .. place end
    return head
end

local function MakeStep(recipe, spot, profName)
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
        segment = Segment(profName, spot.tag, spot.place),
        zone = profName,
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
    for p = 1, #profs do
        local profId = profs[p]
        local prof = data[profId]
        if type(prof) == "table" and type(prof.recipes) == "table" then
            local profName = SpellLabel(prof.skillSpell) or "Profession"
            local here = rank[profId] or 99
            for i = 1, #prof.recipes do
                local recipe = prof.recipes[i]
                local spots = SpotsFor(recipe, side)
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
                            step = MakeStep(recipe, spot, profName),
                        }
                    end
                end
            end
        end
    end
    table.sort(found, FinderBefore)
    local count = 0
    for i = 1, #found do
        steps[#steps + 1] = found[i].step
        count = count + 1
    end
    if count == 0 then
        note.visible = true
        note.text = "None of your professions have a vendor, quest, or world-drop recipe on the loaded list."
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
        blurb = "Recipes a vendor sells, a quest rewards, or that drop in the world, for a profession this character has. Grouped by profession, then vendors, quests, or world drops, then the zone or instance. A world drop names the mob and the percent when Forever Guide's item search has them. That percent is the classic chance Forever Guide ships, not a Forever Wowhead rate. A sighting with no percent says so. Trainer recipes stay at the trainer. A learned recipe leaves the list. This does not level the profession for you.",
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
        text = "No vendor, quest, or world-drop recipe is left for a profession you have.",
        baseText = "No vendor, quest, or world-drop recipe is left for a profession you have.",
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

function SG.Recipes.Apply(guide)
    if not guide or not guide.recipes or not guide.steps then return end
    local row
    if SG.Engine and SG.Engine.Progress then row = SG.Engine.Progress(guide.id) end
    local any = false
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if not step.recipeNote then
            local known = SpellKnown(step.spell)
            local closed = known or (row and row.done[i] and true or false)
            if known and row and row.hold ~= i then row.done[i] = true end
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
