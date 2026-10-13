-- Gear.lua: which reward to take for this class at this level.
-- Level BiS is the best piece you can wear in that slot right now.
-- Upgrade is anything better than what you have on, when a stronger piece already exists.
-- Endgame rank lists do not decide the badge.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Gear = {
    byQuest = {},
    curve = {},
    facts = {},
    bestCache = {},
    ready = false,
}

local ARMOR, WEAPON = 4, 2
local CLOTH, LEATHER, MAIL, PLATE = 1, 2, 3, 4
local SHIELD, LIBRAM, IDOL, TOTEM = 6, 7, 8, 9

-- Classic weapon subclass ids. A missing entry means this class does not train it.
local WEAPONS = {
    WARRIOR = { [0]=true, [1]=true, [2]=true, [3]=true, [4]=true, [5]=true, [6]=true, [7]=true, [8]=true, [10]=true, [13]=true, [15]=true, [16]=true, [18]=true },
    PALADIN = { [0]=true, [1]=true, [4]=true, [5]=true, [6]=true, [7]=true, [8]=true },
    HUNTER  = { [0]=true, [1]=true, [2]=true, [3]=true, [6]=true, [7]=true, [8]=true, [10]=true, [13]=true, [15]=true, [16]=true, [18]=true },
    ROGUE   = { [2]=true, [3]=true, [4]=true, [7]=true, [13]=true, [15]=true, [16]=true, [18]=true },
    PRIEST  = { [4]=true, [5]=true, [10]=true, [15]=true, [19]=true },
    SHAMAN  = { [0]=true, [1]=true, [4]=true, [5]=true, [10]=true, [13]=true, [15]=true },
    MAGE    = { [7]=true, [10]=true, [15]=true, [19]=true },
    WARLOCK = { [7]=true, [10]=true, [15]=true, [19]=true },
    DRUID   = { [4]=true, [5]=true, [6]=true, [10]=true, [13]=true, [15]=true },
}

local EQUIP_SLOT = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3,
    INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_WAIST = 6, INVTYPE_LEGS = 7,
    INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11,
    INVTYPE_TRINKET = 13, INVTYPE_CLOAK = 15, INVTYPE_WEAPON = 16,
    INVTYPE_2HWEAPON = 16, INVTYPE_WEAPONMAINHAND = 16, INVTYPE_WEAPONOFFHAND = 17,
    INVTYPE_SHIELD = 17, INVTYPE_HOLDABLE = 17, INVTYPE_RANGED = 18,
    INVTYPE_RANGEDRIGHT = 18, INVTYPE_THROWN = 18, INVTYPE_RELIC = 18,
}

