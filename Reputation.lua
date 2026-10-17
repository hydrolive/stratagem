-- Reputation.lua: reputation gear, the hand-ins that raise it, and one guide per journal faction.
-- Factions, turn-ins, prices, and quartermasters are read from NaowhForever.Journal at runtime.
-- Nothing in this file invents a faction, a turn-in, a mob, a price, or a recipe.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Reputation = {}

local GEAR_ID = "rep-gear"
local RECIPE_ID = "rep-recipes"
local NAME_CAP = 8
local CHAIN_BASE = 100

local polling = false
local refreshSoon = false

local function Journal()
    local ns = _G.NaowhForever or _G.NaowwahForever
    return ns and ns.Journal
end

local function PlayerSide()
    if SG.playerSide == "A" or SG.playerSide == "H" then return SG.playerSide end
    if SG.PlayerSide then
        local side = SG.PlayerSide()
        if side == "A" or side == "H" then return side end
    end
    return "H"
end

local function RepApi()
    local journal = Journal()
    return journal and journal.Reputation
end

local function ExaltedCut()
    local api = RepApi()
    if api and type(api.EXALTED) == "number" then return api.EXALTED end
    return 8
end

local function StandingName(reaction)
    if type(reaction) ~= "number" then return "The required standing" end
    local api = RepApi()
    if api and api.Label then
        local ok, label = pcall(api.Label, reaction)
        if ok and type(label) == "string" and label ~= "" then return label end
    end
    if GetText then
        local sex = UnitSex and UnitSex("player") or nil
        local ok, label = pcall(GetText, "FACTION_STANDING_LABEL" .. reaction, sex)
        if ok and type(label) == "string" and label ~= "" then return label end
    end
    return "standing " .. reaction
end

local function ReactionOf(factionID)
    if type(factionID) ~= "number" then return nil end
    if not C_Reputation or not C_Reputation.GetFactionDataByID then return nil end
    local ok, data = pcall(C_Reputation.GetFactionDataByID, factionID)
    if not ok or type(data) ~= "table" then return nil end
    if type(data.reaction) ~= "number" then return nil end
    return data.reaction
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

local function ItemLabel(itemID)
    if type(itemID) ~= "number" then return "an item" end
    local ItemDB = _G.ItemDB
    if ItemDB and ItemDB.name then
        local ok, name = pcall(ItemDB.name, itemID)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    if SG.ItemName then
        local name = SG.ItemName(itemID, true)
        if type(name) == "string" and name ~= "" then return name end
    end
    return "item " .. itemID
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

local function TaughtSpell(itemID)
    local ItemDB = _G.ItemDB
    if not ItemDB or not ItemDB.teachesSpell then return nil end
    local ok, spell = pcall(ItemDB.teachesSpell, itemID)
    if ok and type(spell) == "number" and spell > 0 then return spell end
    return nil
end

local function SkillLines()
    local order, seen = {}, {}
    if not GetProfessions or not GetProfessionInfo then return order, seen end
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
    return order, seen
end

local function DataKey()
    local journal = Journal()
    local loaded = (journal and journal.Factions) and "1" or "0"
    local ids = SkillLines()
    local bits = { loaded }
    for i = 1, #ids do bits[#bits + 1] = tostring(ids[i]) end
    return table.concat(bits, ",")
end

local function FactionKey(faction)
    if type(faction.key) == "string" and faction.key ~= "" then return faction.key end
    if type(faction.id) == "number" then return "id" .. faction.id end
    return nil
end

local function SideCode(faction)
    if faction.side == "Alliance" then return "A" end
    if faction.side == "Horde" then return "H" end
    return "B"
end

local function SideMatches(faction, side)
    local code = SideCode(faction)
    return code == "B" or code == side
end

local function FactionList()
    local journal = Journal()
    if not journal or not journal.Factions then return nil end
    local ok, list = pcall(journal.Factions, "reputation")
    if not ok or type(list) ~= "table" then return nil end
    return list
end

local function SortedFactions(side)
    local list = FactionList()
    if not list then return nil end
    local out = {}
    for i = 1, #list do
        local faction = list[i]
        if type(faction) == "table" and not faction.unreleased and FactionKey(faction) then
            if type(faction.name) == "string" and faction.name ~= "" then
                if not side or SideMatches(faction, side) then
                    out[#out + 1] = faction
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return FactionKey(a) < FactionKey(b)
    end)
    return out
