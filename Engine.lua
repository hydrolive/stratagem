-- Engine.lua: turns a guide into ordered steps, and remembers which ones are done.
-- A quest becomes three steps (accept, complete, turn in) so progress is real.
-- Step indexes stay stable when the spec filter changes; filtered steps are
-- marked invisible instead of being removed.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Engine = { guides = {}, byId = {} }

local CLASS_ORDER = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}
local CLASS_NAME = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue",
    PRIEST = "Priest", SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}

local KIND_TITLE = {
    accept = "Accept",
    complete = "Complete",
    turnin = "Turn in",
    travel = "Travel",
    note = "Note",
}

function SG.Engine.Giver(where)
    if type(where) ~= "string" or where == "" then return nil end
    if where:find("not known yet", 1, true) then return nil end
    local rest = where:match(" %- (.+)$") or where
    rest = rest:gsub("%s*%(%s*[%d%.]+%s*,%s*[%d%.]+%s*%)", "")
    local prev
    repeat
        prev = rest
        rest = rest:gsub("%s*%b()%s*$", "")
    until rest == prev
    rest = strtrim(rest)
    if rest == "" then return nil end
    return rest
end

local function Step(fields)
    fields.kind = fields.kind or "note"
    fields.title = fields.title or KIND_TITLE[fields.kind] or "Step"
    fields.visible = true
    fields.optional = fields.optional and true or false
    fields.match = fields.match or "bis"
    return fields
end

