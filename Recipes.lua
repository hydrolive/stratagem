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

local function DropText(recipe)
    local extra = {}
    if recipe.chests then extra[#extra + 1] = "chests" end
    if recipe.fished then extra[#extra + 1] = "fishing" end
    if recipe.pickpocket then extra[#extra + 1] = "pickpocketing" end
    local tail = ""
    if #extra > 0 then tail = " The list also names " .. table.concat(extra, ", ") .. "." end
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
    local text, named = DropText(recipe)
    local place = DropPlace(recipe) or named
    if type(place) ~= "string" or place == "" then place = nil end
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
    if skill > 0 then step.dropLine = "Skill " .. skill end
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
        blurb = "Recipes a vendor sells, a quest rewards, or that drop in the world, for a profession this character has. Grouped by profession, then vendors, quests, or world drops, then the zone or dungeon the list names. Trainer recipes stay at the trainer. A learned recipe leaves the list. This does not level the profession for you.",
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
