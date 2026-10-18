-- Legacy.lua: one guide per client achievement that awards a Legacy point.
-- The name, the requirement, the criteria, and any point sentence come from
-- GetAchievementInfo. Nothing in this file invents a challenge, an id, or a point value.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Legacy = {}

local function LoadAddon(name)
    local load = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
    if type(load) ~= "function" or type(name) ~= "string" then return end
    pcall(load, name)
end

local function Category(id)
    if type(GetCategoryInfo) ~= "function" or type(id) ~= "number" then return nil end
    local ok, title, parent = pcall(GetCategoryInfo, id)
    if not ok or type(title) ~= "string" or title == "" then return nil end
    if type(parent) ~= "number" then parent = -1 end
    return title, parent
end

local function LegacyTitle(title)
    local lower = title:lower()
    if lower == "legacy" or lower == "legacy challenges" then return true end
    if lower:find("legacy", 1, true) then return true end
    return false
end

local function CategoryTable()
    if type(GetCategoryList) ~= "function" then return nil end
    local list = GetCategoryList()
    if type(list) ~= "table" or #list == 0 then
        LoadAddon("Blizzard_AchievementUI")
        if type(GetCategoryList) ~= "function" then return nil end
        list = GetCategoryList()
    end
    if type(list) ~= "table" then return nil end
    local name, parent, ids = {}, {}, {}
    for i = 1, #list do
        local id = list[i]
        local title, up = Category(id)
        if title then
            name[id] = title
            parent[id] = up
            ids[#ids + 1] = id
        end
    end
    return name, parent, ids
end

local function MarkLegacy(name, parent, ids)
    local legacy = {}
    local function mark(id, depth)
        if type(id) ~= "number" or legacy[id] or depth > 8 then return end
        local title = name[id]
        if type(title) == "string" and LegacyTitle(title) then
            legacy[id] = true
            return
        end
        local up = parent[id]
        if type(up) == "number" and up > 0 and name[up] then
            mark(up, depth + 1)
            if legacy[up] then legacy[id] = true end
        end
    end
    for i = 1, #ids do
        mark(ids[i], 0)
    end
    return legacy
end

local function ReadRow(id, aname, points, completed, desc, icon, reward)
    if type(id) ~= "number" or type(aname) ~= "string" or aname == "" then return nil end
    if type(points) ~= "number" then points = 0 end
    if type(desc) ~= "string" then desc = "" end
    if type(reward) ~= "string" then reward = "" end
    return {
        id = id,
        name = aname,
        points = points,
        completed = completed and true or false,
        desc = desc,
        icon = icon,
        reward = reward,
    }
end

local function FromCategory(cat)
    local rows = {}
    if type(GetCategoryNumAchievements) ~= "function" or type(GetAchievementInfo) ~= "function" then
        return rows
    end
    local ok, num = pcall(GetCategoryNumAchievements, cat)
    if not ok or type(num) ~= "number" or num <= 0 then return rows end
    if num > 300 then num = 300 end
    for index = 1, num do
        local okRow, id, aname, points, completed, month, day, year, desc, flags, icon, reward =
            pcall(GetAchievementInfo, cat, index)
        if okRow then
            local row = ReadRow(id, aname, points, completed, desc, icon, reward)
            if row then
                row.cat = cat
                rows[#rows + 1] = row
            end
        end
    end
    return rows
end

local function Awards(row)
    local reward = row.reward:lower()
    if reward:find("legacy", 1, true) or reward:find("point", 1, true) then return true end
    if row.points > 0 and row.reward == "" then return true end
    return false
end

local function SaysLegacy(row)
    if row.reward:lower():find("legacy", 1, true) then return true end
    if row.desc:lower():find("legacy point", 1, true) then return true end
    return false
end

local function Collect(name, ids, legacy, fallback)
    local rows = {}
    for i = 1, #ids do
        local cat = ids[i]
        if fallback or legacy[cat] then
            local found = FromCategory(cat)
            for r = 1, #found do
                local row = found[r]
                local take = false
                if fallback then
                    take = SaysLegacy(row)
                else
                    take = Awards(row)
                end
                if take then
                    row.group = name[cat] or "Legacy"
                    rows[#rows + 1] = row
                end
            end
        end
    end
    return rows
end

local function HasId(list, id)
    for i = 1, #list do
        if list[i] == id then return true end
    end
    return false
end

local function Dedupe(rows)
    local best, order = {}, {}
    for i = 1, #rows do
        local row = rows[i]
        local key = row.name .. "\n" .. row.desc
        local have = best[key]
        if not have then
            row.ids = { row.id }
            best[key] = row
            order[#order + 1] = row
        else
            if not HasId(have.ids, row.id) then
                have.ids[#have.ids + 1] = row.id
            end
            if row.completed and not have.completed then have.completed = true end
            if row.id < have.id then
                have.id = row.id
                have.points = row.points
                have.icon = row.icon
                have.reward = row.reward
                have.group = row.group
                have.cat = row.cat
            end
        end
    end
    return order
end

local function AddCriteria(lines, id)
    if type(GetAchievementNumCriteria) ~= "function" then return end
    if type(GetAchievementCriteriaInfo) ~= "function" then return end
    local ok, num = pcall(GetAchievementNumCriteria, id)
    if not ok or type(num) ~= "number" or num <= 0 then return end
    local cap = num
    if cap > 12 then cap = 12 end
    for i = 1, cap do
        local okRow, text, kind, done, cur, max = pcall(GetAchievementCriteriaInfo, id, i)
        if okRow and type(text) == "string" and text ~= "" then
            local line = text
            if type(max) == "number" and max > 1 and type(cur) == "number" then
                line = string.format("%s (%d/%d)", text, cur, max)
            elseif done then
                line = text .. " (done)"
            end
            lines[#lines + 1] = line
        end
    end
    if num > cap then
        lines[#lines + 1] = "The achievement lists " .. (num - cap) .. " more."
    end
end

local function Live(id)
    if type(GetAchievementInfo) ~= "function" or type(id) ~= "number" then return nil end
    local ok, aid, aname, points, completed, month, day, year, desc, flags, icon, reward =
        pcall(GetAchievementInfo, id)
    if not ok then return nil end
    return ReadRow(aid, aname, points, completed, desc, icon, reward)
end

local function Describe(step)
    local ids = step.legacyIds
    if type(ids) ~= "table" or #ids == 0 then return nil end
    local picked, done
    for i = 1, #ids do
        local info = Live(ids[i])
        if info then
            if info.completed then done = true end
            if not picked or (picked.completed and not info.completed) then picked = info end
        end
    end
    if not picked then return nil end
    local lines = {}
    if picked.desc ~= "" then lines[#lines + 1] = picked.desc end
    if picked.reward ~= "" then
        lines[#lines + 1] = picked.reward
    elseif picked.points > 0 then
        lines[#lines + 1] = "The achievement lists " .. picked.points .. " points."
    end
    local criteriaId = picked.id
    for i = 1, #ids do
        local info = Live(ids[i])
        if info and not info.completed then
            criteriaId = info.id
            break
        end
    end
    AddCriteria(lines, criteriaId)
    local icon = picked.icon
    if icon == "" then icon = nil end
    return table.concat(lines, "\n"), done and true or false, icon, picked.name
end

local function OneGuide(row)
    local ids = row.ids or { row.id }
    local step = {
        kind = "legacy",
        match = "bis",
        visible = true,
        optional = false,
        segment = row.group,
        zone = row.group,
        level = 1,
        title = row.name,
        text = row.desc,
        legacyId = ids[1],
        legacyIds = ids,
        index = 1,
    }
    if row.icon and row.icon ~= "" then step.icon = row.icon end
    local guide = {
        id = "leg-" .. ids[1],
        title = row.name,
        group = row.group,
        category = "legacy",
        side = "B",
        place = row.group,
        blurb = row.desc ~= "" and row.desc or row.name,
        min = 1,
        max = 60,
        steps = { step },
        hiddenQuests = 0,
        questCount = 0,
        visibleQuests = 1,
        empty = false,
        route = false,
        keep = true,
        legacy = true,
    }
    step.guide = guide.id
    return guide
end

local function NoteGuide()
    local text = "No Legacy challenges were listed. The achievement categories did not name a list that awards a point."
    local step = {
        kind = "note",
        legacyNote = true,
        match = "bis",
        visible = true,
        optional = false,
        segment = "Legacy",
        level = 1,
        title = "No Legacy challenges listed",
        text = text,
        index = 1,
        guide = "leg-missing",
    }
    return {
        id = "leg-missing",
        title = "Legacy challenges",
        group = "Legacy",
        category = "legacy",
        side = "B",
        place = "Legacy",
        blurb = text,
        min = 1,
        max = 60,
        steps = { step },
        hiddenQuests = 0,
        questCount = 0,
        visibleQuests = 0,
        empty = false,
        route = false,
        keep = true,
        legacy = true,
    }
end

local function SortRows(rows)
    table.sort(rows, function(a, b)
        if a.cat ~= b.cat then return a.cat < b.cat end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
end

function SG.Legacy.Build()
    local name, parent, ids = CategoryTable()
    local guides = {}
    if not name or not parent or not ids then
        guides[1] = NoteGuide()
        return guides
    end
    local legacy = MarkLegacy(name, parent, ids)
    local any = false
    for i = 1, #ids do
        if legacy[ids[i]] then
            any = true
            break
        end
    end
    if not any then
        LoadAddon("Blizzard_LegacySystem")
        local name2, parent2, ids2 = CategoryTable()
        if name2 and parent2 and ids2 then
            name, parent, ids = name2, parent2, ids2
            legacy = MarkLegacy(name, parent, ids)
        end
    end
    local rows = Collect(name, ids, legacy, false)
    if #rows == 0 then rows = Collect(name, ids, legacy, true) end
    rows = Dedupe(rows)
    SortRows(rows)
    if #rows == 0 then
        guides[1] = NoteGuide()
        return guides
    end
    for i = 1, #rows do
        guides[#guides + 1] = OneGuide(rows[i])
    end
    return guides
end

function SG.Legacy.Apply(guide)
    if not guide or not guide.legacy or type(guide.steps) ~= "table" then return end
    local row = SG.Engine and SG.Engine.Progress and SG.Engine.Progress(guide.id)
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.legacyId then
            local text, done, icon, title = Describe(step)
            if type(text) == "string" and text ~= "" then step.text = text end
            if icon and icon ~= "" then step.icon = icon end
            if type(title) == "string" and title ~= "" then
                step.title = title
                guide.title = title
            end
            if done and row and row.hold ~= i then row.done[i] = true end
            step.visible = true
        end
    end
end

function SG.Legacy.Install(quiet)
    if not SG.Engine or not SG.Engine.guides or not SG.Engine.byId then return end
    if SG.Legacy.Watch then SG.Legacy.Watch() end
    local list = SG.Engine.guides
    for i = #list, 1, -1 do
        if list[i].legacy then
            SG.Engine.byId[list[i].id] = nil
            table.remove(list, i)
        end
    end
    local guides = SG.Legacy.Build()
    for i = 1, #guides do
        local guide = guides[i]
        list[#list + 1] = guide
        SG.Engine.byId[guide.id] = guide
        if SG.Engine.AlignProgress then SG.Engine.AlignProgress(guide) end
        SG.Legacy.Apply(guide)
    end
    if quiet then return end
    if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
end

function SG.Legacy.RefreshSoon()
    if SG.Legacy.waiting then return end
    SG.Legacy.waiting = true
    SG.After(0.3, function()
        SG.Legacy.waiting = false
        if not SG.db or not SG.Engine or not SG.Engine.guides then return end
        local guides = SG.Engine.guides
        local legacyOn = SG.db.category == "legacy"
        for i = 1, #guides do
            local guide = guides[i]
            if guide.legacy then
                SG.Legacy.Apply(guide)
                if SG.char and SG.char.active == guide.id then legacyOn = true end
            end
        end
        local tab = SG.state and SG.state.tab
        if not legacyOn and type(tab) == "string" and tab:sub(1, 4) == "leg-" then
            legacyOn = true
        end
        if legacyOn and SG.UI and SG.UI.frame and SG.UI.frame:IsShown() and SG.UI.Refresh then
            SG.UI.Refresh(false)
        end
        if legacyOn and SG.Tracker and SG.Tracker.Update then
            SG.Tracker.Update()
        elseif SG.Pins and SG.Pins.Update then
            SG.Pins.Update()
        end
    end)
end

function SG.Legacy.Watch()
    if SG.Legacy.frame then return end
    local frame = CreateFrame("Frame")
    SG.Legacy.frame = frame
    frame:SetScript("OnEvent", function()
        if SG.Legacy.RefreshSoon then SG.Legacy.RefreshSoon() end
    end)
    local names = { "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE", "CRITERIA_EARNED" }
    for i = 1, #names do
        pcall(frame.RegisterEvent, frame, names[i])
    end
end