local SPEC_STATS = {
    ["beast-mastery-hunter"] = { "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["marksmanship-hunter"] = { "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["survival-hunter"] = { "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["assassination-rogue"] = { "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["combat-rogue"] = { "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["subtlety-rogue"] = { "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["feral-dps-druid"] = { "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["feral-tank-druid"] = { "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_ARMOR_SHORT" },
    ["enhancement-shaman"] = { "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT" },
    ["arms-warrior"] = { "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["fury-warrior"] = { "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["protection-warrior"] = { "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT" },
    ["protection-paladin"] = { "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_INTELLECT_SHORT" },
    ["retribution-paladin"] = { "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["balance-druid"] = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["elemental-shaman"] = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["arcane-mage"] = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["fire-mage"] = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["frost-mage"] = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["affliction-warlock"] = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_SPIRIT_SHORT" },
    ["demonology-warlock"] = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_SPIRIT_SHORT" },
    ["destruction-warlock"] = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_SPIRIT_SHORT" },
    ["shadow-priest"] = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["restoration-druid"] = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["restoration-shaman"] = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["holy-priest"] = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["discipline-priest"] = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STAMINA_SHORT" },
    ["holy-paladin"] = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STAMINA_SHORT" },
}

local CLASSES = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

local CLASS_MASK = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16,
    SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024,
}

-- Same ChrRaces bits as BiS.lua. Bit 0 is Human, and 0 is a real bit.
local RACE_BITS = {
    [1] = 0, [2] = 1, [3] = 2, [4] = 3, [5] = 4, [6] = 5, [7] = 6, [8] = 7,
    [95] = 32, [96] = 33,
}

local function ClassAllowed(mask, class)
    if not mask or mask == 0 then return true end
    local flag = CLASS_MASK[class]
    if not flag then return false end
    return math.floor(mask / flag) % 2 == 1
end

local function RaceAllowed(mask)
    if not mask or mask == 0 then return true end
    local bit = SG.raceID and RACE_BITS[SG.raceID]
    if bit == nil then return true end
    return math.floor(mask / (2 ^ bit)) % 2 == 1
end

local function SideAllowed(side)
    if not side or side == "B" then return true end
    if not SG.playerSide or SG.playerSide == "B" then return true end
    return side == SG.playerSide
end

-- Zero means unrestricted. A reward from a quest this character cannot
-- accept does not count as the best piece they can wear.
local function QuestGate(questID)
    local classMask, raceMask, side = 0, 0, nil
    local quest = SG.BiS and SG.BiS.Quest(questID)
    if quest then
        if quest.class and CLASS_MASK[quest.class] then
            classMask = CLASS_MASK[quest.class]
        end
        if quest.races and quest.races ~= 0 then
            raceMask = quest.races
        end
        if quest.side and quest.side ~= "B" then
            side = quest.side
        end
    end
    local QuestDB = _G.QuestDB
    if QuestDB then
        if classMask == 0 and QuestDB.requiredClasses then
            local mask = QuestDB.requiredClasses(questID)
            if type(mask) == "number" and mask ~= 0 then classMask = mask end
        end
        if raceMask == 0 and QuestDB.requiredRaces then
            local mask = QuestDB.requiredRaces(questID)
            if type(mask) == "number" and mask ~= 0 then raceMask = mask end
        end
    end
    return classMask, raceMask, side
end

local function Instant(itemID)
    if C_Item and C_Item.GetItemInfoInstant then
        return C_Item.GetItemInfoInstant(itemID)
    end
    if GetItemInfoInstant then
        return GetItemInfoInstant(itemID)
    end
    return nil
end

local function QuestLevel(questID)
    local quest = SG.BiS and SG.BiS.Quest(questID)
    local level = quest and quest.level
    local QuestDB = _G.QuestDB
    if (not level or level < 1) and QuestDB and QuestDB.questLevel then
        level = QuestDB.questLevel(questID)
    end
    if not level or level < 1 then return 1 end
    return level
end

local function AddReward(questID, itemID)
    if not questID or not itemID or questID <= 0 or itemID <= 0 then return end
    local list = SG.Gear.byQuest[questID]
    if not list then
        list = {}
        SG.Gear.byQuest[questID] = list
    end
    for i = 1, #list do
        if list[i] == itemID then return end
    end
    list[#list + 1] = itemID
end

function SG.Gear.Fact(itemID)
    if not itemID then return nil end
    local row = SG.Gear.facts[itemID]
    if not row then
        row = { itemID = itemID, ilvl = 0, req = 1 }
        local _, _, subName, equipLoc, _, classID, subID = Instant(itemID)
        row.equip = equipLoc
        row.classID = classID
        row.subID = subID
        row.subName = subName
        local packed = SG.BiS and SG.BiS.ns and SG.BiS.ns.Shared and SG.BiS.ns.Shared.ItemFacts
        packed = packed and packed[itemID]
        if type(packed) == "table" then
            if not row.classID and packed[1] then row.classID = packed[1] end
            if not row.subID and packed[2] then row.subID = packed[2] end
            if (not row.ilvl or row.ilvl == 0) and packed[3] and packed[3] > 0 then row.ilvl = packed[3] end
            if packed[4] and packed[4] > 0 and (not row.req or row.req <= 1) then row.req = packed[4] end
        end
        row.slot = equipLoc and EQUIP_SLOT[equipLoc] or nil
        local ItemDB = _G.ItemDB
        if ItemDB then
            if ItemDB.name then row.name = ItemDB.name(itemID) end
            if ItemDB.itemLevel then row.ilvl = ItemDB.itemLevel(itemID) or 0 end
            if ItemDB.requiredLevel then row.req = ItemDB.requiredLevel(itemID) or 1 end
            if not row.classID and ItemDB.class then row.classID = ItemDB.class(itemID) end
            if not row.subID and ItemDB.subClass then row.subID = ItemDB.subClass(itemID) end
        end
        SG.Gear.facts[itemID] = row
    end
    if not row.name and SG.ItemName then
        local name = SG.ItemName(itemID)
        if name then row.name = name end
    end
    if row.ilvl == 0 and GetItemInfo and not row.asked then
        row.asked = true
        local _, _, _, ilvl, req = GetItemInfo(itemID)
        if ilvl and ilvl > 0 then row.ilvl = ilvl end
        if req and req > 0 then row.req = req end
    end
    if row.equip == "INVTYPE_CLOAK" then row.subName = "Cloak" end
    if row.slot and SG.SLOT_NAME then row.slotName = SG.SLOT_NAME[row.slot] end
    return row
end

-- Higher is better armor for this class at this level. nil means they cannot equip it.
local function ArmorScore(class, fact, level)
    if fact.equip == "INVTYPE_CLOAK" then return 2 end
    -- Rings, necks, and trinkets are not an armor type. They still fill a slot.
    if fact.equip == "INVTYPE_FINGER" or fact.equip == "INVTYPE_NECK" or fact.equip == "INVTYPE_TRINKET" then
        return 2
    end
    local sub = fact.subID
    if sub == SHIELD then
        if class == "WARRIOR" or class == "PALADIN" or class == "SHAMAN" then return 2 end
        return nil
    end
    if sub == LIBRAM then
        if class == "PALADIN" then return 2 end
        return nil
    end
    if sub == IDOL then
        if class == "DRUID" then return 2 end
        return nil
    end
    if sub == TOTEM then
        if class == "SHAMAN" then return 2 end
        return nil
    end
    if fact.equip == "INVTYPE_HOLDABLE" then
        if class == "MAGE" or class == "PRIEST" or class == "WARLOCK" or class == "DRUID" or class == "SHAMAN" then
            return 2
        end
        return nil
    end
    if class == "MAGE" or class == "PRIEST" or class == "WARLOCK" then
        if sub == CLOTH then return 2 end
        return nil
    end
    if class == "ROGUE" or class == "DRUID" then
        if sub == LEATHER then return 3 end
        if sub == CLOTH then return 1 end
        return nil
    end
    if class == "HUNTER" or class == "SHAMAN" then
        if sub == MAIL then
            if level >= 40 then return 3 end
            return nil
        end
        if sub == LEATHER then return 2 end
        if sub == CLOTH then return 1 end
        return nil
    end
    if class == "WARRIOR" or class == "PALADIN" then
        if sub == PLATE then
            if level >= 40 then return 3 end
            return nil
        end
        if sub == MAIL then return 2 end
        if sub == LEATHER or sub == CLOTH then return 1 end
        return nil
    end
    return nil
end

function SG.Gear.Usable(class, fact, level)
    if not class or not fact or not fact.slot then return nil end
    if fact.classID == WEAPON then
        local known = WEAPONS[class]
        if known and known[fact.subID] then return 2 end
        return nil
    end
    if fact.classID == ARMOR or fact.equip == "INVTYPE_CLOAK" or fact.equip == "INVTYPE_HOLDABLE" then
        return ArmorScore(class, fact, level or 1)
    end
    return nil
end

local function StatScore(itemID)
    if not GetItemStats or not GetItemInfo then return 0 end
    local spec = SG.Specs and SG.Specs.Selected()
    local tokens = spec and SPEC_STATS[spec]
    if not tokens then return 0 end
    local _, link = GetItemInfo(itemID)
    if not link then return 0 end
    local stats = GetItemStats(link)
    if not stats then return 0 end
    local score = 0
    for i = 1, #tokens do
        local token = tokens[i]
        local amount = stats[token] or stats[_G[token]]
        if amount then score = score + amount * (4 - i) end
    end
    return score
end

function SG.Gear.BuildCurve()
    local curve = {}
    for c = 1, #CLASSES do curve[CLASSES[c]] = {} end
    for questID, items in pairs(SG.Gear.byQuest) do
        local qlevel = QuestLevel(questID)
        local classMask, raceMask, side = QuestGate(questID)
        for i = 1, #items do
            local fact = SG.Gear.Fact(items[i])
            if fact and fact.slot and fact.ilvl > 0 then
                for c = 1, #CLASSES do
                    local class = CLASSES[c]
                    -- Level 60 is "can this class ever equip it". The 40
                    -- mail and plate gates are applied later, at the player's level.
                    if ClassAllowed(classMask, class) and SG.Gear.Usable(class, fact, 60) then
                        local list = curve[class][fact.slot]
                        if not list then
                            list = {}
                            curve[class][fact.slot] = list
                        end
                        list[#list + 1] = {
                            ilvl = fact.ilvl,
                            questLevel = qlevel,
                            req = fact.req or 1,
                            race = raceMask,
                            side = side,
                            slot = fact.slot,
                            classID = fact.classID,
                            subID = fact.subID,
                            equip = fact.equip,
                        }
                    end
                end
            end
        end
    end
    SG.Gear.curve = curve
    SG.Gear.bestCache = {}
end

-- Best item level, and the armor score of that tier, among rewards this
-- character can get and wear at or below their current level.
function SG.Gear.Best(class, slot, playerLevel)
    local key = class .. ":" .. tostring(slot) .. ":" .. tostring(playerLevel)
        .. ":" .. tostring(SG.raceID) .. ":" .. tostring(SG.playerSide)
    local hit = SG.Gear.bestCache[key]
    if hit then return hit[1], hit[2] end
    local list = SG.Gear.curve[class] and SG.Gear.curve[class][slot]
    local bestScore, bestIlvl = 0, 0
    if list then
        for i = 1, #list do
            local row = list[i]
            local score = SG.Gear.Usable(class, row, playerLevel)
            if score and row.questLevel <= playerLevel and row.req <= playerLevel
                and RaceAllowed(row.race) and SideAllowed(row.side) and score > bestScore then
                bestScore = score
            end
        end
        for i = 1, #list do
            local row = list[i]
            local score = SG.Gear.Usable(class, row, playerLevel)
            if score and row.questLevel <= playerLevel and row.req <= playerLevel
                and RaceAllowed(row.race) and SideAllowed(row.side)
                and score == bestScore and row.ilvl > bestIlvl then
                bestIlvl = row.ilvl
            end
        end
    end
    SG.Gear.bestCache[key] = { bestIlvl, bestScore }
    return bestIlvl, bestScore
end

function SG.Gear.Worn(slot)
    if not GetInventoryItemID or not slot then return 0, nil end
    local function one(inv)
        local id = GetInventoryItemID("player", inv)
        if not id then return 0, nil end
        local fact = SG.Gear.Fact(id)
        local ilvl = fact and fact.ilvl or 0
        local name = fact and fact.name or nil
        return ilvl, name
    end
    if slot == 11 or slot == 13 then
        local a, an = one(slot)
        local b, bn = one(slot + 1)
        if a == 0 or b == 0 then return 0, nil end
        if a <= b then return a, an end
        return b, bn
    end
    return one(slot)
end

local function RewardIDs(questID)
    local list = SG.Gear.byQuest[questID]
    if list and #list > 0 then return list end
    local quest = SG.BiS and SG.BiS.Quest(questID)
    return quest and quest.rewards or nil
end

local function IsChoice(questID, count)
    local quest = SG.BiS and SG.BiS.Quest(questID)
    if quest and quest.choice then return true end
    if quest and quest.rewards and not quest.choice then return false end
    return count > 1
end

function SG.Gear.Advise(questID, questLevel)
    local ids = RewardIDs(questID)
    if not ids or #ids == 0 then return nil end
    local class = SG.classToken
    if not class then return nil end
    local playerLevel = UnitLevel and UnitLevel("player") or questLevel or 1
    if playerLevel < 1 then playerLevel = 1 end
    local usable, skipped = {}, {}
    for i = 1, #ids do
        local fact = SG.Gear.Fact(ids[i])
        if fact and fact.slot then
            local score = SG.Gear.Usable(class, fact, playerLevel)
            if score then
                local worn, wornName = SG.Gear.Worn(fact.slot)
                usable[#usable + 1] = {
                    itemID = fact.itemID,
                    name = fact.name,
                    slot = fact.slot,
                    slotName = fact.slotName or "slot",
                    subName = fact.subName or "gear",
                    ilvl = fact.ilvl or 0,
                    req = fact.req or 1,
                    score = score,
                    worn = worn,
                    wornName = wornName,
                    upgrade = (fact.ilvl or 0) > worn,
                    empty = worn == 0,
                    stat = StatScore(fact.itemID),
                }
            else
                skipped[#skipped + 1] = fact
            end
        end
    end
    if #usable == 0 and #skipped == 0 then return nil end
    table.sort(usable, function(a, b)
        if a.upgrade ~= b.upgrade then return a.upgrade and not b.upgrade end
        if a.score ~= b.score then return a.score > b.score end
        if a.empty ~= b.empty then return a.empty and not b.empty end
        if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
        if a.stat ~= b.stat then return a.stat > b.stat end
        return a.itemID < b.itemID
    end)
    local choice = IsChoice(questID, #ids)
    local picks = {}
    if choice then
        if usable[1] and usable[1].upgrade then picks[1] = usable[1] end
    else
        for i = 1, #usable do
            if usable[i].upgrade then picks[#picks + 1] = usable[i] end
        end
    end
    local gear, name, itemID, slotName
    local pickSet, skipSet = {}, {}
    local lines = {}
    for i = 1, #picks do
        local pick = picks[i]
        local slotBest, slotScore = SG.Gear.Best(class, pick.slot, playerLevel)
        local canWear = pick.req <= playerLevel or pick.req <= (questLevel or playerLevel)
        local isBis = canWear and pick.ilvl > 0 and pick.ilvl >= slotBest and pick.score >= slotScore
        local mode = isBis and "bis" or "upgrade"
        pickSet[pick.itemID] = mode
        if mode == "bis" and gear ~= "level" then
            gear = "level"
            name = pick.name
            itemID = pick.itemID
            slotName = pick.slotName
        elseif not gear then
            gear = "upgrade"
            name = pick.name
            itemID = pick.itemID
            slotName = pick.slotName
        end
        local why
        if pick.empty then
            why = "that slot is empty"
        elseif pick.wornName then
            why = "replaces " .. pick.wornName
        else
            why = "better than what you have on"
        end
        local kind = isBis and "Level BiS" or "Upgrade"
        local label = pick.name or ((pick.subName or "gear") .. " " .. pick.slotName:lower())
        local verb = choice and "Choose" or "Take"
        local equip = ""
        if pick.req > playerLevel then
            equip = string.format(" Equip it at %d.", pick.req)
        end
        lines[#lines + 1] = string.format(
            "%s %s (%s %s). %s: %s.%s",
            verb, label, (pick.subName or "gear"):lower(), pick.slotName:lower(), kind, why, equip
        )
    end
    if choice and #picks > 0 then
        local picked = {}
        for i = 1, #picks do
            picked[picks[i].itemID] = true
        end
        local pickType = (picks[1].subName or ""):lower()
        local seen, types = {}, {}
        local function note(id, subName)
            if not id or picked[id] then return end
            skipSet[id] = true
            local label = subName and subName:lower() or nil
            if label and label ~= "" and label ~= pickType and not seen[label] then
                seen[label] = true
                types[#types + 1] = label
            end
        end
        for i = 1, #skipped do
            note(skipped[i].itemID, skipped[i].subName)
        end
        for i = 1, #usable do
            note(usable[i].itemID, usable[i].subName)
        end
        if #types > 0 then
            lines[#lines + 1] = "Skip " .. table.concat(types, " and ") .. "."
        end
    end
    if #picks == 0 and #usable == 0 and #skipped > 0 then
        lines[1] = "No reward on this quest fits your class."
        for i = 1, #skipped do
            if skipped[i].itemID then skipSet[skipped[i].itemID] = true end
        end
    end
    local ordered = {}
    local function push(id)
        if not id then return end
        for i = 1, #ordered do
            if ordered[i] == id then return end
        end
        ordered[#ordered + 1] = id
    end
    for i = 1, #picks do push(picks[i].itemID) end
    for i = 1, #ids do push(ids[i]) end
    if #lines == 0 and #ordered == 0 then return nil end
    return {
        gear = gear,
        name = name,
        itemID = itemID,
        slotName = slotName,
        line = table.concat(lines, " "),
        rewards = ordered,
        pickSet = pickSet,
        skipSet = skipSet,
        choice = choice,
    }
end

function SG.Gear.Apply(guide)
    if not guide or not guide.steps then return end
    local advice = {}
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if not step.baseText then step.baseText = step.text or "" end
        local id = step.questID
        if id and advice[id] == nil then
            advice[id] = SG.Gear.Advise(id, step.level) or false
        end
        local row = id and advice[id]
        step.bisFrom = nil
        step.gearName = nil
        step.rank = nil
        step.pickSet = nil
        step.skipSet = nil
        if row and row ~= false then
            step.bisFrom = row.gear
            step.gearName = row.name
            step.itemID = row.itemID
            step.slotName = row.slotName
            step.rewards = row.rewards
            step.choice = row.choice
            step.pickSet = row.pickSet
            step.skipSet = row.skipSet
            if row.line and row.line ~= "" then
                step.text = step.baseText .. " " .. row.line
            else
                step.text = step.baseText
            end
        else
            step.text = step.baseText
        end
    end
end

function SG.Gear.ApplyAll()
    SG.Gear.bestCache = {}
    local guides = SG.Engine and SG.Engine.guides or {}
    for i = 1, #guides do
        SG.Gear.Apply(guides[i])
    end
    if SG.Route and SG.Route.Paint then SG.Route.Paint() end
end

local refreshPending = false
local function RefreshSoon()
    if refreshPending then return end
    refreshPending = true
    SG.After(0.3, function()
        refreshPending = false
        if not SG.db then return end
        if SG.Gear.curveDirty then
            SG.Gear.curveDirty = false
            SG.Gear.BuildCurve()
        end
        SG.Gear.bestCache = {}
        SG.Gear.ApplyAll()
        if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
        if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
    end)
end

function SG.Gear.OnItem(itemID)
    if itemID and SG.Gear.facts then SG.Gear.facts[itemID] = nil end
    SG.Gear.curveDirty = true
    if SG.Gear.ready then RefreshSoon() end
end

function SG.Gear.OnEquip()
    if SG.Gear.ready then RefreshSoon() end
end

local function IndexCatalog()
    SG.Gear.byQuest = {}
    local quests = SG.BiS and SG.BiS.quests or {}
    for i = 1, #quests do
        local quest = quests[i]
        local rewards = quest.rewards or {}
        for r = 1, #rewards do
            AddReward(quest.id, rewards[r])
        end
    end
end

function SG.Gear.Start()
    if SG.Gear.scanning or SG.Gear.scanned then return end
    IndexCatalog()
    SG.Gear.facts = {}
    SG.Gear.ready = false
    local ItemDB = _G.ItemDB
    if not ItemDB or not ItemDB.GetAllIds or not ItemDB.questRewards or not ItemDB.class then
        SG.Gear.BuildCurve()
        SG.Gear.ready = true
        return
    end
    SG.Gear.scanning = true
    SG.Gear.BuildCurve()
    local ids = ItemDB.GetAllIds()
    if type(ids) ~= "table" then
        SG.Gear.scanning = false
        SG.Gear.scanned = true
        SG.Gear.ready = true
        return
    end
    local index = 1
    local function chunk()
        local last = math.min(index + 399, #ids)
        for i = index, last do
            local itemID = ids[i]
            local classID = ItemDB.class(itemID)
            if classID == WEAPON or classID == ARMOR then
                local rewards = ItemDB.questRewards(itemID)
                if type(rewards) == "table" then
                    for r = 1, #rewards do
                        AddReward(rewards[r], itemID)
                    end
                end
            end
        end
        index = last + 1
        if index <= #ids then
            SG.After(0, chunk)
        else
            SG.Gear.scanning = false
            SG.Gear.scanned = true
            SG.Gear.BuildCurve()
            SG.Gear.ready = true
            SG.Gear.ApplyAll()
            if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
            if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
        end
    end
    SG.After(0, chunk)
end
