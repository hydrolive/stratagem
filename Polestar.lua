-- Polestar.lua: read Polestar's loaded guides. Nothing here is copied into the repo.
-- Reputation, profession, and leveling steps come from Polestar.Guides when that
-- addon is enabled. A missing guide stays on the older list, or one note.

local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Polestar = SG.Polestar or {}

local PREFIX = "ps-"
local builtToken

local function Api()
    local P = _G.Polestar
    if P and P.Guides and P.Guides.Get and P.Guides.List and P.Guides.Matches then return P end
    return nil
end

local function Player()
    local _, race = UnitRace("player")
    local _, class = UnitClass("player")
    local faction = UnitFactionGroup("player")
    return { race = race or "", class = class or "", faction = faction or "" }
end

local function Standing(reaction)
    if type(reaction) ~= "number" then return "the next standing" end
    if GetText then
        local sex = UnitSex and UnitSex("player") or nil
        local ok, label = pcall(GetText, "FACTION_STANDING_LABEL" .. reaction, sex)
        if ok and type(label) == "string" and label ~= "" then return label end
    end
    return "standing " .. reaction
end

local function Bar(factionID)
    if type(factionID) ~= "number" then return nil end
    if GetFactionInfoByID then
        local ok, _, _, standingID, barMin, barMax, barValue = pcall(GetFactionInfoByID, factionID)
        if ok and type(barMin) == "number" and type(barMax) == "number" and type(barValue) == "number" and barMax > barMin then
            local width = barMax - barMin
            local have = barValue - barMin
            if have < 0 then have = 0 end
            if have > width then have = width end
            return Standing(standingID), have, width
        end
    end
    if not C_Reputation or not C_Reputation.GetFactionDataByID then return nil end
    local ok, data = pcall(C_Reputation.GetFactionDataByID, factionID)
    if not ok or type(data) ~= "table" then return nil end
    local low = data.currentReactionThreshold
    local high = data.nextReactionThreshold
    local cur = data.currentStanding
    if type(low) ~= "number" or type(high) ~= "number" or type(cur) ~= "number" or high <= low then return nil end
    local width = high - low
    local have = cur - low
    if have < 0 then have = 0 end
    if have > width then have = width end
    return Standing(data.reaction), have, width
end

SG.Polestar.Bar = Bar

local function Token()
    local P = Api()
    if not P then return "0" end
    local list = P.Guides.List()
    local n = (type(list) == "table") and #list or 0
    return "1:" .. n
end

SG.Polestar.Token = Token

local function OnMap(n)
    return type(n) == "number" and n >= 0 and n <= 100
end

local function FirstPin(goal, player, P)
    local list = goal.candidates
    if type(list) == "table" then
        for i = 1, #list do
            local c = list[i]
            if type(c) == "table" and P.Guides.CandidateMatches(c, player) and OnMap(c.map) and OnMap(c.x) and OnMap(c.y) then
                return c.map, c.x, c.y
            end
        end
    end
    if OnMap(goal.map) and OnMap(goal.x) and OnMap(goal.y) then
        return goal.map, goal.x, goal.y
    end
    return nil
end

local function CountName(count, name)
    if type(name) ~= "string" or name == "" then return nil end
    if type(count) == "number" and count > 1 then return count .. " " .. name end
    return name
end

