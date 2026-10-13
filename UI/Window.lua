-- Window.lua: the browser. Sidebar, guide list, tabs, and the detail card.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.UI = SG.UI or {}

local T = SG.Theme
local SIDEBAR_W, DETAIL_W = 206, 300

local function ListWidth(scroll)
    local w = scroll and scroll:GetWidth() or 0
    if not w or w < 40 then
        local frameW = SG.UI.frame and SG.UI.frame:GetWidth() or 1040
        w = frameW - SIDEBAR_W - DETAIL_W - 28
    end
    if w < 80 then w = 480 end
    return w
end

local function Short(text, limit)
    text = text or ""
    if #text <= limit then return text end
    return text:sub(1, limit - 3) .. "..."
end

local function SavePosition(frame)
    local point, _, rel, x, y = frame:GetPoint()
    SG.db.ui.point = point
    SG.db.ui.rel = rel
    SG.db.ui.x = x
    SG.db.ui.y = y
end

function SG.UI.ToggleFavorite(id)
    if SG.db.favorites[id] then
        SG.db.favorites[id] = nil
    else
        SG.db.favorites[id] = true
    end
    SG.UI.Refresh(false)
end

function SG.UI.Select(id)
    SG.db.selected = id
    SG.state.tab = "home"
    SG.UI.Refresh(false)
end

