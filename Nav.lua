-- Nav.lua: TomTom when it is installed, the quest log's own super-track,
-- and a small on-screen arrow for the same-map case.
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
    SG.Nav.step = step
    if not step then
        SG.Nav.ClearTomTom()
        if SG.Arrow then SG.Arrow.Tick() end
        return
    end
    SG.Nav.SuperTrack(step.questID)
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

SG.Arrow = {}

function SG.Arrow.Create()
    if SG.Arrow.frame then return end
    local frame = CreateFrame("Frame", "StratagemArrow", UIParent)
    frame:SetSize(72, 92)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 230)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    local tex = frame:CreateTexture(nil, "OVERLAY")
    tex:SetSize(56, 56)
    tex:SetPoint("TOP")
    tex:SetTexture(SG.MEDIA .. "arrow.tga")
    frame.tex = tex

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("BOTTOM", 0, 0)
    label:SetWidth(160)
    label:SetJustifyH("CENTER")
    frame.label = label

    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.08 then return end
        elapsed = 0
        SG.Arrow.Tick()
    end)
    SG.Arrow.frame = frame
end

local function Wrap(angle)
    while angle > math.pi do angle = angle - (math.pi * 2) end
    while angle < -math.pi do angle = angle + (math.pi * 2) end
    return angle
end

function SG.Arrow.Tick()
    local frame = SG.Arrow.frame
    if not frame then return end
    local step = SG.Nav.step
    local useArrow = SG.db and SG.db.options.arrow and not TomTomOn()
    if not useArrow or not step or not step.x or not step.y then
        frame:Hide()
        return
    end
    frame:Show()
    frame.label:SetText(SG.Nav.CoordText(step))
    local map, px, py = SG.Nav.PlayerPos()
    if not frame.tex.SetRotation then return end
    if not map or map ~= step.map or not px or not py then
        frame.tex:SetRotation(0)
        return
    end
    -- Map x grows east and map y grows south. Facing 0 is north.
    local dx = (step.x / 100) - px
    local dy = (step.y / 100) - py
    local atan2 = math.atan2 or math.atan
    local target = atan2(dx, -dy)
    local facing = GetPlayerFacing and GetPlayerFacing() or 0
    local angle = Wrap(target - (facing or 0))
    if SG.db.options.invertArrow then angle = -angle end
    frame.tex:SetRotation(angle)
end