local function AddQuest(steps, guide, segment, quest, prevLevel, gaps)
    local match = SG.BiS.Match(quest, guide.side)
    local giver = SG.Engine.Giver(quest.where)
    local spec = SG.Specs.Selected()
    local itemID, rank, slot = SG.BiS.BestReward(quest, spec)
    local slotName = slot and SG.SLOT_NAME[slot] or nil
    local from = giver and (" from " .. giver) or ""
    local reward = ""
    if rank and slotName then
        reward = string.format(" Rank %d %s for your spec.", rank, slotName)
    elseif quest.choice then
        reward = " Choose the reward that is best for your spec."
    end
    local place = quest.zone or segment.zone or segment.title
    if gaps and prevLevel and quest.level and (quest.level - prevLevel) >= 4 then
        steps[#steps + 1] = Step({
            kind = "note",
            optional = true,
            match = match,
            segment = segment.title,
            zone = place,
            level = quest.level,
            title = "Level toward " .. quest.level,
            text = string.format(
                "Optional. The next BiS quest is level %d. Quest in %s until you are close, then pick it up. No grind is required if you are already there.",
                quest.level, place
            ),
            map = quest.map, x = quest.x, y = quest.y,
        })
    end
    local shared = {
        questID = quest.id,
        questName = quest.name,
        map = quest.map,
        x = quest.x,
        y = quest.y,
        zone = place,
        segment = segment.title,
        rewards = quest.rewards,
        choice = quest.choice,
        level = quest.level,
        match = match,
        rank = rank,
        slot = slot,
        slotName = slotName,
        itemID = itemID,
    }
    local function add(kind, title, text)
        -- Copy. The three steps must not share one table.
        local row = Step({
            questID = shared.questID, questName = shared.questName,
            map = shared.map, x = shared.x, y = shared.y,
            zone = shared.zone, segment = shared.segment,
            rewards = shared.rewards, choice = shared.choice, level = shared.level,
            match = shared.match, rank = shared.rank, slot = shared.slot,
            slotName = shared.slotName, itemID = shared.itemID,
        })
        row.kind = kind
        row.title = title
        row.text = text
        steps[#steps + 1] = row
    end
    add("accept", "Accept: " .. quest.name,
        string.format("Accept %s%s.%s", quest.name, from, reward))
    add("complete", "Complete: " .. quest.name,
        string.format("Finish the objectives for %s. The reward is why this quest is on the route.", quest.name))
    local turn = giver and (" to " .. giver) or ""
    local choice = quest.choice and " If several pieces are offered, take the one ranked for your spec." or ""
    add("turnin", "Turn in: " .. quest.name,
        string.format("Turn in %s%s.%s", quest.name, turn, choice))
end

local function ApplyVisibility(steps)
    local only = SG.db and SG.db.options and SG.db.options.onlyMySpec
    local hiddenQuests = 0
    for i = 1, #steps do
        local step = steps[i]
        if step.match == "hide" then
            step.visible = false
        elseif step.match == "other" and only then
            step.visible = false
        else
            step.visible = true
        end
        if step.kind == "accept" and step.match == "other" then
            hiddenQuests = hiddenQuests + 1
        end
    end
    -- A travel or note step is shown only when a later quest step in the same
    -- segment is visible, so empty stretches do not linger.
    local segmentLive = {}
    for i = 1, #steps do
        local step = steps[i]
        if step.visible and step.questID then
            segmentLive[step.segment or ""] = true
        end
    end
    for i = 1, #steps do
        local step = steps[i]
        if not step.questID and not segmentLive[step.segment or ""] then
            step.visible = false
        end
    end
    return hiddenQuests
end

local function CountLevels(steps)
    local minLevel, maxLevel, quests = nil, nil, 0
    for i = 1, #steps do
        local step = steps[i]
        if step.questID and step.kind == "accept" and step.match ~= "hide" then
            quests = quests + 1
            if step.level then
                if not minLevel or step.level < minLevel then minLevel = step.level end
                if not maxLevel or step.level > maxLevel then maxLevel = step.level end
            end
        end
    end
    return minLevel, maxLevel, quests
end

function SG.Engine.Compile(def)
    local steps = {}
    local segments = def.segments or {}
    local gaps = def.category == "leveling"
    for s = 1, #segments do
        local segment = segments[s]
        if segment.arrive and segment.arrive.text then
            steps[#steps + 1] = Step({
                kind = "travel",
                optional = true,
                match = "bis",
                segment = segment.title,
                zone = segment.zone or segment.title,
                title = "Travel: " .. (segment.title or def.title),
                text = segment.arrive.text,
                map = segment.arrive.map,
                x = segment.arrive.x,
                y = segment.arrive.y,
            })
        end
        local prev = nil
        local quests = segment.quests or {}
        for q = 1, #quests do
            local quest = SG.BiS.Quest(quests[q])
            if quest then
                AddQuest(steps, def, segment, quest, prev, gaps)
                prev = quest.level or prev
            end
        end
    end
    for i = 1, #steps do
        steps[i].index = i
        steps[i].guide = def.id
    end
    local hidden = ApplyVisibility(steps)
    local minLevel, maxLevel, quests = CountLevels(steps)
    local visibleQuests = 0
    for i = 1, #steps do
        if steps[i].visible and steps[i].kind == "accept" then
            visibleQuests = visibleQuests + 1
        end
    end
    return {
        id = def.id,
        title = def.title,
        group = def.group,
        category = def.category or "leveling",
        side = def.side or "B",
        place = def.place or def.title,
        blurb = def.blurb or "",
        min = minLevel or def.min or 1,
        max = maxLevel or def.max or 60,
        steps = steps,
        hiddenQuests = hidden,
        questCount = quests,
        visibleQuests = visibleQuests,
        empty = visibleQuests == 0,
    }
end