local function GoalLine(goal)
    local t = goal.t
    if t == "rep" then return "Reach " .. Standing(goal.standing) .. "." end
    if t == "skill" then
        return "Reach " .. (goal.skill or "the profession") .. " " .. tostring(goal.level or "?") .. "."
    end
    if t == "train" then return "Train " .. (goal.skill or "the profession") .. "." end
    if t == "craft" then
        local line = "Craft " .. (goal.spellName or goal.itemName or "the recipe")
        if type(goal.untilSkill) == "number" then line = line .. " until " .. goal.untilSkill end
        local reagents = goal.reagents
        if type(reagents) == "table" and #reagents > 0 then
            local bits, n = {}, #reagents
            if n > 6 then n = 6 end
            for i = 1, n do
                local row = reagents[i]
                if type(row) == "table" then
                    local named = CountName(row.count, row.itemName)
                    if named then bits[#bits + 1] = named end
                end
            end
            if #bits > 0 then line = line .. ". Uses " .. table.concat(bits, ", ") end
        end
        return line .. "."
    end
    if t == "accept" then return "Accept " .. (goal.title or "the quest") .. "." end
    if t == "turnin" then return "Turn in " .. (goal.title or "the quest") .. "." end
    if t == "collect" then
        local named = CountName(goal.count, goal.itemName)
        return "Collect " .. (named or "the item") .. "."
    end
    if t == "kill" then
        local named = CountName(goal.count, goal.target or goal.npcName)
        return "Kill " .. (named or "the target") .. "."
    end
    if t == "buy" then
        local named = CountName(goal.count, goal.itemName)
        return "Buy " .. (named or "the item") .. "."
    end
    if t == "talk" then return "Talk to " .. (goal.npcName or "the NPC") .. "." end
    if t == "level" and type(goal.level) == "number" then return "Reach level " .. goal.level .. "." end
    if t == "note" and type(goal.text) == "string" and goal.text ~= "" then return goal.text end
    if t == "goto" and type(goal.text) == "string" and goal.text ~= "" then return "Go to " .. goal.text .. "." end
    if t == "interact" then return "Use " .. (goal.objName or goal.itemName or "the object") .. "." end
    if t == "sethome" then return "Set your hearth" .. (goal.location and (" at " .. goal.location) or "") .. "." end
    if t == "getfp" then return "Get the flight path" .. (goal.location and (" at " .. goal.location) or "") .. "." end
    if t == "vendor" then return "Vendor junk." end
    return nil
end

local function OneStep(ps, player, P, mode)
    if ps.only and not P.Guides.Matches(ps.only, player) then return nil end
    local goals = ps.goals
    if type(goals) ~= "table" then return nil end
    local lines = {}
    local map, x, y
    local standing, faction, skillTo, levelGoal, qlvl
    local turnins, accepts
    local used = 0
    for i = 1, #goals do
        local goal = goals[i]
        if type(goal) == "table" and (not goal.only or P.Guides.Matches(goal.only, player)) then
            used = used + 1
            if not map then map, x, y = FirstPin(goal, player, P) end
            if goal.t == "rep" and type(goal.standing) == "number" then
                standing = goal.standing
                if type(goal.faction) == "number" then faction = goal.faction end
            elseif goal.t == "skill" and type(goal.level) == "number" then
                skillTo = goal.level
            elseif goal.t == "craft" and type(goal.untilSkill) == "number" and not skillTo then
                skillTo = goal.untilSkill
            elseif goal.t == "level" and type(goal.level) == "number" then
                levelGoal = goal.level
            elseif goal.t == "turnin" and type(goal.quest) == "number" and not goal.optional then
                turnins = turnins or {}
                turnins[#turnins + 1] = goal.quest
            elseif goal.t == "accept" and type(goal.quest) == "number" and not goal.optional then
                accepts = accepts or {}
                accepts[#accepts + 1] = goal.quest
            end
            if type(goal.qlvl) == "number" and (not qlvl or goal.qlvl < qlvl) then qlvl = goal.qlvl end
            if #lines < 8 then
                local line = GoalLine(goal)
                if line and line ~= "" then lines[#lines + 1] = line end
            end
        end
    end
    if used == 0 and (type(ps.note) ~= "string" or ps.note == "") then return nil end
    local text = ""
    if type(ps.note) == "string" and ps.note ~= "" then text = ps.note end
    if #lines > 0 then
        if text ~= "" then text = text .. "\n" end
        text = text .. table.concat(lines, "\n")
    end
    local extra = used - #lines
    if extra > 0 then text = text .. "\nThe guide lists " .. extra .. " more on this step." end
    local title = ps.title or "Step"
    if mode ~= "rep" and lines[1] then title = lines[1]:gsub("%.$", "") end
    local step = {
        kind = (mode == "prof" and "prof") or (mode == "rep" and "rep") or "path",
        optional = false,
        match = "bis",
        visible = true,
        title = title,
        segment = ps.title or title,
        zone = ps.title or title,
        text = text,
        baseText = text,
        map = map,
        x = x,
        y = y,
    }
    if mode == "rep" then
        step.repWork = true
        step.repStanding = standing
        step.repFaction = faction
        step.level = levelGoal
        local only = ps.only
        if type(only) == "table" and type(only.factions) == "table" and #only.factions == 1 then
            if only.factions[1] == "Alliance" then step.repSide = "A" end
            if only.factions[1] == "Horde" then step.repSide = "H" end
        end
    elseif mode == "prof" then
        step.profTrack = "work"
        step.profOrder = 1
        step.skillGate = skillTo
        step.level = levelGoal
    else
        step.turnins = turnins
        step.accepts = accepts
        step.level = qlvl or levelGoal
        step.psRoute = true
    end
    return step
end

local function RepStepOk(ps, factionID)
    if type(factionID) ~= "number" then return true end
    local goals = ps.goals
    if type(goals) ~= "table" then return true end
    local saw = false
    for i = 1, #goals do
        local goal = goals[i]
        if type(goal) == "table" and goal.t == "rep" and type(goal.faction) == "number" then
            saw = true
            if goal.faction == factionID then return true end
        end
    end
    return not saw
end

local function ViewerFor(ps, player)
    local only = ps.only
    if type(only) == "table" and type(only.factions) == "table" and #only.factions == 1 then
        return { race = player.race, class = player.class, faction = only.factions[1] }
    end
    return player
end

-- Steps that actually raise this faction id. open means those steps are not
-- locked to one side, so the logged-in player is the filter. A locked side
-- keeps that side's steps even when the other faction is logged in.
local function AllowedFactions(guide, factionID)
    local allowed = {}
    local open = false
    local saw = false
    local steps = guide.steps
    if type(steps) ~= "table" then return allowed, true end
    for i = 1, #steps do
        local ps = steps[i]
        local goals = type(ps) == "table" and ps.goals
        if type(goals) == "table" then
            local hit = false
            for g = 1, #goals do
                local goal = goals[g]
                if type(goal) == "table" and goal.t == "rep" and goal.faction == factionID then
                    hit = true
                    break
                end
            end
            if hit then
                saw = true
                local only = ps.only
                local factions = type(only) == "table" and only.factions
                if type(factions) == "table" and #factions == 1 then
                    allowed[factions[1]] = true
                else
                    open = true
                end
            end
        end
    end
    if not saw then open = true end
    return allowed, open
end

local function StepSideOk(ps, allowed, open)
    if open then return true end
    local only = ps.only
    local factions = type(only) == "table" and only.factions
    if type(factions) ~= "table" or #factions ~= 1 then return true end
    return allowed[factions[1]] and true or false
end

local function Walk(guide, mode, factionID)
    local P = Api()
    local steps = {}
    if not P or not guide or type(guide.steps) ~= "table" then return steps end
    local player = Player()
    if guide.faction and P.Guides.GuideMatches and not P.Guides.GuideMatches(guide, player) then
        return steps
    end
    local allowed, open = {}, true
    if mode == "rep" and type(factionID) == "number" then
        allowed, open = AllowedFactions(guide, factionID)
    end
    for i = 1, #guide.steps do
        local ps = guide.steps[i]
        local keep = type(ps) == "table"
        if keep and mode == "rep" then
            keep = RepStepOk(ps, factionID) and StepSideOk(ps, allowed, open)
        end
        if keep then
            local viewer = player
            if mode == "rep" and not open then viewer = ViewerFor(ps, player) end
            local step = OneStep(ps, viewer, P, mode)
            if step then steps[#steps + 1] = step end
        end
    end
    return steps
end

local function TagRep(steps)
    local gates = {}
    for i = 1, #steps do
        if steps[i].repStanding then gates[#gates + 1] = i end
    end
    local at = 1
    for i = 1, #steps do
        while at < #gates and i > gates[at] do at = at + 1 end
        local gate = gates[at]
        local name = gate and Standing(steps[gate].repStanding) or "Reputation"
        steps[i].segment = name
        steps[i].zone = name
    end
end

local function TagProf(steps)
    local from, start = 1, 1
    for i = 1, #steps do
        local gate = steps[i].skillGate
        if type(gate) == "number" then
            for j = start, i do
                steps[j].skillFrom = from
                steps[j].skillTo = gate
            end
            from = gate
            start = i + 1
        end
    end
    local cap = 300
    if from > cap then cap = from end
    for j = start, #steps do
        steps[j].skillFrom = from
        steps[j].skillTo = cap
    end
    for i = 1, #steps do
        local step = steps[i]
        step.dropLine = (step.skillFrom or 1) .. "-" .. (step.skillTo or cap)
    end
end

local function Ensure()
    local token = Token()
    if token == builtToken and SG.Polestar.repMap and SG.Polestar.profMap then return Api() ~= nil end
    builtToken = token
    SG.Polestar.repMap = {}
    SG.Polestar.profMap = {}
    local P = Api()
    if not P then return false end
    local player = Player()
    local headers = P.Guides.List()
    if type(headers) ~= "table" then return true end
    for i = 1, #headers do
        local header = headers[i]
        local category = header.category
        if (category == "Reputation" or category == "Professions") and P.Guides.GuideMatches(header, player) then
            local guide = P.Guides.Get(header.id)
            local steps = guide and guide.steps
            if type(steps) == "table" then
                for s = 1, #steps do
                    local goals = steps[s].goals
                    if type(goals) == "table" then
                        for g = 1, #goals do
                            local goal = goals[g]
                            if type(goal) == "table" then
                                if category == "Professions" and type(goal.skillLine) == "number" then
                                    if not SG.Polestar.profMap[goal.skillLine] then
                                        SG.Polestar.profMap[goal.skillLine] = header.id
                                    end
                                elseif category == "Reputation" and goal.t == "rep" and type(goal.faction) == "number" then
                                    SG.Polestar.repMap[goal.faction] = header.id
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return true
end

function SG.Polestar.HasRep()
    if not Ensure() then return false end
    return next(SG.Polestar.repMap) ~= nil
end

function SG.Polestar.HasProf()
    if not Ensure() then return false end
    return next(SG.Polestar.profMap) ~= nil
end

function SG.Polestar.FactionSteps(factionID)
    if not Ensure() or type(factionID) ~= "number" then return nil end
    local id = SG.Polestar.repMap[factionID]
    if not id then return nil end
    local guide = Api().Guides.Get(id)
    if not guide then return nil end
    local steps = Walk(guide, "rep", factionID)
    if #steps == 0 then return nil end
    TagRep(steps)
    for i = 1, #steps do
        if not steps[i].repFaction then steps[i].repFaction = factionID end
    end
    return steps, guide.minLevel, guide.maxLevel
end

function SG.Polestar.ProfessionSteps(skillLine)
    if not Ensure() or type(skillLine) ~= "number" then return nil end
    local id = SG.Polestar.profMap[skillLine]
    if not id then return nil end
    local guide = Api().Guides.Get(id)
    if not guide then return nil end
    local steps = Walk(guide, "prof")
    if #steps == 0 then return nil end
    TagProf(steps)
    return steps
end

local function SideOf(guide)
    if guide.faction == "Alliance" then return "A" end
    if guide.faction == "Horde" then return "H" end
    return "B"
end

local function GroupOf(guide)
    if guide.faction == "Alliance" then return "Alliance leveling" end
    if guide.faction == "Horde" then return "Horde leveling" end
    return "Both"
end

function SG.Polestar.ExtraReps(seen)
    local out = {}
    if not Ensure() then return out end
    local P = Api()
    seen = seen or {}
    for factionID, id in pairs(SG.Polestar.repMap) do
        if not seen[factionID] then
            local guide = P.Guides.Get(id)
            if guide then
                local steps = Walk(guide, "rep", factionID)
                local matched, side
                for i = 1, #steps do
                    if steps[i].repFaction == factionID then
                        matched = true
                        if not side and steps[i].repSide then side = steps[i].repSide end
                    end
                end
                if matched then
                    TagRep(steps)
                    for i = 1, #steps do
                        if not steps[i].repFaction then steps[i].repFaction = factionID end
                    end
                    out[#out + 1] = {
                        faction = factionID,
                        name = guide.title or ("Faction " .. factionID),
                        side = side or SideOf(guide),
                        steps = steps,
                        min = guide.minLevel,
                        max = guide.maxLevel,
                    }
                end
            end
        end
    end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    return out
end

local function TurnedIn(questID)
    if not SG.QuestState then return false end
    local done = SG.QuestState(questID)
    return done and true or false
end

function SG.Polestar.Apply(guide)
    if not guide or not guide.psRoute or not guide.steps then return end
    local row
    if SG.Engine and SG.Engine.Progress then row = SG.Engine.Progress(guide.id) end
    local steps = guide.steps
    local last = 0
    for i = 1, #steps do
        local turns = steps[i].turnins
        if type(turns) == "table" and #turns > 0 then
            local all = true
            for n = 1, #turns do
                if not TurnedIn(turns[n]) then
                    all = false
                    break
                end
            end
            if all then last = i end
        end
    end
    for i = 1, #steps do
        steps[i].visible = true
        if i <= last and row and row.hold ~= i then row.done[i] = true end
    end
end

local function IsRoute(id)
    return type(id) == "string" and id:sub(1, #PREFIX) == PREFIX
end

local function NoteGuide()
    local text = "Leveling routes load with Polestar and Polestar_Guides. Nothing is filled in past the guides those addons have loaded."
    return {
        id = PREFIX .. "missing",
        title = "Leveling routes",
        group = "Leveling",
        category = "routes",
        side = "B",
        place = "Leveling",
        blurb = text,
        min = 1,
        max = 60,
        steps = {
            {
                kind = "note",
                optional = false,
                match = "bis",
                visible = true,
                index = 1,
                guide = PREFIX .. "missing",
                segment = "Leveling",
                zone = "Leveling",
                level = 1,
                title = "No routes loaded",
                text = text,
                baseText = text,
            },
        },
        hiddenQuests = 0,
        questCount = 1,
        visibleQuests = 1,
        empty = false,
        route = false,
        psRoute = true,
    }
end

local function RouteGuide(header, P)
    local guide = P.Guides.Get(header.id)
    if not guide then return nil end
    local steps = Walk(guide, "route")
    if #steps == 0 then return nil end
    local lo = guide.minLevel or header.minLevel or 1
    local hi = guide.maxLevel or header.maxLevel or 60
    local name = guide.title or header.title or "Route"
    local title = name
    if type(lo) == "number" and type(hi) == "number" then title = name .. " (" .. lo .. "-" .. hi .. ")" end
    local id = PREFIX .. (guide.id or header.id or "route"):gsub("[^%w]+", "-")
    local built = {
        id = id,
        title = title,
        group = GroupOf(guide),
        category = "routes",
        side = SideOf(guide),
        place = guide.zoneName or name,
        blurb = "Levels " .. tostring(lo) .. " to " .. tostring(hi) .. " from the loaded guide. A finished turn-in marks that step done, and the steps before it.",
        min = lo,
        max = hi,
        steps = steps,
        hiddenQuests = 0,
        questCount = #steps,
        visibleQuests = #steps,
        empty = false,
        route = false,
        psRoute = true,
    }
    for i = 1, #steps do
        steps[i].index = i
        steps[i].guide = id
    end
    return built
end

function SG.Polestar.Install(quiet)
    if not SG.Engine or not SG.Engine.guides or not SG.Engine.byId then return end
    builtToken = nil
    local list = SG.Engine.guides
    local i = 1
    while i <= #list do
        if IsRoute(list[i].id) then
            SG.Engine.byId[list[i].id] = nil
            table.remove(list, i)
        else
            i = i + 1
        end
    end
    local built = {}
    local P = Api()
    if P then
        local player = Player()
        local headers = P.Guides.List()
        if type(headers) == "table" then
            for n = 1, #headers do
                local header = headers[n]
                if header.category == "Leveling" and P.Guides.GuideMatches(header, player) then
                    built[#built + 1] = header
                end
            end
        end
        table.sort(built, function(a, b)
            local am, bm = a.minLevel or 0, b.minLevel or 0
            if am ~= bm then return am < bm end
            return (a.title or "") < (b.title or "")
        end)
    end
    local guides = {}
    for n = 1, #built do
        local guide = RouteGuide(built[n], P)
        if guide then guides[#guides + 1] = guide end
    end
    if #guides == 0 then guides[1] = NoteGuide() end
    for n = 1, #guides do
        local guide = guides[n]
        list[#list + 1] = guide
        SG.Engine.byId[guide.id] = guide
        if SG.Engine.AlignProgress then SG.Engine.AlignProgress(guide) end
        SG.Polestar.Apply(guide)
    end
    SG.Polestar.key = Token()
    if quiet then return end
    local active = SG.Engine.Active and SG.Engine.Active()
    if active and active.psRoute and SG.Engine.PlaceCursor then
        active = SG.Engine.Get(active.id) or active
        SG.Engine.PlaceCursor(active)
    end
    if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
end

function SG.Polestar.Refresh()
    if not SG.Engine then return end
    if SG.Polestar.key ~= Token() then
        SG.Polestar.Install()
        return
    end
    local list = SG.Engine.guides or {}
    for i = 1, #list do
        if list[i].psRoute then SG.Polestar.Apply(list[i]) end
    end
    local active = SG.Engine.Active and SG.Engine.Active()
    if active and active.psRoute and SG.Engine.PlaceCursor then
        active = SG.Engine.Get(active.id) or active
        SG.Engine.PlaceCursor(active)
    end
    if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
end

function SG.Polestar.Prepare(id)
    if not SG.Engine then return end
    if SG.Polestar.key ~= Token() then SG.Polestar.Install(true) end
    local guide = id and SG.Engine.Get(id)
    if guide and guide.psRoute then SG.Polestar.Apply(guide) end
end
