-- Minimap.lua: a draggable button orbiting the minimap. No LibDBIcon.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Minimap = {}

local function Place(button)
    local angle = math.rad((SG.db.minimap and SG.db.minimap.angle) or 220)
    local radius = (Minimap:GetWidth() / 2) + 6
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function SG.Minimap.Create()
    if SG.Minimap.button then
        SG.Minimap.Update()
        return
    end
    local button = CreateFrame("Button", "StratagemMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    SG.Paint(bg, { 0.04, 0.04, 0.07, 0.9 })
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexture(SG.MEDIA .. "Icon.tga")
    SG.Widgets.Edge(button, SG.Theme.line)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Stratagem", 0.85, 0.7, 1)
        GameTooltip:AddLine("Left-click to open. Right-click the tracker.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag to move.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(_, which)
        if which == "RightButton" then
            SG.db.options.tracker = not SG.db.options.tracker
            SG.Tracker.Update()
        else
            SG.UI.Toggle()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local atan2 = math.atan2 or math.atan
            SG.db.minimap.angle = math.deg(atan2(cy - my, cx - mx))
            Place(self)
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        Place(self)
    end)

    SG.Minimap.button = button
    Place(button)
    SG.Minimap.Update()
end

function SG.Minimap.Update()
    local button = SG.Minimap.button
    if not button then return end
    if SG.db.options.minimap then button:Show() else button:Hide() end
    Place(button)
end
