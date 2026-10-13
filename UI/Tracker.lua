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
    frame.prev:SetScript("OnClick", function() SG.Engine.Nudge(-1) end)
    frame.waypoint:SetScript("OnClick", function() SG.Engine.WaypointCurrent() end)
    frame.done:SetScript("OnClick", function() SG.Engine.Nudge(0) end)
    frame.next:SetScript("OnClick", function() SG.Engine.Nudge(1) end)

    SG.Tracker.frame = frame
    SG.Tracker.Update()
end

function SG.Tracker.Update()
    local frame = SG.Tracker.frame
    if not frame then return end
    if not SG.db.options.tracker then
        frame:Hide()
        return
    end
    local guide = SG.Engine.Active()
    if not guide then
        frame:Show()
        frame.count:SetText("")
        frame.step:SetText("Open a guide and press Continue.")
        frame.coord:SetText("No route yet.")
        frame.bar:SetPercent(0)
        return
    end
    frame:Show()
    local done, total = SG.Engine.Stats(guide)
    local percent = total > 0 and (done / total) or 0
    frame.bar:SetPercent(percent, total > 0 and done == total)
    frame.count:SetText(string.format("%d / %d", done, total))
    local index = SG.Engine.CurrentIndex(guide)
    local step = index and guide.steps[index] or nil
    if not step then
        frame.step:SetText(guide.title .. " is complete.")
        frame.coord:SetText(guide.place or "")
    else
        frame.step:SetText(step.title)
        frame.coord:SetText(SG.Nav.CoordText(step))
    end
end
