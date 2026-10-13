-- Nav.lua: TomTom when it is installed, the quest log's own super-track,
-- and a HUD arrow that points at the step and shows the distance.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Nav = { following = false, uid = nil, step = nil }

local function TomTomOn()
    return SG.db and SG.db.options.tomtom and type(_G.TomTom) == "table" and TomTom.AddWaypoint
end

function SG.Nav.ClearTomTom()
    local uid = SG.Nav.uid
    SG.Nav.uid = nil
    if uid and type(TomTom) == "table" and TomTom.RemoveWaypoint then
        pcall(TomTom.RemoveWaypoint, TomTom, uid)
    end
end

function SG.Nav.SuperTrack(questID)
    if not SG.db.options.superTrack or not questID then return end
    if C_QuestLog and C_QuestLog.AddQuestWatch then
        pcall(C_QuestLog.AddQuestWatch, questID)
    elseif AddQuestWatch then
        local index
        if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
            index = C_QuestLog.GetLogIndexForQuestID(questID)
        elseif GetQuestLogIndexByID then
            index = GetQuestLogIndexByID(questID)
        end
        if index and index > 0 then pcall(AddQuestWatch, index) end
    end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        pcall(C_SuperTrack.SetSuperTrackedQuestID, questID)
    end
end

function SG.Nav.Set(step)
    if SG.Nav.step == step then
        if SG.Arrow then SG.Arrow.Tick() end
        return
    end
    SG.Nav.step = step
    if not step then
        SG.Nav.ClearTomTom()
        if SG.Arrow then SG.Arrow.Tick() end
        return
    end
    local track = step.questID
    if not track and step.kind == "run" and SG.Engine and SG.Engine.RunTrack then
        track = SG.Engine.RunTrack(step)
    end
    SG.Nav.SuperTrack(track)
    SG.Nav.ClearTomTom()
    if TomTomOn() and step.map and step.x and step.y then
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, step.map, step.x / 100, step.y / 100, {
            title = "Stratagem: " .. (step.title or "Step"),
            persistent = false,
            minimap = true,
            world = true,
            from = "Stratagem",
        })
        if ok then SG.Nav.uid = uid end
    end
    if SG.Arrow then SG.Arrow.Tick() end
    if SG.Tracker and SG.Tracker.Update then SG.Tracker.Update() end
end

function SG.Nav.MapName(mapID)
    if not mapID or not C_Map or not C_Map.GetMapInfo then return nil end
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or nil
end

function SG.Nav.PlayerPos()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then
        return nil
    end
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return nil end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return map end
    local x, y
    if pos.GetXY then
        x, y = pos:GetXY()
    else
        x, y = pos.x, pos.y
    end
    return map, x, y
end

function SG.Nav.CoordText(step)
    if not step then return "No step selected" end
    local mapName = SG.Nav.MapName(step.map) or step.zone or "Unknown zone"
    if step.x and step.y then
        return string.format("%s   %.1f, %.1f", mapName, step.x, step.y)
    end
    return mapName
end

local function HereBeDragons()
    if not LibStub then return nil end
    return LibStub("HereBeDragons-2.0", true)
end

-- x and y are 0-1. Returns instance, worldX, worldY when the client can convert.
local function WorldXY(map, x, y)
    if not map or not x or not y then return nil end
    if C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local inst, wx, wy = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
        if type(wx) == "number" and type(wy) == "number" then
            return inst, wx, wy
        end
        if type(wx) == "table" then
            local px, py = wx.x, wx.y
            if wx.GetXY then px, py = wx:GetXY() end
            if type(px) == "number" and type(py) == "number" then
                return inst, px, py
            end
        end
    end
    local hbd = HereBeDragons()
    if hbd and hbd.GetWorldCoordinatesFromZone then
        local wx, wy, inst = hbd:GetWorldCoordinatesFromZone(x, y, map)
        if type(wx) == "number" and type(wy) == "number" then
            return inst, wx, wy
        end
    end
end

-- Same angle HereBeDragons uses: atan2(-dx, dy), then fold into 0..2pi.
-- dx is east and dy is north. Distance is the length of that same vector.
local function VectorAngle(dx, dy)
    local atan2 = math.atan2 or math.atan
    local angle = atan2(-dx, dy)
    if angle > 0 then
        angle = (math.pi * 2) - angle
    else
        angle = -angle
    end
    return angle
end

