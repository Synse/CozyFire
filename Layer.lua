local addonName, addon = ...

local HBD = LibStub("HereBeDragons-2.0")

-- Creature and player-cast GUIDs carry the zoneUID in their fifth field which we use to determine the current layer
-- Creature GUIDs are formatted as Creature-0-[serverID]-[instanceID]-[zoneUID]-[npcID]-[spawnUID]
-- Player-cast GUIDs are formatted as Cast-[type]-[serverID]-[instanceID]-[zoneUID]-[spellID]-[castUID]
local function GetLayerFromGUID(guid)
    if issecretvalue and issecretvalue(guid) then return nil end
    if type(guid) ~= "string" then return nil end

    local zoneUID = select(5, strsplit("-", guid))
    zoneUID = tonumber(zoneUID)
    if not zoneUID or zoneUID == 0 then return nil end

    return zoneUID
end
addon.GetLayerFromGUID = GetLayerFromGUID

local currentLayer
local currentMapID
local currentSource

local function SetCurrent(newLayer, newMapID, newSource)
    newLayer = tonumber(newLayer)
    if newLayer == 0 then newLayer = nil end
    newMapID = newMapID or C_Map.GetBestMapForUnit("player")
    newSource = newLayer and (newSource or "manual") or nil
    if newLayer == currentLayer and newMapID == currentMapID and newSource == currentSource then return end

    currentLayer = newLayer
    currentMapID = newMapID
    currentSource = newSource

    if addon.pins and addon.pins.ApplyLayerVisibility then
        addon.pins:ApplyLayerVisibility()
    end
end

-- Clear the current layer when changing zones
local function SyncPlayerMap()
    local mapID = C_Map.GetBestMapForUnit("player")

    if mapID ~= currentMapID then
        SetCurrent(nil, mapID)
    end

    return mapID
end
HBD.RegisterCallback(addon, "PlayerZoneChanged", SyncPlayerMap)

-- Returns the current layer
local function GetLayer()
    if IsInInstance() or not currentMapID or currentMapID ~= C_Map.GetBestMapForUnit("player") then
        return nil
    end

    return currentLayer
end
addon.GetLayer = GetLayer

local function UpdateLayerFromUnit(unit)
    local mapID = SyncPlayerMap()
    if not mapID or IsInInstance() or currentSource == "cast" then return end

    -- Skip non-combat pets (e.g., Frog Familiar)
    if not unit then return end
    local creatureType = UnitCreatureType(unit)
    if issecretvalue and issecretvalue(creatureType) then return end
    if creatureType == "Non-combat Pet" then return end
    local guid = UnitGUID(unit)

    -- Skip non-creature GUIDs
    if issecretvalue and issecretvalue(guid) then return end
    if type(guid) ~= "string" or strsub(guid, 1, 8) ~= "Creature" then return end

    local zoneUID = GetLayerFromGUID(guid)
    if zoneUID then SetCurrent(zoneUID, mapID, "npc") end
end

local function UpdateLayerFromCast(castGUID)
    local mapID = SyncPlayerMap()
    if not mapID or IsInInstance() then return end

    local zoneUID = GetLayerFromGUID(castGUID)
    if zoneUID then SetCurrent(zoneUID, mapID, "cast") end
end

-- Read GUIDs from target, mouseover, nameplate units, and player spell casts to track the current layer
-- zoneUIDs from creatures are provisional because you can target or mouseover an NPC in another zone (mapID)
-- but zoneUIDs from player spellcasts are definitive
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_JOINED")
eventFrame:RegisterEvent("GROUP_LEFT")
eventFrame:RegisterEvent("SHARD_TRANSFER")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        UpdateLayerFromUnit("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        UpdateLayerFromUnit("mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        UpdateLayerFromUnit(...)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, castGUID = ...
        UpdateLayerFromCast(castGUID)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "GROUP_JOINED" or event == "GROUP_LEFT" or event == "SHARD_TRANSFER" then
        SetCurrent(nil, C_Map.GetBestMapForUnit("player"))
    end
end)
