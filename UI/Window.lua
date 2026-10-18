-- Window.lua: the browser. Sidebar, guide list, search, and the detail card.
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

local function SavePosition(frame)
    local point, _, rel, x, y = frame:GetPoint()
    SG.db.ui.point = point
    SG.db.ui.rel = rel
    SG.db.ui.x = x
    SG.db.ui.y = y
end

function SG.UI.Select(id)
    SG.db.selected = id
    SG.state.tab = "home"
    SG.UI.Refresh(false)
end

function SG.UI.Continue(id)
    local guide = SG.Engine.Get(id)
    if not guide then return end
    SG.state.tab = id
    SG.db.selected = id
    SG.char.active = id
    if SG.RememberRecent then SG.RememberRecent(id) end
    if SG.Engine.CatchUp then SG.Engine.CatchUp(guide, true) end
    local index = SG.Engine.ShownIndex(guide)
    SG.state.stepIndex = index
    if index and SG.Engine.Focus then
        SG.Engine.Focus(guide, index, true)
    elseif SG.Nav then
        SG.Nav.Set(nil)
    end
    SG.UI.Refresh(true)
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
end

function SG.UI.Show()
    if not SG.db then return end
    if not SG.UI.frame then SG.UI.Create() end
    if SG.UI.frame then SG.UI.frame:Show() end
end

function SG.UI.DirectId()
    local category = SG.db and SG.db.category
    if category == "leveling" and SG.Route and SG.Route.ActiveId then
        return SG.Route.ActiveId()
    end
    if category == "bis" then return "bis-60" end
    if category == "collectibles" then return "collect-all" end
    return nil
end

function SG.UI.ShowGuides()
    if not SG.db then return end
    if not SG.UI.frame then SG.UI.Create() end
    if not SG.UI.frame then return end
    SG.state = SG.state or { query = "", tab = "home", stepIndex = nil }
    SG.db.category = "leveling"
    local id = SG.UI.DirectId()
    local guide = id and SG.Engine.Get(id)
    if guide then
        SG.state.tab = id
        local index = SG.Engine.ShownIndex(guide)
        SG.Engine.Focus(guide, index, true)
    else
        SG.state.tab = "home"
    end
    SG.UI.frame:Show()
    SG.UI.Refresh(true)
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

function SG.UI.OpenProfessionRecipes(profId)
    if not SG.db then return end
    if not SG.UI.frame then SG.UI.Create() end
    SG.db.profTab = "recipes"
    SG.db.category = "professions"
    if type(profId) == "number" and profId > 0 then SG.db.recipeProf = profId end
    SG.state = SG.state or { query = "", tab = "home", stepIndex = nil }
    SG.state.tab = "prof-recipes"
    SG.db.selected = "prof-recipes"
    if SG.Recipes and SG.Recipes.Refresh then SG.Recipes.Refresh() end
    local guide = SG.Engine and SG.Engine.Get and SG.Engine.Get("prof-recipes")
    if guide and SG.Engine.Focus then
        SG.Engine.Focus(guide, SG.Engine.ShownIndex(guide), true)
    end
    if SG.UI.frame then SG.UI.frame:Show() end
    if SG.UI.Refresh then SG.UI.Refresh(true) end
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
end

function SG.UI.OpenProfessionGuides()
    if not SG.db then return end
    SG.db.profTab = "guides"
    SG.db.category = "professions"
    SG.state = SG.state or { query = "", tab = "home", stepIndex = nil }
    SG.state.tab = "home"
    if SG.UI.Refresh then SG.UI.Refresh(true) end
end