-- Returns the world bearing and the yards. Both come from one vector, so
-- walking the way the arrow points makes the distance fall.
function SG.Nav.Bearing(step)
    if not step or not step.map or not step.x or not step.y then return nil, nil end
    local hbd = HereBeDragons()
    if hbd and hbd.GetPlayerWorldPosition and hbd.GetWorldCoordinatesFromZone and hbd.GetWorldVector then
        local x, y, instance = hbd:GetPlayerWorldPosition()
        local destX, destY, destInst = hbd:GetWorldCoordinatesFromZone(step.x / 100, step.y / 100, step.map)
        if x and destX and instance and destInst and instance == destInst then
            local angle, dist = hbd:GetWorldVector(instance, x, y, destX, destY)
            if type(angle) == "number" and type(dist) == "number" then
                return angle, dist
            end
        end
    end
    local map, px, py = SG.Nav.PlayerPos()
    if not map or not px or not py then return nil, nil end
    local inst1, x1, y1 = WorldXY(map, px, py)
    local inst2, x2, y2 = WorldXY(step.map, step.x / 100, step.y / 100)
    if x1 and x2 and (not inst1 or not inst2 or inst1 == inst2) then
        local dx, dy = x2 - x1, y2 - y1
        return VectorAngle(dx, dy), math.sqrt(dx * dx + dy * dy)
    end
    -- Same map, and neither HereBeDragons nor the world-position API answered.
    -- Map y grows south, so north is the player's y minus the pin's y.
    -- 42 yards per map percent is only a stand-in so the HUD still shows a range.
    if map == step.map then
        local dx = ((step.x / 100) - px) * 4200
        local dy = (py - (step.y / 100)) * 4200
        return VectorAngle(dx, dy), math.sqrt(dx * dx + dy * dy)
    end
    return nil, nil
end

function SG.Nav.Measure(step)
    local _, yards = SG.Nav.Bearing(step)
    local map = SG.Nav.PlayerPos()
    return yards, map
end

function SG.Nav.FormatDistance(yards)
    if type(yards) ~= "number" then return nil end
    if yards < 8 then return "Here" end
    if yards >= 10000 then
        return string.format("%.1fk yd", yards / 1000)
    end
    return string.format("%d yd", math.floor(yards + 0.5))
end

SG.Arrow = {}

local function SaveArrow(frame)
    if not SG.db or not SG.db.ui then return end
    if type(SG.db.ui.arrow) ~= "table" then SG.db.ui.arrow = {} end
    local point, _, rel, x, y = frame:GetPoint()
    local pos = SG.db.ui.arrow
    pos.point, pos.rel, pos.x, pos.y = point, rel, x, y
end

-- The step the tracker is on. The arrow reads this every tick, so Next,
-- Prev, and a click in the list move it even when nothing else calls Nav.Set.
function SG.Arrow.Target()
    if not SG.Engine or not SG.Engine.Active then return nil end
    local guide = SG.Engine.Active()
    if not guide then return nil end
    local index = SG.Engine.ShownIndex(guide)
    if not index then return nil end
    return guide.steps[index]
end

function SG.Arrow.Create()
    if SG.Arrow.frame then return end
    local frame = CreateFrame("Frame", "StratagemArrow", UIParent)
    frame:SetSize(168, 132)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    local pos = SG.db and SG.db.ui and SG.db.ui.arrow or {}
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.rel or "CENTER", pos.x or 0, pos.y or 230)
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveArrow(self)
    end)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and SG.UI and SG.UI.ShowGuides then
            SG.UI.ShowGuides()
        end
    end)
    frame:Hide()

    local tex = frame:CreateTexture(nil, "OVERLAY")
    tex:SetSize(56, 56)
    tex:SetPoint("TOP", 0, -4)
    tex:SetTexture(SG.MEDIA .. "arrow.tga")
    frame.tex = tex

    local dist = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dist:SetPoint("TOP", tex, "BOTTOM", 0, -2)
    dist:SetWidth(160)
    dist:SetJustifyH("CENTER")
    dist:SetTextColor(0.93, 0.78, 0.45, 1)
    frame.dist = dist

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOP", dist, "BOTTOM", 0, -2)
    label:SetWidth(160)
    label:SetHeight(32)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(true)
    frame.label = label

    -- A hidden arrow does not receive OnUpdate, so the driver stays shown
    -- and keeps the direction pointed at the current step.
    if not SG.Arrow.driver then
        local elapsed = 0
        local driver = CreateFrame("Frame")
        driver:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed < 0.08 then return end
            elapsed = 0
            SG.Arrow.Tick()
        end)
        SG.Arrow.driver = driver
    end
    SG.Arrow.frame = frame
    SG.Arrow.Tick()
end

local function Wrap(angle)
    while angle > math.pi do angle = angle - (math.pi * 2) end
    while angle < -math.pi do angle = angle + (math.pi * 2) end
    return angle
end

function SG.Arrow.Tick()
    local frame = SG.Arrow.frame
    if not frame then return end
    local step = SG.Arrow.Target()
    if step ~= SG.Nav.step then
        SG.Nav.Set(step)
        return
    end
    local useArrow = SG.db and SG.db.options.arrow
    if not useArrow or not step or not step.x or not step.y then
        frame:Hide()
        return
    end
    frame:Show()
    local angle, yards = SG.Nav.Bearing(step)
    local pretty = SG.Nav.FormatDistance(yards)
    frame.dist:SetText(pretty or "—")
    frame.label:SetText(step.title or step.questName or SG.Nav.CoordText(step))
    if not frame.tex.SetRotation then return end
    if type(angle) ~= "number" then
        frame.tex:SetRotation(0)
        if not pretty then
            local playerMap = SG.Nav.PlayerPos()
            frame.dist:SetText(playerMap and "Other zone" or "—")
        end
        return
    end
    local facing = GetPlayerFacing and GetPlayerFacing() or 0
    local turn = Wrap(angle - (facing or 0))
    if SG.db.options.invertArrow then turn = -turn end
    frame.tex:SetRotation(turn)
end
