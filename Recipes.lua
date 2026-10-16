-- Recipes.lua: where to buy or loot a recipe for a profession this character has.
-- Trainer recipes stay with the trainer. This list does not invent a vendor, a drop, or a price.
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

local function VendorText(recipe, side)
    local rows = recipe.vendors
    if type(rows) ~= "table" then
        return "The recipe comes from a vendor. The list does not name them.", nil, nil, nil, nil
    end
    local other = false
    for i = 1, #rows do
        local row = rows[i]
        if type(row) == "table" and FactionOK(row[3], side) then
            local name = row[2]
            local map, x, y = row[4], row[5], row[6]
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
            if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
                map, x, y = nil, nil, nil
            end
            return table.concat(bits, " "), map, x, y, ZoneName(map)
        elseif type(row) == "table" and type(row[3]) == "string" and not FactionOK(row[3], side) then
            other = true
        end
    end
    if other then return nil end
    return "The recipe comes from a vendor. The list does not name them.", nil, nil, nil, nil
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

local function SourceOf(recipe, side)
    if type(recipe) ~= "table" then return nil end
    if recipe.source == "vendor" then
        local text, map, x, y, place = VendorText(recipe, side)
        if not text then return nil end
        return text, map, x, y, place, "Vendor"
    end
    if recipe.source == "drop" then
        local text, place = DropText(recipe)
        return text, nil, nil, nil, place, "Drop"
    end
    return nil
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
        blurb = "Recipes a vendor sells, or that drop, for a profession this character has. Trainer recipes stay at the trainer. A learned recipe leaves the list. This does not level the profession for you.",
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
        text = "No vendor or drop recipe is left for a profession you have.",
        baseText = "No vendor or drop recipe is left for a profession you have.",
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
        note.text = "Learn a profession. This list then names recipes a vendor sells, or that drop, so you can go find them."
        note.baseText = note.text
        note.visible = true
    else
        local rank = {}
        for i = 1, #profs do rank[profs[i]] = i end
        local groups, order = {}, {}
        for p = 1, #profs do
            local profId = profs[p]
            local prof = data[profId]
            if type(prof) == "table" and type(prof.recipes) == "table" then
                local profName = SpellLabel(prof.skillSpell) or "Profession"
                for i = 1, #prof.recipes do
                    local recipe = prof.recipes[i]
                    local text, map, x, y, place, tag = SourceOf(recipe, side)
                    if text and type(recipe.spell) == "number" then
                        local group = groups[profId]
                        if not group then
                            group = { title = profName, rank = rank[profId] or 99, steps = {} }
                            groups[profId] = group
                            order[#order + 1] = profId
                        end
                        local recipeId = recipe.recipe
                        local name = ItemLabel(recipeId) or SpellLabel(recipe.spell) or "Recipe"
                        local skill = type(recipe.skill) == "number" and recipe.skill or 0
                        local skillNote = ""
                        if skill > 0 then skillNote = " It asks for skill " .. skill .. "." end
                        local step = {
                            kind = "recipe",
                            spell = recipe.spell,
                            optional = false,
                            match = "bis",
                            visible = true,
                            segment = profName,
                            zone = profName,
                            level = skill > 0 and skill or 1,
                            title = name,
                            text = text .. skillNote,
                            baseText = text .. skillNote,
                            dropLine = tag .. (skill > 0 and ("  Skill " .. skill) or ""),
                            placeName = place,
                            map = map,
                            x = x,
                            y = y,
                        }
                        if type(recipeId) == "number" and recipeId > 0 then
                            step.rewards = { recipeId }
                            step.itemID = recipeId
                        end
                        group.steps[#group.steps + 1] = step
                    end
                end
            end
        end
        table.sort(order, function(a, b)
            if groups[a].rank ~= groups[b].rank then return groups[a].rank < groups[b].rank end
            if groups[a].title ~= groups[b].title then return groups[a].title < groups[b].title end
            return a < b
        end)
        local count = 0
        for i = 1, #order do
            local group = groups[order[i]]
            table.sort(group.steps, function(a, b)
                if a.level ~= b.level then return a.level < b.level end
                return (a.spell or 0) < (b.spell or 0)
            end)
            for s = 1, #group.steps do
                steps[#steps + 1] = group.steps[s]
                count = count + 1
            end
        end
        if count == 0 then
            note.visible = true
            note.text = "None of your professions have a vendor or drop recipe on the loaded list."
            note.baseText = note.text
        end
        guide.questCount = count
        guide.visibleQuests = count
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