local function BucketQuests(def)
    local buckets = {}
    local order = {}
    local function add(key, title, quest)
        local bucket = buckets[key]
        if not bucket then
            bucket = { title = title, zone = quest.zone or title, quests = {}, level = quest.level or 99 }
            buckets[key] = bucket
            order[#order + 1] = key
        end
        bucket.quests[#bucket.quests + 1] = quest.id
        if quest.level and quest.level < bucket.level then bucket.level = quest.level end
        if not bucket.map and quest.map then
            bucket.map, bucket.x, bucket.y = quest.map, quest.x, quest.y
        end
    end
    local quests = SG.BiS.quests or {}
    for i = 1, #quests do
        local quest = quests[i]
        if SG.BiS.Match(quest, def.side) ~= "hide" then
            if def.dynamic == "dungeons" then
                if quest.dungeon then add(quest.dungeon, quest.dungeon, quest) end
            elseif def.dynamic == "class" then
                if quest.class then
                    add(quest.class, (CLASS_NAME[quest.class] or quest.class) .. " quests", quest)
                end
            elseif def.dynamic == "choices" then
                if quest.choice then
                    local zone = quest.zone or "Elsewhere"
                    add(zone, zone, quest)
                end
            else
                local zone = quest.zone or "Elsewhere"
                add(zone, zone, quest)
            end
        end
    end
    if def.dynamic == "class" then
        table.sort(order, function(a, b)
            local ai, bi = 99, 99
            for i = 1, #CLASS_ORDER do
                if CLASS_ORDER[i] == a then ai = i end
                if CLASS_ORDER[i] == b then bi = i end
            end
            if ai ~= bi then return ai < bi end
            return a < b
        end)
    else
        table.sort(order, function(a, b)
            if buckets[a].level ~= buckets[b].level then
                return buckets[a].level < buckets[b].level
            end
            return buckets[a].title < buckets[b].title
        end)
    end
    local segments = {}
    for i = 1, #order do
        local bucket = buckets[order[i]]
        segments[#segments + 1] = {
            title = bucket.title,
            zone = bucket.zone,
            arrive = {
                text = "Work the BiS quests in " .. bucket.title .. " in the order below.",
                map = bucket.map, x = bucket.x, y = bucket.y,
            },
            quests = bucket.quests,
        }
    end
    return segments
end

function SG.Engine.Rebuild()
    SG.Engine.guides = {}
    SG.Engine.byId = {}
    local data = SG.GuideData or {}
    for i = 1, #data do
        local def = data[i]
        if def.dynamic then
            def = {
                id = def.id, title = def.title, group = def.group,
                category = def.category, side = def.side, place = def.place or def.title,
                blurb = def.blurb, min = def.min, max = def.max,
                segments = BucketQuests(def),
            }
        end
        local guide = SG.Engine.Compile(def)
        SG.Engine.guides[#SG.Engine.guides + 1] = guide
        SG.Engine.byId[guide.id] = guide
    end
end

function SG.Engine.Get(id)
    return SG.Engine.byId[id]
end

function SG.Engine.Progress(id)
    local all = SG.char.progress
    local row = all[id]
    if type(row) ~= "table" then
        row = { done = {} }
        all[id] = row
    end
    if type(row.done) ~= "table" then row.done = {} end
    return row
end

function SG.Engine.IsDone(guide, index)
    local row = SG.Engine.Progress(guide.id)
    return row.done[index] and true or false
end

function SG.Engine.Stats(guide)
    local required, done = 0, 0
    if not guide then return 0, 0 end
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.visible and not step.optional then
            required = required + 1
            if SG.Engine.IsDone(guide, i) then done = done + 1 end
        end
    end
    return done, required
end

function SG.Engine.CurrentIndex(guide)
    if not guide then return nil end
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.visible and not step.optional and not SG.Engine.IsDone(guide, i) then
            return i
        end
    end
    return nil
end

function SG.Engine.FirstVisible(guide)
    for i = 1, #guide.steps do
        if guide.steps[i].visible then return i end
    end
    return nil
end

function SG.Engine.Mark(guide, index, done)
    if not guide or not guide.steps[index] then return end
    SG.Engine.Progress(guide.id).done[index] = done and true or nil
end

local function AutoDone(step, completed, inLog, objectives)
    if step.kind == "accept" then return completed or inLog end
    if step.kind == "complete" then return completed or (inLog and objectives) end
    if step.kind == "turnin" then return completed end
    return false
end

function SG.Engine.SyncAll()
    local guides = SG.Engine.guides or {}
    for g = 1, #guides do
        local guide = guides[g]
        local cache = {}
        for i = 1, #guide.steps do
            local step = guide.steps[i]
            if step.visible and step.questID and not step.optional then
                local state = cache[step.questID]
                if not state then
                    local completed, inLog, objectives = SG.QuestState(step.questID)
                    state = { completed, inLog, objectives }
                    cache[step.questID] = state
                end
                if AutoDone(step, state[1], state[2], state[3]) then
                    SG.Engine.Mark(guide, i, true)
                end
            end
        end
    end
end

local questPending = false
function SG.Engine.OnQuestUpdate()
    if questPending then return end
    questPending = true
    SG.After(0.25, function()
        questPending = false
        if not SG.db then return end
        local active = SG.Engine.Get(SG.char.active)
        local before = active and SG.Engine.CurrentIndex(active) or nil
        if SG.db.options.autoAdvance then SG.Engine.SyncAll() end
        local after = active and SG.Engine.CurrentIndex(active) or nil
        if active and before ~= after and SG.Nav and SG.Nav.following then
            local step = after and active.steps[after] or nil
            if step then SG.Nav.Set(step) end
        end
        if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
        if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
    end)
end

function SG.Engine.Active()
    return SG.Engine.Get(SG.char and SG.char.active)
end

function SG.Engine.Focus(guide, index, waypoint)
    if not guide then return end
    SG.char.active = guide.id
    SG.db.selected = guide.id
    local step = index and guide.steps[index] or nil
    if waypoint and step and SG.Nav then
        SG.Nav.following = true
        SG.Nav.Set(step)
    end
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
end

function SG.Engine.Nudge(direction)
    local guide = SG.Engine.Active() or SG.Engine.Get(SG.db.selected)
    if not guide then
        if SG.UI and SG.UI.Show then SG.UI.Show() end
        SG.Print("Choose a guide in the list, then press Continue.")
        return
    end
    local current = SG.Engine.CurrentIndex(guide) or SG.Engine.FirstVisible(guide)
    if direction == 0 and current then
        SG.Engine.Mark(guide, current, true)
        current = SG.Engine.CurrentIndex(guide)
    elseif direction ~= 0 and current then
        local index = current
        while true do
            index = index + direction
            local step = guide.steps[index]
            if not step then break end
            if step.visible then
                -- Walking backwards should un-complete the step you land on
                -- only when moving forward we mark the one we left.
                if direction > 0 then SG.Engine.Mark(guide, current, true) end
                current = index
                break
            end
        end
    end
    if current then SG.Engine.Focus(guide, current, true) end
    if SG.UI and SG.UI.Refresh then SG.UI.Refresh(false) end
end

function SG.Engine.WaypointCurrent()
    local guide = SG.Engine.Active() or SG.Engine.Get(SG.db.selected)
    if not guide then
        if SG.UI and SG.UI.Show then SG.UI.Show() end
        SG.Print("Choose a guide in the list, then press Continue.")
        return
    end
    local index = SG.Engine.CurrentIndex(guide) or SG.Engine.FirstVisible(guide)
    if index then SG.Engine.Focus(guide, index, true) end
end

function SG.Engine.Matches(guide, query)
    if not query or query == "" then return true end
    local needle = query:lower()
    if guide.title:lower():find(needle, 1, true) then return true end
    if guide.place and guide.place:lower():find(needle, 1, true) then return true end
    if guide.group and guide.group:lower():find(needle, 1, true) then return true end
    if guide.blurb and guide.blurb:lower():find(needle, 1, true) then return true end
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.visible and step.title and step.title:lower():find(needle, 1, true) then
            return true
        end
    end
    return false
end

function SG.Engine.ZoneLine(guide)
    local seen, names = {}, {}
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        local zone = step.visible and step.zone or nil
        if zone and not seen[zone] then
            seen[zone] = true
            names[#names + 1] = zone
            if #names == 3 then break end
        end
    end
    if #names == 0 then return guide.place or guide.title end
    return table.concat(names, ", ")
end
