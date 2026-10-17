-- Gear.lua: which reward to take, and the Gear guide.
-- Level BiS is the best piece for this spec you can wear at this level.
-- Upgrade is anything that beats what you already have for that spec.
-- A higher item level is not enough, and a lower armor type does not replace a higher one.
-- The Gear guide lists those pickups. It does not walk a zone route.
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
    loads = {},
    loadAt = {},
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

-- Forever fills C_Item. The older globals are absent or stay empty, which
-- left every gear tab on "still loading" and then "nothing to upgrade".
local function ClientItem(itemID)
    if not itemID then return nil end
    local function pack(ok, name, link, _, ilvl, req, _, _, _, _, _, _, _, _, bind)
        if not ok or not name or not link then return nil end
        return name, link, ilvl, req, bind
    end
    if C_Item and C_Item.GetItemInfo then
        local name, link, ilvl, req, bind = pack(pcall(C_Item.GetItemInfo, itemID))
        if name and link then return name, link, ilvl, req, bind end
    end
    if GetItemInfo then
        local name, link, _, ilvl, req, _, _, _, _, _, _, _, _, bind = GetItemInfo(itemID)
        if name and link then return name, link, ilvl, req, bind end
    end
    return nil
end

-- True once Forever says this id is in the client cache. A name alone is not
-- enough: GetItemStats can hand back an empty table before that, and scoring
-- that empty table made every filled slot look like it had no upgrade.
local function ItemCached(itemID)
    if not itemID then return false end
    if C_Item and C_Item.IsItemDataCachedByID then
        local ok, cached = pcall(C_Item.IsItemDataCachedByID, itemID)
        if ok then return cached and true or false end
    end
    return ClientItem(itemID) and true or false
end

-- stats, answered. A table with numbers is the answer even before the cache
-- flag flips. An empty table counts only after the item is cached. Before
-- that it is still loading, not a score of 0.
local function ClientStats(itemID, link)
    local function take(fn, query)
        if not fn or query == nil then return nil end
        local ok, stats = pcall(fn, query)
        if ok and type(stats) == "table" and next(stats) ~= nil then return stats end
        return nil
    end
    local fn = C_Item and C_Item.GetItemStats
    local query = itemID and ("item:" .. itemID) or nil
    local stats = take(fn, query)
    if not stats and type(link) == "string" then stats = take(fn, link) end
    if not stats and GetItemStats then
        stats = take(GetItemStats, query)
        if not stats and type(link) == "string" then stats = take(GetItemStats, link) end
    end
    if stats then return stats, true end
    if ItemCached(itemID) then return {}, true end
    return nil, false
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
            if packed[4] and packed[4] > 0 and (not row.req or row.req <= 1) then
                row.req = packed[4]
                row.reqKnown = true
            end
        end
        row.slot = equipLoc and EQUIP_SLOT[equipLoc] or nil
        local ItemDB = _G.ItemDB
        if ItemDB then
            if ItemDB.name then row.name = ItemDB.name(itemID) end
            if ItemDB.itemLevel then row.ilvl = ItemDB.itemLevel(itemID) or 0 end
            if ItemDB.requiredLevel then
                local req = ItemDB.requiredLevel(itemID)
                if type(req) == "number" and req > 0 then
                    row.req = req
                    row.reqKnown = true
                elseif req == 0 then
                    row.req = 1
                    row.reqKnown = true
                end
            end
            if not row.classID and ItemDB.class then row.classID = ItemDB.class(itemID) end
            if not row.subID and ItemDB.subClass then row.subID = ItemDB.subClass(itemID) end
        end
        SG.Gear.facts[itemID] = row
    end
    -- Quiet. Fact runs for the whole catalog. ItemName would ask the client
    -- for every missing name, and that queue is what stuck the gear list.
    if not row.name and SG.ItemName then
        local name = SG.ItemName(itemID, true)
        if name then row.name = name end
    end
    -- Do not call GetItemInfo here. Fact runs for the whole catalog, and that
    -- queue is what kept the client from returning the items on the open tab.
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
    local spec = SG.Specs and SG.Specs.Selected()
    local tokens = spec and SPEC_STATS[spec]
    if not tokens then return 0 end
    local _, link = ClientItem(itemID)
    local stats = ClientStats(itemID, link)
    if type(stats) ~= "table" then return 0 end
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
    if SG.Gear.FilterGuides then SG.Gear.FilterGuides() end
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
        local active = SG.Engine and SG.Engine.Active and SG.Engine.Active()
        if active and active.gear and SG.Engine.PlaceCursor then
            SG.Engine.PlaceCursor(active)
        end
        if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
        if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
    end)
end

-- While a tab is waiting on the client, keep filtering so the next batch is
-- asked even when no item event arrives.
local function PollLoads()
    if SG.Gear.loadPoll then return end
    SG.Gear.loadPoll = true
    SG.After(0.6, function()
        SG.Gear.loadPoll = false
        if not SG.db or not SG.Gear.ready then return end
        RefreshSoon()
    end)
end

-- success comes from GET_ITEM_INFO_RECEIVED. Only an item this addon asked
-- for refreshes the list. A miss is remembered so the same id is not asked again.
function SG.Gear.OnItem(itemID, success)
    local loads = SG.Gear.loads
    if not itemID or type(loads) ~= "table" then return end
    local state = loads[itemID]
    if state ~= "ask" and state ~= "miss" then return end
    if success == true or ItemCached(itemID) then
        loads[itemID] = "ok"
    elseif success == false then
        loads[itemID] = "miss"
    elseif state == "miss" then
        return
    end
    if SG.Gear.facts then SG.Gear.facts[itemID] = nil end
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
    SG.Gear.loads = {}
    SG.Gear.loadAt = {}
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
            if SG.Gear.RebuildGuides then
                SG.Gear.RebuildGuides()
            else
                SG.Gear.ApplyAll()
                if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
                if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
            end
        end
    end
    SG.After(0, chunk)
end

-- How far ahead of the character a pickup still shows. Past that, it waits.
local AHEAD = 3
local SOURCE_SEP = " \194\183 "

local GEAR_BLURB = "Upgrades for the spec you selected. Tabs are Quests, Profession, Auction House, World Drops, and Reputation. A line shows only when that piece beats what you have equipped or in your bags for this spec, within a few levels. A higher item level with the wrong stats is left off. An empty slot counts. The same item level is not an upgrade. Profession is crafts from professions you have. A bind-on-pickup craft stays off until you have that profession. Auction House is bind-on-equip crafts from professions you do not have, and bind-on-equip world drops. World Drops lists world drops and dungeon drops. Reputation is a quartermaster reward, and the hand-ins for that reward stay listed while it is an upgrade and the standing is still short. A quest reward that is an upgrade lists the earlier quests in that chain under one Chain header. A world drop names the drop percent and the kills tracked since Stratagem started counting. This does not choose a zone path."

local function Namespace()
    return SG.BiS and SG.BiS.ns or nil
end