function SG.UI.ProfEntries()
    local entries = { { kind = "guides", label = "Guides" } }
    local guide = SG.Engine and SG.Engine.Get and SG.Engine.Get("prof-recipes")
    local tabs = (SG.Recipes and SG.Recipes.Tabs and SG.Recipes.Tabs(guide)) or {}
    if #tabs == 0 then
        entries[#entries + 1] = { kind = "recipes", label = "Recipes" }
        return entries
    end
    for i = 1, #tabs do
        entries[#entries + 1] = { kind = "recipes", id = tabs[i].id, label = tabs[i].name }
    end
    return entries
end

function SG.UI.EnsureProfButton(bar, index)
    local buttons = SG.UI.profTabButtons
    if not buttons then
        buttons = {}
        SG.UI.profTabButtons = buttons
    end
    local button = buttons[index]
    if button then return button end
    button = SG.Widgets.Button(bar, "", "ghost")
    button:SetHeight(28)
    button:SetScript("OnClick", function(self)
        if self.profTab == "guides" then
            SG.UI.OpenProfessionGuides()
        else
            SG.UI.OpenProfessionRecipes(self.profId)
        end
    end)
    buttons[index] = button
    return button
end

function SG.UI.LayoutProfTabs(bar)
    local entries = SG.UI.ProfEntries()
    local buttons = SG.UI.profTabButtons or {}
    local width = bar:GetWidth()
    if not width or width < 80 then width = 520 end
    local chosen
    if SG.db and SG.db.profTab == "recipes" and SG.Recipes and SG.Recipes.Selected then
        local guide = SG.Engine and SG.Engine.Get and SG.Engine.Get("prof-recipes")
        chosen = SG.Recipes.Selected(guide)
    end
    local x, row = 0, 0
    for i = 1, #entries do
        local entry = entries[i]
        local button = SG.UI.EnsureProfButton(bar, i)
        button:SetLabel(entry.label)
        button.profTab = entry.kind
        button.profId = entry.id
        local textW = 0
        local label = button.label
        if label and label.GetStringWidth then textW = label:GetStringWidth() or 0 end
        if textW < 8 then textW = #entry.label * 7 end
        local w = math.floor(textW + 28)
        if w < 64 then w = 64 end
        if x > 0 and (x + w) > width then
            row = row + 1
            x = 0
        end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -(row * 32))
        button:SetSize(w, 28)
        local selected = false
        if entry.kind == "guides" then
            selected = not SG.db or SG.db.profTab ~= "recipes"
        elseif entry.id then
            selected = SG.db and SG.db.profTab == "recipes" and entry.id == chosen
        else
            selected = SG.db and SG.db.profTab == "recipes"
        end
        button.kind = selected and "primary" or "ghost"
        button:Show()
        if button.Paint then button:Paint(false) end
        x = x + w + 6
    end
    for i = #entries + 1, #buttons do
        buttons[i]:Hide()
    end
    local rows = row + 1
    bar:SetHeight(rows * 28 + (rows - 1) * 4)
end

function SG.UI.SyncProfBar()
    if SG.db and SG.db.category == "professions" and SG.state then
        if SG.state.tab == "prof-recipes" then
            SG.db.profTab = "recipes"
        else
            SG.db.profTab = "guides"
        end
    end
    local bar = SG.UI.profBar
    local on = SG.db and SG.db.category == "professions" and bar and true or false
    if bar then
        if on then bar:Show() else bar:Hide() end
    end
    local barH = 28
    if on then
        SG.UI.LayoutProfTabs(bar)
        barH = bar:GetHeight()
        if not barH or barH < 28 then barH = 28 end
    end
    local offset = on and -(barH + 8) or 0
    if SG.UI.profOffset ~= offset and SG.UI.tabbar then
        SG.UI.profOffset = offset
        local tabbar = SG.UI.tabbar
        if SG.UI.home then
            SG.UI.home:ClearAllPoints()
            SG.UI.home:SetPoint("TOPLEFT", tabbar, "BOTTOMLEFT", 0, offset)
            SG.UI.home:SetPoint("BOTTOMRIGHT")
        end
        if SG.UI.steps then
            SG.UI.steps:ClearAllPoints()
            SG.UI.steps:SetPoint("TOPLEFT", tabbar, "BOTTOMLEFT", 0, offset)
            SG.UI.steps:SetPoint("BOTTOMRIGHT")
        end
    end
end

function SG.UI.BuildProfBar(center)
    local bar = CreateFrame("Frame", nil, center)
    bar:SetPoint("TOPLEFT", SG.UI.tabbar, "BOTTOMLEFT", 8, -4)
    bar:SetPoint("TOPRIGHT", SG.UI.tabbar, "BOTTOMRIGHT", -8, -4)
    bar:SetHeight(28)
    local level = center:GetFrameLevel() + 30
    if SG.UI.home and SG.UI.home:GetFrameLevel() >= level then
        level = SG.UI.home:GetFrameLevel() + 5
    end
    bar:SetFrameLevel(level)
    bar:Hide()
    SG.UI.profBar = bar
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
            if self.id == "leveling" or self.id == "bis" or self.id == "collectibles" then
                local id
                if self.id == "bis" then
                    id = "bis-60"
                elseif self.id == "collectibles" then
                    id = "collect-all"
                elseif SG.Route and SG.Route.ActiveId then
                    id = SG.Route.ActiveId()
                end
                local guide = id and SG.Engine.Get(id)
                if guide then
                    SG.state.tab = id
                    SG.db.selected = id
                    if self.id == "leveling" then
                        SG.Engine.Focus(guide, SG.Engine.ShownIndex(guide), true)
                    else
                        SG.state.stepIndex = nil
                    end
                end
            elseif self.id == "professions" and SG.db.profTab == "recipes" then
                SG.UI.OpenProfessionRecipes()
                return
            elseif self.id ~= "options" then
                SG.state.tab = "home"
            end
            if self.id == "reputation" and SG.Reputation and SG.Reputation.Refresh then
                SG.Reputation.Refresh()
            end
            if self.id == "routes" and SG.Polestar and SG.Polestar.Refresh then
                SG.Polestar.Refresh()
            end
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

    local homeScroll = SG.Widgets.Scroll(home)
    homeScroll:SetPoint("TOPLEFT", 0, -8)
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
    empty:SetPoint("TOPLEFT", 24, -16)
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
    local showSpecs = SG.Widgets.Button(empty, "Show every spec", "ghost")
    showSpecs:SetSize(160, 28)
    showSpecs:SetPoint("TOPLEFT", 0, -40)
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
    local gearBar = CreateFrame("Frame", nil, steps)
    gearBar:SetPoint("TOPLEFT", 8, -4)
    gearBar:SetPoint("TOPRIGHT", -8, -4)
    gearBar:SetHeight(28)
    gearBar:Hide()
    local gearTabs = {
        { id = "quest", label = "Quests", width = 70 },
        { id = "profession", label = "Profession", width = 96 },
        { id = "auction", label = "Auction House", width = 112 },
        { id = "world", label = "World Drops", width = 96 },
        { id = "reputation", label = "Reputation", width = 100 },
    }
    local gearButtons = {}
    local previous
    for i = 1, #gearTabs do
        local info = gearTabs[i]
        local button = SG.Widgets.Button(gearBar, info.label, "ghost")
        button.gearTab = info.id
        button:SetSize(info.width, 28)
        if i == 1 then
            button:SetPoint("LEFT", 0, 0)
        else
            button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
        end
        button:SetScript("OnClick", function()
            if not SG.db then return end
            SG.db.gearTab = info.id
            local active = SG.Engine and SG.Engine.Active and SG.Engine.Active()
            if active and active.gear and SG.Gear and SG.Gear.Filter then
                SG.Gear.Filter(active)
                if SG.Engine.PlaceCursor then SG.Engine.PlaceCursor(active) end
            end
            if info.id == "reputation" and SG.Reputation and SG.Reputation.Refresh then
                SG.Reputation.Refresh()
            end
            SG.UI.Refresh(true)
            if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
        end)
        gearButtons[i] = button
        previous = button
    end
    SG.UI.gearBar = gearBar
    SG.UI.gearTabButtons = gearButtons
    local stepScroll = SG.Widgets.Scroll(steps)
    stepScroll:SetPoint("TOPLEFT", 0, -4)
    stepScroll:SetPoint("BOTTOMRIGHT")
    SG.UI.steps = steps
    SG.UI.stepScroll = stepScroll
    SG.UI.stepScrollOffset = -4

    local options = CreateFrame("Frame", nil, center)
    options:SetPoint("TOPLEFT", tabbar, "BOTTOMLEFT", 0, 0)
    options:SetPoint("BOTTOMRIGHT")
    options:Hide()
    SG.UI.options = options
    SG.UI.BuildOptions(options)
    SG.UI.BuildDetail(detail)
    SG.UI.BuildPicker(footer)
    SG.UI.BuildProfBar(center)

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

    local scroller = CreateFrame("ScrollFrame", nil, detail)
    scroller:SetPoint("TOPLEFT", 16, -106)
    scroller:SetPoint("RIGHT", -16, 0)
    scroller:SetHeight(72)
    scroller:EnableMouse(true)
    scroller:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, scroller)
    child:SetSize(240, 72)
    scroller:SetScrollChild(child)
    local blurb = SG.Widgets.Text(child, 12)
    blurb:SetPoint("TOPLEFT", 0, 0)
    blurb:SetJustifyH("LEFT")
    blurb:SetWordWrap(true)
    blurb:SetWidth(240)
    blurb:SetHeight(72)
    detail.blurb = blurb
    detail.blurbScroll = scroller
    scroller:SetScript("OnMouseWheel", function(self, delta)
        local shown = self:GetHeight()
        local full = child:GetHeight()
        local maxScroll = full - shown
        if maxScroll < 0 then maxScroll = 0 end
        local offset = self:GetVerticalScroll() - delta * 18
        if offset < 0 then offset = 0 end
        if offset > maxScroll then offset = maxScroll end
        self:SetVerticalScroll(offset)
    end)

    local chain = CreateFrame("Button", nil, detail)
    chain:SetSize(16, 16)
    chain:SetPoint("TOPRIGHT", -16, -40)
    local chainTex = chain:CreateTexture(nil, "ARTWORK")
    chainTex:SetAllPoints()
    chainTex:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    chainTex:SetVertexColor(SG.RGB(T.gold))
    chain:SetScript("OnEnter", function(self)
        if self.step and SG.ShowChainTip then SG.ShowChainTip(self, self.step) end
    end)
    chain:SetScript("OnLeave", function() GameTooltip:Hide() end)
    chain:Hide()
    detail.chain = chain

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
    detail.secondary = wide("Mark done", "ghost", -298)
    detail.tertiary = wide("Next step", "ghost", -332)
    detail.pin = wide("Pin", "ghost", -366)

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
    checks[#checks + 1] = addCheck("Hide rewards meant for other specs", function() return SG.db.options.onlyMySpec end, function(on)
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
    checks[#checks + 1] = addCheck("HUD arrow with direction and distance", function() return SG.db.options.arrow end, function(on)
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
    local mini = SG.Widgets.Bar(row)
    mini:SetHeight(3)
    mini:SetPoint("BOTTOMLEFT", 12, 6)
    mini:SetPoint("BOTTOMRIGHT", -78, 6)
    row.mini = mini
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button ~= "LeftButton" then return end
        local now = GetTime()
        if self.last and (now - self.last) < 0.35 then
            self.last = nil
            SG.UI.Continue(self.guideID)
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
    text:SetPoint("RIGHT", -8, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
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
    local function wheel(_, delta)
        local turn = parent:GetScript("OnMouseWheel")
        if turn then turn(parent, delta) end
    end
    local icon = CreateFrame("Button", nil, row)
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", 8, -8)
    icon:SetFrameLevel(row:GetFrameLevel() + 3)
    local iconTex = icon:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints()
    icon.tex = iconTex
    icon:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(self.itemID)
        else
            GameTooltip:SetHyperlink("item:" .. self.itemID)
        end
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    icon:SetScript("OnClick", function(self)
        local owner = self:GetParent()
        local handler = owner:GetScript("OnClick")
        if handler then handler(owner, "LeftButton") end
    end)
    icon:EnableMouseWheel(true)
    icon:SetScript("OnMouseWheel", wheel)
    icon:Hide()
    row.icon = icon
    local title = SG.Widgets.Text(row, 12)
    title:SetPoint("TOPLEFT", 12, -6)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(true)
    row.title = title
    local pin = CreateFrame("Button", nil, row)
    pin:SetSize(46, 16)
    pin:SetFrameLevel(row:GetFrameLevel() + 4)
    pin:SetPoint("TOPRIGHT", -6, -6)
    local pinText = SG.Widgets.Text(pin, 10)
    pinText:SetPoint("CENTER")
    pinText:SetText("Pin")
    pinText:SetTextColor(SG.RGB(T.gold))
    pin.label = pinText
    pin:SetScript("OnClick", function()
        local guide = SG.Engine.Get(SG.state.tab)
        if guide and SG.Pins and SG.Pins.Toggle then
            SG.Pins.Toggle(guide, row.index)
            SG.UI.Refresh(false)
        end
    end)
    pin:EnableMouseWheel(true)
    pin:SetScript("OnMouseWheel", wheel)
    row.pin = pin
    local chain = CreateFrame("Button", nil, row)
    chain:SetSize(16, 16)
    chain:SetFrameLevel(row:GetFrameLevel() + 3)
    chain:SetPoint("TOPRIGHT", pin, "TOPLEFT", -4, 0)
    local chainTex = chain:CreateTexture(nil, "ARTWORK")
    chainTex:SetAllPoints()
    chainTex:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    chainTex:SetVertexColor(SG.RGB(T.gold))
    chain:SetScript("OnEnter", function(self)
        local guide = SG.Engine.Get(SG.state.tab)
        local step = guide and guide.steps[row.index]
        if step and SG.ShowChainTip then SG.ShowChainTip(self, step) end
    end)
    chain:SetScript("OnLeave", function() GameTooltip:Hide() end)
    chain:SetScript("OnClick", function() end)
    chain:EnableMouseWheel(true)
    chain:SetScript("OnMouseWheel", wheel)
    chain:Hide()
    row.chain = chain
    local sub = SG.Widgets.Text(row, 11)
    sub:SetPoint("TOPLEFT", 12, -24)
    sub:SetJustifyH("LEFT")
    sub:SetWordWrap(true)
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
    row:SetScript("OnMouseWheel", wheel)
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
    if row.bisFrom == "level" then
        SG.Paint(row.bar, T.gold)
        row.bar:Show()
    elseif row.bisFrom == "upgrade" then
        SG.Paint(row.bar, T.good)
        row.bar:Show()
    elseif on then
        SG.Paint(row.bar, T.accent)
        row.bar:Show()
    else
        row.bar:Hide()
    end
end

function SG.UI.RefreshTabs()
    if SG.UI.tabPool then HidePool(SG.UI.tabPool) end
end

local function Passes(guide, category, faction, query)
    if guide.empty then return false end
    if guide.category ~= category then return false end
    if category == "professions" and guide.recipes then return false end
    if guide.side ~= "B" and guide.side ~= faction then return false end
    return SG.Engine.Matches(guide, query)
end

function SG.UI.RefreshHome(resetScroll)
    HidePool(SG.UI.guidePool)
    HidePool(SG.UI.headerPool)
    local content = SG.UI.homeScroll.content
    local scroll = SG.UI.homeScroll.scroll
    local width = ListWidth(scroll)
    content:SetWidth(width)
    local category = SG.db.category or "leveling"
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

function SG.UI.FillStepRow(row, step, width, guide)
    local index = row.index or step.index
    local done = index and SG.Engine.IsDone(guide, index) or false
    row.done = done and true or false
    row.bisFrom = step.bisFrom
    local itemID = step.itemID
    if not itemID and step.rewards and SG.BiS and SG.BiS.BestReward and SG.Specs and SG.Specs.Selected then
        itemID = SG.BiS.BestReward({ rewards = step.rewards }, SG.Specs.Selected())
    end
    if not itemID and step.rewards then itemID = step.rewards[1] end
    local iconTex
    if itemID and SG.ItemName then
        iconTex = select(4, SG.ItemName(itemID))
    end
    if (not iconTex) and step.icon and step.icon ~= "" then iconTex = step.icon end
    local showIcon = itemID ~= nil or (step.icon ~= nil and step.icon ~= "")
    if row.icon then
        if showIcon then
            row.icon:Show()
            row.icon.itemID = itemID
            if iconTex then
                row.icon.tex:SetTexture(iconTex)
            else
                row.icon.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
        else
            row.icon.itemID = nil
            row.icon:Hide()
        end
    end
    local pinned = SG.Pins and SG.Pins.Has and index and SG.Pins.Has(guide, index)
    if row.pin and row.pin.label then
        row.pin.label:SetText(pinned and "Unpin" or "Pin")
        row.pin:Show()
    end
    local chained = SG.HasChain and SG.HasChain(step) and true or false
    if row.chain then
        if chained then row.chain:Show() else row.chain:Hide() end
    end
    local left = showIcon and 48 or 12
    local rightPad = chained and 78 or 58
    local textW = width - 16 - left - rightPad
    if textW < 40 then textW = 40 end
    local main = step.title
    if not main or main == "" then main = step.text or "" end
    if done then main = "Done  " .. main end
    row.title:ClearAllPoints()
    row.title:SetPoint("TOPLEFT", left, -6)
    row.title:SetWidth(textW)
    row.title:SetWordWrap(true)
    row.title:SetText(main)
    row.title:SetHeight(4000)
    local textH = row.title:GetStringHeight() or 0
    if textH < 14 then
        local per = math.floor(textW / 6.5)
        if per < 8 then per = 8 end
        textH = math.ceil((#main > 0 and #main or 1) / per) * 14
        if textH < 14 then textH = 14 end
    end
    row.title:SetHeight(textH)
    local bits = {}
    if step.level and (step.questID or step.kind == "farm" or step.kind == "gear" or step.kind == "run" or step.kind == "path") then
        bits[#bits + 1] = "Lv " .. step.level
    end
    if step.optional then bits[#bits + 1] = "(Optional)" end
    if step.bisFrom == "level" then
        bits[#bits + 1] = "Level BiS"
    elseif step.bisFrom == "upgrade" then
        bits[#bits + 1] = "Upgrade"
    elseif step.match == "path" and not step.optional then
        bits[#bits + 1] = "Starting zone"
    end
    if step.gearName then bits[#bits + 1] = step.gearName end
    if step.dropLine then bits[#bits + 1] = step.dropLine end
    if step.placeName and step.placeName ~= "" then bits[#bits + 1] = step.placeName end
    if step.x and step.y then
        bits[#bits + 1] = string.format("%.1f, %.1f", step.x, step.y)
    end
    local sub = table.concat(bits, "   ")
    row.sub:ClearAllPoints()
    row.sub:SetPoint("TOPLEFT", left, -(8 + textH))
    row.sub:SetWidth(textW)
    row.sub:SetWordWrap(true)
    row.sub:SetText(sub)
    local subH = 0
    if sub ~= "" then
        row.sub:Show()
        row.sub:SetHeight(4000)
        subH = row.sub:GetStringHeight() or 0
        if subH < 14 then subH = 14 end
        row.sub:SetHeight(subH)
    else
        row.sub:Hide()
        row.sub:SetHeight(1)
    end
    local height = 8 + textH + 4 + subH + 8
    if height < 48 then height = 48 end
    local rowW = width - 16
    if rowW < 40 then rowW = 40 end
    row:SetSize(rowW, height)
    if step.bisFrom == "level" then
        row.sub:SetTextColor(SG.RGB(T.gold))
    elseif step.bisFrom == "upgrade" then
        row.sub:SetTextColor(SG.RGB(T.good))
    else
        row.sub:SetTextColor(SG.RGB(T.muted))
    end
    SG.UI.PaintStep(row)
    return height
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
        SG.state.stepIndex = SG.Engine.ShownIndex(guide)
    end
    local query = (SG.state.query or ""):lower()
    local function listed(step)
        if query == "" then return true end
        if step.title and step.title:lower():find(query, 1, true) then return true end
        if step.segment and step.segment:lower():find(query, 1, true) then return true end
        if step.text and step.text:lower():find(query, 1, true) then return true end
        if step.dropLine and step.dropLine:lower():find(query, 1, true) then return true end
        if step.gearName and step.gearName:lower():find(query, 1, true) then return true end
        if step.placeName and step.placeName:lower():find(query, 1, true) then return true end
        if step.rewards and SG.ItemName then
            for n = 1, #step.rewards do
                local name = SG.ItemName(step.rewards[n], true)
                if name and name:lower():find(query, 1, true) then return true end
            end
        end
        if step.itemID and SG.ItemName then
            local name = SG.ItemName(step.itemID, true)
            if name and name:lower():find(query, 1, true) then return true end
        end
        return false
    end
    local y = 4
    local last = nil
    local focusAt = nil
    local shown = SG.Engine.ShownIndex(guide)
    for i = 1, #guide.steps do
        local step = guide.steps[i]
        if step.visible and listed(step) then
            if step.segment ~= last then
                local header = Acquire(SG.UI.headerPool, content, Header)
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y)
                header:SetSize(math.max(40, width - 16), 26)
                header.text:SetText(step.segment or guide.title)
                last = step.segment
                y = y + 24
            end
            if i == shown then focusAt = y end
            local row = Acquire(SG.UI.stepPool, content, StepRow)
            row.index = i
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -y)
            local height = SG.UI.FillStepRow(row, step, width, guide)
            y = y + height + 4
        end
    end
    content:SetHeight(math.max(y + 12, scroll:GetHeight() + 1))
    if resetScroll then
        local maxScroll = math.max(0, content:GetHeight() - scroll:GetHeight())
        local offset = 0
        if focusAt and focusAt > 40 then offset = focusAt - 28 end
        if offset > maxScroll then offset = maxScroll end
        scroll:SetVerticalScroll(offset)
        SG.UI.stepScroll.Update()
    else
        SG.UI.stepScroll.Update()
    end
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
            local mode = step.pickSet and step.pickSet[itemID]
            if mode == "bis" then
                tag = "   Take · Level BiS"
            elseif mode == "upgrade" then
                tag = "   Take · Upgrade"
            elseif step.skipSet and step.skipSet[itemID] then
                tag = "   Skip"
            end
            row.text:SetText((name or ("Item " .. itemID)) .. tag)
            row.text:SetTextColor(r, g, b, 1)
        else
            row.itemID = nil
            row:Hide()
        end
    end
end

local function LayoutDetail(detail, step)
    local blurb = detail.blurb
    local scroll = detail.blurbScroll
    if not blurb or not scroll then return end
    local chained = step and SG.HasChain and SG.HasChain(step) and true or false
    if detail.chain then
        detail.chain.step = chained and step or nil
        if chained then detail.chain:Show() else detail.chain:Hide() end
    end
    if detail.title then
        detail.title:ClearAllPoints()
        detail.title:SetPoint("TOPLEFT", 16, -36)
        detail.title:SetPoint("TOPRIGHT", chained and -36 or -16, -36)
    end
    local width = (detail:GetWidth() or 300) - 48
    if width < 80 then width = 240 end
    blurb:SetWidth(width)
    -- Tall enough to measure a dungeon clear. The region is shrunk to the text after.
    blurb:SetHeight(4000)
    local textH = blurb:GetStringHeight() or 0
    if textH < 1 then
        local text = blurb:GetText() or ""
        local per = math.floor(width / 6.5)
        if per < 24 then per = 24 end
        local lines, count = 1, 0
        for i = 1, #text do
            local ch = text:sub(i, i)
            if ch == "\n" then
                lines = lines + 1
                count = 0
            else
                count = count + 1
                if count >= per then
                    lines = lines + 1
                    count = 0
                end
            end
        end
        textH = lines * 16
    end
    blurb:SetHeight(textH + 4)
    local child = scroll:GetScrollChild()
    if child then
        child:SetWidth(width)
        child:SetHeight(textH + 4)
    end
    local frameH = detail:GetHeight()
    if not frameH or frameH < 400 then frameH = 640 end
    -- Buttons and the reward rows that are actually showing sit at the bottom.
    -- The objective text gets everything above them, so a dungeon clear is not
    -- stuck in a short box with empty room reserved for four reward rows.
    local function shown(widget)
        return widget and widget.IsShown and widget:IsShown()
    end
    local function blank(widget)
        if not widget or not widget.GetText then return true end
        local text = widget:GetText()
        return text == nil or text == ""
    end
    local stack = {}
    local function push(widget, h, both, skipBlank)
        if not shown(widget) then return end
        if skipBlank and blank(widget) then return end
        stack[#stack + 1] = { widget, h, both }
    end
    push(detail.zone, 18, true, true)
    push(detail.hidden, 16, true, true)
    push(detail.bar, 16, true, false)
    push(detail.percent, 16, false, true)
    push(detail.primary, 40, true, false)
    push(detail.secondary, 34, true, false)
    push(detail.tertiary, 34, true, false)
    push(detail.pin, 34, true, false)
    push(detail.reset, 22, false, false)
    local items = detail.items or {}
    local rewardCount = 0
    for i = 1, #items do
        if shown(items[i]) then rewardCount = rewardCount + 1 end
    end
    local stackH = 12
    for i = 1, #stack do stackH = stackH + stack[i][2] end
    stackH = stackH + rewardCount * 26
    local view = frameH - 106 - 8 - stackH
    if view < 72 then view = 72 end
    local same = detail.blurbStep == step
    detail.blurbStep = step
    local kept = same and scroll:GetVerticalScroll() or 0
    scroll:SetHeight(view)
    local maxScroll = (textH + 4) - view
    if maxScroll < 0 then maxScroll = 0 end
    if kept < 0 then kept = 0 end
    if kept > maxScroll then kept = maxScroll end
    scroll:SetVerticalScroll(kept)
    local top = -(106 + view + 4)
    local y = 0
    for i = 1, #stack do
        local widget, h, both = stack[i][1], stack[i][2], stack[i][3]
        widget:ClearAllPoints()
        widget:SetPoint("TOPLEFT", 16, top - y)
        if both then widget:SetPoint("TOPRIGHT", -16, top - y) end
        y = y + h
    end
    for i = 1, #items do
        local row = items[i]
        row:ClearAllPoints()
        if shown(row) then
            row:SetPoint("TOPLEFT", 16, top - y)
            row:SetPoint("RIGHT", -16, 0)
            y = y + 26
        end
    end
    if detail.bar and detail.bar.SetPercent then
        detail.bar:SetPercent(detail.bar.percent, detail.bar.done)
    end
end

function SG.UI.RefreshDetail()
    local detail = SG.UI.detail
    local guide = SG.Engine.Get(SG.db.selected) or SG.Engine.Get(SG.state.tab)
    if SG.db.category == "options" then
        detail.eyebrow:SetText("OPTIONS")
        detail.title:SetText("Stratagem")
        detail.meta:SetText(SG.Specs.Label(SG.Specs.Selected()))
        detail.blurb:SetText("Routes call out every gear upgrade. Gold means it is the best piece for that slot at your level.")
        detail.zone:SetText("")
        detail.hidden:SetText(SG.BiS.Status())
        detail.bar:SetPercent(0)
        detail.percent:SetText("")
        detail.primary:Hide()
        detail.secondary:Hide()
        detail.tertiary:Hide()
        detail.pin:Hide()
        detail.reset:Hide()
        ShowRewards(detail, nil)
        LayoutDetail(detail, nil)
        return
    end
    if not guide then
        detail.eyebrow:SetText("STRATAGEM")
        detail.title:SetText("Pick a guide")
        detail.meta:SetText("BiS before speed")
        detail.blurb:SetText("Gear lists upgrades you can pick up around your level. The other categories are lists. Click Open, then Continue.")
        detail.zone:SetText("")
        detail.hidden:SetText("")
        detail.bar:SetPercent(0)
        detail.percent:SetText("")
        detail.primary:Hide()
        detail.secondary:Hide()
        detail.tertiary:Hide()
        detail.pin:Hide()
        detail.reset:Hide()
        ShowRewards(detail, nil)
        LayoutDetail(detail, nil)
        return
    end
    local done, total = SG.Engine.Stats(guide)
    local percent = total > 0 and (done / total) or 0
    detail.bar:SetPercent(percent, total > 0 and done == total)
    detail.percent:SetText(string.format("%s    %d / %d steps", PercentText(done, total), done, total))
    detail.primary:Show()
    detail.secondary:Hide()
    detail.tertiary:Hide()
    detail.pin:Hide()
    detail.reset:Show()

    local stepMode = SG.state.tab == guide.id
    local step
    if stepMode then
        step = SG.state.stepIndex and guide.steps[SG.state.stepIndex] or nil
        if not step or not step.visible then
            local index = SG.Engine.ShownIndex(guide)
            step = index and guide.steps[index] or nil
            SG.state.stepIndex = index
        end
    end

    if stepMode and step then
        detail.primary:Enable()
        if step.bisFrom == "level" then
            detail.eyebrow:SetText("LEVEL BIS")
        elseif step.bisFrom == "upgrade" then
            detail.eyebrow:SetText("UPGRADE")
        elseif step.optional then
            detail.eyebrow:SetText("OPTIONAL")
        else
            detail.eyebrow:SetText((guide.recipes and step.profName) or guide.title)
        end
        detail.title:SetText(step.title)
        if guide.scoreText and guide.scoreText ~= "" then
            detail.meta:SetText(guide.scoreText)
        else
            detail.meta:SetText(string.format("%s    %d-%d", SG.SideName(guide.side), guide.min or 1, guide.max or 60))
        end
        local blurb = step.text or ""
        if (step.kind == "complete" or step.kind == "run") and SG.QuestProgressText then
            local extra = SG.QuestProgressText(step)
            if extra and extra ~= "" then blurb = blurb .. "\n" .. extra end
        end
        detail.blurb:SetText(blurb)
        local dist = SG.Nav.FormatDistance(SG.Nav.Measure(step))
        local coord = SG.Nav.CoordText(step)
        if step.placeName and step.placeName ~= "" and step.x and step.y then
            coord = string.format("%s   %.1f, %.1f", step.placeName, step.x, step.y)
        end
        detail.zone:SetText(dist and (coord .. "    " .. dist) or coord)
        detail.hidden:SetText("")
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
                local nextIndex = step.index + 1
                while guide.steps[nextIndex] and not guide.steps[nextIndex].visible do
                    nextIndex = nextIndex + 1
                end
                if not guide.steps[nextIndex] then nextIndex = nil end
                SG.state.stepIndex = nextIndex
                if nextIndex and SG.Nav.following then
                    SG.Engine.Focus(guide, nextIndex, true)
                elseif nextIndex then
                    SG.Engine.Progress(guide.id).cursor = nextIndex
                end
            end
            SG.UI.Refresh(false)
            SG.Tracker.Update()
        end)
        detail.tertiary:Show()
        detail.tertiary:SetLabel("Next step")
        detail.tertiary:SetScript("OnClick", function() SG.Engine.Nudge(1) end)
        detail.secondary:Show()
        detail.pin:Show()
        detail.pin:SetLabel((SG.Pins and SG.Pins.Has and SG.Pins.Has(guide, step.index or SG.state.stepIndex)) and "Unpin" or "Pin")
        detail.pin:SetScript("OnClick", function()
            if SG.Pins and SG.Pins.Toggle then
                SG.Pins.Toggle(guide, step.index or SG.state.stepIndex)
                SG.UI.Refresh(false)
            end
        end)
        ShowRewards(detail, nil)
        LayoutDetail(detail, step)
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
        ShowRewards(detail, nil)
        LayoutDetail(detail, nil)
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
    SG.UI.RefreshTabs()

    local direct = SG.UI.DirectId()
    if direct and SG.Engine.Get(direct) and SG.state.tab ~= direct and SG.db.category ~= "options" then
        SG.state.tab = direct
        SG.db.selected = direct
        SG.state.stepIndex = nil
    end
    if SG.UI.SyncProfBar then SG.UI.SyncProfBar() end

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
        local shown = SG.Engine.Get(SG.state.tab)
        local gearOn = shown and shown.gear and true or false
        if SG.UI.gearBar then
            if gearOn then SG.UI.gearBar:Show() else SG.UI.gearBar:Hide() end
            local offset = gearOn and -36 or -4
            if SG.UI.stepScrollOffset ~= offset then
                SG.UI.stepScrollOffset = offset
                SG.UI.stepScroll:ClearAllPoints()
                SG.UI.stepScroll:SetPoint("TOPLEFT", 0, offset)
                SG.UI.stepScroll:SetPoint("BOTTOMRIGHT")
            end
            local buttons = SG.UI.gearTabButtons or {}
            local selected = SG.db.gearTab or "quest"
            for i = 1, #buttons do
                local button = buttons[i]
                button.kind = (button.gearTab == selected) and "primary" or "ghost"
                button:Paint(false)
            end
        end
        SG.UI.RefreshSteps(resetScroll)
    else
        SG.state.tab = "home"
        SG.UI.steps:Hide()
        SG.UI.options:Hide()
        SG.UI.home:Show()
        SG.UI.RefreshHome(resetScroll)
    end
    if SG.UI.SyncProfBar then SG.UI.SyncProfBar() end
    SG.UI.RefreshDetail()
end

function SG.UI.OnItem()
    if SG.UI.frame and SG.UI.frame:IsShown() then
        SG.UI.Refresh(false)
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