-- Replaces the guide tab you are looking at. From the home list this just opens one.
function SG.UI.OpenInPlace(id)
    if not SG.Engine.Get(id) then return end
    local current = SG.state.tab
    if not current or current == "home" or current == id then
        SG.UI.OpenTab(id)
        return
    end
    local tabs = SG.db.tabs
    for i = #tabs, 1, -1 do
        if tabs[i] == id then table.remove(tabs, i) end
    end
    local replaced = false
    for i = 1, #tabs do
        if tabs[i] == current then
            tabs[i] = id
            replaced = true
        end
    end
    if not replaced then
        while #tabs >= 4 do table.remove(tabs, 1) end
        tabs[#tabs + 1] = id
    end
    SG.state.tab = id
    SG.db.selected = id
    SG.char.active = id
    SG.RememberRecent(id)
    local guide = SG.Engine.Get(id)
    SG.state.stepIndex = SG.Engine.CurrentIndex(guide) or SG.Engine.FirstVisible(guide)
    SG.UI.Refresh(true)
end

function SG.UI.OpenTab(id, refresh)
    if not SG.Engine.Get(id) then return end
    local tabs = SG.db.tabs
    local found = false
    for i = 1, #tabs do
        if tabs[i] == id then found = true end
    end
    if not found then
        while #tabs >= 4 do table.remove(tabs, 1) end
        tabs[#tabs + 1] = id
    end
    SG.state.tab = id
    SG.db.selected = id
    SG.char.active = id
    SG.RememberRecent(id)
    local guide = SG.Engine.Get(id)
    SG.state.stepIndex = SG.Engine.CurrentIndex(guide) or SG.Engine.FirstVisible(guide)
    if refresh ~= false then SG.UI.Refresh(true) end
end

function SG.UI.CloseTab(id)
    local tabs = SG.db.tabs
    for i = #tabs, 1, -1 do
        if tabs[i] == id then table.remove(tabs, i) end
    end
    if SG.state.tab == id then SG.state.tab = "home" end
    SG.UI.Refresh(true)
end

function SG.UI.Continue(id)
    local guide = SG.Engine.Get(id)
    if not guide then return end
    SG.UI.OpenTab(id, false)
    local index = SG.Engine.CurrentIndex(guide) or SG.Engine.FirstVisible(guide)
    SG.state.stepIndex = index
    if index then SG.Engine.Focus(guide, index, true) end
    SG.UI.Refresh(true)
    if SG.Tracker.Update then SG.Tracker.Update() end
end

function SG.UI.Show()
    if not SG.db then return end
    if not SG.UI.frame then SG.UI.Create() end
    if SG.UI.frame then SG.UI.frame:Show() end
end

function SG.UI.Toggle()
    if not SG.db then return end
    if not SG.UI.frame then SG.UI.Create() end
    if not SG.UI.frame then return end
    if SG.UI.frame:IsShown() then SG.UI.frame:Hide() else SG.UI.frame:Show() end
end

local function PercentText(done, total)
    if total <= 0 then return "0%" end
    return string.format("%d%%", math.floor((done / total) * 100 + 0.5))
end

function SG.UI.Create()
    if SG.UI.frame or not SG.db then return end
    SG.state = SG.state or { query = "", tab = "home", stepIndex = nil }

    local frame = CreateFrame("Frame", "StratagemFrame", UIParent)
    frame:SetSize(1040, 640)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetScale(SG.db.ui.scale or 1)
    frame:SetPoint(SG.db.ui.point or "CENTER", UIParent, SG.db.ui.rel or "CENTER", SG.db.ui.x or 0, SG.db.ui.y or 0)
    SG.Widgets.Backdrop(frame, T.bg)
    SG.Widgets.Edge(frame, T.line)
    frame:Hide()
    frame:SetScript("OnShow", function()
        SG.After(0, function()
            if SG.UI.frame and SG.UI.frame:IsShown() then SG.UI.Refresh(true) end
        end)
    end)
    frame:SetScript("OnHide", function()
        if SG.UI.picker then SG.UI.picker:Hide() end
    end)
    if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "StratagemFrame") end
    SG.UI.frame = frame

    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetPoint("TOPLEFT")
    sidebar:SetPoint("BOTTOMLEFT")
    sidebar:SetWidth(SIDEBAR_W)
    SG.Widgets.Backdrop(sidebar, T.sidebar)

    -- Textures cannot take mouse scripts. A button over the logo is the drag handle.
    local logoHit = CreateFrame("Button", nil, sidebar)
    logoHit:SetSize(58, 58)
    logoHit:SetPoint("TOP", 0, -16)
    logoHit:RegisterForDrag("LeftButton")
    local logo = logoHit:CreateTexture(nil, "ARTWORK")
    logo:SetAllPoints()
    logo:SetTexture(SG.MEDIA .. "Icon.tga")
    logoHit:SetScript("OnDragStart", function() frame:StartMoving() end)
    logoHit:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition(frame)
    end)

    local word = SG.Widgets.Text(sidebar, 13)
    word:SetPoint("TOP", logo, "BOTTOM", 0, -8)
    word:SetText("STRATAGEM")
    word:SetTextColor(SG.RGB(T.gold))
    local tag = SG.Widgets.Text(sidebar, 10)
    tag:SetPoint("TOP", word, "BOTTOM", 0, -2)
    tag:SetText("BiS leveling")
    tag:SetTextColor(SG.RGB(T.muted))

    local search = SG.Widgets.Search(sidebar, function(text)
        SG.state.query = text or ""
        if SG.db.category == "options" then SG.db.category = "all" end
        SG.state.tab = "home"
        SG.UI.Refresh(true)
    end)
    search:SetPoint("TOPLEFT", 12, -112)
    search:SetPoint("TOPRIGHT", -12, -112)

    SG.UI.categories = {}
    for i = 1, #SG.CATEGORIES do
        local info = SG.CATEGORIES[i]
        local button = CreateFrame("Button", nil, sidebar)
        button:SetHeight(30)
        button:SetPoint("TOPLEFT", 8, -150 - (i - 1) * 32)
        button:SetPoint("TOPRIGHT", -8, -150 - (i - 1) * 32)
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        button.bg = bg
        local bar = button:CreateTexture(nil, "ARTWORK")
        bar:SetWidth(3)
        bar:SetPoint("TOPLEFT", 0, -3)
        bar:SetPoint("BOTTOMLEFT", 0, 3)
        SG.Paint(bar, T.accent)
        button.bar = bar
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", 10, 0)
        icon:SetTexture(SG.MEDIA .. info.icon)
        local label = SG.Widgets.Text(button, 12)
        label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        label:SetText(info.name)
        button.label = label
        button.id = info.id
        button:SetScript("OnClick", function(self)
            SG.db.category = self.id
            if self.id ~= "options" then SG.state.tab = "home" end
            SG.UI.Refresh(true)
        end)
        button:SetScript("OnEnter", function(self)
            if SG.db.category ~= self.id then SG.Paint(self.bg, T.rowHot) end
        end)
        button:SetScript("OnLeave", function(self) SG.UI.PaintCategory(self) end)
        SG.UI.categories[i] = button
    end

    local footer = CreateFrame("Button", nil, sidebar)
    footer:SetHeight(46)
    footer:SetPoint("BOTTOMLEFT", 8, 8)
    footer:SetPoint("BOTTOMRIGHT", -8, 8)
    SG.Widgets.Backdrop(footer, T.inset)
    SG.Widgets.Edge(footer, T.line)
    local specText = SG.Widgets.Text(footer, 12)
    specText:SetPoint("LEFT", 10, 6)
    specText:SetPoint("RIGHT", -10, 6)
    specText:SetJustifyH("LEFT")
    local specHint = SG.Widgets.Text(footer, 10)
    specHint:SetPoint("BOTTOMLEFT", 10, 6)
    specHint:SetText("Click to change spec")
    specHint:SetTextColor(SG.RGB(T.dim))
    footer.label = specText
    footer:SetScript("OnClick", function() SG.UI.TogglePicker() end)
    footer:SetScript("OnEnter", function(self) SG.Paint(self.bg, T.rowHot) end)
    footer:SetScript("OnLeave", function(self) SG.Paint(self.bg, T.inset) end)
    SG.UI.footer = footer

    local detail = CreateFrame("Frame", nil, frame)
    detail:SetPoint("TOPRIGHT")
    detail:SetPoint("BOTTOMRIGHT")
    detail:SetWidth(DETAIL_W)
    SG.Widgets.Backdrop(detail, T.panel)
    SG.UI.detail = detail

    local center = CreateFrame("Frame", nil, frame)
    center:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    center:SetPoint("BOTTOMRIGHT", detail, "BOTTOMLEFT", 0, 0)
    SG.UI.center = center

    local tabbar = CreateFrame("Button", nil, center)
    tabbar:SetHeight(40)
    tabbar:SetPoint("TOPLEFT")
    tabbar:SetPoint("TOPRIGHT")
    tabbar:RegisterForDrag("LeftButton")
    tabbar:SetScript("OnDragStart", function() frame:StartMoving() end)
    tabbar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition(frame)
    end)
    SG.UI.tabbar = tabbar

    local close = CreateFrame("Button", nil, tabbar)
    close:SetSize(22, 22)
    close:SetPoint("RIGHT", -8, 0)
    local closeText = SG.Widgets.Text(close, 14)
    closeText:SetPoint("CENTER")
    closeText:SetText("x")
    close:SetScript("OnClick", function() frame:Hide() end)
    close:SetScript("OnEnter", function() closeText:SetTextColor(SG.RGB(T.gold)) end)
    close:SetScript("OnLeave", function() closeText:SetTextColor(SG.RGB(T.text)) end)

    local home = CreateFrame("Frame", nil, center)
    home:SetPoint("TOPLEFT", tabbar, "BOTTOMLEFT", 0, 0)
    home:SetPoint("BOTTOMRIGHT")
    SG.UI.home = home

    local faction = SG.Widgets.Button(home, "Faction", "ghost")
    faction:SetHeight(22)
    faction:SetPoint("TOPRIGHT", -14, -8)
    faction:SetWidth(150)
    faction:SetScript("OnClick", function()
        local order = { "auto", "H", "A", "both" }
        local current = SG.db.options.faction or "auto"
        local nextMode = "auto"
        for i = 1, #order do
            if order[i] == current then nextMode = order[i % #order + 1] end
        end
        SG.db.options.faction = nextMode
        SG.UI.Refresh(true)
    end)
    SG.UI.factionButton = faction

    local homeScroll = SG.Widgets.Scroll(home)
    homeScroll:SetPoint("TOPLEFT", 0, -36)
    homeScroll:SetPoint("BOTTOMRIGHT")
    homeScroll.onSized = function()
        if not SG.UI.home:IsShown() or SG.UI.sizing then return end
        SG.UI.sizing = true
        SG.After(0, function()
            SG.UI.sizing = false
            if SG.UI.frame and SG.UI.frame:IsShown() and SG.UI.home:IsShown() then
                SG.UI.Refresh(false)
            end
        end)
    end
    SG.UI.homeScroll = homeScroll

    local empty = CreateFrame("Frame", nil, home)
    empty:SetPoint("TOPLEFT", 24, -72)
    empty:SetPoint("RIGHT", -24, 0)
    empty:SetHeight(96)
    empty:SetFrameLevel(home:GetFrameLevel() + 20)
    empty:Hide()
    local emptyText = SG.Widgets.Text(empty, 13)
    emptyText:SetPoint("TOPLEFT")
    emptyText:SetPoint("TOPRIGHT")
    emptyText:SetJustifyH("LEFT")
    emptyText:SetWordWrap(true)
    emptyText:SetHeight(36)
    emptyText:SetText("No guides match these filters.")
    local showBoth = SG.Widgets.Button(empty, "Show both factions", "primary")
    showBoth:SetSize(180, 28)
    showBoth:SetPoint("TOPLEFT", 0, -40)
    showBoth:SetScript("OnClick", function()
        SG.db.options.faction = "both"
        SG.UI.Refresh(true)
    end)
    local showSpecs = SG.Widgets.Button(empty, "Show every spec", "ghost")
    showSpecs:SetSize(160, 28)
    showSpecs:SetPoint("LEFT", showBoth, "RIGHT", 8, 0)
    showSpecs:SetScript("OnClick", function()
        SG.db.options.onlyMySpec = false
        SG.Engine.Rebuild()
        if SG.db.options.autoAdvance then SG.Engine.SyncAll() end
        SG.UI.Refresh(true)
    end)
    SG.UI.empty = empty

    local steps = CreateFrame("Frame", nil, center)
    steps:SetPoint("TOPLEFT", tabbar, "BOTTOMLEFT", 0, 0)
    steps:SetPoint("BOTTOMRIGHT")
    steps:Hide()
    local stepScroll = SG.Widgets.Scroll(steps)
    stepScroll:SetPoint("TOPLEFT", 0, -4)
    stepScroll:SetPoint("BOTTOMRIGHT")
    SG.UI.steps = steps
    SG.UI.stepScroll = stepScroll

    local options = CreateFrame("Frame", nil, center)
    options:SetPoint("TOPLEFT", tabbar, "BOTTOMLEFT", 0, 0)
    options:SetPoint("BOTTOMRIGHT")
    options:Hide()
    SG.UI.options = options
    SG.UI.BuildOptions(options)
    SG.UI.BuildDetail(detail)
    SG.UI.BuildPicker(footer)

    SG.UI.guidePool = {}
    SG.UI.headerPool = {}
    SG.UI.stepPool = {}
    SG.UI.tabPool = {}
end

function SG.UI.PaintCategory(button)
    local on = SG.db.category == button.id
    SG.Paint(button.bg, on and T.rowOn or { 0, 0, 0, 0 })
    if on then button.bar:Show() else button.bar:Hide() end
    button.label:SetTextColor(SG.RGB(on and T.text or T.muted))
end

function SG.UI.BuildDetail(detail)
    local eyebrow = SG.Widgets.Text(detail, 11)
    eyebrow:SetPoint("TOPLEFT", 16, -16)
    eyebrow:SetPoint("TOPRIGHT", -36, -16)
    eyebrow:SetJustifyH("LEFT")
    eyebrow:SetTextColor(SG.RGB(T.gold))
    detail.eyebrow = eyebrow

    local star = CreateFrame("Button", nil, detail)
    star:SetSize(22, 22)
    star:SetPoint("TOPRIGHT", -12, -12)
    local starTex = star:CreateTexture(nil, "ARTWORK")
    starTex:SetAllPoints()
    starTex:SetTexture(SG.MEDIA .. "cat_favorites.tga")
    star.tex = starTex
    star:SetScript("OnClick", function()
        local id = SG.db.selected
        if id then SG.UI.ToggleFavorite(id) end
    end)
    detail.star = star

    local title = SG.Widgets.Text(detail, 18)
    title:SetPoint("TOPLEFT", 16, -36)
    title:SetPoint("TOPRIGHT", -16, -36)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(true)
    title:SetHeight(46)
    detail.title = title

    local meta = SG.Widgets.Text(detail, 12)
    meta:SetPoint("TOPLEFT", 16, -84)
    meta:SetPoint("TOPRIGHT", -16, -84)
    meta:SetJustifyH("LEFT")
    meta:SetTextColor(SG.RGB(T.muted))
    detail.meta = meta

    local blurb = SG.Widgets.Text(detail, 12)
    blurb:SetPoint("TOPLEFT", 16, -106)
    blurb:SetPoint("TOPRIGHT", -16, -106)
    blurb:SetJustifyH("LEFT")
    blurb:SetWordWrap(true)
    blurb:SetHeight(72)
    detail.blurb = blurb

    local zone = SG.Widgets.Text(detail, 12)
    zone:SetPoint("TOPLEFT", 16, -182)
    zone:SetPoint("TOPRIGHT", -16, -182)
    zone:SetJustifyH("LEFT")
    detail.zone = zone

    local hidden = SG.Widgets.Text(detail, 11)
    hidden:SetPoint("TOPLEFT", 16, -200)
    hidden:SetPoint("TOPRIGHT", -16, -200)
    hidden:SetJustifyH("LEFT")
    hidden:SetTextColor(SG.RGB(T.dim))
    detail.hidden = hidden

    local bar = SG.Widgets.Bar(detail)
    bar:SetPoint("TOPLEFT", 16, -222)
    bar:SetPoint("TOPRIGHT", -16, -222)
    detail.bar = bar

    local percent = SG.Widgets.Text(detail, 11)
    percent:SetPoint("TOPLEFT", 16, -234)
    percent:SetTextColor(SG.RGB(T.muted))
    detail.percent = percent

    local function wide(text, kind, y)
        local button = SG.Widgets.Button(detail, text, kind)
        button:SetPoint("TOPLEFT", 16, y)
        button:SetPoint("TOPRIGHT", -16, y)
        return button
    end
    detail.primary = wide("Continue", "primary", -258)
    detail.secondary = wide("Open in tab", "ghost", -298)
    detail.tertiary = wide("Open in new tab", "ghost", -332)

    local reset = CreateFrame("Button", nil, detail)
    reset:SetHeight(18)
    reset:SetPoint("TOPLEFT", 16, -368)
    local resetText = SG.Widgets.Text(reset, 11)
    resetText:SetPoint("LEFT")
    resetText:SetText("Reset progress")
    resetText:SetTextColor(SG.RGB(T.dim))
    reset:SetScript("OnClick", function()
        local id = SG.db.selected
        local guide = id and SG.Engine.Get(id)
        if guide and StaticPopup_Show then
            StaticPopup_Show("STRATAGEM_RESET_GUIDE", guide.title, nil, guide.id)
        end
    end)
    reset:SetScript("OnEnter", function() resetText:SetTextColor(SG.RGB(T.danger)) end)
    reset:SetScript("OnLeave", function() resetText:SetTextColor(SG.RGB(T.dim)) end)
    detail.reset = reset

    detail.items = {}
    for i = 1, 4 do
        local row = CreateFrame("Button", nil, detail)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", 16, -396 - (i - 1) * 26)
        row:SetPoint("RIGHT", -16, 0)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(22, 22)
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
        detail.items[i] = row
    end
    SG.UI.detail = detail
end

function SG.UI.BuildOptions(parent)
    local scroll = SG.Widgets.Scroll(parent)
    scroll:SetAllPoints()
    local content = scroll.content
    local y = -8
    local function addCheck(text, getter, setter)
        local check = SG.Widgets.Check(content, text)
        check:SetPoint("TOPLEFT", 16, y)
        check:SetPoint("RIGHT", -16, 0)
        check.getter = getter
        check.setter = setter
        check.changed = function(on)
            setter(on)
        end
        y = y - 28
        return check
    end
    local checks = {}
    checks[#checks + 1] = addCheck("Match my talent tab", function() return SG.char.autoDetect end, function(on)
        SG.Specs.SetAuto(on)
    end)
    checks[#checks + 1] = addCheck("Only quests that are BiS for my spec", function() return SG.db.options.onlyMySpec end, function(on)
        SG.db.options.onlyMySpec = on
        SG.Engine.Rebuild()
        if SG.db.options.autoAdvance then SG.Engine.SyncAll() end
        SG.UI.Refresh(true)
    end)
    checks[#checks + 1] = addCheck("Advance when the quest log updates", function() return SG.db.options.autoAdvance end, function(on)
        SG.db.options.autoAdvance = on
        if on then SG.Engine.SyncAll() end
        SG.UI.Refresh(false)
    end)
    checks[#checks + 1] = addCheck("TomTom waypoint on the current step", function() return SG.db.options.tomtom end, function(on)
        SG.db.options.tomtom = on
        SG.Arrow.Tick()
    end)
    checks[#checks + 1] = addCheck("On-screen arrow when TomTom is not steering", function() return SG.db.options.arrow end, function(on)
        SG.db.options.arrow = on
        SG.Arrow.Tick()
    end)
    checks[#checks + 1] = addCheck("Invert the arrow", function() return SG.db.options.invertArrow end, function(on)
        SG.db.options.invertArrow = on
    end)
    checks[#checks + 1] = addCheck("Super-track the quest in the quest log", function() return SG.db.options.superTrack end, function(on)
        SG.db.options.superTrack = on
    end)
    checks[#checks + 1] = addCheck("Minimap button", function() return SG.db.options.minimap end, function(on)
        SG.db.options.minimap = on
        SG.Minimap.Update()
    end)
    checks[#checks + 1] = addCheck("Step tracker", function() return SG.db.options.tracker end, function(on)
        SG.db.options.tracker = on
        SG.Tracker.Update()
    end)
    checks[#checks + 1] = addCheck("Lock the tracker in place", function() return SG.db.options.lockTracker end, function(on)
        SG.db.options.lockTracker = on
    end)
    SG.UI.optionChecks = checks

    local scaleLabel = SG.Widgets.Text(content, 12)
    scaleLabel:SetPoint("TOPLEFT", 16, y - 8)
    scaleLabel:SetText("UI scale")
    SG.UI.scaleLabel = scaleLabel
    local slider = SG.Widgets.Slider(content, 0.8, 1.25, 0.05)
    slider:SetPoint("TOPLEFT", 16, y - 30)
    slider:SetPoint("RIGHT", -16, 0)
    slider:SetValue(SG.db.ui.scale or 1)
    slider:SetScript("OnValueChanged", function(_, value)
        local scaled = math.floor((value * 20) + 0.5) / 20
        SG.db.ui.scale = scaled
        if SG.UI.frame then SG.UI.frame:SetScale(scaled) end
        scaleLabel:SetText(string.format("UI scale   %.2f", scaled))
    end)
    SG.UI.scaleSlider = slider
    y = y - 64

    local resetAll = SG.Widgets.Button(content, "Reset all progress", "ghost")
    resetAll:SetPoint("TOPLEFT", 16, y)
    resetAll:SetPoint("RIGHT", -16, 0)
    resetAll:SetScript("OnClick", function()
        if StaticPopup_Show then StaticPopup_Show("STRATAGEM_RESET_ALL") end
    end)
    y = y - 46

    local status = SG.Widgets.Text(content, 12)
    status:SetPoint("TOPLEFT", 16, y)
    status:SetPoint("RIGHT", -16, 0)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(true)
    status:SetHeight(80)
    status:SetTextColor(SG.RGB(T.muted))
    SG.UI.statusText = status
    content:SetHeight(math.abs(y) + 120)
    SG.UI.optionsScroll = scroll
end

function SG.UI.BuildPicker(anchor)
    local picker = CreateFrame("Frame", "StratagemSpecPicker", UIParent)
    picker:SetSize(280, 420)
    picker:SetFrameStrata("DIALOG")
    picker:SetClampedToScreen(true)
    picker:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 8, 0)
    SG.Widgets.Backdrop(picker, T.bg)
    SG.Widgets.Edge(picker, T.line)
    picker:Hide()
    picker:SetScript("OnShow", function(self)
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 8, 0)
    end)

    local scroll = SG.Widgets.Scroll(picker)
    scroll:SetPoint("TOPLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", 0, 8)
    picker.scroll = scroll
    SG.UI.picker = picker
