-- Nav.lua: TomTom when it is installed, and the quest log's own super-track.
-- TomTom draws the arrow. Stratagem does not.
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

-- Drops the marker Set waypoint placed. A pin the player dropped on their
-- own is left alone.
function SG.Nav.ClearMapPin()
    local openMap = SG.Nav.openMap
    local userPin = SG.Nav.userPin
    SG.Nav.openMap = nil
    SG.Nav.userPin = nil
    if openMap then
        local ns = _G.OpenMap
        if type(ns) == "table" and ns.GetModule then
            local ok, mod = pcall(ns.GetModule, ns, "worldmap")
            if ok and type(mod) == "table" and mod.ClearPin then
                pcall(mod.ClearPin)
                return
            end
        end
    end
    if userPin and C_Map and C_Map.ClearUserWaypoint then
        pcall(C_Map.ClearUserWaypoint)
    end
end

local function WayTitle(step)
    return "Stratagem: " .. (step.title or "Step")
end

-- OpenMap draws this on its map. Coordinates here are 0-1. TrackPoint also
-- sets the Blizzard user waypoint when that map allows one.
local function MarkOpenMap(step, title)
    local ns = _G.OpenMap
    if type(ns) ~= "table" or not ns.GetModule then return false end
    local ok, mod = pcall(ns.GetModule, ns, "worldmap")
    if not ok or type(mod) ~= "table" or type(mod.TrackPoint) ~= "function" then
        return false
    end
    local ran = pcall(mod.TrackPoint, step.map, step.x / 100, step.y / 100, title)
    if not ran then return false end
    SG.Nav.openMap = true
    SG.Nav.userPin = nil
    return true
end

local function PlaceUserPin(step)
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return
    end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(step.map) then
        return
    end
    local point = UiMapPoint.CreateFromCoordinates(step.map, step.x / 100, step.y / 100)
    local ok = pcall(C_Map.SetUserWaypoint, point)
    if not ok then return end
    SG.Nav.userPin = true
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
end

-- OpenMap's TrackPoint also drops a TomTom pin. When the TomTom option is
-- off, remove only the pin this call just added.
local function DropOpenMapTomTom(mapID, title)
    if type(TomTom) ~= "table" or type(TomTom.waypoints) ~= "table" or not TomTom.RemoveWaypoint then
        return
    end
    local list = TomTom.waypoints[mapID]
    if type(list) ~= "table" then return end
    local drop = {}
    for _, uid in pairs(list) do
        if type(uid) == "table" and uid.from == "OpenMap" and uid.title == title then
            drop[#drop + 1] = uid
        end
    end
    for i = 1, #drop do
        pcall(TomTom.RemoveWaypoint, TomTom, drop[i])
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

function SG.Nav.CurrentStep()
    if not SG.Engine or not SG.Engine.Active or not SG.Engine.ShownIndex then return nil end
    local guide = SG.Engine.Active()
    if not guide then return nil end
    local index = SG.Engine.ShownIndex(guide)
    if not index then return nil end
    return guide.steps[index]
end

-- Point TomTom at the step the tracker is on. force reapplies the same step,
-- which is how the TomTom option turns the pin on or off.
function SG.Nav.Follow(force)
    local step = SG.Nav.CurrentStep()
    if not force and step == SG.Nav.step then return end
    SG.Nav.Set(step, force)
end

function SG.Nav.Set(step, force)
    if not force and SG.Nav.step == step then return end
    SG.Nav.step = step
    if not step then
        SG.Nav.ClearTomTom()
        SG.Nav.ClearMapPin()
        return
    end
    local track = step.questID
    if not track and step.kind == "run" and SG.Engine and SG.Engine.RunTrack then
        track = SG.Engine.RunTrack(step)
    end
    SG.Nav.SuperTrack(track)
    SG.Nav.ClearTomTom()
    local title = WayTitle(step)
    local marked = false
    if step.map and step.x and step.y then
        marked = MarkOpenMap(step, title)
        if marked then
            if not TomTomOn() then DropOpenMapTomTom(step.map, title) end
        else
            SG.Nav.ClearMapPin()
            PlaceUserPin(step)
        end
    else
        SG.Nav.ClearMapPin()
    end
    if TomTomOn() and step.map and step.x and step.y then
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, step.map, step.x / 100, step.y / 100, {
            title = title,
            persistent = false,
            minimap = true,
            world = true,
            from = marked and "OpenMap" or "Stratagem",
        })
        if ok then SG.Nav.uid = uid end
    end
    if SG.Tracker and SG.Tracker.Update and not SG.Tracker.updating then
        SG.Tracker.Update()
    end
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

-- Returns the world bearing and the yards. The tracker prints the yards.
-- TomTom draws the arrow from the waypoint.
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
    -- 42 yards per map percent is only a stand-in so the tracker still shows a range.
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