end

local function RecipeSubclass(itemID)
    local journal = Journal()
    local loot = journal and journal.Loot
    if not loot or not loot.Recipe then return nil end
    local ok, subclass = pcall(loot.Recipe, itemID)
    if not ok or type(subclass) ~= "number" then return nil end
    return subclass
end

local function RecipeMine(subclass, skills)
    local journal = Journal()
    local loot = journal and journal.Loot
    if not loot or not loot.RecipeYours then return false end
    local ok, yours = pcall(loot.RecipeYours, subclass, { skills = skills })
    if not ok then return false end
    return yours and true or false
end

-- Journal pins are 0-100. Nav divides by 100. Do not divide here.
local function Pin(spot)
    if type(spot) ~= "table" then return nil end
    local name = spot.name
    if type(name) ~= "string" or name == "" then name = nil end
    local map, x, y = spot.map, spot.x, spot.y
    if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return name
    end
    return name, map, x, y
end

local function PickQuest(quests, side)
    if type(quests) ~= "table" then return nil end
    local both
    for i = 1, #quests do
        local row = quests[i]
        if type(row) == "table" then
            if row[2] == side then return row end
            if row[2] == "B" and not both then both = row end
        end
    end
    return both
end

local function TakesText(takes)
    if type(takes) ~= "table" then return nil end
    local bits = {}
    for i = 1, #takes, 2 do
        local id, count = takes[i], takes[i + 1]
        if type(id) == "number" and type(count) == "number" then
            bits[#bits + 1] = count .. " " .. ItemLabel(id)
        end
    end
    if #bits == 0 then return nil end
    return table.concat(bits, ", ")
end

local function FromPlace(place)
    if type(place) ~= "table" then return nil end
    local zone = place[1]
    if type(zone) ~= "string" or zone == "" then return nil end
    local stored = {}
    for i = 3, #place do
        local mob = place[i]
        if type(mob) == "string" and mob ~= "" then
            stored[#stored + 1] = mob
        end
    end
    local limit = NAME_CAP
    if #stored < limit then limit = #stored end
    local show = {}
    for i = 1, limit do show[i] = stored[i] end
    local unnamed = 0
    if type(place[2]) == "number" then
        unnamed = place[2] - #stored
        if unnamed < 0 then unnamed = 0 end
    end
    local more = unnamed + (#stored - #show)
    local text = zone
    if #show > 0 then text = zone .. ": " .. table.concat(show, ", ") end
    if more > 0 then text = text .. ", and the journal lists " .. more .. " more" end
    return text
end

local function FromText(from)
    if type(from) ~= "table" then return nil end
    local bits = {}
    for i = 1, #from do
        local line = FromPlace(from[i])
        if line then bits[#bits + 1] = line end
    end
    if #bits == 0 then return nil end
    return table.concat(bits, ". ")
end

local function TurnInText(turnin, quest)
    local bits = {}
    bits[#bits + 1] = "Hand in " .. turnin.name .. "."
    local takes = TakesText(turnin.takes)
    if takes then bits[#bits + 1] = "It takes " .. takes .. "." end
    if type(turnin.rep) == "number" then
        bits[#bits + 1] = string.format("+%d reputation each time you hand it in.", turnin.rep)
    end
    if quest and type(quest[3]) == "string" and quest[3] ~= "" then
        bits[#bits + 1] = quest[3] .. "."
    end
    local where = FromText(turnin.from)
    if where then bits[#bits + 1] = "Where to get them: " .. where .. "." end
    return table.concat(bits, " ")
end

local function Progress(guide)
    if not guide or not guide.id then return nil end
    if SG.Engine and SG.Engine.Progress then return SG.Engine.Progress(guide.id) end
    return nil
end

local function BlankGuide(id, title, side, blurb, place)
    return {
        id = id,
        title = title,
        group = "Reputation",
        category = "reputation",
        side = side,
        place = place or title,
        blurb = blurb,
        min = 1,
        max = 60,
        steps = {},
        hiddenQuests = 0,
        questCount = 0,
        visibleQuests = 0,
        empty = false,
        route = false,
        reputation = true,
        repKey = DataKey(),
    }
end

local function NoteStep(title, text, segment)
    return {
        kind = "note",
        repNote = true,
        optional = false,
        match = "bis",
        visible = true,
        segment = segment or title,
        zone = segment or title,
        level = 1,
        title = title,
        text = text,
        baseText = text,
    }
end

local function Stamp(guide, steps)
    local minLevel, maxLevel
    for i = 1, #steps do
        local step = steps[i]
        step.index = i
        step.guide = guide.id
        if step.repWork and step.level then
            if not minLevel or step.level < minLevel then minLevel = step.level end
            if not maxLevel or step.level > maxLevel then maxLevel = step.level end
        end
    end
    guide.steps = steps
    guide.min = minLevel or 1
    guide.max = maxLevel or 60
end

local function GearLevel(fact)
    if (fact.ilvl or 0) > 1 then return fact.ilvl end
    if (fact.req or 0) > 1 then return fact.req end
    return 1
end

local function PriceOf(faction, itemID)
    local prices = faction.prices
    if type(prices) ~= "table" then return nil end
    local copper = prices[itemID]
    if type(copper) ~= "number" or copper <= 0 then return nil end
    return copper
end

-- Class-usable armor and weapons on this faction. Recipes and consumables stay off.
local function WearableGear(faction, class)
    local found = {}
    if not class or not SG.Gear or not SG.Gear.Fact or not SG.Gear.Usable then return found end
    local tiers = faction.tiers
    if type(tiers) ~= "table" then return found end
    local seen = {}
    for t = 1, #tiers do
        local tier = tiers[t]
        local items = tier and tier.items
        local standing = tier and tier.standing
        if type(items) == "table" and type(standing) == "number" then
            for n = 1, #items do
                local itemID = items[n]
                if type(itemID) == "number" and itemID > 0 and not seen[itemID] and not RecipeSubclass(itemID) then
                    local fact = SG.Gear.Fact(itemID)
                    if fact and fact.slot and (fact.ilvl or 0) > 0 and SG.Gear.Usable(class, fact, 60) then
                        seen[itemID] = true
                        found[#found + 1] = { itemID = itemID, standing = standing, fact = fact }
                    end
                end
            end
        end
    end
    table.sort(found, function(a, b)
        if a.standing ~= b.standing then return a.standing < b.standing end
        return a.itemID < b.itemID
    end)
    return found
end

local function FactionRecipes(faction, skills)
    local found = {}
    local tiers = faction.tiers
    if type(tiers) ~= "table" then return found end
    local seen = {}
    for t = 1, #tiers do
        local tier = tiers[t]
        local items = tier and tier.items
        local standing = tier and tier.standing
        if type(items) == "table" and type(standing) == "number" then
            for n = 1, #items do
                local itemID = items[n]
                if type(itemID) == "number" and itemID > 0 and not seen[itemID] then
                    local subclass = RecipeSubclass(itemID)
                    if subclass and RecipeMine(subclass, skills) then
                        seen[itemID] = true
                        found[#found + 1] = {
                            itemID = itemID,
                            standing = standing,
                            spell = TaughtSpell(itemID),
                        }
                    end
                end
            end
        end
    end
    table.sort(found, function(a, b)
        if a.standing ~= b.standing then return a.standing < b.standing end
        return a.itemID < b.itemID
    end)
    return found
end

local function GearLine(step)
    local name = ItemLabel(step.itemID)
    local who = step.vendorName or "the quartermaster"
    local standing = step.repStandingName or "The required standing"
    local faction = step.repFactionName or step.segment or "that reputation"
    local cost = ""
    local price = PriceText(step.repPrice)
    if price then cost = " It costs " .. price .. "." end
    step.title = name
    step.text = string.format("Buy %s from %s. %s with %s is required.%s", name, who, standing, faction, cost)
    step.baseText = step.text
end

local function TurnInStep(turnin, side, segment, forGear, chainGroup, chainPos, factionID)
    if type(turnin) ~= "table" or type(turnin.name) ~= "string" or turnin.name == "" then return nil end
    local quest = PickQuest(turnin.quests, side)
    if not quest then return nil end
    local step = {
        kind = "rep",
        repWork = true,
        optional = forGear and true or false,
        match = "bis",
        visible = true,
        segment = segment,
        zone = segment,
        level = type(turnin.level) == "number" and turnin.level or 1,
        title = turnin.name,
        repFaction = factionID,
    }
    step.text = TurnInText(turnin, quest)
    step.baseText = step.text
    if forGear then
        step.chainLead = true
        step.chainGroup = chainGroup
        step.chainPos = chainPos
    end
    local map, x, y = quest[4], quest[5], quest[6]
    if type(map) == "number" and type(x) == "number" and type(y) == "number" then
        step.map, step.x, step.y = map, x, y
    end
    return step
end

local function AddGearReward(raw, faction, row, who, map, x, y)
    local fact = row.fact
    local step = {
        kind = "gear",
        optional = true,
        match = "bis",
        visible = true,
        sourceKind = "reputation",
        chainGroup = FactionKey(faction),
        chainPos = CHAIN_BASE + row.standing,
        segment = faction.name,
        zone = faction.name,
        level = GearLevel(fact),
        repStanding = row.standing,
        repFaction = faction.id,
        repFactionName = faction.name,
        repStandingName = StandingName(row.standing),
        vendorName = who,
        repPrice = PriceOf(faction, row.itemID),
        itemID = row.itemID,
        gearItem = row.itemID,
        rewards = { row.itemID },
        allRewards = { row.itemID },
    }
    if type(map) == "number" then
        step.map, step.x, step.y = map, x, y
    end
    step.title = "(Optional) " .. faction.name
    step.baseText = step.title
    step.text = step.baseText
    raw[#raw + 1] = step
end

-- Gear-tab rows. Turn-ins are added only when this faction has gear this class can wear.
function SG.Reputation.AppendGear(raw, class, side)
    if type(raw) ~= "table" or not class or (side ~= "A" and side ~= "H") then return end
    local factions = SortedFactions(side)
    if not factions then return end
    local seen = {}
    for i = 1, #factions do
        local faction = factions[i]
        local gear = WearableGear(faction, class)
        local kept = {}
        for g = 1, #gear do
            local row = gear[g]
            if not seen[row.itemID] then
                seen[row.itemID] = true
                kept[#kept + 1] = row
            end
        end
        if #kept > 0 then
            local key = FactionKey(faction)
            local who, map, x, y = Pin(faction.quartermaster)
            local turnins = faction.turnins
            local pos = 0
            if type(turnins) == "table" then
                for t = 1, #turnins do
                    pos = pos + 1
                    local step = TurnInStep(turnins[t], side, faction.name, true, key, pos, faction.id)
                    if step then raw[#raw + 1] = step end
                end
            end
            for g = 1, #kept do
                AddGearReward(raw, faction, kept[g], who, map, x, y)
            end
        end
    end
end

-- Hide hand-ins once the character already has the standing the visible rewards need.
-- One hand-in does not finish a repeatable. This does not mark the line done.
function SG.Reputation.Fold(guide)
    if not guide or not guide.gear or not guide.steps then return end
    local steps = guide.steps
    local need = {}
    for i = 1, #steps do
        local step = steps[i]
        if step.sourceKind == "reputation" and step.chainGroup and not step.chainLead
            and step.visible and step.gearState == "show" and type(step.repStanding) == "number" then
            local prev = need[step.chainGroup]
            if not prev or step.repStanding > prev then need[step.chainGroup] = step.repStanding end
        end
    end
    local reaction = {}
    for i = 1, #steps do
        local step = steps[i]
        local standing = step.chainLead and step.chainGroup and need[step.chainGroup]
        if standing and type(step.repFaction) == "number" then
            local have = reaction[step.repFaction]
            if have == nil then
                have = ReactionOf(step.repFaction)
                if have == nil then have = false end
                reaction[step.repFaction] = have
            end
            if type(have) == "number" and have >= standing then
                step.visible = false
                step.gearState = "wait"
            end
        end
    end
end

local function BuildGear(side, key)
    local guide = BlankGuide(
        GEAR_ID,
        "Gear Upgrades",
        side,
        "Reputation rewards that beat what you have equipped or in your bags for your spec, within 3 levels. They are grouped by reputation. The hand-ins are on that reputation's guide and on the Gear Reputation tab.",
        "Reputation"
    )
    guide.repKind = "gear"
    guide.repKey = key
    local note = NoteStep(
        "Reputation list missing",
        "The reputation list loads with NaowhForever_DungeonJournal.",
        "Gear Upgrades"
    )
    note.repMissing = true
    local steps = { note }
    local factions = SortedFactions(side)
    local class = SG.classToken
    if not factions then
        Stamp(guide, steps)
        return guide
    end
    if not class then
        note.repMissing = nil
        note.repNoProf = true
        note.title = "No class yet"
        note.text = "Gear upgrades load once your class is known."
        note.baseText = note.text
        Stamp(guide, steps)
        return guide
    end
    note.visible = false
    note.repMissing = nil
    local count = 0
    local seen = {}
    for i = 1, #factions do
        local faction = factions[i]
        local gear = WearableGear(faction, class)
        local who, map, x, y = Pin(faction.quartermaster)
        for g = 1, #gear do
            local row = gear[g]
            if not seen[row.itemID] then
                seen[row.itemID] = true
                local step = {
                    kind = "gear",
                    repWork = true,
                    optional = false,
                    match = "bis",
                    visible = true,
                    segment = faction.name,
                    zone = faction.name,
                    level = GearLevel(row.fact),
                    itemID = row.itemID,
                    rewards = { row.itemID },
                    repStanding = row.standing,
                    repStandingName = StandingName(row.standing),
                    repFaction = faction.id,
                    repFactionName = faction.name,
                    vendorName = who,
                    repPrice = PriceOf(faction, row.itemID),
                }
                if type(map) == "number" then
                    step.map, step.x, step.y = map, x, y
                end
                GearLine(step)
                steps[#steps + 1] = step
                count = count + 1
            end
        end
    end
    if count == 0 then
        note.visible = true
        note.title = "Nothing to upgrade"
        note.text = "No reputation reward in the next 3 levels beats what you have on for this spec."
        note.baseText = note.text
    end
    Stamp(guide, steps)
    return guide
end

local function RecipeLine(step)
    local name = ItemLabel(step.itemID)
    local who = step.vendorName or "the quartermaster"
    local standing = step.repStandingName or "The required standing"
    local faction = step.repFactionName or step.segment or "that reputation"
    local cost = ""
    local price = PriceText(step.repPrice)
    if price then cost = " It costs " .. price .. "." end
    local taught = ""
    local spellName = SpellLabel(step.spell)
    if spellName then taught = " It teaches " .. spellName .. "." end
    step.title = name
    step.text = string.format("Buy %s from %s. %s with %s is required.%s%s", name, who, standing, faction, cost, taught)
    step.baseText = step.text
end

local function BuildRecipes(side, key)
    local guide = BlankGuide(
        RECIPE_ID,
        "Professions",
        side,
        "Recipes the reputation quartermasters sell for a profession this character has. A learned recipe leaves the list when the client names the spell it teaches.",
        "Reputation"
    )
    guide.repKind = "recipes"
    guide.repKey = key
    local note = NoteStep(
        "Reputation list missing",
        "The reputation list loads with NaowhForever_DungeonJournal.",
        "Professions"
    )
    note.repMissing = true
    local steps = { note }
    local factions = SortedFactions(side)
    if not factions then
        Stamp(guide, steps)
        return guide
    end
    local order, skills = SkillLines()
    if #order == 0 then
        note.repMissing = nil
        note.repNoProf = true
        note.title = "No profession yet"
        note.text = "Learn a profession. This list then names reputation recipes for the professions you have."
        note.baseText = note.text
        Stamp(guide, steps)
        return guide
    end
    note.visible = false
    note.repMissing = nil
    local count = 0
    for i = 1, #factions do
        local faction = factions[i]
        local recipes = FactionRecipes(faction, skills)
        local who, map, x, y = Pin(faction.quartermaster)
        for r = 1, #recipes do
            local row = recipes[r]
            local step = {
                kind = "recipe",
                repWork = true,
                optional = false,
                match = "bis",
                visible = true,
                spell = row.spell,
                segment = faction.name,
                zone = faction.name,
                level = row.standing,
                itemID = row.itemID,
                rewards = { row.itemID },
                repStanding = row.standing,
                repStandingName = StandingName(row.standing),
                repFactionName = faction.name,
                vendorName = who,
                repPrice = PriceOf(faction, row.itemID),
            }
            if type(map) == "number" then
                step.map, step.x, step.y = map, x, y
            end
            RecipeLine(step)
            steps[#steps + 1] = step
            count = count + 1
        end
    end
    if count == 0 then
        note.visible = true
        note.title = "No recipes"
        note.text = "None of your professions have a reputation recipe on the journal list."
        note.baseText = note.text
    end
    Stamp(guide, steps)
    return guide
end

local function BuildFaction(faction, key)
    local side = SideCode(faction)
    local questSide = side
    if questSide == "B" then questSide = PlayerSide() end
    local place = faction.zone
    if type(place) ~= "string" or place == "" then place = faction.name end
    local guide = BlankGuide(
        "rep-" .. FactionKey(faction),
        faction.name,
        side,
        "Turn-ins and the quartermaster the journal lists for " .. faction.name .. ". The steps stay up until you are exalted. Handing one in does not finish it.",
        place
    )
    guide.repKind = "faction"
    guide.repKey = key
    guide.repFaction = faction.id
    local steps = {}
    local who, map, x, y = Pin(faction.quartermaster)
    if who and type(map) == "number" then
        local step = {
            kind = "rep",
            repWork = true,
            optional = false,
            match = "bis",
            visible = true,
            segment = faction.name,
            zone = faction.name,
            level = 1,
            title = who,
            map = map,
            x = x,
            y = y,
            repFaction = faction.id,
        }
        step.text = "The quartermaster is " .. who .. "."
        step.baseText = step.text
        steps[#steps + 1] = step
    end
    local turnins = faction.turnins
    if type(turnins) == "table" then
        for t = 1, #turnins do
            local step = TurnInStep(turnins[t], questSide, faction.name, false, nil, nil, faction.id)
            if step then steps[#steps + 1] = step end
        end
    end
    if #steps == 0 then
        local empty = NoteStep(
            "No steps",
            "The journal has no steps for " .. faction.name .. ".",
            faction.name
        )
        empty.repEmpty = true
        steps[#steps + 1] = empty
    end
    local exalted = NoteStep(
        "Exalted",
        "You are exalted with " .. faction.name .. ".",
        faction.name
    )
    exalted.repExalted = true
    exalted.visible = false
    steps[#steps + 1] = exalted
    Stamp(guide, steps)
    return guide
end

local function Collect()
    local side = PlayerSide()
    local key = DataKey()
    local guides = { BuildGear(side, key), BuildRecipes(side, key) }
    local factions = SortedFactions(nil)
    if factions then
        for i = 1, #factions do
            guides[#guides + 1] = BuildFaction(factions[i], key)
        end
    end
    return guides
end

local function ApplyGear(guide, allowAsk)
    local pending = false
    local any = false
    local row = Progress(guide)
    local held, class, playerLevel
    local restoreLoads = false
    if SG.Gear and SG.Gear.Held then
        if not allowAsk and not SG.Gear.deferLoads then
            SG.Gear.deferLoads = true
            restoreLoads = true
        end
        held, class, playerLevel = SG.Gear.Held()
        if restoreLoads then SG.Gear.deferLoads = false end
    end
    if allowAsk and SG.Gear then SG.Gear.loadBudget = 64 end
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.itemID then
            local manual = row and row.done[i] and row.hold ~= i
            local beats = false
            if class and SG.Gear and SG.Gear.BeatsHeld then
                beats = SG.Gear.BeatsHeld(step.itemID, held, class, playerLevel, allowAsk and true or false)
            end
            if beats == nil then
                pending = true
                step.visible = false
            elseif beats == true and not manual then
                step.visible = true
                any = true
                GearLine(step)
            else
                step.visible = false
            end
        end
    end
    if SG.Gear then SG.Gear.loadBudget = nil end
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.repNote then
            if step.repMissing or step.repNoProf then
                step.visible = true
            elseif pending and not any then
                step.visible = true
                step.title = "Items still loading"
                step.text = "Some reputation rewards are still loading. The list updates when their stats arrive."
                step.baseText = step.text
            elseif not any then
                step.visible = true
                step.title = "Nothing to upgrade"
                step.text = "No reputation reward in the next 3 levels beats what you have on for this spec."
                step.baseText = step.text
            else
                step.visible = false
            end
        end
    end
    return pending
end

local function ApplyRecipes(guide)
    local any = false
    local row = Progress(guide)
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.itemID then
            local known = step.spell and SpellKnown(step.spell)
            local manual = row and row.done[i] and row.hold ~= i
            if known and row and row.hold ~= i then row.done[i] = true end
            if known or manual then
                step.visible = false
            else
                step.visible = true
                any = true
                RecipeLine(step)
            end
        end
    end
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.repNote then
            if step.repMissing or step.repNoProf then
                step.visible = true
            else
                step.visible = not any
                if not any then
                    step.title = "No recipes left"
                    step.text = "No reputation recipe is left for a profession you have."
                    step.baseText = step.text
                end
            end
        end
    end
    return false
end

local function ApplyFaction(guide)
    local reaction = ReactionOf(guide.repFaction)
    local exalted = type(reaction) == "number" and reaction >= ExaltedCut()
    local row = Progress(guide)
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.repWork then
            local manual = row and row.done[i] and row.hold ~= i
            if exalted then
                step.visible = false
                if row and row.hold ~= i then row.done[i] = true end
            elseif manual then
                step.visible = false
            else
                step.visible = true
            end
        elseif step.repExalted then
            step.visible = exalted and true or false
        elseif step.repEmpty then
            step.visible = not exalted
        end
    end
    return false
end

function SG.Reputation.Apply(guide, allowAsk)
    if not guide or not guide.reputation then return false end
    if guide.repKind == "gear" then return ApplyGear(guide, allowAsk) end
    if guide.repKind == "recipes" then return ApplyRecipes(guide) end
    return ApplyFaction(guide)
end

function SG.Reputation.ApplyAll(allowAsk)
    local guides = SG.Engine and SG.Engine.guides or {}
    local pending = false
    for i = 1, #guides do
        local guide = guides[i]
        if guide.reputation and SG.Reputation.Apply(guide, allowAsk) then pending = true end
    end
    return pending
end

function SG.Reputation.Watching()
    if not SG.db then return false end
    if SG.db.category == "reputation" then return true end
    if SG.db.gearTab == "reputation" then return true end
    local active = SG.Engine and SG.Engine.Active and SG.Engine.Active()
    if active and active.reputation then return true end
    return false
end

local function Kick()
    if polling or not SG.Reputation.Watching() then return end
    polling = true
    SG.After(0.6, function()
        polling = false
        if SG.Reputation.Watching() then SG.Reputation.Refresh() end
    end)
end

function SG.Reputation.Install(quiet)
    if not SG.Engine or not SG.Engine.guides or not SG.Engine.byId then return end
    local list = SG.Engine.guides
    local kept = {}
    for i = 1, #list do
        local guide = list[i]
        if guide.reputation then
            SG.Engine.byId[guide.id] = nil
        else
            kept[#kept + 1] = guide
        end
    end
    SG.Engine.guides = kept
    list = kept
    local built = Collect()
    local at = #list + 1
    for i = 1, #list do
        if list[i].category == "reputation" then
            at = i
            break
        end
    end
    for i = #built, 1, -1 do
        table.insert(list, at, built[i])
    end
    for i = 1, #built do
        local guide = built[i]
        SG.Engine.byId[guide.id] = guide
        if SG.Engine.AlignProgress then SG.Engine.AlignProgress(guide) end
    end
    local pending = SG.Reputation.ApplyAll(false)
    if not quiet then
        local active = SG.Engine.Active and SG.Engine.Active()
        if active and active.reputation then
            active = SG.Engine.Get(active.id) or active
            if SG.Engine.PlaceCursor then SG.Engine.PlaceCursor(active) end
        end
        if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
        if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
    end
    return pending
end

function SG.Reputation.Refresh()
    if not SG.Reputation.Watching() then return end
    local current = SG.Engine and SG.Engine.Get and SG.Engine.Get(RECIPE_ID)
    if not current or current.repKey ~= DataKey() then
        SG.Reputation.Install(true)
    end
    local pending = SG.Reputation.ApplyAll(true)
    local active = SG.Engine and SG.Engine.Active and SG.Engine.Active()
    if active and active.reputation and SG.Engine.PlaceCursor then
        active = SG.Engine.Get(active.id) or active
        SG.Engine.PlaceCursor(active)
    end
    if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
    if pending then Kick() end
end

function SG.Reputation.RefreshSoon()
    if not SG.Reputation.Watching() then return end
    if refreshSoon then return end
    refreshSoon = true
    SG.After(0.3, function()
        refreshSoon = false
        if SG.Reputation.Watching() then SG.Reputation.Refresh() end
    end)
end

function SG.Reputation.Prepare(id)
    local current = SG.Engine and SG.Engine.Get and SG.Engine.Get(RECIPE_ID)
    if not current or current.repKey ~= DataKey() then
        SG.Reputation.Install(true)
    end
    local guide = id and SG.Engine.Get(id)
    if not guide or not guide.reputation then return false end
    local pending = SG.Reputation.Apply(guide, true)
    if pending then Kick() end
    return pending
end
