-- Tracker.lua: the small step card that stays on screen while you follow a guide.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Tracker = {}

local function Save(frame)
    local point, _, rel, x, y = frame:GetPoint()
    local pos = SG.db.ui.tracker
    pos.point, pos.rel, pos.x, pos.y = point, rel, x, y
end

function SG.Tracker.Create()
    if SG.Tracker.frame then
        SG.Tracker.Update()
        return
    end
    local frame = CreateFrame("Button", "StratagemTracker", UIParent)
    frame:SetSize(300, 148)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    local pos = SG.db.ui.tracker
    frame:SetPoint(pos.point or "BOTTOM", UIParent, pos.rel or "BOTTOM", pos.x or 280, pos.y or 210)
    SG.Widgets.Backdrop(frame, SG.Theme.bg)
    SG.Widgets.Edge(frame, SG.Theme.line)

    frame:SetScript("OnDragStart", function(self)
        if not SG.db.options.lockTracker then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Save(self)
    end)

    local title = SG.Widgets.Text(frame, 11)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetTextColor(SG.RGB(SG.Theme.gold))
    title:SetText("STRATAGEM")
    frame.title = title

    local count = SG.Widgets.Text(frame, 11)
    count:SetPoint("TOPRIGHT", -12, -10)
    count:SetTextColor(SG.RGB(SG.Theme.muted))
    frame.count = count

    local bar = SG.Widgets.Bar(frame)
    bar:SetPoint("TOPLEFT", 12, -28)
    bar:SetPoint("TOPRIGHT", -12, -28)
    frame.bar = bar

    local step = SG.Widgets.Text(frame, 13)
    step:SetPoint("TOPLEFT", 12, -40)
    step:SetPoint("TOPRIGHT", -12, -40)
    step:SetJustifyH("LEFT")
    step:SetWordWrap(true)
    step:SetHeight(36)
    frame.step = step

    local coord = SG.Widgets.Text(frame, 11)
    coord:SetPoint("TOPLEFT", 12, -78)
    coord:SetPoint("TOPRIGHT", -12, -78)
    coord:SetJustifyH("LEFT")
    coord:SetTextColor(SG.RGB(SG.Theme.muted))
    frame.coord = coord

    local function small(text, x)
        local button = SG.Widgets.Button(frame, text, "ghost")
        button:SetSize(64, 22)
        button:SetPoint("BOTTOMLEFT", x, 10)
        return button
    end
    frame.prev = small("Prev", 12)
    frame.waypoint = small("Point", 80)
    frame.done = small("Done", 148)
    frame.next = small("Next", 216)
    local function onStep(nudge)
        return function(_, button)
            if button == "RightButton" then
                if SG.UI and SG.UI.ShowGuides then SG.UI.ShowGuides() end
            else
                nudge()
            end
        end
    end
    frame.prev:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame.waypoint:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame.done:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame.next:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame.prev:SetScript("OnClick", onStep(function() SG.Engine.Nudge(-1) end))
    frame.waypoint:SetScript("OnClick", onStep(function() SG.Engine.WaypointCurrent() end))
    frame.done:SetScript("OnClick", onStep(function() SG.Engine.Nudge(0) end))
    frame.next:SetScript("OnClick", onStep(function() SG.Engine.Nudge(1) end))
    frame:RegisterForClicks("RightButtonUp")
    frame:SetScript("OnClick", function(_, button)
        if button == "RightButton" and SG.UI and SG.UI.ShowGuides then
            SG.UI.ShowGuides()
        end
    end)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Stratagem", 0.85, 0.7, 1)
        GameTooltip:AddLine("Right-click to open the leveling route.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local choose = SG.Widgets.Button(frame, "Open the route", "primary")
    choose:SetPoint("BOTTOMLEFT", 12, 10)
    choose:SetPoint("BOTTOMRIGHT", -12, 10)
    choose:SetScript("OnClick", function()
        if SG.UI.ShowGuides then SG.UI.ShowGuides() else SG.UI.Show() end
    end)
    frame.choose = choose

    SG.Tracker.frame = frame
    SG.Tracker.Update()
end

local function Line(frame, index)
    local line = frame.lines and frame.lines[index]
    if line then return line end
    frame.lines = frame.lines or {}
    line = SG.Widgets.Text(frame, 11)
    line:SetJustifyH("LEFT")
    line:SetWordWrap(false)
    line:SetHeight(14)
    line:Hide()
    frame.lines[index] = line
    return line
end

local function RewardRow(frame, index)
    local row = frame.rewards and frame.rewards[index]
    if row then return row end
    frame.rewards = frame.rewards or {}
    row = CreateFrame("Button", nil, frame)
    row:SetHeight(24)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("LEFT")
    local text = SG.Widgets.Text(row, 11)
    text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    text:SetPoint("RIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    row.icon = icon
    row.text = text
    row:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(self.itemID)
        else
            GameTooltip:SetHyperlink("item:" .. self.itemID)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:Hide()
    frame.rewards[index] = row
    return row
end

local function HideExtras(frame)
    local lines = frame.lines or {}
    for i = 1, #lines do lines[i]:Hide() end
    local rewards = frame.rewards or {}
    for i = 1, #rewards do
        rewards[i].itemID = nil
        rewards[i]:Hide()
    end
end

local function Byte(n)
    n = math.floor((n or 1) * 255 + 0.5)
    if n < 0 then n = 0 end
    if n > 255 then n = 255 end
    return n
end

local function Hex(r, g, b)
    return string.format("|cff%02x%02x%02x", Byte(r), Byte(g), Byte(b))
end

local function ShowTurnIn(frame, step, y)
    local rewards = step.rewards or {}
    local shown = 0
    for i = 1, #rewards do
        if shown >= 4 then break end
        local itemID = rewards[i]
        if itemID then
            shown = shown + 1
            local row = RewardRow(frame, shown)
            row.itemID = itemID
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 12, -y)
            row:SetPoint("TOPRIGHT", -12, -y)
            local name, _, quality, texture = SG.ItemName(itemID)
            if texture then
                row.icon:SetTexture(texture)
            else
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            local r, g, b = SG.ItemColor(quality)
            local tag, tr, tg, tb = "", nil, nil, nil
            local mode = step.pickSet and step.pickSet[itemID]
            if mode == "bis" then
                tag = "   Take · Level BiS"
                tr, tg, tb = SG.RGB(SG.Theme.gold)
            elseif mode == "upgrade" then
                tag = "   Take · Upgrade"
                tr, tg, tb = SG.RGB(SG.Theme.good)
            elseif step.skipSet and step.skipSet[itemID] then
                tag = "   Skip"
                tr, tg, tb = SG.RGB(SG.Theme.muted)
            end
            local line = Hex(r, g, b) .. (name or ("Item " .. itemID)) .. "|r"
            if tag ~= "" then line = line .. Hex(tr, tg, tb) .. tag .. "|r" end
            row.text:SetText(line)
            row.text:SetTextColor(1, 1, 1, 1)
            row:Show()
            y = y + 26
        end
    end
    local pool = frame.rewards or {}
    for i = shown + 1, #pool do
        pool[i].itemID = nil
        pool[i]:Hide()
    end
    return y
end

local function ShowObjectives(frame, step, y)
    local rows = SG.StepObjectives and SG.StepObjectives(step) or {}
    local cap = #rows
    if cap > 16 then cap = 16 end
    for i = 1, cap do
        local row = rows[i]
        local line = Line(frame, i)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", 12, -y)
        line:SetPoint("TOPRIGHT", -12, -y)
        line:SetText(row.text or "")
        if row.finished then
            line:SetTextColor(SG.RGB(SG.Theme.good))
        else
            line:SetTextColor(SG.RGB(SG.Theme.text))
        end
        line:Show()
        y = y + 14
    end
    local pool = frame.lines or {}
    for i = cap + 1, #pool do pool[i]:Hide() end
    return y
end

function SG.Tracker.Update()
    local frame = SG.Tracker.frame
    if not frame or SG.Tracker.updating then return end
    SG.Tracker.updating = true
    if not SG.db.options.tracker then
        frame:Hide()
        SG.Tracker.updating = false
        if SG.Arrow and SG.Arrow.Tick then SG.Arrow.Tick() end
        return
    end
    local guide = SG.Engine.Active()
    local function steps(show)
        if show then
            frame.prev:Show()
            frame.waypoint:Show()
            frame.done:Show()
            frame.next:Show()
            frame.choose:Hide()
        else
            frame.prev:Hide()
            frame.waypoint:Hide()
            frame.done:Hide()
            frame.next:Hide()
            frame.choose:Show()
        end
    end
    if not guide then
        frame:Show()
        frame:SetHeight(148)
        HideExtras(frame)
        steps(false)
        frame.count:SetText("")
        frame.step:SetTextColor(SG.RGB(SG.Theme.text))
        frame.step:SetText("The leveling route is not ready yet.")
        frame.coord:SetText("Open the route once the addon has finished loading.")
        frame.bar:SetPercent(0)
        SG.Tracker.updating = false
        if SG.Arrow and SG.Arrow.Tick then SG.Arrow.Tick() end
        return
    end
    frame:Show()
    steps(true)
    local done, total = SG.Engine.Stats(guide)
    local percent = total > 0 and (done / total) or 0
    frame.bar:SetPercent(percent, total > 0 and done == total)
    frame.count:SetText(string.format("%d / %d", done, total))
    local index = SG.Engine.ShownIndex(guide)
    local step = index and guide.steps[index] or nil
    HideExtras(frame)
    local y = 78
    frame.coord:ClearAllPoints()
    frame.coord:SetPoint("TOPLEFT", 12, -y)
    frame.coord:SetPoint("TOPRIGHT", -12, -y)
    if not step then
        frame:SetHeight(148)
        frame.step:SetTextColor(SG.RGB(SG.Theme.text))
        frame.step:SetText(guide.title .. " is complete.")
        frame.coord:SetText(guide.place or "")
    else
        local tag = ""
        if step.bisFrom == "level" then
            tag = "Level BiS   "
            frame.step:SetTextColor(SG.RGB(SG.Theme.gold))
        elseif step.bisFrom == "upgrade" then
            tag = "Upgrade   "
            frame.step:SetTextColor(SG.RGB(SG.Theme.good))
        else
            frame.step:SetTextColor(SG.RGB(SG.Theme.text))
        end
        frame.step:SetText(tag .. step.title)
        local dist = SG.Nav.FormatDistance(SG.Nav.Measure(step))
        local coord = SG.Nav.CoordText(step)
        if step.gearName and step.gearName ~= "" and step.kind ~= "turnin" then
            coord = step.gearName .. (coord ~= "" and ("    " .. coord) or "")
        end
        frame.coord:SetText(dist and (coord .. "    " .. dist) or coord)
        y = y + 18
        if step.kind == "complete" or step.kind == "run" then
            y = ShowObjectives(frame, step, y)
        elseif step.kind == "turnin" then
            y = ShowTurnIn(frame, step, y)
        end
        local height = y + 42
        if height < 148 then height = 148 end
        frame:SetHeight(height)
    end
    SG.Tracker.updating = false
    if SG.Arrow and SG.Arrow.Tick then SG.Arrow.Tick() end
end