end

function SG.UI.TogglePicker()
    local picker = SG.UI.picker
    if picker:IsShown() then picker:Hide() return end
    local content = picker.scroll.content
    if content.built then
        picker:Show()
        return
    end
    local y = 0
    local function rowButton(text, indent, onClick, color)
        local button = CreateFrame("Button", nil, content)
        button:SetHeight(24)
        button:SetPoint("TOPLEFT", 8 + (indent or 0), -y)
        button:SetPoint("RIGHT", -8, 0)
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        button.bg = bg
        SG.Paint(bg, { 0, 0, 0, 0 })
        local label = SG.Widgets.Text(button, 12)
        label:SetPoint("LEFT", 6, 0)
        label:SetText(text)
        if color then label:SetTextColor(color[1], color[2], color[3], 1) end
        button:SetScript("OnEnter", function() SG.Paint(bg, T.rowHot) end)
        button:SetScript("OnLeave", function() SG.Paint(bg, { 0, 0, 0, 0 }) end)
        button:SetScript("OnClick", onClick)
        y = y + 26
        return button
    end
    rowButton("Match my talent tab", 0, function()
        SG.Specs.SetAuto(true)
        picker:Hide()
    end, T.gold)
    local classes = SG.Specs.Classes()
    for c = 1, #classes do
        local class = classes[c]
        local r, g, b = 0.9, 0.9, 0.9
        local colors = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class.token]
        if colors then r, g, b = colors.r, colors.g, colors.b end
        rowButton(class.name, 0, function() end, { r, g, b })
        for s = 1, #class.specs do
            local spec = class.specs[s]
            local key = spec.key
            rowButton(spec.name, 14, function()
                SG.Specs.Choose(key)
                picker:Hide()
            end)
        end
    end
    content:SetHeight(y + 8)
    content.built = true
    picker.scroll.Update()
    picker:Show()
