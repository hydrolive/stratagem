-- Widgets.lua: flat navy controls. No Ace3, no Blizzard button templates.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Widgets = {}
local T = SG.Theme

local function Font(parent, size, inherit)
    local fs = parent:CreateFontString(nil, "OVERLAY", inherit or "GameFontHighlight")
    local path, _, flags = fs:GetFont()
    if path and size then fs:SetFont(path, size, flags or "") end
    fs:SetTextColor(SG.RGB(T.text))
    return fs
end

function SG.Widgets.Text(parent, size, inherit)
    return Font(parent, size, inherit)
end

function SG.Widgets.Edge(frame, color)
    local function line(p1, p2, horizontal)
        local tex = frame:CreateTexture(nil, "BORDER")
        SG.Paint(tex, color or T.line)
        tex:SetPoint(p1, frame, p1, 0, 0)
        tex:SetPoint(p2, frame, p2, 0, 0)
        if horizontal then tex:SetHeight(1) else tex:SetWidth(1) end
        return tex
    end
    line("TOPLEFT", "TOPRIGHT", true)
    line("BOTTOMLEFT", "BOTTOMRIGHT", true)
    line("TOPLEFT", "BOTTOMLEFT", false)
    line("TOPRIGHT", "BOTTOMRIGHT", false)
end

function SG.Widgets.Backdrop(frame, color)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    SG.Paint(bg, color or T.bg)
    frame.bg = bg
    return bg
end

function SG.Widgets.Button(parent, text, kind)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(kind == "primary" and 34 or 28)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    button.bg = bg
    local label = Font(button, kind == "primary" and 14 or 12)
    label:SetPoint("CENTER")
    label:SetText(text or "")
    button.label = label
    button.kind = kind or "ghost"
    SG.Widgets.Edge(button, { 0.45, 0.38, 0.68, 0.45 })

    function button:Paint(hot)
        local enabled = self:IsEnabled()
        if not enabled then
            SG.Paint(self.bg, { 0.10, 0.10, 0.14, 0.85 })
            self.label:SetTextColor(0.45, 0.46, 0.52, 1)
        elseif self.kind == "primary" then
            SG.Paint(self.bg, hot and T.accentHot or T.accent)
            self.label:SetTextColor(1, 1, 1, 1)
        else
            SG.Paint(self.bg, hot and T.rowHot or T.inset)
            self.label:SetTextColor(SG.RGB(T.text))
        end
    end
    button:SetScript("OnEnter", function(self) self:Paint(true) end)
    button:SetScript("OnLeave", function(self) self:Paint(false) end)
    button:SetScript("OnEnable", function(self) self:Paint(false) end)
    button:SetScript("OnDisable", function(self) self:Paint(false) end)
    button:Paint(false)
    function button:SetLabel(value) label:SetText(value or "") end
    return button
end

function SG.Widgets.Check(parent, text)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(22)
    local box = CreateFrame("Frame", nil, button)
    box:SetSize(16, 16)
    box:SetPoint("LEFT")
    SG.Widgets.Backdrop(box, T.inset)
    SG.Widgets.Edge(box, T.line)
    local mark = box:CreateTexture(nil, "OVERLAY")
    mark:SetPoint("TOPLEFT", 3, -3)
    mark:SetPoint("BOTTOMRIGHT", -3, 3)
    SG.Paint(mark, T.accent)
    button.mark = mark
    local label = Font(button, 12)
    label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    label:SetText(text or "")
    button.label = label

    function button:Paint()
        if self.on then mark:Show() else mark:Hide() end
    end
    function button:SetChecked(on)
        self.on = on and true or false
        self:Paint()
    end
    button:SetScript("OnClick", function(self)
        self.on = not self.on
        self:Paint()
        if self.changed then self.changed(self.on) end
    end)
    button:SetChecked(false)
    button:SetScript("OnEnter", function() label:SetTextColor(SG.RGB(T.gold)) end)
    button:SetScript("OnLeave", function() label:SetTextColor(SG.RGB(T.text)) end)
    return button
end

