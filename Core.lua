-- Core.lua: saved variables, events, slash commands, and the few helpers every file shares.
local addonName, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.name = addonName or "Stratagem"
SG.version = "1.0.0"
SG.MEDIA = "Interface\\AddOns\\Stratagem\\Media\\"

-- Slot ids match the inventory slots used by NaowhForever_BiS.
SG.SLOT_NAME = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist",
    [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Finger",
    [12] = "Finger", [13] = "Trinket", [14] = "Trinket", [15] = "Back",
    [16] = "Weapon", [17] = "Off Hand", [18] = "Ranged",
}

SG.DB_DEFAULTS = {
    minimap = { angle = 220 },
    ui = {
        scale = 1,
        point = "CENTER",
        rel = "CENTER",
        x = 0,
        y = 0,
        tracker = { point = "BOTTOM", rel = "BOTTOM", x = 280, y = 210 },
        arrow = { point = "CENTER", rel = "CENTER", x = 0, y = 230 },
    },
    options = {
        tomtom = true,
        arrow = true,
        invertArrow = false,
        autoAdvance = true,
        onlyMySpec = true,
        minimap = true,
        tracker = true,
        lockTracker = false,
        superTrack = true,
        faction = "auto",
    },
    favorites = {},
    recent = {},
    tabs = {},
    category = "leveling",
    selected = nil,
}

SG.CHAR_DEFAULTS = {
    class = nil,
    spec = nil,
    autoDetect = true,
    active = nil,
    progress = {},
}

function SG.CopyDefaults(dst, src)
    for key, value in pairs(src) do
        if dst[key] == nil then
            if type(value) == "table" then
                dst[key] = {}
                SG.CopyDefaults(dst[key], value)
            else
                dst[key] = value
            end
        elseif type(value) == "table" and type(dst[key]) == "table" then
            SG.CopyDefaults(dst[key], value)
        end
    end
end

function SG.Print(msg)
    local frame = DEFAULT_CHAT_FRAME
    if frame then
        frame:AddMessage("|cff9a74ffStratagem|r  " .. tostring(msg))
    end
end

function SG.After(seconds, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(seconds, fn)
        return
    end
    local wait = CreateFrame("Frame")
    local elapsed = 0
    wait:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed < (seconds or 0) then return end
        self:SetScript("OnUpdate", nil)
        fn()
    end)
end

-- Lua 5.1 keeps every return value only when the call is the last argument.
function SG.RGB(color)
    return color[1], color[2], color[3], color[4] or 1
end

function SG.Paint(tex, color)
    local r, g, b, a = color[1], color[2], color[3], color[4] or 1
    if tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a)
    else
        tex:SetTexture("Interface\\Buttons\\WHITE8x8")
        tex:SetVertexColor(r, g, b, a)
    end
end

function SG.PlayerSide()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if faction == "Alliance" then return "A" end
    return "H"
end

function SG.SideName(side)
    if side == "A" then return "Alliance" end
    if side == "H" then return "Horde" end
    return "Both"
end

function SG.FactionFilter()
    local mode = SG.db and SG.db.options.faction or "auto"
    if mode == "A" or mode == "H" or mode == "both" then return mode end
    return SG.playerSide or "H"
end

function SG.ItemName(itemID)
    if not itemID then return nil end
    local name, link, quality, _, _, _, _, _, _, texture
    if C_Item and C_Item.GetItemInfo then
        name, link, quality, _, _, _, _, _, _, texture = C_Item.GetItemInfo(itemID)
    elseif GetItemInfo then
        name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(itemID)
    end
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return name, link, quality, texture
end

function SG.ItemColor(quality)
    local colors = ITEM_QUALITY_COLORS
    local row = colors and quality and colors[quality]
    if row then return row.r, row.g, row.b end
    return 0.9, 0.9, 0.9
end

-- One snapshot of turned-in quests and the current log, so a guide can
-- skip work this character already did. Single-id APIs miss that history
-- until the client has cached each quest.
function SG.RefreshQuestCache()
    local done, inLog, ready = {}, {}, {}
    if GetQuestsCompleted then
        local map = GetQuestsCompleted()
        if type(map) == "table" then
            for questID, flagged in pairs(map) do
                if flagged then done[questID] = true end
            end
        end
    end
    if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
        local ids = C_QuestLog.GetAllCompletedQuestIDs()
        if type(ids) == "table" then
            for i = 1, #ids do done[ids[i]] = true end
        end
    end
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local count = C_QuestLog.GetNumQuestLogEntries()
        for i = 1, count do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID and info.questID > 0 then
                inLog[info.questID] = true
                -- true or 1 means the objectives are done. -1 is a failed quest.
                if info.isComplete == true or info.isComplete == 1 then
                    ready[info.questID] = true
                end
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        local count = GetNumQuestLogEntries()
        for i = 1, count do
            local _, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
            if not isHeader and questID and questID > 0 then
                inLog[questID] = true
                if isComplete == 1 or isComplete == true then ready[questID] = true end
            end
        end
    end
    SG.questCache = { done = done, inLog = inLog, ready = ready }
