-- Specs.lua: the class and spec list, plus talent-tab detection where the client has one.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

-- Keys match NaowhForever_BiS Data\BiS.lua so a reward can be ranked per spec.
-- `tab` is the classic talent tab (1, 2, 3). Feral tank shares tab 2 with feral DPS;
-- auto-detect picks feral DPS, and the tank spec stays a manual choice.
local CLASSES = {
    { token = "DRUID", name = "Druid", specs = {
        { key = "balance-druid", name = "Balance", tab = 1 },
        { key = "feral-dps-druid", name = "Feral DPS", tab = 2 },
        { key = "feral-tank-druid", name = "Feral Tank", tab = 2 },
        { key = "restoration-druid", name = "Restoration", tab = 3 },
    }},
    { token = "HUNTER", name = "Hunter", specs = {
        { key = "beast-mastery-hunter", name = "Beast Mastery", tab = 1 },
        { key = "marksmanship-hunter", name = "Marksmanship", tab = 2 },
        { key = "survival-hunter", name = "Survival", tab = 3 },
    }},
    { token = "MAGE", name = "Mage", specs = {
        { key = "arcane-mage", name = "Arcane", tab = 1 },
        { key = "fire-mage", name = "Fire", tab = 2 },
        { key = "frost-mage", name = "Frost", tab = 3 },
    }},
    { token = "PALADIN", name = "Paladin", specs = {
        { key = "holy-paladin", name = "Holy", tab = 1 },
        { key = "protection-paladin", name = "Protection", tab = 2 },
        { key = "retribution-paladin", name = "Retribution", tab = 3 },
    }},
    { token = "PRIEST", name = "Priest", specs = {
        { key = "discipline-priest", name = "Discipline", tab = 1 },
        { key = "holy-priest", name = "Holy", tab = 2 },
        { key = "shadow-priest", name = "Shadow", tab = 3 },
    }},
    { token = "ROGUE", name = "Rogue", specs = {
        { key = "assassination-rogue", name = "Assassination", tab = 1 },
        { key = "combat-rogue", name = "Combat", tab = 2 },
        { key = "subtlety-rogue", name = "Subtlety", tab = 3 },
    }},
    { token = "SHAMAN", name = "Shaman", specs = {
        { key = "elemental-shaman", name = "Elemental", tab = 1 },
        { key = "enhancement-shaman", name = "Enhancement", tab = 2 },
        { key = "restoration-shaman", name = "Restoration", tab = 3 },
    }},
    { token = "WARLOCK", name = "Warlock", specs = {
        { key = "affliction-warlock", name = "Affliction", tab = 1 },
        { key = "demonology-warlock", name = "Demonology", tab = 2 },
        { key = "destruction-warlock", name = "Destruction", tab = 3 },
    }},
    { token = "WARRIOR", name = "Warrior", specs = {
        { key = "arms-warrior", name = "Arms", tab = 1 },
        { key = "fury-warrior", name = "Fury", tab = 2 },
        { key = "protection-warrior", name = "Protection", tab = 3 },
    }},
}

local byKey = {}
for i = 1, #CLASSES do
    local class = CLASSES[i]
    for s = 1, #class.specs do
        local spec = class.specs[s]
        spec.token = class.token
        spec.className = class.name
        byKey[spec.key] = spec
    end
end

SG.Specs = { list = CLASSES }

function SG.Specs.Classes()
    return CLASSES
end

function SG.Specs.Find(key)
    return byKey[key]
end

function SG.Specs.ForClass(token)
    for i = 1, #CLASSES do
        if CLASSES[i].token == token then return CLASSES[i].specs end
    end
    return nil
end

function SG.Specs.DefaultFor(token)
    local specs = SG.Specs.ForClass(token)
    return specs and specs[1].key or nil
end

function SG.Specs.Label(key)
    local spec = byKey[key]
    if not spec then return "No spec" end
    return spec.className .. " - " .. spec.name
end

function SG.Specs.Selected()
    local key = SG.char and SG.char.spec
    if key and byKey[key] and (not SG.classToken or byKey[key].token == SG.classToken) then
        return key
    end
    return SG.Specs.DefaultFor(SG.classToken)
end

local function TalentTab()
    if not GetNumTalentTabs or not GetTalentTabInfo then return nil, 0 end
    local best, bestPoints = nil, -1
    local tabs = GetNumTalentTabs() or 0
    for i = 1, tabs do
        local _, _, points = GetTalentTabInfo(i)
        points = points or 0
        if points > bestPoints then
            best, bestPoints = i, points
        end
    end
    return best, bestPoints
end

-- Retail-style specs, if this client actually has them. Forever's classic
-- talent UI is the normal path; this is only a bonus when the API exists.
local function ModernSpecKey(token)
    if not GetSpecialization or not GetSpecializationInfo then return nil end
    local index = GetSpecialization()
    if not index or index == 0 then return nil end
    local _, name = GetSpecializationInfo(index)
    if not name then return nil end
    local specs = SG.Specs.ForClass(token)
    if not specs then return nil end
    local lower = name:lower()
    for i = 1, #specs do
        if specs[i].name:lower() == lower then return specs[i].key end
    end
    return specs[index] and specs[index].key or nil
end

function SG.Specs.Suggest()
    local token = SG.classToken
    if not token then return nil end
    local modern = ModernSpecKey(token)
    if modern then return modern end
    local tab, points = TalentTab()
    if not tab or points <= 0 then
        return SG.Specs.DefaultFor(token)
    end
    local specs = SG.Specs.ForClass(token)
    local fallback = nil
    for i = 1, #specs do
        if specs[i].tab == tab then
            -- Two feral specs share a tab. Prefer the DPS key unless the
            -- player already chose the tank spec by hand.
            if not fallback then fallback = specs[i].key end
            if SG.char and SG.char.spec == specs[i].key then return specs[i].key end
        end
    end
    return fallback or SG.Specs.DefaultFor(token)
end

function SG.Specs.Detect()
    if not SG.char.autoDetect and SG.Specs.Find(SG.char.spec) then
        local spec = SG.Specs.Find(SG.char.spec)
        if spec.token == SG.classToken then return end
    end
    local suggested = SG.Specs.Suggest()
    if suggested then SG.char.spec = suggested end
end

function SG.Specs.Choose(key)
    local spec = byKey[key]
    if not spec then return end
    SG.char.spec = key
    SG.char.class = spec.token
    SG.char.autoDetect = false
    if SG.Engine and SG.Engine.Rebuild then
        SG.Engine.Rebuild()
        if SG.db.options.autoAdvance then SG.Engine.SyncAll() end
    end
    if SG.UI and SG.UI.Refresh then SG.UI.Refresh(true) end
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
end

function SG.Specs.SetAuto(on)
    SG.char.autoDetect = on and true or false
    if on then
        SG.char.spec = SG.Specs.Suggest()
        if SG.Engine and SG.Engine.Rebuild then
            SG.Engine.Rebuild()
            if SG.db.options.autoAdvance then SG.Engine.SyncAll() end
        end
        if SG.UI and SG.UI.Refresh then SG.UI.Refresh(true) end
    end
end