end

local function Acquire(pool, parent, factory)
    for i = 1, #pool do
        local row = pool[i]
        if not row:IsShown() then
            -- Headers are shared by the home list and the step list.
            if row:GetParent() ~= parent then row:SetParent(parent) end
            row:Show()
            return row
        end
    end
    local row = factory(parent)
    pool[#pool + 1] = row
    return row
end

local function HidePool(pool)
    for i = 1, #pool do pool[i]:Hide() end
end

local function GuideRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(58)
    row:SetFrameLevel(parent:GetFrameLevel() + 2)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    row.bg = bg
    local bar = row:CreateTexture(nil, "ARTWORK")
    bar:SetWidth(3)
    bar:SetPoint("TOPLEFT", 0, -4)
    bar:SetPoint("BOTTOMLEFT", 0, 4)
    SG.Paint(bar, T.accent)
    row.bar = bar
    local open = SG.Widgets.Button(row, "Open", "primary")
    open:SetSize(58, 22)
    open:SetPoint("RIGHT", -8, 4)
    open:SetScript("OnClick", function()
        if row.guideID then SG.UI.Continue(row.guideID) end
    end)
    row.open = open
    local title = SG.Widgets.Text(row, 13)
    title:SetPoint("TOPLEFT", 12, -8)
    title:SetPoint("RIGHT", open, "LEFT", -8, 0)
    title:SetJustifyH("LEFT")
    row.title = title
    local sub = SG.Widgets.Text(row, 11)
    sub:SetPoint("TOPLEFT", 12, -28)
    sub:SetPoint("RIGHT", open, "LEFT", -8, 0)
    sub:SetJustifyH("LEFT")
    sub:SetTextColor(SG.RGB(T.muted))
    row.sub = sub
    local star = row:CreateTexture(nil, "OVERLAY")
    star:SetSize(14, 14)
    star:SetPoint("RIGHT", open, "LEFT", -6, 8)
    star:SetTexture(SG.MEDIA .. "cat_favorites.tga")
    row.star = star
    local mini = SG.Widgets.Bar(row)
    mini:SetHeight(3)
    mini:SetPoint("BOTTOMLEFT", 12, 6)
    mini:SetPoint("BOTTOMRIGHT", -78, 6)
    row.mini = mini
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            SG.UI.ToggleFavorite(self.guideID)
            return
        end
        local now = GetTime()
        if self.last and (now - self.last) < 0.35 then
            self.last = nil
            SG.UI.OpenTab(self.guideID)
        else
            self.last = now
            SG.UI.Select(self.guideID)
        end
    end)
    row:SetScript("OnEnter", function(self)
        if SG.db.selected ~= self.guideID then SG.Paint(self.bg, T.rowHot) end
    end)
    row:SetScript("OnLeave", function(self) SG.UI.PaintGuide(self) end)
    open:SetFrameLevel(row:GetFrameLevel() + 2)
    local function wheel(_, delta)
        local turn = parent:GetScript("OnMouseWheel")
        if turn then turn(parent, delta) end
    end
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", wheel)
    open:EnableMouseWheel(true)
    open:SetScript("OnMouseWheel", wheel)
    return row