local function SpellName(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if type(name) == "string" and name ~= "" then return name end
    end
    if GetSpellInfo then
        local name = GetSpellInfo(spellID)
        if type(name) == "string" and name ~= "" then return name end
    end
    return nil
end

local function PlayerLevel()
    local level = UnitLevel and UnitLevel("player") or 1
    if not level or level < 1 then level = 1 end
    return level
end

local function ItemLabel(fact)
    if fact and type(fact.name) == "string" and fact.name ~= "" then return fact.name end
    if fact and fact.itemID then return "item " .. fact.itemID end
    return "item"
end

-- Mail and plate open at 40. Usable already encodes that. The level returned
-- here is the first level this class can wear the piece.
local function WearLevel(class, fact)
    if not class or not fact then return nil end
    local req = fact.req or 1
    if req < 1 then req = 1 end
    if SG.Gear.Usable(class, fact, req) then return req end
    if req < 40 and SG.Gear.Usable(class, fact, 40) then return 40 end
    if SG.Gear.Usable(class, fact, 60) then return math.max(req, 40) end
    return nil
end

local function TurnedIn(questID)
    if not questID or not SG.QuestState then return false end
    local completed = SG.QuestState(questID)
    return completed and true or false
end

local function QuestTitle(questID)
    local quest = SG.BiS and SG.BiS.Quest(questID)
    if quest and type(quest.name) == "string" and quest.name ~= "" then
        return quest.name, quest
    end
    local QuestDB = _G.QuestDB
    if QuestDB and QuestDB.name then
        local name = QuestDB.name(questID)
        if type(name) == "string" and name ~= "" then return name, quest end
    end
    local ns = Namespace()
    local names = ns and ns.Journal and ns.Journal.QuestChainNames
    if type(names) == "table" then
        local name = names[questID]
        if type(name) == "string" and name ~= "" then return name, quest end
    end
    return nil, quest
end

local function ZoneName(quest, where)
    if quest and type(quest.zone) == "string" and quest.zone ~= "" then return quest.zone end
    if type(where) == "string" and where ~= "" and not where:find("not known", 1, true) then
        local zone = where:match("^([^,]+)")
        if zone and strtrim then zone = strtrim(zone) end
        if zone and zone ~= "" then return zone end
    end
    return "Quests"
end

local function DungeonBand(name)
    local ns = Namespace()
    local journal = ns and ns.Journal
    if not journal or type(journal.QuestData) ~= "table" or type(name) ~= "string" then return nil end
    local want = name:lower()
    for i = 1, #journal.QuestData do
        local block = journal.QuestData[i]
        if type(block) == "table" and type(block.name) == "string" and block.name:lower() == want then
            local levels = block.levels
            if type(levels) == "table" and type(levels[1]) == "number" and levels[1] > 0 then
                return levels[1]
            end
        end
    end
    return nil
end

local function EntranceOf(name)
    local ns = Namespace()
    local journal = ns and ns.Journal
    if not journal or not journal.Dungeons or type(name) ~= "string" then return nil end
    local ok, dungeons = pcall(journal.Dungeons)
    if not ok or type(dungeons) ~= "table" then return nil end
    local want = name:lower()
    for i = 1, #dungeons do
        local dungeon = dungeons[i]
        if type(dungeon) == "table" and (dungeon.name or ""):lower() == want and type(dungeon.entrance) == "table" then
            return dungeon.entrance
        end
    end
    return nil
end

local function ChanceText(trash, chance)
    if trash then return "trash, no percent in the journal" end
    if type(chance) == "number" and chance > 0 then
        return string.format("%d%%", chance)
    end
    return "no percent in the journal"
end

local function ProfFrom(src)
    if type(src) ~= "string" then return nil end
    local who, place = src:match("^(.-)" .. SOURCE_SEP .. "(.+)$")
    if place and place:lower():find("crafted", 1, true) and who and who ~= "" then
        return who
    end
    return nil
end

local function IsCrafted(src)
    return type(src) == "string" and src:lower():find("crafted", 1, true) ~= nil
end

local function IsWorld(src)
    return type(src) == "string" and src:lower():find("world drop", 1, true) ~= nil
end

local function IsAuction(src)
    return type(src) == "string" and src:lower():find("auction", 1, true) ~= nil
end

-- rows are { id, name, faction, map, x, y } from the profession data.
local function PersonPin(rows, side)
    if type(rows) ~= "table" then return nil end
    for i = 1, #rows do
        local row = rows[i]
        if type(row) == "table" and row[4] and row[5] and row[6] then
            local faction = row[3]
            if faction == nil or faction == side or faction == "AH" or faction == "-" or faction == "B" then
                return row[4], row[5], row[6], row[2]
            end
        end
    end
    return nil
end

local function RecipeNote(recipe, side)
    if type(recipe) ~= "table" then
        return "The list does not name where the recipe comes from."
    end
    local bits = {}
    if type(recipe.skill) == "number" and recipe.skill > 0 then
        bits[#bits + 1] = "The recipe asks for skill " .. recipe.skill .. "."
    end
    local source = recipe.source
    if source == "trainer" then
        bits[#bits + 1] = "Learned from a trainer."
    elseif source == "teacher" then
        bits[#bits + 1] = "Learned from a teacher."
    elseif source == "vendor" then
        local _, _, _, vendor = PersonPin(recipe.vendors, side)
        if type(vendor) == "string" and vendor ~= "" then
            bits[#bits + 1] = "Recipe vendor: " .. vendor .. "."
        else
            bits[#bits + 1] = "The recipe comes from a vendor."
        end
    elseif source == "drop" then
        local mob = recipe.drops and recipe.drops[1] and recipe.drops[1][1]
        if type(mob) == "string" and mob ~= "" then
            bits[#bits + 1] = "The recipe drops. The list names " .. mob .. "."
        else
            bits[#bits + 1] = "The recipe drops. The list does not name the mob."
        end
    else
        bits[#bits + 1] = "The list does not name where the recipe comes from."
    end
    return table.concat(bits, " ")
end

local function ContentLevel(fact, class, band)
    local wear = WearLevel(class, fact)
    if band and wear and wear > band then return wear end
    if band then return band end
    if fact.reqKnown and wear then return wear end
    if (fact.ilvl or 0) > 1 then return fact.ilvl end
    return wear or 1
end

local function QuestAllowed(questID, side, class)
    local classMask, raceMask, questSide = QuestGate(questID)
    if not ClassAllowed(classMask, class) then return false end
    if not RaceAllowed(raceMask) then return false end
    if questSide and questSide ~= "B" and questSide ~= side then return false end
    local quest = SG.BiS and SG.BiS.Quest(questID)
    if quest and SG.BiS.Match and SG.BiS.Match(quest, side) == "hide" then return false end
    return true
end

local function BlankStep()
    return {
        kind = "gear",
        optional = true,
        match = "bis",
        visible = true,
    }
end

local function QuestPlace(questID)
    local name, quest = QuestTitle(questID)
    local level = QuestLevel(questID)
    local map, x, y, where
    if quest then
        map, x, y, where = quest.map, quest.x, quest.y, quest.where
    end
    if SG.Route and SG.Route.StartOf then
        local smap, sx, sy, swhere = SG.Route.StartOf(questID)
        if not (map and x and y) and smap and sx and sy then
            map, x, y = smap, sx, sy
        end
        if type(swhere) == "string" and swhere ~= "" then
            if type(where) ~= "string" or where == "" then where = swhere end
        end
    end
    local zone = ZoneName(quest, where)
    local giver = SG.Engine and SG.Engine.Giver and SG.Engine.Giver(where) or nil
    local from = (giver and giver ~= "") and (" from " .. giver) or ""
    local inZone = (zone ~= "Quests") and (" in " .. zone) or ""
    return name, level, map, x, y, zone, from, inZone
end

local function CopyNames(list)
    if not list or #list == 0 then return nil end
    local copy = {}
    for i = 1, #list do copy[i] = list[i] end
    return copy
end

-- Lead-in quests for a reward that can be gear. One step per named quest.
-- An earlier gear reward splits the chain, so a quest is listed once.
local function ExpandChains(raw, gearQuests, side, class)
    if not SG.Route or not SG.Route.ChainTo then return raw end
    local leads = {}
    local used = {}
    for id in pairs(gearQuests) do used[id] = true end
    for i = 1, #raw do
        local step = raw[i]
        if step.sourceKind == "quest" and step.questID then
            local root = step.questID
            local flat = SG.Route.ChainTo(root)
            if type(flat) == "table" then
                local startAt = 1
                for n = 1, #flat do
                    local entry = flat[n]
                    local qid = entry and entry.id
                    if qid and qid ~= root and gearQuests[qid] then
                        startAt = n + 1
                    end
                end
                local group = {}
                for n = startAt, #flat do
                    local entry = flat[n]
                    local qid = entry and entry.id
                    if qid and qid ~= root and not used[qid] and QuestAllowed(qid, side, class) then
                        local name, level, map, x, y, zone, from, inZone = QuestPlace(qid)
                        if name then
                            used[qid] = true
                            group[#group + 1] = {
                                id = qid,
                                alt = entry.alt,
                                name = name,
                                level = level,
                                map = map,
                                x = x,
                                y = y,
                                zone = zone,
                                from = from,
                                inZone = inZone,
                            }
                        end
                    end
                end
                if #group > 0 then
                    local rewardName = step.questName or "the reward"
                    local prior = {}
                    local header = "Chain: " .. rewardName
                    for g = 1, #group do
                        local row = group[g]
                        local lead = BlankStep()
                        lead.sourceKind = "quest"
                        lead.questID = row.id
                        lead.questName = row.name
                        lead.level = row.level
                        lead.chainLead = true
                        lead.chainGroup = root
                        if row.alt then lead.chainAlt = true end
                        lead.chainPos = g
                        lead.map, lead.x, lead.y = row.map, row.x, row.y
                        if row.zone ~= "Quests" then lead.placeName = row.zone end
                        lead.segment = header
                        lead.zone = header
                        lead.title = row.name
                        local alt = ""
                        if row.alt then
                            alt = " The chain lists this beside other quests. Complete one."
                        end
                        lead.baseText = string.format(
                            "Pick up %s%s%s. This leads to %s.%s",
                            row.name, row.from, row.inZone, rewardName, alt
                        )
                        lead.text = lead.baseText
                        if g > 1 then lead.chainPrior = CopyNames(prior) end
                        prior[#prior + 1] = row.name
                        leads[#leads + 1] = lead
                    end
                    step.chainGroup = root
                    step.chainPos = #group + 1
                    step.chainPrior = CopyNames(prior)
                    step.segment = header
                    step.zone = header
                end
            end
        end
    end
    if #leads == 0 then return raw end
    local out = {}
    for i = 1, #leads do out[#out + 1] = leads[i] end
    for i = 1, #raw do out[#out + 1] = raw[i] end
    return out
end

function SG.Gear.Build(side)
    SG.Gear.deferLoads = true
    local alliance = side == "A"
    local guide = {
        id = alliance and "gear-a" or "gear-h",
        title = alliance and "Alliance gear" or "Horde gear",
        group = alliance and "Alliance gear" or "Horde gear",
        category = "leveling",
        side = side,
        place = alliance and "Alliance" or "Horde",
        blurb = GEAR_BLURB,
        min = 1,
        max = 60,
        steps = {},
        hiddenQuests = 0,
        questCount = 0,
        visibleQuests = 0,
        empty = false,
        route = false,
        keep = true,
        gear = true,
    }
    local class = SG.classToken
    local note = {
        kind = "note",
        gearNote = true,
        optional = false,
        match = "bis",
        visible = false,
        segment = "Gear",
        zone = "Gear",
        level = 1,
        title = "Nothing to upgrade",
        text = "No upgrade is within reach yet.",
        baseText = "No upgrade is within reach yet.",
    }
    local steps = { note }
    if not class then
        guide.steps = steps
        note.index = 1
        note.guide = guide.id
        SG.Gear.deferLoads = false
        return guide
    end

    local sourceText = {}
    local ns = Namespace()
    local listed = ns and ns.BiSData and ns.BiSData.sources
    local sources = ns and ns.BiS and ns.BiS.Sources
    if type(listed) == "table" then
        for itemID, src in pairs(listed) do
            if type(itemID) == "number" and type(src) == "string" then
                sourceText[itemID] = src
                if sources and sources.Of then
                    local ok, kind, target = pcall(sources.Of, itemID)
                    if ok and kind == "quest" and type(target) == "number" then
                        AddReward(target, itemID)
                    end
                end
            end
        end
    end

    local raw = {}
    local questItems, dungeonItems, craftItems = {}, {}, {}
    local seenQuest = {}
    for questID, items in pairs(SG.Gear.byQuest) do
        if not seenQuest[questID] and QuestAllowed(questID, side, class) then
            local name, quest = QuestTitle(questID)
            local rewards = {}
            for i = 1, #items do
                local fact = SG.Gear.Fact(items[i])
                if fact and fact.slot and (fact.ilvl or 0) > 0 and WearLevel(class, fact) then
                    rewards[#rewards + 1] = items[i]
                end
            end
            if name and #rewards > 0 then
                seenQuest[questID] = true
                for i = 1, #rewards do questItems[rewards[i]] = true end
                local map, x, y, where
                if quest then
                    map, x, y, where = quest.map, quest.x, quest.y, quest.where
                end
                if SG.Route and SG.Route.StartOf then
                    local smap, sx, sy, swhere = SG.Route.StartOf(questID)
                    if not (map and x and y) and smap and sx and sy then
                        map, x, y = smap, sx, sy
                    end
                    if type(swhere) == "string" and swhere ~= "" then
                        if type(where) ~= "string" or where == "" then where = swhere end
                    end
                end
                local zone = ZoneName(quest, where)
                local giver = SG.Engine and SG.Engine.Giver and SG.Engine.Giver(where) or nil
                local from = (giver and giver ~= "") and (" from " .. giver) or ""
                local inZone = (zone ~= "Quests") and (" in " .. zone) or ""
                local step = BlankStep()
                step.sourceKind = "quest"
                step.questID = questID
                step.questName = name
                step.level = QuestLevel(questID)
                step.segment = zone
                step.zone = zone
                step.placeName = zone ~= "Quests" and zone or nil
                step.map, step.x, step.y = map, x, y
                step.allRewards = rewards
                step.rewards = rewards
                step.gearItem = rewards[1]
                step.itemID = rewards[1]
                step.baseText = string.format("Pick up %s%s%s.", name, from, inZone)
                step.text = step.baseText
                step.title = "(Optional) " .. name
                raw[#raw + 1] = step
            end
        end
    end
    raw = ExpandChains(raw, seenQuest, side, class)

    local journal = ns and ns.Journal
    if journal and journal.Dungeons then
        local ok, dungeons = pcall(journal.Dungeons)
        if ok and type(dungeons) == "table" then
            for d = 1, #dungeons do
                local dungeon = dungeons[d]
                local dungeonName = type(dungeon) == "table" and dungeon.name or nil
                if type(dungeonName) == "string" and dungeonName ~= "" then
                    local best = {}
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
                                    if fact and fact.slot and (fact.ilvl or 0) > 0 and WearLevel(class, fact) then
                                        local trash = boss.trash and true or false
                                        local chance = 0
                                        if not trash and type(boss.chance) == "table" and type(boss.chance[i]) == "number" then
                                            chance = boss.chance[i]
                                        end
                                        local prev = best[itemID]
                                        local take = not prev
                                        if prev and chance > (prev.chance or 0) then take = true end
                                        if prev and (prev.chance or 0) <= 0 and chance > 0 then take = true end
                                        if take then
                                            best[itemID] = {
                                                itemID = itemID,
                                                trash = trash,
                                                chance = chance,
                                                boss = trash and "Trash" or (boss.name or "a boss"),
                                            }
                                        end
                                    end
                                end
                            end
                        end
                    end
                    local band = DungeonBand(dungeonName)
                    local entrance = dungeon.entrance
                    for itemID, row in pairs(best) do
                        dungeonItems[itemID] = true
                        local fact = SG.Gear.Fact(itemID)
                        local step = BlankStep()
                        step.sourceKind = "dungeon"
                        step.itemID = itemID
                        step.gearItem = itemID
                        step.allRewards = { itemID }
                        step.rewards = { itemID }
                        step.instance = dungeonName
                        step.bossName = row.boss
                        step.chanceText = ChanceText(row.trash, row.chance)
                        step.level = ContentLevel(fact, class, band)
                        step.segment = dungeonName
                        step.zone = dungeonName
                        if type(entrance) == "table" then
                            step.map, step.x, step.y = entrance.map, entrance.x, entrance.y
                        end
                        step.title = "(Optional) " .. dungeonName
                        step.baseText = step.title
                        step.text = step.baseText
                        raw[#raw + 1] = step
                    end
                end
            end
        end
    end

    local function addCraft(itemID, profName, note, map, x, y, profId)
        if craftItems[itemID] or questItems[itemID] then return end
        local fact = SG.Gear.Fact(itemID)
        if not fact or not fact.slot or (fact.ilvl or 0) <= 0 or not WearLevel(class, fact) then return end
        craftItems[itemID] = true
        local step = BlankStep()
        step.sourceKind = "craft"
        step.profId = profId
        step.itemID = itemID
        step.gearItem = itemID
        step.allRewards = { itemID }
        step.rewards = { itemID }
        step.profName = profName
        step.recipeNote = note
        step.level = ContentLevel(fact, class, nil)
        step.segment = profName or "Crafting"
        step.zone = step.segment
        step.map, step.x, step.y = map, x, y
        step.title = "(Optional) " .. step.segment
        step.baseText = step.title
        step.text = step.baseText
        raw[#raw + 1] = step
    end

    local recipes = ns and ns.RecipeData
    if type(recipes) == "table" then
        for profId, prof in pairs(recipes) do
            if type(prof) == "table" and type(prof.recipes) == "table" then
                local profName = SpellName(prof.skillSpell)
                local id = type(profId) == "number" and profId or nil
                for i = 1, #prof.recipes do
                    local recipe = prof.recipes[i]
                    local itemID = recipe and recipe.item
                    if type(itemID) == "number" and itemID > 0 then
                        local map, x, y
                        if recipe.source == "trainer" or recipe.source == "teacher" then
                            map, x, y = PersonPin(prof.trainers, side)
                        elseif recipe.source == "vendor" then
                            map, x, y = PersonPin(recipe.vendors, side)
                        end
                        local named = profName or ProfFrom(sourceText[itemID])
                        addCraft(itemID, named, RecipeNote(recipe, side), map, x, y, id)
                    end
                end
            end
        end
    end
    for itemID, src in pairs(sourceText) do
        if IsCrafted(src) then
            addCraft(itemID, ProfFrom(src), "Source: " .. src .. ".", nil, nil, nil, nil)
        end
    end

    if SG.Reputation and SG.Reputation.AppendGear then
        SG.Reputation.AppendGear(raw, class, side)
    end

    for itemID, src in pairs(sourceText) do
        local auction = IsAuction(src)
        local world = IsWorld(src)
        if (auction or world) and not questItems[itemID] and not dungeonItems[itemID] and not craftItems[itemID] then
            local fact = SG.Gear.Fact(itemID)
            if fact and fact.slot and (fact.ilvl or 0) > 0 and WearLevel(class, fact) then
                local step = BlankStep()
                step.itemID = itemID
                step.gearItem = itemID
                step.allRewards = { itemID }
                step.rewards = { itemID }
                step.level = ContentLevel(fact, class, nil)
                if world then
                    step.sourceKind = "world"
                    if auction then step.auctionSource = true end
                    step.segment = "World drops"
                else
                    step.sourceKind = "auction"
                    step.segment = "Auction house"
                    step.worldLine = "Buy it on the auction house. " .. src .. "."
                end
                step.zone = step.segment
                step.title = "(Optional) " .. step.segment
                step.baseText = step.worldLine or step.title
                step.text = step.baseText
                raw[#raw + 1] = step
            end
        end
    end

    local groups, order = {}, {}
    for i = 1, #raw do
        local step = raw[i]
        local key = step.segment or "Gear"
        local group = groups[key]
        if not group then
            group = { title = key, level = step.level or 1, steps = {} }
            groups[key] = group
            order[#order + 1] = key
        end
        if step.level and step.level < group.level then group.level = step.level end
        group.steps[#group.steps + 1] = step
    end
    table.sort(order, function(a, b)
        if groups[a].level ~= groups[b].level then return groups[a].level < groups[b].level end
        if groups[a].title ~= groups[b].title then return groups[a].title < groups[b].title end
        return a < b
    end)
    local minLevel, maxLevel, quests = nil, nil, 0
    for i = 1, #order do
        local group = groups[order[i]]
        table.sort(group.steps, function(a, b)
            if a.chainGroup and a.chainGroup == b.chainGroup then
                local ap, bp = a.chainPos or 0, b.chainPos or 0
                if ap ~= bp then return ap < bp end
            end
            if a.level ~= b.level then return a.level < b.level end
            local aq, bq = a.questID or 0, b.questID or 0
            if aq ~= bq then return aq < bq end
            return (a.itemID or 0) < (b.itemID or 0)
        end)
        for s = 1, #group.steps do
            local step = group.steps[s]
            steps[#steps + 1] = step
            if step.level then
                if not minLevel or step.level < minLevel then minLevel = step.level end
                if not maxLevel or step.level > maxLevel then maxLevel = step.level end
            end
            if step.questID then quests = quests + 1 end
        end
    end
    for i = 1, #steps do
        steps[i].index = i
        steps[i].guide = guide.id
    end
    guide.steps = steps
    guide.min = minLevel or 1
    guide.max = maxLevel or 60
    guide.questCount = quests
    guide.visibleQuests = quests
    SG.Gear.deferLoads = false
    return guide
end

local function IdsOf(step)
    if step.allRewards and #step.allRewards > 0 then return step.allRewards end
    if step.gearItem then return { step.gearItem } end
    if step.rewards and #step.rewards > 0 then return step.rewards end
    return {}
end

local SPELL_EXTRA = {
    "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
    "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    "ITEM_MOD_SPELL_POWER_SHORT",
}

local function StatAmount(stats, token)
    if not token or type(stats) ~= "table" then return 0 end
    local amount = stats[token]
    local key = _G[token]
    if key and key ~= token then
        local other = stats[key]
        if type(other) == "number" and (type(amount) ~= "number" or other > amount) then
            amount = other
        end
    end
    if type(amount) ~= "number" then return 0 end
    return amount
end

-- One request per item. "ask" is in flight, "ok" came back, "miss" will not.
-- The gear list waits only while that item is still uncached. A miss is left off.
-- Score 0 is a cached item whose stat table is empty.
local LOAD_WAIT = 20
local LOAD_BUDGET = 64

function SG.Gear.AskItem(itemID)
    if not itemID or SG.Gear.deferLoads then return end
    local loads = SG.Gear.loads
    if type(loads) ~= "table" then
        loads = {}
        SG.Gear.loads = loads
    end
    local state = loads[itemID]
    if state == "ask" or state == "ok" or state == "miss" then return end
    local budget = SG.Gear.loadBudget
    if type(budget) == "number" and budget <= 0 then return end
    if type(budget) == "number" then SG.Gear.loadBudget = budget - 1 end
    loads[itemID] = "ask"
    if type(SG.Gear.loadAt) ~= "table" then SG.Gear.loadAt = {} end
    if GetTime then SG.Gear.loadAt[itemID] = GetTime() end
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    elseif RequestLoadItemDataByID then
        RequestLoadItemDataByID(itemID)
    end
    ClientItem(itemID)
end

-- True when an asked item is still uncached after the wait.
-- Cached items are scored, including a cached item with no stats.
local function GaveUp(itemID)
    local loads = SG.Gear.loads
    local state = loads and loads[itemID]
    if state == "miss" then return true end
    if state ~= "ask" and state ~= "ok" then return false end
    if ItemCached(itemID) then return false end
    local at = SG.Gear.loadAt and SG.Gear.loadAt[itemID]
    if not at or not GetTime then return false end
    if (GetTime() - at) < LOAD_WAIT then return false end
    loads[itemID] = "miss"
    return true
end

-- known is false while a request is in flight. failed is true when the client
-- will not return the item. Score 0 is only for an item that is cached and
-- whose stat table is empty. An empty table before that stays pending.
local function SpecValue(itemID, allowAsk)
    if allowAsk == nil then allowAsk = true end
    if not itemID then return nil, false, true end
    local hasAPI = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not hasAPI then return nil, false, false end
    local spec = SG.Specs and SG.Specs.Selected()
    local tokens = spec and SPEC_STATS[spec]
    if not tokens then return nil, false, false end
    local name, link, ilvl, req = ClientItem(itemID)
    if name and SG.Gear.facts and SG.Gear.facts[itemID] then
        local fact = SG.Gear.facts[itemID]
        if ilvl and ilvl > 0 and (not fact.ilvl or fact.ilvl == 0) then fact.ilvl = ilvl end
        if req and req > 0 and not fact.reqKnown then
            fact.req = req
            fact.reqKnown = true
        end
    end
    local stats, answered = ClientStats(itemID, link)
    local state = SG.Gear.loads and SG.Gear.loads[itemID]
    if not answered then
        if state == "miss" or GaveUp(itemID) then return nil, false, true end
        if allowAsk then SG.Gear.AskItem(itemID) end
        state = SG.Gear.loads and SG.Gear.loads[itemID]
        if state == "miss" then return nil, false, true end
        return nil, false, false
    end
    if type(stats) ~= "table" then return 0, true, false end
    if state == "ask" and SG.Gear.loads then SG.Gear.loads[itemID] = "ok" end
    local score = 0
    for i = 1, #tokens do
        score = score + StatAmount(stats, tokens[i]) * (4 - i)
    end
    if tokens[1] == "ITEM_MOD_INTELLECT_SHORT" then
        for i = 1, #SPELL_EXTRA do
            score = score + StatAmount(stats, SPELL_EXTRA[i]) * 2
        end
    else
        local listed = false
        for i = 1, #tokens do
            if tokens[i] == "ITEM_MOD_ATTACK_POWER_SHORT" then listed = true end
        end
        if not listed then
            score = score + StatAmount(stats, "ITEM_MOD_ATTACK_POWER_SHORT") * 2
        end
    end
    return score, true, false
end

-- 0 none, 1 BoP, 2 BoE, 3 BoU, 4 quest. Nil means the client has not said.
local function BindOf(itemID)
    if not itemID then return nil end
    local fact = SG.Gear.facts and SG.Gear.facts[itemID]
    if fact and fact.bindKnown then return fact.bind end
    local name, _, _, _, bind = ClientItem(itemID)
    if not name then
        local state = SG.Gear.loads and SG.Gear.loads[itemID]
        if state ~= "ok" and state ~= "miss" then SG.Gear.AskItem(itemID) end
        return nil
    end
    if type(bind) ~= "number" then return nil end
    if fact then
        fact.bind = bind
        fact.bindKnown = true
    end
    return bind
end

local function Sellable(bind)
    return bind == 0 or bind == 2
end

local function PlayerProfessions()
    local have = {}
    if not GetProfessions or not GetProfessionInfo then return have end
    local function consider(index)
        if not index then return end
        local _, _, _, _, _, _, skillLine = GetProfessionInfo(index)
        if type(skillLine) == "number" and skillLine > 0 then
            have[skillLine] = true
        end
    end
    local first, second, arch, fish, cook = GetProfessions()
    consider(first)
    consider(second)
    consider(arch)
    consider(fish)
    consider(cook)
    return have
end

local function BagSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    if GetContainerNumSlots then return GetContainerNumSlots(bag) end
    return 0
end

local function BagItem(bag, slot)
    if C_Container and C_Container.GetContainerItemID then
        return C_Container.GetContainerItemID(bag, slot)
    end
    if GetContainerItemID then return GetContainerItemID(bag, slot) end
    return nil
end

-- Weapons compare on spec score and item level. Armor slots keep their tier
-- so cloth cannot replace leather just by having more of a stat.
local function ArmorTier(class, fact, level)
    if not fact then return 0 end
    local slot = fact.slot
    if slot == 16 or slot == 17 or slot == 18 then return 0 end
    return SG.Gear.Usable(class, fact, level or 1) or 0
end

-- nil when either side is uncached. true only when cand is a real upgrade.
local function Beats(cand, bar)
    if not cand or not cand.known then return nil end
    if not bar then return true end
    if not bar.known then return nil end
    if cand.score > bar.score and cand.armor >= bar.armor then return true end
    if cand.score >= bar.score and cand.armor > bar.armor then return true end
    if cand.score == bar.score and cand.armor == bar.armor and cand.ilvl > bar.ilvl then return true end
    return false
end

local function BetterBar(a, b)
    local ab = Beats(a, b)
    local ba = Beats(b, a)
    if ab == nil or ba == nil then return nil end
    if ab and not ba then return a end
    if ba and not ab then return b end
    if a.armor ~= b.armor then
        if a.armor > b.armor then return a end
        return b
    end
    if a.score ~= b.score then
        if a.score > b.score then return a end
        return b
    end
    if a.ilvl ~= b.ilvl then
        if a.ilvl > b.ilvl then return a end
        return b
    end
    if a.itemID == b.itemID then return nil end
    if a.itemID < b.itemID then return a end
    return b
end

local function RankHeld(list)
    for i = 1, #list do
        if not list[i].known then return nil end
    end
    local ordered = {}
    for i = 1, #list do ordered[i] = list[i] end
    table.sort(ordered, function(a, b)
        local best = BetterBar(a, b)
        if not best then return false end
        return best == a
    end)
    return ordered
end

-- Rings and trinkets: the bar is the worse of the two you would wear.
-- One owned piece leaves the other slot empty.
local function BarFor(slot, list)
    if not list or #list == 0 then return nil, false end
    local ordered = RankHeld(list)
    if not ordered then return nil, true end
    if slot == 11 or slot == 13 then
        if #ordered < 2 then return nil, false end
        return ordered[2], false
    end
    return ordered[1], false
end

local function CollectHeld(class, playerLevel)
    local count = {}
    local bySlot = {}
    local function add(itemID)
        if type(itemID) ~= "number" or itemID <= 0 then return end
        count[itemID] = (count[itemID] or 0) + 1
        local fact = SG.Gear.Fact(itemID)
        if not fact or not fact.slot then return end
        if (fact.req or 1) > playerLevel then return end
        if not SG.Gear.Usable(class, fact, playerLevel) then return end
        local score, known, failed = SpecValue(itemID)
        if failed then return end
        local list = bySlot[fact.slot]
        if not list then
            list = {}
            bySlot[fact.slot] = list
        end
        list[#list + 1] = {
            itemID = itemID,
            score = score or 0,
            known = known and true or false,
            armor = ArmorTier(class, fact, playerLevel),
            ilvl = fact.ilvl or 0,
            name = fact.name,
        }
    end
    if GetInventoryItemID then
        for inv = 1, 18 do
            add(GetInventoryItemID("player", inv))
        end
    end
    for bag = 0, 4 do
        local n = BagSlots(bag) or 0
        for slot = 1, n do
            add(BagItem(bag, slot))
        end
    end
    return { count = count, bySlot = bySlot }
end

-- One pass over worn and bag gear. The reputation guide uses this so it does
-- not walk the bags once per reward.
function SG.Gear.Held()
    local class = SG.classToken
    if not class then return nil end
    return CollectHeld(class, PlayerLevel()), class, PlayerLevel()
end

-- nil while stats are still loading. false when it is not an upgrade you can
-- wear within AHEAD levels. true when it beats the piece you would replace.
function SG.Gear.BeatsHeld(itemID, held, class, playerLevel, allowAsk)
    if not itemID or not class then return false end
    local fact = SG.Gear.Fact(itemID)
    if not fact or not fact.slot or (fact.ilvl or 0) <= 0 then return false end
    local wear = playerLevel or 1
    if (fact.req or 1) > wear then wear = fact.req end
    if wear > (playerLevel or 1) + AHEAD then return false end
    if not SG.Gear.Usable(class, fact, wear) then return false end
    local score, known, failed = SpecValue(itemID, allowAsk and true or false)
    if failed or not known then
        if failed then return false end
        return nil
    end
    local slots = held and held.bySlot or {}
    local bar, barPending = BarFor(fact.slot, slots[fact.slot])
    if barPending then return nil end
    local beats = Beats({
        itemID = itemID,
        score = score or 0,
        known = true,
        armor = ArmorTier(class, fact, wear),
        ilvl = fact.ilvl or 0,
    }, bar)
    if beats == nil then return nil end
    local counts = held and held.count or {}
    if (counts[itemID] or 0) > 0 then return false end
    return beats and true or false
end

local function GearTab()
    local tab = SG.db and SG.db.gearTab
    if tab == "profession" or tab == "auction" or tab == "world" or tab == "reputation" then return tab end
    return "quest"
end

local function OnGearTab(step, tab)
    local kind = step.gearTab
    if kind == tab then return true end
    if tab == "auction" and kind == "world" and step.boe then return true end
    if tab == "world" and kind == "dungeon" then return true end
    return false
end

-- false means the line is not something this character would buy or craft.
local function AssignTab(step, profs)
    step.boe = nil
    step.gearTab = nil
    local kind = step.sourceKind
    if kind == "quest" then
        step.gearTab = "quest"
        return true
    end
    if kind == "dungeon" then
        step.gearTab = "dungeon"
        return true
    end
    if kind == "world" then
        local bind = BindOf(step.itemID or step.gearItem)
        if Sellable(bind) or step.auctionSource then step.boe = true end
        step.gearTab = "world"
        return true
    end
    if kind == "auction" then
        step.gearTab = "auction"
        step.boe = true
        return true
    end
    if kind == "reputation" then
        step.gearTab = "reputation"
        return true
    end
    if kind ~= "craft" then return false end
    local mine = step.profId and profs[step.profId] and true or false
    if mine then
        step.gearTab = "profession"
        return true
    end
    local bind = BindOf(step.itemID or step.gearItem)
    if Sellable(bind) then
        step.gearTab = "auction"
        step.boe = true
        return true
    end
    return false
end

local function TrimPercent(chance)
    local text = string.format("%.1f", chance)
    if text == "0.0" then text = string.format("%.2f", chance) end
    if text:sub(-2) == ".0" then text = text:sub(1, -3) end
    return text
end

local function TrackedKills(npcID)
    local kills = SG.char and SG.char.kills
    if type(kills) ~= "table" or not npcID then return 0 end
    local n = kills[npcID]
    if type(n) ~= "number" then n = kills[tostring(npcID)] end
    if type(n) ~= "number" or n < 0 then return 0 end
    return n
end

-- QuestieDB wowhead drop table. Nil until that addon is loaded. false means
-- the module was there and could not be read. Never invent a percent.
function SG.Gear.DropTable()
    if type(SG.Gear.drops) == "table" then return SG.Gear.drops end
    if SG.Gear.drops == false then return nil end
    local lib = _G.LibQuestieDB
    local support = lib and lib.Support
    if not support or not support.Get then return nil end
    local ok, mod = pcall(support.Get, "QuestieClassicItemDrops")
    if not ok or type(mod) ~= "table" then return nil end
    local data = mod.wowheadData
    if type(data) ~= "string" or data == "" then
        SG.Gear.drops = false
        return nil
    end
    if not loadstring then
        SG.Gear.drops = false
        return nil
    end
    local fn = loadstring(data)
    if type(fn) ~= "function" then
        SG.Gear.drops = false
        return nil
    end
    local ran, parsed = pcall(fn)
    if not ran or type(parsed) ~= "table" then
        SG.Gear.drops = false
        return nil
    end
    SG.Gear.drops = parsed
    return parsed
end

local function DropChance(itemID)
    local drops = SG.Gear.DropTable()
    if not drops or not itemID then return nil end
    local row = drops[itemID]
    if type(row) ~= "table" then return nil end
    local bestId, bestChance
    for npcID, chance in pairs(row) do
        if type(npcID) == "number" and type(chance) == "number" and chance > 0 then
            if not bestChance or chance > bestChance or (chance == bestChance and npcID < bestId) then
                bestChance = chance
                bestId = npcID
            end
        end
    end
    if not bestId then return nil end
    local name
    local NpcDB = _G.NpcDB
    if NpcDB and NpcDB.name then
        local ok, value = pcall(NpcDB.name, bestId)
        if ok and type(value) == "string" and value ~= "" then name = value end
    end
    return bestId, bestChance, name
end

local function DropSentence(itemID)
    local npcID, chance, name = DropChance(itemID)
    if not npcID or not chance or chance <= 0 then
        return "The drop list has no percent for this item."
    end
    local who = name or ("npc " .. npcID)
    local kills = math.ceil(100 / chance)
    local tracked = TrackedKills(npcID)
    return string.format(
        "%s drops it at %s%% (about %d kills). Tracked kills: %d.",
        who, TrimPercent(chance), kills, tracked
    )
end

local TAB_EMPTY = {
    quest = "No quest reward in the next %d levels beats what you have on for %s.",
    profession = "No craft from a profession you have in the next %d levels beats what you have on for %s. A bind-on-pickup craft stays off until you have that profession.",
    auction = "No auction house upgrade in the next %d levels beats what you have on for %s. This tab is bind-on-equip crafts from professions you do not have, and bind-on-equip world drops.",
    world = "No world drop or dungeon drop in the next %d levels beats what you have on for %s.",
    reputation = "No reputation reward in the next %d levels beats what you have on for %s. Hand-ins for a reward show with that reputation.",
}

local function Why(pick)
    if pick.empty then
        if pick.pair then return " One of those slots is still empty." end
        return " That slot is empty."
    end
    if pick.wornName and pick.wornName ~= "" then return " It replaces " .. pick.wornName .. "." end
    return " It is better for this spec than what you already have."
end

local function PreferPick(prev, pick)
    if not prev then return true end
    if pick.now ~= prev.now then return pick.now and not prev.now end
    local cand = {
        score = pick.score, known = true, armor = pick.armor, ilvl = pick.ilvl, itemID = pick.itemID,
    }
    local other = {
        score = prev.score, known = true, armor = prev.armor, ilvl = prev.ilvl, itemID = prev.itemID,
    }
    local beats = Beats(cand, other)
    if beats then return true end
    if beats == nil then return false end
    return false
end

-- False when this step cannot show on the open tab, so its items are not requested.
local function MaybeThisTab(step, tab, profs)
    local kind = step.sourceKind
    if kind == "quest" then return tab == "quest" end
    if kind == "dungeon" then return tab == "world" end
    if kind == "auction" then return tab == "auction" end
    if kind == "craft" then
        if tab == "profession" then
            return step.profId and profs and profs[step.profId] and true or false
        end
        return tab == "auction"
    end
    if kind == "world" then return tab == "world" or tab == "auction" end
    if kind == "reputation" then return tab == "reputation" end
    return false
end

local function Survey(step, class, playerLevel, held, tab, profs)
    local ids = IdsOf(step)
    local result = { anyBetter = false, wearable = false, ownedOpen = false, pending = false, now = {} }
    local soon = (step.level or 1) <= playerLevel + AHEAD
    local better, ownedBetter = 0, 0
    local counts = held and held.count or {}
    local slots = held and held.bySlot or {}
    for i = 1, #ids do
        local fact = SG.Gear.Fact(ids[i])
        local wear = fact and WearLevel(class, fact) or nil
        local reach = soon and wear and wear <= playerLevel + AHEAD
        local ask = reach and MaybeThisTab(step, tab, profs)
        local seen = fact and SG.Gear.loads and SG.Gear.loads[fact.itemID]
        -- Other tabs are scored only after this addon has already asked for them.
        if fact and fact.slot and (fact.ilvl or 0) > 0 and reach and (ask or seen == "ok" or seen == "ask") then
            local score, known, failed = SpecValue(fact.itemID, ask)
            if not failed and known then
                result.wearable = true
                local tierLevel = playerLevel
                if wear > tierLevel then tierLevel = wear end
                local cand = {
                    itemID = fact.itemID,
                    score = score or 0,
                    known = true,
                    armor = ArmorTier(class, fact, tierLevel),
                    ilvl = fact.ilvl or 0,
                }
                local bar, barPending = BarFor(fact.slot, slots[fact.slot])
                if barPending then result.pending = true end
                local beats = Beats(cand, bar)
                if beats == nil then result.pending = true end
                local usableNow = SG.Gear.Usable(class, fact, playerLevel) and (fact.req or 1) <= playerLevel
                local now = usableNow and (step.level or 1) <= playerLevel and known
                if now then
                    result.now[#result.now + 1] = {
                        slot = fact.slot, score = cand.score, armor = cand.armor, ilvl = fact.ilvl,
                    }
                end
                if beats then
                    result.anyBetter = true
                    better = better + 1
                    local owned = counts[fact.itemID] or 0
                    local wearableCopies = 0
                    local list = slots[fact.slot]
                    if list then
                        for n = 1, #list do
                            if list[n].itemID == fact.itemID then
                                wearableCopies = wearableCopies + 1
                            end
                        end
                    end
                    local need = (fact.slot == 11 or fact.slot == 13) and 2 or 1
                    -- A copy you cannot wear yet still means you already have the item.
                    -- Wearable copies fill a slot only when both ring or trinket slots are covered.
                    local filled = owned > wearableCopies or wearableCopies >= need
                    if filled then
                        ownedBetter = ownedBetter + 1
                    end
                    if not filled then
                        local pick = {
                            fact = fact,
                            itemID = fact.itemID,
                            worn = bar and bar.ilvl or 0,
                            wornName = bar and bar.name or nil,
                            score = cand.score,
                            armor = cand.armor,
                            ilvl = fact.ilvl,
                            now = now and true or false,
                            empty = not bar,
                            pair = (fact.slot == 11 or fact.slot == 13) and true or false,
                        }
                        if PreferPick(result.pick, pick) then result.pick = pick end
                    end
                end
            elseif ask and not failed then
                result.pending = true
            end
        end
    end
    result.ownedOpen = better > 0 and ownedBetter == better and not result.pending
    return result
end

local function WritePick(step, pick, playerLevel)
    local fact = pick.fact
    local name = ItemLabel(fact)
    local slot = fact.slotName or "slot"
    local equip = ""
    if (fact.req or 1) > playerLevel then
        equip = string.format(" Equip it at %d.", fact.req)
    end
    local why = Why(pick)
    step.gearName = name
    step.itemID = pick.itemID
    step.slot = fact.slot
    step.slotName = slot
    step.bisFrom = pick.bis and "level" or "upgrade"
    if step.sourceKind == "dungeon" then
        local chance = step.chanceText or "no percent in the journal"
        local boss = step.bossName or "a boss"
        local place = step.instance or "the dungeon"
        step.dropLine = boss .. "  " .. chance
        step.title = "(Optional) " .. slot .. ": " .. name
        step.text = string.format("(Optional) Run %s until %s drops from %s (%s).%s%s", place, name, boss, chance, equip, why)
    elseif step.sourceKind == "craft" then
        local prof = (step.profName and step.profName ~= "") and (step.profName .. ": ") or ""
        local note = step.recipeNote or ""
        if note ~= "" then note = " " .. note end
        if prof == "" and note == "" then
            note = " The list does not name the profession."
        end
        step.title = "(Optional) " .. slot .. ": " .. name
        step.text = "(Optional) " .. prof .. "Craft " .. name .. "." .. note .. equip .. why
    elseif step.sourceKind == "world" or step.sourceKind == "auction" then
        local line
        if step.sourceKind == "world" then
            line = DropSentence(step.itemID)
            step.dropLine = line
        else
            line = step.worldLine or "Buy it on the auction house."
        end
        step.title = "(Optional) " .. slot .. ": " .. name
        step.text = "(Optional) " .. line .. equip .. why
    elseif step.sourceKind == "reputation" then
        local who = step.vendorName or "the quartermaster"
        local standing = step.repStandingName or "The required standing"
        local cost = ""
        if type(step.repPrice) == "number" and step.repPrice > 0 then
            local gold = math.floor(step.repPrice / 10000)
            local silver = math.floor((step.repPrice % 10000) / 100)
            local copper = step.repPrice % 100
            local bits = {}
            if gold > 0 then bits[#bits + 1] = gold .. "g" end
            if silver > 0 then bits[#bits + 1] = silver .. "s" end
            if copper > 0 or #bits == 0 then bits[#bits + 1] = copper .. "c" end
            cost = " It costs " .. table.concat(bits, " ") .. "."
        end
        local faction = step.repFactionName or step.segment or "that reputation"
        step.title = "(Optional) " .. slot .. ": " .. name
        step.text = string.format("(Optional) Buy %s from %s. %s with %s is required.%s%s%s",
            name, who, standing, faction, cost, equip, why)
    else
        step.title = "(Optional) " .. (step.questName or "Quest") .. ": " .. name
        local kind = pick.bis and "Level BiS" or "Upgrade"
        local because
        if pick.empty then
            because = pick.pair and "one of those slots is still empty" or "that slot is empty"
        elseif pick.wornName and pick.wornName ~= "" then
            because = "replaces " .. pick.wornName
        else
            because = "better for this spec than what you already have"
        end
        step.text = string.format("%s Take %s (%s). %s: %s.%s", step.baseText or "", name, slot:lower(), kind, because, equip)
    end
    step.baseText = step.baseText or step.text
    if step.sourceKind ~= "quest" then step.baseText = step.text end
    step.rewards = { pick.itemID }
end

-- A chain lead stays hidden until that reward is an upgrade on this tab.
-- Turned-in leads stay listed and done. They do not set skip.
local function ApplyChains(guide, row)
    local rewardAt = {}
    local steps = guide.steps
    for i = 1, #steps do
        local step = steps[i]
        if step.chainGroup and not step.chainLead and step.visible and step.gearState == "show" then
            rewardAt[step.chainGroup] = i
        end
    end
    for i = 1, #steps do
        local step = steps[i]
        local at = step.chainLead and step.chainGroup and rewardAt[step.chainGroup]
        if at and i < at then
            step.visible = true
            if TurnedIn(step.questID) then
                step.gearState = "done"
                if row and row.hold ~= i then
                    row.done[i] = true
                    row.skip[i] = nil
                end
            else
                step.gearState = "show"
                if row and row.skip[i] and row.hold ~= i then
                    row.done[i] = nil
                    row.skip[i] = nil
                end
            end
        end
    end
end

function SG.Gear.Filter(guide)
    if not guide or not guide.gear or not guide.steps then return end
    SG.Gear.deferLoads = false
    -- Worn and bag pieces are few. Ask for those before the per-pass cap.
    SG.Gear.loadBudget = nil
    local class = SG.classToken
    local playerLevel = PlayerLevel()
    local row
    if SG.Engine and SG.Engine.Progress and guide.id then
        row = SG.Engine.Progress(guide.id)
    end
    if row and type(row.skip) ~= "table" then row.skip = {} end
    -- skip marks a line this gear pass hid. A Done click does not set skip,
    -- so a later equip refresh does not reopen a line the player closed.
    local function mark(i, step, mode)
        if mode == "show" then
            step.visible = true
            step.gearState = "show"
            if row and row.skip[i] and row.hold ~= i then
                row.done[i] = nil
                row.skip[i] = nil
            end
            return
        end
        if mode == "wait" then
            step.visible = false
            step.gearState = "wait"
            if row and row.skip[i] and row.hold ~= i then
                row.done[i] = nil
                row.skip[i] = nil
            end
            return
        end
        -- Another tab. Hide it without clearing a Done click or an auto-skip.
        if mode == "aside" then
            step.visible = false
            step.gearState = "wait"
            return
        end
        -- Turned in, but not on this tab. Stay done, and stay out of this bar.
        if mode == "keep" then
            step.visible = false
            step.gearState = "wait"
            if row and row.hold ~= i then
                row.done[i] = true
                row.skip[i] = nil
            end
            return
        end
        step.visible = false
        step.gearState = "done"
        if row and row.hold ~= i then
            if mode == "done" then
                row.done[i] = true
                row.skip[i] = nil
            elseif not row.done[i] then
                row.done[i] = true
                row.skip[i] = true
            end
        end
    end

    local ownedGear = class and CollectHeld(class, playerLevel) or nil
    local profs = PlayerProfessions()
    local tab = GearTab()
    SG.Gear.loadBudget = LOAD_BUDGET
    local specName = "this spec"
    if SG.Specs and SG.Specs.Label and SG.Specs.Selected then
        local label = SG.Specs.Label(SG.Specs.Selected())
        if type(label) == "string" and label ~= "" then specName = label end
    end
    local bestSpec = {}
    local surveyed = {}
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.chainLead then
            -- No item. Shown later only when the reward on this tab is an upgrade.
        elseif not step.gearNote and class then
            local info = Survey(step, class, playerLevel, ownedGear, tab, profs)
            surveyed[i] = info
            for n = 1, #info.now do
                local item = info.now[n]
                local prev = bestSpec[item.slot]
                local take = not prev or item.score > prev.score
                if prev and item.score == prev.score and item.armor > prev.armor then take = true end
                if prev and item.score == prev.score and item.armor == prev.armor and item.ilvl > prev.ilvl then
                    take = true
                end
                if take then bestSpec[item.slot] = item end
            end
        end
    end

    local any = false
    local waiting = false
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.chainLead then
            mark(i, step, "wait")
        elseif not step.gearNote then
            local info = surveyed[i]
            local pick = info and info.pick
            -- A turned-in quest cannot be picked up again, even when the
            -- reward would still beat what you have.
            if class and step.questID and TurnedIn(step.questID) then
                AssignTab(step, profs)
                if OnGearTab(step, tab) then
                    mark(i, step, "done")
                else
                    mark(i, step, "keep")
                end
            elseif not class or not info then
                mark(i, step, "wait")
            elseif info.pending and not pick then
                if AssignTab(step, profs) and OnGearTab(step, tab) then
                    if (step.level or 1) <= playerLevel + AHEAD then
                        waiting = true
                    end
                    mark(i, step, "wait")
                elseif step.gearTab then
                    mark(i, step, "aside")
                else
                    mark(i, step, "wait")
                end
            elseif pick then
                if not AssignTab(step, profs) then
                    mark(i, step, "wait")
                elseif not OnGearTab(step, tab) then
                    mark(i, step, "aside")
                else
                    local best = bestSpec[pick.fact.slot]
                    pick.bis = pick.now and (not best or pick.score >= best.score)
                    WritePick(step, pick, playerLevel)
                    mark(i, step, "show")
                    any = true
                end
            elseif info.ownedOpen or (info.wearable and not info.anyBetter) then
                AssignTab(step, profs)
                if OnGearTab(step, tab) then
                    mark(i, step, "auto")
                else
                    mark(i, step, "aside")
                end
            else
                mark(i, step, "wait")
            end
        end
    end
    ApplyChains(guide, row)
    if SG.Reputation and SG.Reputation.Fold then SG.Reputation.Fold(guide) end
    any = false
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.visible and not step.gearNote then any = true end
    end
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.gearNote then
            step.visible = not any
            step.gearState = "wait"
            if waiting then
                step.title = "Items still loading"
                step.text = "Some items on this tab are still loading. The list updates when their stats arrive. Until then, a higher item level is not treated as an upgrade."
            else
                step.title = "Nothing to upgrade"
                local pattern = TAB_EMPTY[tab] or TAB_EMPTY.quest
                step.text = string.format(pattern, AHEAD, specName)
            end
            step.baseText = step.text
            if row and row.hold ~= i then row.done[i] = nil end
        end
    end
    if row and row.hold then
        local held = guide.steps[row.hold]
        if not held or not held.visible then row.hold = nil end
    end
    SG.Gear.loadBudget = nil
    if waiting then PollLoads() end
end

function SG.Gear.FilterGuides()
    local guides = SG.Engine and SG.Engine.guides or {}
    for i = 1, #guides do
        if guides[i].gear then SG.Gear.Filter(guides[i]) end
    end
end

function SG.Gear.RebuildGuides()
    if not SG.Engine or not SG.Engine.byId or not SG.Gear.Build then return end
    local sides = { "H", "A" }
    for s = 1, #sides do
        local guide = SG.Gear.Build(sides[s])
        local list = SG.Engine.guides or {}
        local replaced = false
        for i = 1, #list do
            if list[i].id == guide.id then
                list[i] = guide
                replaced = true
                break
            end
        end
        if not replaced then list[#list + 1] = guide end
        SG.Engine.guides = list
        SG.Engine.byId[guide.id] = guide
        if SG.Engine.AlignProgress then SG.Engine.AlignProgress(guide) end
        if SG.Gear.Apply then SG.Gear.Apply(guide) end
        SG.Gear.Filter(guide)
    end
    if SG.Reputation and SG.Reputation.Install then SG.Reputation.Install(true) end
    local active = SG.Engine.Active and SG.Engine.Active()
    if active and active.gear and SG.Engine.PlaceCursor then
        SG.Engine.PlaceCursor(active)
    end
    if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
end

local function NoteKill()
    if not SG.char or type(SG.char.kills) ~= "table" then return end
    if not CombatLogGetCurrentEventInfo then return end
    local _, subevent, _, sourceGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if subevent ~= "PARTY_KILL" then return end
    local player = UnitGUID and UnitGUID("player")
    local pet = UnitGUID and UnitGUID("pet")
    if sourceGUID ~= player and (not pet or sourceGUID ~= pet) then return end
    if type(destGUID) ~= "string" then return end
    local npc = tonumber(destGUID:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
    if not npc then return end
    local prev = SG.char.kills[npc]
    if type(prev) ~= "number" then prev = SG.char.kills[tostring(npc)] end
    if type(prev) ~= "number" or prev < 0 then prev = 0 end
    SG.char.kills[npc] = prev + 1
    if SG.Gear.OnEquip then SG.Gear.OnEquip() end
end

local killFrame = CreateFrame("Frame")
killFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
killFrame:SetScript("OnEvent", NoteKill)
