local addonName, addon = ...

-- Creature GUIDs are formatted as Creature-0-[serverID]-[instanceID]-[zoneUID]-[npcID]-[spawnUID]
-- zoneUID is used to determine which layer we are on
local function GetLayerFromGUID(guid)
    if type(guid) ~= "string" then return nil end

    local zoneUID = select(5, strsplit("-", guid))
    zoneUID = tonumber(zoneUID)
    if not zoneUID or zoneUID == 0 then return nil end

    return zoneUID
end
addon.GetLayerFromGUID = GetLayerFromGUID

local currentLayer

local function SetCurrent(newLayer)
    newLayer = tonumber(newLayer)
    if newLayer == 0 then newLayer = nil end
    if newLayer == currentLayer then return end
    currentLayer = newLayer

    if addon.pins and addon.pins.ApplyLayerVisibility then
        addon.pins:ApplyLayerVisibility()
    end
end

local function GetLayer()
    return currentLayer
end
addon.GetLayer = GetLayer

local function UpdateLayerFromUnit(unit)
    if IsInInstance() then return end

    -- Skip non-combat pets (e.g., Frog Familiar)
    if not unit or UnitCreatureType(unit) == "Non-combat Pet" then return end
    local guid = UnitGUID(unit)

    -- Skip non-creature GUIDs
    if type(guid) ~= "string" or strsub(guid, 1, 8) ~= "Creature" then return end

    local zoneUID = GetLayerFromGUID(guid)
    if zoneUID then SetCurrent(zoneUID) end
end

-- Read GUIDs from target, mouseover, and nameplate units to track the current layer
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        UpdateLayerFromUnit("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        UpdateLayerFromUnit("mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        UpdateLayerFromUnit(...)
    end
end)
