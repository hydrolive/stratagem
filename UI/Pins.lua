-- Pins.lua: a second window for steps the player pinned.
-- The main tracker stays on the active guide. Pinning does not move it.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Pins = { pool = {} }

local function Save(frame)
    local point, _, rel, x, y = frame:GetPoint()
    local pos = SG.db.ui.pins
    if type(pos) ~= "table" then
        pos = {}
        SG.db.ui.pins = pos
    end
    pos.point, pos.rel, pos.x, pos.y = point, rel, x, y
end

function SG.Pins.Key(step, guide)
    if type(step) ~= "table" then return nil end
    if type(step.questID) == "number" and step.questID > 0 then
        return "q" .. step.questID
    end
    if type(step.spell) == "number" and step.spell > 0 then
        return "s" .. step.spell
    end
    if type(step.itemID) == "number" and step.itemID > 0 then
        return "i" .. step.itemID
    end
    local gid = (guide and guide.id) or step.guide or ""
    return "t" .. gid .. ":" .. (step.title or "")
end

function SG.Pins.Has(guide, index)
    if not guide or not SG.char or type(SG.char.pins) ~= "table" then return false end
    local step = guide.steps and guide.steps[index]
    local key = step and SG.Pins.Key(step, guide)
    return key ~= nil and SG.char.pins[key] ~= nil
end

local function Scan(guide, key)
    local steps = guide and guide.steps
    if type(steps) ~= "table" then return nil end
    local fallback
    for i = 1, #steps do
        local step = steps[i]
        if SG.Pins.Key(step, guide) == key then
            if step.kind == "complete" or step.kind == "collect" or step.kind == "recipe" or step.kind == "gear" then
                return guide, step, i
            end
            if not fallback then fallback = { guide, step, i } end
        end
    end
    if fallback then return fallback[1], fallback[2], fallback[3] end
    return nil
end

function SG.Pins.Find(record)
    if type(record) ~= "table" or type(record.key) ~= "string" then return nil end
    if record.guide and SG.Engine and SG.Engine.Get then
        local guide, step, index = Scan(SG.Engine.Get(record.guide), record.key)
        if guide then return guide, step, index end
    end
    local guides = SG.Engine and SG.Engine.guides or {}
    for i = 1, #guides do
        local guide, step, index = Scan(guides[i], record.key)
        if guide then return guide, step, index end
    end
    return nil
end

function SG.Pins.Remove(key)
    if SG.char and type(SG.char.pins) == "table" then
        SG.char.pins[key] = nil
    end
    SG.Pins.Update()
end

function SG.Pins.Toggle(guide, index)
    if not SG.char or not guide or type(guide.steps) ~= "table" then return end
    if type(SG.char.pins) ~= "table" then SG.char.pins = {} end
    local step = guide.steps[index]
    if not step then return end
    local key = SG.Pins.Key(step, guide)
    if not key then return end
    if SG.char.pins[key] then
        SG.char.pins[key] = nil
    else
        SG.char.pins[key] = {
            key = key,
            guide = guide.id,
            title = step.title,
            text = step.text,
            questID = step.questID,
            spell = step.spell,
            itemID = step.itemID,
            kind = step.kind,
        }
    end
    if not SG.Pins.frame then SG.Pins.Create() end
    SG.Pins.Update()
end

function SG.Pins.Open(record)
    local guide, _, index = SG.Pins.Find(record)
    if not guide or not SG.UI or not SG.UI.Continue then return end
    SG.UI.Continue(guide.id)
    if index and SG.Engine and SG.Engine.Focus then
        SG.state.stepIndex = index
        SG.Engine.Focus(guide, index, true)
        if SG.UI.Refresh then SG.UI.Refresh(false) end
    end
end