end

function SG.UI.PaintGuide(row)
    local on = SG.db.selected == row.guideID
    SG.Paint(row.bg, on and T.rowOn or T.row)
    if on then row.bar:Show() else row.bar:Hide() end
end

local function Header(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(26)
    local text = SG.Widgets.Text(frame, 11)
    text:SetPoint("LEFT", 8, 0)
    text:SetTextColor(SG.RGB(T.gold))
    frame.text = text
    return frame
end

local function StepRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(48)
    row:SetFrameLevel(parent:GetFrameLevel() + 2)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    row.bg = bg
    local bar = row:CreateTexture(nil, "ARTWORK")
    bar:SetWidth(3)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("BOTTOMLEFT")
    SG.Paint(bar, T.accent)
    row.bar = bar
    local title = SG.Widgets.Text(row, 12)
    title:SetPoint("TOPLEFT", 12, -6)
    title:SetPoint("RIGHT", -8, 0)
    title:SetJustifyH("LEFT")
    row.title = title
    local sub = SG.Widgets.Text(row, 11)
    sub:SetPoint("TOPLEFT", 12, -24)
    sub:SetPoint("RIGHT", -8, 0)
    sub:SetJustifyH("LEFT")
    sub:SetTextColor(SG.RGB(T.muted))
    row.sub = sub
    row:SetScript("OnClick", function(self)
        local guide = SG.Engine.Get(SG.state.tab)
        if not guide then return end
        SG.state.stepIndex = self.index
        SG.Engine.Focus(guide, self.index, true)
        SG.UI.Refresh(false)
    end)
    row:SetScript("OnEnter", function(self)
        if SG.state.stepIndex ~= self.index then SG.Paint(self.bg, T.rowHot) end
    end)
    row:SetScript("OnLeave", function(self) SG.UI.PaintStep(self) end)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta)
        local turn = parent:GetScript("OnMouseWheel")
        if turn then turn(parent, delta) end
    end)
    return row