function SG.Widgets.Slider(parent, minValue, maxValue, step)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetHeight(18)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetHeight(4)
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)
    SG.Paint(track, { 0.18, 0.16, 0.28, 1 })
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(12, 16)
    SG.Paint(thumb, T.accent)
    slider:SetThumbTexture(thumb)
    return slider
end

function SG.Widgets.Bar(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(8)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    SG.Paint(bg, { 0.10, 0.10, 0.14, 1 })
    local fill = frame:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT")
    fill:SetPoint("BOTTOMLEFT")
    SG.Paint(fill, T.accent)
    frame.fill = fill
    frame.percent = 0
    function frame:SetPercent(percent, done)
        self.percent = math.max(0, math.min(1, percent or 0))
        if done ~= nil then self.done = done and true or false end
        SG.Paint(fill, self.done and T.good or T.accent)
        local width = self:GetWidth()
        if not width or width < 1 then width = 1 end
        if self.percent <= 0 then
            fill:Hide()
        else
            fill:Show()
            fill:SetWidth(math.max(1, width * self.percent))
        end
    end
    frame:SetScript("OnSizeChanged", function(self) self:SetPercent(self.percent) end)
    return frame
end

function SG.Widgets.Scroll(parent)
    local holder = CreateFrame("Frame", nil, parent)
    local scroll = CreateFrame("ScrollFrame", nil, holder)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -10, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(100, 100)
    scroll:SetScrollChild(content)

    local bar = CreateFrame("Frame", nil, holder)
    bar:SetWidth(4)
    bar:SetPoint("TOPRIGHT", 0, -2)
    bar:SetPoint("BOTTOMRIGHT", 0, 2)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    SG.Paint(track, { 0.12, 0.11, 0.18, 0.9 })
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(4)
    SG.Paint(thumb, T.accent)
    thumb:Hide()

    local function Update()
        local view = scroll:GetHeight()
        local total = content:GetHeight()
        if view < 1 or total <= view + 1 then
            thumb:Hide()
            return
        end
        thumb:Show()
        local height = math.max(28, view * (view / total))
        local maxScroll = total - view
        local offset = scroll:GetVerticalScroll()
        local travel = view - height
        thumb:ClearAllPoints()
        thumb:SetHeight(height)
        thumb:SetPoint("TOP", bar, "TOP", 0, -travel * (offset / maxScroll))
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local maxScroll = math.max(0, content:GetHeight() - scroll:GetHeight())
        local next = scroll:GetVerticalScroll() - delta * 46
        if next < 0 then next = 0 end
        if next > maxScroll then next = maxScroll end
        scroll:SetVerticalScroll(next)
        Update()
    end)
    scroll:SetScript("OnSizeChanged", function()
        content:SetWidth(math.max(1, scroll:GetWidth()))
        Update()
    end)

    holder.scroll = scroll
    holder.content = content
    holder.Update = Update
    function holder:Reset()
        scroll:SetVerticalScroll(0)
        Update()
    end
    return holder
end

function SG.Widgets.Search(parent, onChange)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(30)
    SG.Widgets.Backdrop(frame, T.inset)
    SG.Widgets.Edge(frame, T.line)
    local edit = CreateFrame("EditBox", nil, frame)
    edit:SetPoint("TOPLEFT", 8, -2)
    edit:SetPoint("BOTTOMRIGHT", -8, 2)
    edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontHighlightSmall)
    if edit.SetTextInsets then edit:SetTextInsets(2, 2, 0, 0) end
    local hint = Font(frame, 12)
    hint:SetPoint("LEFT", 12, 0)
    hint:SetText("Search guides")
    hint:SetTextColor(SG.RGB(T.dim))
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text == "" then hint:Show() else hint:Hide() end
        if onChange then onChange(text) end
    end)
    edit:SetScript("OnEditFocusGained", function() hint:SetTextColor(0.55, 0.5, 0.7, 1) end)
    edit:SetScript("OnEditFocusLost", function() hint:SetTextColor(SG.RGB(T.dim)) end)
    frame.edit = edit
    return frame
end
