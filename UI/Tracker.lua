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

    local chain = CreateFrame("Button", nil, frame)
    chain:SetSize(16, 16)
    chain:SetFrameLevel(frame:GetFrameLevel() + 5)
    chain:SetPoint("TOPRIGHT", -10, -46)
    local chainTex = chain:CreateTexture(nil, "ARTWORK")
    chainTex:SetAllPoints()
    chainTex:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    chainTex:SetVertexColor(SG.RGB(SG.Theme.gold))
    chain:SetScript("OnEnter", function(self)
        local guide = SG.Engine.Active()
        local index = guide and SG.Engine.ShownIndex(guide)
        local current = index and guide.steps[index]
        if current and SG.ShowChainTip then SG.ShowChainTip(self, current) end
    end)
    chain:SetScript("OnLeave", function() GameTooltip:Hide() end)
    chain:Hide()
    frame.chain = chain
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = self.objMax or 0
        if maxScroll <= 0 then return end
        local offset = (self.objOffset or 0) - delta * 28
        if offset < 0 then offset = 0 end
        if offset > maxScroll then offset = maxScroll end
        self.objOffset = offset
        SG.Tracker.Update()
    end)

    local coord = SG.Widgets.Text(frame, 11)
    coord:SetPoint("TOPLEFT", 12, -78)
    coord:SetPoint("TOPRIGHT", -12, -78)
    coord:SetJustifyH("LEFT")
    coord:SetWordWrap(true)
    coord:SetHeight(16)
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
        GameTooltip:AddLine("Right-click to open Gear.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local choose = SG.Widgets.Button(frame, "Open Gear", "primary")
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
    line:SetWordWrap(true)
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

local function ObjectiveRows(frame, step)
    local rows = SG.StepObjectives and SG.StepObjectives(step) or {}
    local heights = {}
    local total = 0
    for i = 1, #rows do
        local line = Line(frame, i)
        line:SetWidth(276)
        line:SetText(rows[i].text or "")
        local h = line:GetStringHeight() or 0
        if h < 14 then
            local text = rows[i].text or ""
            local lines = math.floor((#text + 45) / 46)
            if lines < 1 then lines = 1 end
            h = lines * 14
        end
        heights[i] = h
        total = total + h + 2
    end
    return rows, heights, total
end

local function ShowObjectives(frame, step, y, viewBottom, rows, heights)
    local offset = frame.objOffset or 0
    local cursor = 0
    for i = 1, #rows do
        local line = Line(frame, i)
        local top = y + cursor - offset
        local bottom = top + heights[i]
        cursor = cursor + heights[i] + 2
        if bottom > y and top < viewBottom then
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", 12, -top)
            line:SetPoint("TOPRIGHT", -12, -top)
            line:SetHeight(heights[i])
            if rows[i].finished then
                line:SetTextColor(SG.RGB(SG.Theme.good))
            else
                line:SetTextColor(SG.RGB(SG.Theme.text))
            end
            line:Show()
        else
            line:Hide()
        end
    end
    local pool = frame.lines or {}
    for i = #rows + 1, #pool do pool[i]:Hide() end
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
        if frame.chain then frame.chain:Hide() end
        frame.objMax = 0
        steps(false)
        frame.count:SetText("")
        frame.step:SetTextColor(SG.RGB(SG.Theme.text))
        frame.step:SetText("Gear is not ready yet.")
        frame.coord:SetText("Open Gear once the addon has finished loading.")
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
    if frame.objStep ~= step then
        frame.objStep = step
        frame.objOffset = 0
    end
    if not step then
        frame:SetHeight(148)
        frame.objMax = 0
        if frame.chain then frame.chain:Hide() end
        frame.step:ClearAllPoints()
        frame.step:SetPoint("TOPLEFT", 12, -40)
        frame.step:SetPoint("TOPRIGHT", -12, -40)
        frame.step:SetTextColor(SG.RGB(SG.Theme.text))
        frame.step:SetText(guide.title .. " is complete.")
        frame.coord:SetText(guide.place or "")
    else
        local chained = SG.HasChain and SG.HasChain(step)
        if frame.chain then
            if chained then frame.chain:Show() else frame.chain:Hide() end
        end
        frame.step:ClearAllPoints()
        frame.step:SetPoint("TOPLEFT", 12, -40)
        frame.step:SetPoint("TOPRIGHT", chained and -32 or -12, -40)
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
        if step.placeName and step.placeName ~= "" and step.x and step.y then
            coord = string.format("%s   %.1f, %.1f", step.placeName, step.x, step.y)
        end
        if step.gearName and step.gearName ~= "" and step.kind ~= "turnin" then
            coord = step.gearName .. (coord ~= "" and ("    " .. coord) or "")
        end
        local line = dist and (coord .. "    " .. dist) or coord
        local extra = 0
        if step.dropLine and step.dropLine ~= "" then
            if #step.dropLine > 42 then
                if line ~= "" then line = line .. "\n" end
                line = line .. step.dropLine
                extra = 32
            else
                line = line .. (line ~= "" and "    " or "") .. step.dropLine
            end
        end
        frame.coord:SetHeight(16 + extra)
        frame.coord:SetText(line)
        y = y + 18 + extra
        local rows, heights, contentH = nil, nil, 0
        local rewardStep = step.kind == "turnin" or ((step.kind == "gear" or step.kind == "recipe") and step.rewards and step.rewards[1])
        if step.kind == "complete" or step.kind == "run" then
            rows, heights, contentH = ObjectiveRows(frame, step)
        elseif rewardStep then
            local rewards = step.rewards or {}
            local shown = 0
            for i = 1, #rewards do
                if rewards[i] and shown < 4 then shown = shown + 1 end
            end
            contentH = shown * 26
        end
        local natural = y + contentH + 42
        if natural < 148 then natural = 148 end
        local maxH = 700
        if UIParent and UIParent.GetHeight then
            local screen = UIParent:GetHeight()
            if type(screen) == "number" and screen > 200 then maxH = screen - 40 end
        end
        local height = natural
        if height > maxH then height = maxH end
        frame:SetHeight(height)
        local viewBottom = height - 42
        local room = viewBottom - y
        if room < 0 then room = 0 end
        frame.objMax = contentH - room
        if frame.objMax < 0 then frame.objMax = 0 end
        if (frame.objOffset or 0) > frame.objMax then frame.objOffset = frame.objMax end
        if rows then
            ShowObjectives(frame, step, y, viewBottom, rows, heights)
        elseif rewardStep then
            ShowTurnIn(frame, step, y)
        end
    end
    SG.Tracker.updating = false
    if SG.Pins and SG.Pins.Update and not SG.Pins.painting then SG.Pins.Update() end
    if SG.Arrow and SG.Arrow.Tick then SG.Arrow.Tick() end
end