end

function SG.UI.PaintStep(row)
    local on = SG.state.stepIndex == row.index
    if row.done then
        SG.Paint(row.bg, on and T.rowOn or { 0.05, 0.05, 0.07, 0.4 })
        row.title:SetTextColor(SG.RGB(T.dim))
    else
        SG.Paint(row.bg, on and T.rowOn or T.row)
        row.title:SetTextColor(SG.RGB(T.text))
    end
    if on then row.bar:Show() else row.bar:Hide() end
end

function SG.UI.RefreshTabs()
    HidePool(SG.UI.tabPool)
    local x = 8
    local function tab(id, label, closable)
        local button = Acquire(SG.UI.tabPool, SG.UI.tabbar, function(parent)
            local created = CreateFrame("Button", nil, parent)
            created:SetHeight(26)
            local bg = created:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            created.bg = bg
            local text = SG.Widgets.Text(created, 11)
            text:SetPoint("LEFT", 8, 0)
            text:SetJustifyH("LEFT")
            created.label = text
            local ex = CreateFrame("Button", nil, created)
            ex:SetSize(16, 16)
            ex:SetPoint("RIGHT", -4, 0)
            local exText = SG.Widgets.Text(ex, 11)
            exText:SetPoint("CENTER")
            exText:SetText("x")
            created.ex = ex
            created.exText = exText
            return created
        end)
        button:ClearAllPoints()
        button:SetPoint("LEFT", SG.UI.tabbar, "LEFT", x, -4)
        local width = closable and 118 or 72
        button:SetWidth(width)
        button.label:SetText(label)
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", 8, 0)
        button.label:SetWidth(closable and 88 or 56)
        local on = SG.state.tab == id and SG.db.category ~= "options"
        if id == "home" then on = SG.state.tab == "home" and SG.db.category ~= "options" end
        SG.Paint(button.bg, on and T.rowOn or T.inset)
        button.label:SetTextColor(SG.RGB(on and T.text or T.muted))
        button:SetScript("OnClick", function()
            if id == "home" then
                SG.state.tab = "home"
                if SG.db.category == "options" then SG.db.category = "all" end
            else
                SG.state.tab = id
                if SG.db.category == "options" then SG.db.category = "all" end
                SG.db.selected = id
                SG.char.active = id
                local guide = SG.Engine.Get(id)
                SG.state.stepIndex = SG.state.stepIndex or (guide and SG.Engine.CurrentIndex(guide))
            end
            SG.UI.Refresh(true)
        end)
        if closable then
            button.ex:Show()
            button.ex:SetScript("OnClick", function() SG.UI.CloseTab(id) end)
        else
            button.ex:Hide()
        end
        x = x + width + 4
    end
    tab("home", "Guides", false)
    local tabs = SG.db.tabs or {}
    for i = 1, #tabs do
        local guide = SG.Engine.Get(tabs[i])
        if guide then tab(guide.id, Short(guide.title, 16), true) end
    end
end

local function FactionLabel()
    local mode = SG.db.options.faction or "auto"
    if mode == "auto" then return "Faction: " .. SG.SideName(SG.playerSide) end
    if mode == "both" then return "Faction: Both" end
    return "Faction: " .. SG.SideName(mode)
end

local function Passes(guide, category, faction, query)
    if guide.empty then return false end
    if category == "favorites" then
        if not SG.db.favorites[guide.id] then return false end
    elseif category ~= "all" and guide.category ~= category then
        return false
    end
    if faction ~= "both" and guide.side ~= "B" and guide.side ~= faction then
        return false
    end
    return SG.Engine.Matches(guide, query)
end

function SG.UI.RefreshHome(resetScroll)
    HidePool(SG.UI.guidePool)
    HidePool(SG.UI.headerPool)
    local content = SG.UI.homeScroll.content
    local scroll = SG.UI.homeScroll.scroll
    local width = ListWidth(scroll)
    content:SetWidth(width)
    local category = SG.db.category or "all"
    local faction = SG.FactionFilter()
    local query = SG.state.query or ""
    local y = 4
    local groups, order = {}, {}
    local function push(name, guide)
        local group = groups[name]
        if not group then
            group = {}
            groups[name] = group
            order[#order + 1] = name
        end
        group[#group + 1] = guide
    end
    if category == "all" and query == "" then
        local recent = SG.db.recent or {}
        for i = 1, #recent do
            local guide = SG.Engine.Get(recent[i])
            if guide and Passes(guide, "all", faction, "") then
                push("Recent", guide)
            end
        end
    end
    for i = 1, #SG.Engine.guides do
        local guide = SG.Engine.guides[i]
        if Passes(guide, category, faction, query) then
            push(guide.group or "Guides", guide)
        end
    end
    local firstId = nil
    local selectedOk = false
    for g = 1, #order do
        local name = order[g]
        local header = Acquire(SG.UI.headerPool, content, Header)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y)
        header:SetSize(math.max(40, width - 16), 26)
        header.text:SetText(name)
        y = y + 26
        local list = groups[name]
        for i = 1, #list do
            local guide = list[i]
            if not firstId then firstId = guide.id end
            if guide.id == SG.db.selected then selectedOk = true end
            local row = Acquire(SG.UI.guidePool, content, GuideRow)
            row.guideID = guide.id
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -y)
            row:SetSize(math.max(40, width - 16), 58)
            row.title:SetText(guide.title)
            local done, total = SG.Engine.Stats(guide)
            row.sub:SetText(string.format("%d-%d   %s   %d steps", guide.min or 1, guide.max or 60, SG.SideName(guide.side), total))
            row.mini:SetPercent(total > 0 and (done / total) or 0, total > 0 and done == total)
            if SG.db.favorites[guide.id] then
                row.star:SetVertexColor(1, 0.82, 0.35, 1)
            else
                row.star:SetVertexColor(0.5, 0.5, 0.55, 0.35)
            end
            SG.UI.PaintGuide(row)
            y = y + 62
        end
    end
    if not selectedOk then SG.db.selected = firstId end
    if SG.UI.empty then
        if #order == 0 then SG.UI.empty:Show() else SG.UI.empty:Hide() end
    end
    if #order == 0 then
        y = 40
    end
    content:SetHeight(math.max(y + 12, scroll:GetHeight() + 1))
    if resetScroll then SG.UI.homeScroll:Reset() else SG.UI.homeScroll.Update() end