local function Split(text)
    local lines = {}
    if type(text) ~= "string" or text == "" then return lines end
    local start = 1
    while start <= #text and #lines < 8 do
        local nl = string.find(text, "\n", start, true)
        local piece
        if nl then
            piece = text:sub(start, nl - 1)
            start = nl + 1
        else
            piece = text:sub(start)
            start = #text + 1
        end
        if piece ~= "" then lines[#lines + 1] = piece end
    end
    return lines
end

local function LinesFor(record, step)
    local questID = (step and step.questID) or record.questID
    if type(questID) == "number" and questID > 0 and SG.StepObjectives then
        local probe = {
            questID = questID,
            kind = "complete",
            questName = (step and (step.questName or step.title)) or record.title,
            title = (step and step.title) or record.title,
        }
        local rows = SG.StepObjectives(probe) or {}
        local lines = {}
        for i = 1, #rows do
            local text = rows[i] and rows[i].text
            if type(text) == "string" and text ~= "" then
                lines[#lines + 1] = text
            end
        end
        if #lines > 0 then return lines end
    end
    local text = (step and step.text) or record.text or ""
    local lines = Split(text)
    if #lines == 0 then
        local title = (step and step.title) or record.title
        if type(title) == "string" and title ~= "" then lines[1] = title end
    end
    return lines
end

local function Block(parent)
    local frame = CreateFrame("Frame", nil, parent)
    local title = SG.Widgets.Text(frame, 12)
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(true)
    frame.title = title
    frame.lines = {}
    local unpin = SG.Widgets.Button(frame, "Unpin", "ghost")
    unpin:SetSize(64, 18)
    frame.unpin = unpin
    local open = SG.Widgets.Button(frame, "Open", "ghost")
    open:SetSize(52, 18)
    frame.open = open
    return frame
end

local function Line(block, index)
    local line = block.lines[index]
    if line then return line end
    line = SG.Widgets.Text(block, 11)
    line:SetJustifyH("LEFT")
    line:SetWordWrap(true)
    line:SetTextColor(SG.RGB(SG.Theme.muted))
    block.lines[index] = line
    return line
end

local function HideLines(block)
    local lines = block.lines or {}
    for i = 1, #lines do lines[i]:Hide() end
end

local function LayoutBlock(block, record, width)
    local guide, step = SG.Pins.Find(record)
    local title = (step and step.title) or record.title or "Pinned step"
    block.title:ClearAllPoints()
    block.title:SetPoint("TOPLEFT", 0, 0)
    block.title:SetWidth(width)
    block.title:SetText(title)
    local titleH = block.title:GetStringHeight() or 14
    if titleH < 14 then titleH = 14 end
    block.title:SetHeight(titleH)
    HideLines(block)
    local lines = LinesFor(record, step)
    local y = titleH + 2
    local shown = #lines
    if shown > 8 then shown = 8 end
    for i = 1, shown do
        local line = Line(block, i)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", 0, -y)
        line:SetWidth(width)
        line:SetText(lines[i])
        local h = line:GetStringHeight() or 14
        if h < 14 then h = 14 end
        line:SetHeight(h)
        line:Show()
        y = y + h + 2
    end
    block.unpin:ClearAllPoints()
    block.unpin:SetPoint("TOPLEFT", 0, -y)
    block.open:ClearAllPoints()
    block.open:SetPoint("LEFT", block.unpin, "RIGHT", 6, 0)
    block.unpin:SetScript("OnClick", function() SG.Pins.Remove(record.key) end)
    block.open:SetScript("OnClick", function() SG.Pins.Open(record) end)
    local height = y + 22
    block:SetHeight(height)
    return height
end

function SG.Pins.Create()
    if SG.Pins.frame then
        SG.Pins.Update()
        return
    end
    if not SG.db or not SG.Widgets then return end
    local frame = CreateFrame("Button", "StratagemPins", UIParent)
    frame:SetSize(300, 120)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    local pos = SG.db.ui.pins or {}
    frame:SetPoint(pos.point or "TOPRIGHT", UIParent, pos.rel or "TOPRIGHT", pos.x or -20, pos.y or -220)
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
    title:SetText("PINNED")
    title:SetTextColor(SG.RGB(SG.Theme.gold))
    frame.title = title
    local count = SG.Widgets.Text(frame, 11)
    count:SetPoint("TOPRIGHT", -12, -10)
    count:SetTextColor(SG.RGB(SG.Theme.muted))
    frame.count = count
    local holder = SG.Widgets.Scroll(frame)
    holder:SetPoint("TOPLEFT", 10, -28)
    holder:SetPoint("BOTTOMRIGHT", -4, 8)
    frame.holder = holder
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Pinned steps", 0.93, 0.78, 0.45)
        GameTooltip:AddLine("Drag to move. These do not move the main tracker.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    SG.Pins.frame = frame
    SG.Pins.Update()
end

function SG.Pins.Update()
    local frame = SG.Pins.frame
    if not frame or not SG.db then return end
    local pins = SG.char and SG.char.pins
    local keys = {}
    if type(pins) == "table" then
        for key, record in pairs(pins) do
            if type(record) == "table" and type(record.key) == "string" then
                keys[#keys + 1] = key
            elseif type(key) == "string" then
                pins[key] = nil
            end
        end
    end
    table.sort(keys)
    local pool = SG.Pins.pool
    for i = 1, #pool do pool[i]:Hide() end
    if #keys == 0 then
        frame:Hide()
        return
    end
    frame:Show()
    frame.count:SetText(tostring(#keys))
    local content = frame.holder.content
    local scroll = frame.holder.scroll
    local width = scroll:GetWidth() or 0
    if width < 80 then width = 260 end
    content:SetWidth(width)
    local y = 4
    for i = 1, #keys do
        local block = pool[i]
        if not block then
            block = Block(content)
            pool[i] = block
        end
        if block:GetParent() ~= content then block:SetParent(content) end
        local record = pins[keys[i]]
        block:ClearAllPoints()
        block:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        block:SetWidth(math.max(40, width - 8))
        local h = LayoutBlock(block, record, math.max(40, width - 8))
        block:Show()
        y = y + h + 8
    end
    content:SetHeight(math.max(y + 4, (scroll:GetHeight() or 0) + 1))
    local maxH = 480
    if UIParent and UIParent.GetHeight then
        local screen = UIParent:GetHeight()
        if type(screen) == "number" and screen > 240 then
            maxH = math.min(520, screen - 80)
        end
    end
    local height = y + 40
    if height < 96 then height = 96 end
    if height > maxH then height = maxH end
    frame:SetHeight(height)
    if frame.holder.Update then frame.holder.Update() end
end
