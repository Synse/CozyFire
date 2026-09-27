local addonName, addon = ...

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

local PIN_TTL = 30                                             -- seconds; campfires despawn after ~10 min
local DEDUP_RANGE = 100                                         -- yards; only one campfire per 100 yds
local PIN_TEXTURE = "Interface/Icons/INV_Summerfest_FireSpirit"
local PIN_SIZE = 16
local SWEEP_INTERVAL = 5
local REF = addonName                                          -- HBD-Pins registry reference

local pins = {}
addon.pins = pins

local active = {}
local nextId = 1

local function CreateIcon()
    local icon = CreateFrame("Frame", nil, UIParent)
    icon:SetSize(PIN_SIZE, PIN_SIZE)
    local tex = icon:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture(PIN_TEXTURE)
    icon.texture = tex
    return icon
end

-- Return an existing pin within DEDUP_RANGE in the same instance, if any
local function FindNearby(instanceID, x, y)
    for id, pin in pairs(active) do
        if pin.instanceID == instanceID then
            local dist = HBD:GetWorldDistance(instanceID, x, y, pin.x, pin.y)
            if dist and dist <= DEDUP_RANGE then
                return id, pin
            end
        end
    end
end

-- Add a campfire pin at world coordinates. Returns id, created (true for a new pin, false if an existing pin was found)
function pins:AddPin(instanceID, x, y, campName, ttl)
    if not instanceID or not x or not y then return end

    -- A campfire already known within 100 yds is the same one; leave its fixed lifetime untouched
    local existingId, existing = FindNearby(instanceID, x, y)
    if existing then
        return existingId, false
    end

    local worldIcon = CreateIcon()
    local miniIcon = CreateIcon()

    HBDPins:AddWorldMapIconWorld(REF, worldIcon, instanceID, x, y, HBD_PINS_WORLDMAP_SHOW_PARENT)
    HBDPins:AddMinimapIconWorld(REF, miniIcon, instanceID, x, y, true)

    local id = nextId
    nextId = nextId + 1
    active[id] = {
        instanceID = instanceID,
        x = x,
        y = y,
        campName = campName,
        worldIcon = worldIcon,
        miniIcon = miniIcon,
        expires = GetTime() + (ttl or PIN_TTL),
    }

    return id, true
end

function pins:RemovePin(id)
    local pin = active[id]
    if not pin then return end
    HBDPins:RemoveWorldMapIcon(REF, pin.worldIcon)
    HBDPins:RemoveMinimapIcon(REF, pin.miniIcon)
    active[id] = nil
end

C_Timer.NewTicker(SWEEP_INTERVAL, function()
    local now = GetTime()
    for id, pin in pairs(active) do
        if now >= pin.expires then
            pins:RemovePin(id)
        end
    end
end)