end

function SG.UI.RefreshSteps(resetScroll)
    HidePool(SG.UI.stepPool)
    HidePool(SG.UI.headerPool)
    local guide = SG.Engine.Get(SG.state.tab)
    local content = SG.UI.stepScroll.content
    local scroll = SG.UI.stepScroll.scroll
    local width = ListWidth(scroll)
    content:SetWidth(width)
    if not guide then
        content:SetHeight(math.max(1, scroll:GetHeight() + 1))
        if resetScroll then SG.UI.stepScroll:Reset() else SG.UI.stepScroll.Update() end
        return
    end
    if not SG.state.stepIndex or not guide.steps[SG.state.stepIndex] or not guide.steps[SG.state.stepIndex].visible then
        SG.state.stepIndex = SG.Engine.CurrentIndex(guide) or SG.Engine.FirstVisible(guide)
    end
    local y = 4
    local last = nil
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.visible then
            if step.segment ~= last then
                local header = Acquire(SG.UI.headerPool, content, Header)
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y)
                header:SetSize(math.max(40, width - 16), 26)
                header.text:SetText(step.segment or guide.title)
                last = step.segment
                y = y + 24
            end
            local row = Acquire(SG.UI.stepPool, content, StepRow)
            row.index = i
            row.done = SG.Engine.IsDone(guide, i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -y)
            row:SetSize(math.max(40, width - 16), 48)
            local prefix = row.done and "Done  " or ""
            row.title:SetText(prefix .. step.title)
            local bits = {}
            if step.level and step.questID then bits[#bits + 1] = "Lv " .. step.level end
            if step.rank and step.slotName then
                bits[#bits + 1] = string.format("BiS %s rank %d", step.slotName, step.rank)
            elseif step.match == "path" and not step.optional then
                bits[#bits + 1] = "Starting zone"
            elseif step.optional then
                bits[#bits + 1] = "Optional"
            end
            if step.x and step.y then
                bits[#bits + 1] = string.format("%.1f, %.1f", step.x, step.y)
            end
            row.sub:SetText(table.concat(bits, "   "))
            SG.UI.PaintStep(row)
            y = y + 52
        end
    end
    content:SetHeight(math.max(y + 12, scroll:GetHeight() + 1))
    if resetScroll then SG.UI.stepScroll:Reset() else SG.UI.stepScroll.Update() end
end

local function ShowRewards(detail, step)
    local rewards = step and step.rewards or {}
    for i = 1, #detail.items do
        local row = detail.items[i]
        local itemID = rewards[i]
        if itemID then
            row:Show()
            row.itemID = itemID
            local name, _, quality, texture = SG.ItemName(itemID)
            if texture then
                row.icon:SetTexture(texture)
            else
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            local r, g, b = SG.ItemColor(quality)
            local tag = ""
            if step.itemID == itemID and step.rank then
                tag = string.format("   BiS %s rank %d", step.slotName or "", step.rank)
            elseif step.choice then
                tag = "   choice"
            end
            row.text:SetText((name or ("Item " .. itemID)) .. tag)
            row.text:SetTextColor(r, g, b, 1)
        else
            row.itemID = nil
            row:Hide()
        end
    end
end

function SG.UI.RefreshDetail()
    local detail = SG.UI.detail
    local guide = SG.Engine.Get(SG.db.selected) or SG.Engine.Get(SG.state.tab)
    if SG.db.category == "options" then
        detail.eyebrow:SetText("OPTIONS")
        detail.title:SetText("Stratagem")
        detail.meta:SetText(SG.Specs.Label(SG.Specs.Selected()))
        detail.blurb:SetText("Routes follow the quests that reward best-in-slot gear for your spec. Settings save as you change them.")
        detail.zone:SetText("")
        detail.hidden:SetText(SG.BiS.Status())
        detail.bar:SetPercent(0)
        detail.percent:SetText("")
        detail.primary:Hide()
        detail.secondary:Hide()
        detail.tertiary:Hide()
        detail.reset:Hide()
        detail.star:Hide()
        ShowRewards(detail, nil)
        return
    end
    detail.star:Show()
    if not guide then
        detail.eyebrow:SetText("STRATAGEM")
        detail.title:SetText("Pick a guide")
        detail.meta:SetText("BiS before speed")
        detail.blurb:SetText("Click Open on a guide in the list. Continue on the right starts the highlighted one.")
        detail.zone:SetText("")
        detail.hidden:SetText("")
        detail.bar:SetPercent(0)
        detail.percent:SetText("")
        detail.primary:Hide()
        detail.secondary:Hide()
        detail.tertiary:Hide()
        detail.reset:Hide()
        ShowRewards(detail, nil)
        return
    end
    local done, total = SG.Engine.Stats(guide)
    local percent = total > 0 and (done / total) or 0
    local fav = SG.db.favorites[guide.id]
    detail.star.tex:SetVertexColor(1, 0.82, 0.35, fav and 1 or 0.35)
    detail.bar:SetPercent(percent, total > 0 and done == total)
    detail.percent:SetText(string.format("%s    %d / %d steps", PercentText(done, total), done, total))
    detail.primary:Show()
    detail.secondary:Show()
    detail.tertiary:Show()
    detail.reset:Show()

    local stepMode = SG.state.tab == guide.id
    local step
    if stepMode then
        step = SG.state.stepIndex and guide.steps[SG.state.stepIndex] or nil
        if not step or not step.visible then
            local index = SG.Engine.CurrentIndex(guide) or SG.Engine.FirstVisible(guide)
            step = index and guide.steps[index] or nil
            SG.state.stepIndex = index
        end
    end

    if stepMode and step then
        detail.primary:Enable()
        detail.eyebrow:SetText(guide.title)
        detail.title:SetText(step.title)
        detail.meta:SetText(string.format("%s    %d-%d", SG.SideName(guide.side), guide.min or 1, guide.max or 60))
        detail.blurb:SetText(step.text or "")
        detail.zone:SetText(SG.Nav.CoordText(step))
        detail.primary:SetLabel("Set waypoint")
        detail.primary:SetScript("OnClick", function()
            SG.Engine.Focus(guide, step.index, true)
            SG.Tracker.Update()
        end)
        detail.secondary:SetLabel(SG.Engine.IsDone(guide, step.index) and "Mark not done" or "Mark done")
        detail.secondary:SetScript("OnClick", function()
            local was = SG.Engine.IsDone(guide, step.index)
            SG.Engine.Mark(guide, step.index, not was)
            if not was then
                local nextIndex = SG.Engine.CurrentIndex(guide)
                SG.state.stepIndex = nextIndex
                if nextIndex and SG.Nav.following then
                    SG.Engine.Focus(guide, nextIndex, true)
                end
            end
            SG.UI.Refresh(false)
            SG.Tracker.Update()
        end)
        detail.tertiary:SetLabel("Next step")
        detail.tertiary:SetScript("OnClick", function() SG.Engine.Nudge(1) end)
        ShowRewards(detail, step)
    else
        detail.eyebrow:SetText(guide.group or "GUIDE")
        detail.title:SetText(guide.title)
        detail.meta:SetText(string.format("%d-%d    %s", guide.min or 1, guide.max or 60, SG.SideName(guide.side)))
        detail.blurb:SetText(guide.blurb or "")
        local zones = SG.Engine.ZoneLine(guide)
        detail.zone:SetText(string.format("%d steps  ·  %s", total, zones))
        if guide.hiddenQuests and guide.hiddenQuests > 0 and SG.db.options.onlyMySpec then
            detail.hidden:SetText(string.format("%d quests hidden: not BiS for %s.", guide.hiddenQuests, SG.Specs.Label(SG.Specs.Selected())))
        else
            detail.hidden:SetText("")
        end
        local index = SG.Engine.CurrentIndex(guide)
        if not index then
            detail.primary:SetLabel("Completed")
            detail.primary:Disable()
        else
            detail.primary:SetLabel("Continue")
            detail.primary:Enable()
        end
        detail.primary:SetScript("OnClick", function() SG.UI.Continue(guide.id) end)
        detail.secondary:SetLabel("Open in tab")
        detail.secondary:SetScript("OnClick", function() SG.UI.OpenInPlace(guide.id) end)
        detail.tertiary:SetLabel("Open in new tab")
        detail.tertiary:SetScript("OnClick", function() SG.UI.OpenTab(guide.id) end)
        local nextStep = index and guide.steps[index] or nil
        ShowRewards(detail, nextStep)
    end
    detail.primary:Paint(false)
end

function SG.UI.RefreshOptions()
    local checks = SG.UI.optionChecks or {}
    for i = 1, #checks do
        checks[i]:SetChecked(checks[i].getter())
    end
    if SG.UI.scaleLabel then
        SG.UI.scaleLabel:SetText(string.format("UI scale   %.2f", SG.db.ui.scale or 1))
    end
    if SG.UI.statusText then
        SG.UI.statusText:SetText(SG.BiS.Status())
    end
end

function SG.UI.Refresh(resetScroll)
    if not SG.UI.frame or not SG.UI.frame:IsShown() then return end
    local spec = SG.Specs.Find(SG.Specs.Selected())
    if spec then
        local colors = RAID_CLASS_COLORS and RAID_CLASS_COLORS[spec.token]
        SG.UI.footer.label:SetText(spec.className .. "  ·  " .. spec.name)
        if colors then
            SG.UI.footer.label:SetTextColor(colors.r, colors.g, colors.b, 1)
        end
    end
    for i = 1, #SG.UI.categories do
        SG.UI.PaintCategory(SG.UI.categories[i])
    end
    SG.UI.factionButton:SetLabel(FactionLabel())
    SG.UI.RefreshTabs()

    local optionsOn = SG.db.category == "options"
    if optionsOn then
        SG.UI.home:Hide()
        SG.UI.steps:Hide()
        SG.UI.options:Show()
        SG.UI.RefreshOptions()
    elseif SG.state.tab and SG.state.tab ~= "home" and SG.Engine.Get(SG.state.tab) then
        SG.UI.home:Hide()
        SG.UI.options:Hide()
        SG.UI.steps:Show()
        SG.db.selected = SG.state.tab
        SG.UI.RefreshSteps(resetScroll)
    else
        SG.state.tab = "home"
        SG.UI.steps:Hide()
        SG.UI.options:Hide()
        SG.UI.home:Show()
        SG.UI.RefreshHome(resetScroll)
    end
    SG.UI.RefreshDetail()
end

function SG.UI.OnItem()
    if SG.UI.frame and SG.UI.frame:IsShown() then
        SG.UI.RefreshDetail()
    end
end

if not StaticPopupDialogs.STRATAGEM_RESET_GUIDE then
    StaticPopupDialogs.STRATAGEM_RESET_GUIDE = {
        text = "Reset progress for %s?",
        button1 = "Reset",
        button2 = "Cancel",
        OnAccept = function(self, data)
            data = data or (self and self.data)
            if not data then return end
            SG.char.progress[data] = { done = {} }
            if SG.db.options.autoAdvance then SG.Engine.SyncAll() end
            SG.UI.Refresh(false)
            if SG.Tracker.Update then SG.Tracker.Update() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopupDialogs.STRATAGEM_RESET_ALL = {
        text = "Reset Stratagem progress on this character?",
        button1 = "Reset",
        button2 = "Cancel",
        OnAccept = function()
            SG.char.progress = {}
            if SG.db.options.autoAdvance then SG.Engine.SyncAll() end
            SG.UI.Refresh(false)
            if SG.Tracker.Update then SG.Tracker.Update() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end
