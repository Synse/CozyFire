local addonName, addon = ...

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

local PIN_TTL = 900        -- seconds; campfires despawn 15 minutes after being placed
local DEDUP_RANGE = 100    -- yards; only one campfire per 100 yds
local PIN_TEXTURE = "Interface\\AddOns\\CozyFire\\Media\\flame.tga"
local WORLD_PIN_SIZE = 28  -- world map pin size
local MINI_PIN_SIZE = 24   -- minimap pin size
local SWEEP_INTERVAL = 5   -- seconds; how often to cleanup expired pins
local REF = addonName      -- HBD-Pins registry reference

local pins = {}
addon.pins = pins

local active = {}
local nextId = 1

local function CreateIcon(size)
    local icon = CreateFrame("Frame", nil, UIParent)
    icon:SetSize(size, size)
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

-- Build the pin frames and register it. Returns the new id
local function CreatePin(instanceID, x, y, campName, approximate, expires)
    local worldIcon = CreateIcon(WORLD_PIN_SIZE)
    local miniIcon = CreateIcon(MINI_PIN_SIZE)

    -- PIN_FRAME_LEVEL_TOPMOST draws the world map pin above the player arrow
    HBDPins:AddWorldMapIconWorld(REF, worldIcon, instanceID, x, y, HBD_PINS_WORLDMAP_SHOW_PARENT, "PIN_FRAME_LEVEL_TOPMOST")
    HBDPins:AddMinimapIconWorld(REF, miniIcon, instanceID, x, y, false)

    local id = nextId
    nextId = nextId + 1
    active[id] = {
        instanceID = instanceID,
        x = x,
        y = y,
        campName = campName,
        approximate = approximate,
        worldIcon = worldIcon,
        miniIcon = miniIcon,
        expires = expires,
    }
    return id
end

-- Add a campfire pin at world coordinates. `approximate` is true for fuzzy (manual) marks and false when the
-- player gains the "Welcoming Campfire" buff. Returns id, action ("created"/"replaced"/"exists")
function pins:AddPin(instanceID, x, y, campName, approximate, ttl)
    if not instanceID or not x or not y then return end

    local existingId, existing = FindNearby(instanceID, x, y)
    if existing then
        -- An exact mark repositions a fuzzy pin, keeping its original lifetime
        if not approximate and existing.approximate then
            local carriedExpires = existing.expires
            self:RemovePin(existingId)
            return CreatePin(instanceID, x, y, campName, approximate, carriedExpires), "replaced"
        end
        return existingId, "exists"
    end

    return CreatePin(instanceID, x, y, campName, approximate, time() + (ttl or PIN_TTL)), "created"
end

function pins:RemovePin(id)
    local pin = active[id]
    if not pin then return end
    HBDPins:RemoveWorldMapIcon(REF, pin.worldIcon)
    HBDPins:RemoveMinimapIcon(REF, pin.miniIcon)
    active[id] = nil
end

C_Timer.NewTicker(SWEEP_INTERVAL, function()
    local now = time()
    for id, pin in pairs(active) do
        if now >= pin.expires then
            pins:RemovePin(id)
        end
    end
end)