end

local function QuestFlagged(questID)
    local cache = SG.questCache
    if cache and cache.done[questID] then return true end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questID) and true or false
    end
    if IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(questID) and true or false
    end
    return false
end

local function QuestInLog(questID)
    local cache = SG.questCache
    if cache and cache.inLog[questID] then return true end
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local index = C_QuestLog.GetLogIndexForQuestID(questID)
        return index and index > 0
    end
    if GetQuestLogIndexByID then
        local index = GetQuestLogIndexByID(questID)
        return index and index > 0
    end
    return false
end

local function QuestObjectivesDone(questID)
    local cache = SG.questCache
    if cache and (cache.ready[questID] or cache.done[questID]) then return true end
    if C_QuestLog and C_QuestLog.IsComplete then
        return C_QuestLog.IsComplete(questID) and true or false
    end
    if IsQuestComplete then
        return IsQuestComplete(questID) and true or false
    end
    return false
end

-- completed, inLog, objectivesDone
function SG.QuestState(questID)
    if not questID then return false, false, false end
    return QuestFlagged(questID), QuestInLog(questID), QuestObjectivesDone(questID)
end

-- Objective rows from the quest log. Text is whatever the client returns.
-- Counts are added only when the client gave a required number and the text
-- does not already contain it. Nothing here invents a kill or a gather line.
function SG.QuestLines(questID)
    local lines = {}
    if not questID then return lines end
    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questID)
        if ok and type(objs) == "table" then
            for i = 1, #objs do
                local row = objs[i]
                if type(row) == "table" and type(row.text) == "string" and row.text ~= "" then
                    lines[#lines + 1] = {
                        text = row.text,
                        finished = row.finished and true or false,
                        numFulfilled = tonumber(row.numFulfilled),
                        numRequired = tonumber(row.numRequired),
                    }
                end
            end
        end
    end
    if #lines == 0 then
        local index
        if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
            index = C_QuestLog.GetLogIndexForQuestID(questID)
        elseif GetQuestLogIndexByID then
            index = GetQuestLogIndexByID(questID)
        end
        if index and index > 0 and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
            local count = GetNumQuestLeaderBoards(index) or 0
            for i = 1, count do
                local text, _, finished = GetQuestLogLeaderBoard(i, index)
                if type(text) == "string" and text ~= "" then
                    lines[#lines + 1] = { text = text, finished = finished and true or false }
                end
            end
        end
    end
    return lines
end

local function WithCount(row)
    local text = row.text or ""
    local need = row.numRequired
    if type(need) == "number" and need > 0 then
        local have = row.numFulfilled or 0
        local count = string.format("%d/%d", have, need)
        if not text:find(count, 1, true) then
            text = count .. "  " .. text
        end
    end
    return text
end

function SG.StepObjectives(step)
    local lines = {}
    if not step then return lines end
    local function add(questID, name)
        local rows = SG.QuestLines(questID)
        if #rows == 0 then
            local label = name or "This quest"
            local completed, _, objectives = SG.QuestState(questID)
            if completed or objectives then
                lines[#lines + 1] = { text = label .. ": ready to turn in.", finished = true }
            else
                lines[#lines + 1] = {
                    text = label .. ": objectives show once it is in your log.",
                    finished = false,
                    pending = true,
                }
            end
            return
        end
        for i = 1, #rows do
            local text = WithCount(rows[i])
            if name and step.kind == "run" and not text:find(name, 1, true) then
                text = name .. ": " .. text
            end
            lines[#lines + 1] = { text = text, finished = rows[i].finished and true or false }
        end
    end
    if step.kind == "complete" and step.questID then
        add(step.questID, step.questName)
    elseif step.kind == "run" and type(step.runs) == "table" then
        local only = SG.db and SG.db.options and SG.db.options.onlyMySpec
        for i = 1, #step.runs do
            local row = step.runs[i]
            local skip = row.match == "hide" or (row.match == "other" and only)
            if not skip then add(row.id, row.name) end
        end
    end
    return lines
end

function SG.QuestProgressText(step)
    local lines = SG.StepObjectives(step)
    if #lines == 0 then return nil end
    local parts = {}
    for i = 1, #lines do parts[#parts + 1] = lines[i].text end
    return table.concat(parts, "\n")
end

function SG.InitDB()
    if type(_G.StratagemDB) ~= "table" then _G.StratagemDB = {} end
    if type(_G.StratagemCharDB) ~= "table" then _G.StratagemCharDB = {} end
    SG.db = _G.StratagemDB
    SG.char = _G.StratagemCharDB
    SG.CopyDefaults(SG.db, SG.DB_DEFAULTS)
    SG.CopyDefaults(SG.char, SG.CHAR_DEFAULTS)
    if type(SG.db.favorites) ~= "table" then SG.db.favorites = {} end
    if type(SG.db.recent) ~= "table" then SG.db.recent = {} end
    if type(SG.db.tabs) ~= "table" then SG.db.tabs = {} end
    if type(SG.char.progress) ~= "table" then SG.char.progress = {} end
    if SG.db.category == "all" or SG.db.category == nil then SG.db.category = "leveling" end
end

function SG.OnLogin()
    local _, classToken = UnitClass("player")
    local _, _, raceID = UnitRace("player")
    SG.classToken = classToken
    SG.raceID = raceID
    SG.playerSide = SG.PlayerSide()
    if SG.char.class ~= classToken then
        -- A different character, or the first login. Keep an explicit spec only
        -- when it still belongs to this class; Specs.Detect handles the rest.
        SG.char.class = classToken
    end
    SG.Specs.Detect()
    SG.BiS.Refresh()
    if SG.Gear and SG.Gear.Start then SG.Gear.Start() end
    local previous = SG.char.active
    SG.Engine.Rebuild()
    SG.RefreshQuestCache()
    if SG.db.options.autoAdvance then
        SG.Engine.SyncAll(true)
    end
    local active = previous and SG.Engine.Get(previous)
    local route
    if SG.Route and SG.Route.ActiveId then
        route = SG.Engine.Get(SG.Route.ActiveId())
    end
    -- Leveling is one route. A saved dungeon or profession must not keep the arrow
    -- while the window is showing that route.
    local assigned = false
    if SG.db.category == "leveling" then
        if route then
            assigned = not active
            SG.char.active = route.id
            SG.db.selected = route.id
            active = route
        end
    elseif not active and route then
        assigned = true
        SG.char.active = route.id
        SG.db.selected = route.id
        SG.db.category = "leveling"
        active = route
    end
    if active then SG.Engine.CatchUp(active, false) end
    SG.state = SG.state or { query = "", tab = "home", stepIndex = nil }
    if SG.db.category == "bis" then
        SG.state.tab = "bis-60"
    elseif SG.db.category == "leveling" and active then
        SG.state.tab = active.id
    end
    SG.UI.Create()
    SG.Minimap.Create()
    SG.Tracker.Create()
    SG.Arrow.Create()
    if active and SG.db.category ~= "bis" then
        local index = SG.Engine.ShownIndex(active)
        if index then SG.Engine.Focus(active, index, true) end
    end
    if assigned then SG.UI.Show() end
    local events = {
        "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED",
        "GET_ITEM_INFO_RECEIVED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
        "ZONE_CHANGED_NEW_AREA",
    }
    for i = 1, #events do
        SG.eventFrame:RegisterEvent(events[i])
    end
end

function SG.RememberRecent(guideID)
    local recent = SG.db.recent
    for i = #recent, 1, -1 do
        if recent[i] == guideID then table.remove(recent, i) end
    end
    table.insert(recent, 1, guideID)
    while #recent > 8 do table.remove(recent) end
end

local function Slash(msg)
    if not SG.db or not SG.char then
        SG.Print("Still loading.")
        return
    end
    msg = strtrim(msg or "")
    local command, rest = msg:match("^(%S*)%s*(.*)$")
    command = (command or ""):lower()
    if command == "" or command == "toggle" then
        SG.UI.Toggle()
    elseif command == "show" then
        SG.UI.Show()
    elseif command == "hide" then
        if SG.UI.frame then SG.UI.frame:Hide() end
    elseif command == "tracker" then
        SG.db.options.tracker = not SG.db.options.tracker
        SG.Tracker.Update()
        SG.Print(SG.db.options.tracker and "Tracker shown." or "Tracker hidden.")
    elseif command == "next" then
        SG.Engine.Nudge(1)
    elseif command == "prev" or command == "previous" then
        SG.Engine.Nudge(-1)
    elseif command == "done" then
        SG.Engine.Nudge(0)
    elseif command == "wp" or command == "waypoint" then
        SG.Engine.WaypointCurrent()
    elseif command == "arrowflip" then
        SG.db.options.invertArrow = not SG.db.options.invertArrow
        SG.Print(SG.db.options.invertArrow and "Arrow mirrored." or "Arrow set back.")
    elseif command == "status" then
        local spec = SG.Specs.Label(SG.Specs.Selected())
        SG.Print(spec .. ". " .. SG.BiS.Status())
    elseif command == "spec" then
        if rest == "" then
            SG.Print("Current spec: " .. SG.Specs.Label(SG.Specs.Selected()) .. "  (" .. tostring(SG.Specs.Selected()) .. ")")
            SG.Print("Set one with /sg spec <key>, for example /sg spec beast-mastery-hunter")
        else
            local key = rest:lower()
            if SG.Specs.Find(key) then
                SG.char.spec = key
                SG.char.autoDetect = false
                SG.Engine.Rebuild()
                if SG.db.options.autoAdvance then SG.Engine.SyncAll() end
                if SG.UI.Refresh then SG.UI.Refresh(true) end
                SG.Print("Spec set to " .. SG.Specs.Label(key) .. ".")
            else
                SG.Print("Unknown spec key. /sg spec lists the current one.")
            end
        end
    elseif command == "reset" then
        if (rest or ""):lower() == "all" then
            SG.char.progress = {}
            SG.Print("All guide progress cleared.")
        else
            local id = SG.char.active or SG.db.selected
            if id then
                SG.char.progress[id] = { done = {} }
                SG.Print("Progress cleared for the current guide.")
            end
        end
        if SG.db.options.autoAdvance then
            SG.Engine.SyncAll()
            local active = SG.Engine.Active()
            if active then SG.Engine.PlaceCursor(active) end
        end
        if SG.UI.Refresh then SG.UI.Refresh(false) end
        if SG.Tracker.Update then SG.Tracker.Update() end
    else
        SG.Print("Commands: show, hide, tracker, next, prev, done, waypoint, spec, status, reset, reset all, arrowflip")
    end
end

SLASH_STRATAGEM1 = "/stratagem"
SLASH_STRATAGEM2 = "/sg"
SlashCmdList.STRATAGEM = Slash

BINDING_HEADER_STRATAGEM = "Stratagem"
BINDING_NAME_STRATAGEM_TOGGLE = "Toggle Stratagem"

SG.eventFrame = CreateFrame("Frame")
SG.eventFrame:RegisterEvent("ADDON_LOADED")
SG.eventFrame:RegisterEvent("PLAYER_LOGIN")
SG.eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == SG.name then
        SG.InitDB()
    elseif event == "ADDON_LOADED" and arg1 == "QuestieDB" then
        if SG.classToken and SG.Gear and SG.Gear.Start then SG.Gear.Start() end
    elseif event == "ADDON_LOADED" and SG.classToken and (
        arg1 == "NaowhForever" or arg1 == "NaowhForever_BiS" or arg1 == "NaowhForever_DungeonJournal"
        or arg1 == "NaowwahForever" or arg1 == "NaowwahForever_BiS"
    ) then
        if SG.BiS and SG.BiS.Refresh then SG.BiS.Refresh() end
        if SG.Engine and SG.Engine.Rebuild then
            SG.Engine.Rebuild()
            if SG.db and SG.db.options.autoAdvance then SG.Engine.SyncAll(true) end
            local active = SG.Engine.Active and SG.Engine.Active()
            if active then SG.Engine.PlaceCursor(active) end
            if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
        end
    elseif event == "PLAYER_LOGIN" then
        SG.OnLogin()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if SG.UI.OnItem then SG.UI.OnItem(arg1) end
        if SG.Gear and SG.Gear.OnItem then SG.Gear.OnItem(arg1) end
    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_TURNED_IN" or event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" then
        if SG.Engine and SG.Engine.OnQuestUpdate then SG.Engine.OnQuestUpdate() end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" then
        if SG.Gear and SG.Gear.OnEquip then SG.Gear.OnEquip() end
        if event == "PLAYER_LEVEL_UP" and SG.Engine and SG.Engine.Active and SG.Engine.AimForward then
            SG.Engine.AimForward(SG.Engine.Active())
        end
        if event == "PLAYER_LEVEL_UP" and SG.Arrow and SG.Arrow.Tick then SG.Arrow.Tick() end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        if SG.Arrow and SG.Arrow.Tick then SG.Arrow.Tick() end
    end
end)
