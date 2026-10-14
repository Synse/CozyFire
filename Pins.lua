local addonName, addon = ...

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

local PIN_TTL = 900        -- seconds; campfires despawn 15 minutes after being placed
local DEDUP_RANGE = 100    -- yards; only one campfire per 100 yds
local PIN_TEXTURE = "Interface\\AddOns\\CozyFire\\Media\\CozyFire.tga"
local WORLD_PIN_SIZE = 24  -- world map pin size
local MINI_PIN_SIZE = 24   -- minimap pin size
local SWEEP_INTERVAL = 5   -- seconds; how often to cleanup expired pins
local OTHER_LAYER_DESATURATION = 0.75  -- color removed from pins on a different layer

local pins = {}
addon.pins = pins

local active = {}
local nextId = 1

-- The zoneUID is a per-map (zone) layer identifier
local function IsOtherLayer(pin)
    local current = addon.GetLayer()
    return pin.layer ~= nil and current ~= nil and pin.layer ~= current
        and pin.mapID == C_Map.GetBestMapForUnit("player")
end

-- Determine if a pin for another layer is covered by a pin on this layer
local function CoveredByCurrentLayer(pin)
    local current = addon.GetLayer()
    if not current then return false end
    for _, other in pairs(active) do
        if other ~= pin and other.layer == current and other.instanceID == pin.instanceID
            and other.mapID == pin.mapID then
            local dist = HBD:GetWorldDistance(pin.instanceID, pin.x, pin.y, other.x, other.y)
            if dist and dist <= DEDUP_RANGE then
                return true
            end
        end
    end
    return false
end

local function ApplyPinAppearance(pin)
    local other = IsOtherLayer(pin)
    local hidden = other and CoveredByCurrentLayer(pin)

    -- Pins on other layers are hidden if they are covered by a pin on the current layer
    local alpha = hidden and 0 or 1
    pin.worldIcon:SetAlpha(alpha)
    pin.miniIcon:SetAlpha(alpha)
    pin.worldIcon:EnableMouse(not hidden)

    -- Pins on other layers are desaturated
    local amount = other and OTHER_LAYER_DESATURATION or 0
    pin.worldIcon.texture:SetDesaturation(amount)
    pin.miniIcon.texture:SetDesaturation(amount)
end

local function CreateIcon(size)
    local icon = CreateFrame("Frame", nil, UIParent)
    icon:SetSize(size, size)
    local tex = icon:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture(PIN_TEXTURE)
    icon.texture = tex
    return icon
end

-- Return an existing pin at the same spot on the same layer, or a shared pin
local function FindNearby(instanceID, x, y, layer)
    for id, pin in pairs(active) do
        if pin.instanceID == instanceID and (pin.layer == layer or pin.shared) then
            local dist = HBD:GetWorldDistance(instanceID, x, y, pin.x, pin.y)
            if dist and dist <= DEDUP_RANGE then
                return id, pin
            end
        end
    end
end

-- Render the tooltip for a map pin
local function RenderPinTooltip(pin)
    local remaining = math.max(0, pin.expires - GetServerTime())
    GameTooltip:ClearLines()
    GameTooltip:AddLine("CozyFire")

    -- Fires placed by other players have an approximate time remaining
    -- but fires placed by the player have an exact time remaining
    local remainingTime = "|cffff7f00" .. SecondsToTime(remaining) .. "|r"
    if pin.approximateTime then
        GameTooltip:AddLine("Less than " .. remainingTime .. " remaining", 1, 1, 1)
    else
        GameTooltip:AddLine(remainingTime .. " remaining", 1, 1, 1)
    end

    -- Manually placed pins have an approximate location
    if pin.approximateLocation then
        GameTooltip:AddLine("Location is approximate", 1, 1, 1)
    end

    if pin.placedBy then
        GameTooltip:AddLine("Placed by: |cffffd100" .. pin.placedBy .. "|r", 1, 1, 1)
    end

    if IsOtherLayer(pin) then
        GameTooltip:AddLine("On a different layer", 1, 0.5, 0.5)
    end

    GameTooltip:Show()
end

-- Show a map pin tooltip, refreshing every second
local function ShowPinTooltip(self)
    local pin = self.pin
    if not pin then return end

    -- Cancel any existing ticker so re-entering the icon can't orphan one
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    RenderPinTooltip(pin)

    local ticker
    ticker = C_Timer.NewTicker(1, function()
        -- Only refresh CozyFire map pins
        if GameTooltip:GetOwner() ~= self then
            ticker:Cancel()
            if self.ticker == ticker then
                self.ticker = nil
            end
            return
        end
        RenderPinTooltip(pin)
    end)
    self.ticker = ticker
end

-- Hide a map pin tooltip
local function HidePinTooltip(self)
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    GameTooltip:Hide()
end

-- Build the pin frames and register it. Returns the new id
local function CreatePin(instanceID, x, y, approximateLocation, approximateTime, expires, placedBy, layer, mapID, shared)
    local worldIcon = CreateIcon(WORLD_PIN_SIZE)
    local miniIcon = CreateIcon(MINI_PIN_SIZE)

    -- PIN_FRAME_LEVEL_TOPMOST draws the world map pin above the player arrow
    HBDPins:AddWorldMapIconWorld(addonName, worldIcon, instanceID, x, y, HBD_PINS_WORLDMAP_SHOW_PARENT, "PIN_FRAME_LEVEL_TOPMOST")
    HBDPins:AddMinimapIconWorld(addonName, miniIcon, instanceID, x, y, false)

    local id = nextId
    nextId = nextId + 1
    local pin = {
        instanceID = instanceID,
        x = x,
        y = y,
        approximateLocation = approximateLocation,
        approximateTime = approximateTime,
        worldIcon = worldIcon,
        miniIcon = miniIcon,
        expires = expires,
        placedBy = placedBy,
        layer = layer,
        mapID = mapID,
        shared = shared,
    }
    active[id] = pin

    worldIcon.pin = pin
    worldIcon:EnableMouse(true)
    worldIcon:SetScript("OnEnter", ShowPinTooltip)
    worldIcon:SetScript("OnLeave", HidePinTooltip)

    pins:ApplyLayerVisibility()

    return id
end

-- Pins on other layers are always desaturated and if they overlap with a pin
-- on the current layer they are hidden completely
function pins:ApplyLayerVisibility()
    for _, pin in pairs(active) do
        ApplyPinAppearance(pin)
    end
end

-- Add a campfire pin at world coordinates. `approximateLocation` is true for manual marks and false when the
-- player gains the "Welcoming Campfire" buff. `approximateTime` is false when the player places the campfire,
-- and true otherwise. `placedBy` is the name of the player who placed the fire, if known. `layer` is the
-- zoneUID of the layer the fire was seen on, if known.
-- Returns id, action ("created"/"replaced"/"exists")
function pins:AddPin(instanceID, x, y, approximateLocation, approximateTime, ttl, placedBy, layer)
    if not instanceID or not x or not y then return end

    local mapID = C_Map.GetBestMapForUnit("player")
    local existingId, existing = FindNearby(instanceID, x, y, layer)
    if existing then
        -- Placing a campfire replaces any nearby pins
        if not approximateLocation and not approximateTime then
            self:RemovePin(existingId)
            return CreatePin(instanceID, x, y, approximateLocation, approximateTime, GetServerTime() + (ttl or PIN_TTL), placedBy, layer, mapID), "replaced"
        end

        -- Sitting at a campfire replaces nearby approximate pins, but retains their original expiration time
        if not approximateLocation and existing.approximateLocation then
            local carriedExpires = existing.expires
            local carriedApproximateTime = existing.approximateTime
            local carriedPlacedBy = existing.placedBy
            self:RemovePin(existingId)
            return CreatePin(instanceID, x, y, approximateLocation, carriedApproximateTime, carriedExpires, carriedPlacedBy, layer, mapID), "replaced"
        end
        return existingId, "exists"
    end

    local id = CreatePin(instanceID, x, y, approximateLocation, approximateTime, GetServerTime() + (ttl or PIN_TTL), placedBy, layer, mapID)
    return id, "created", active[id]
end

-- Add a pin broadcast by another player if we dont already have one nearby
function pins:AddSharedPin(data)
    local instanceID, x, y = data.instanceID, data.x, data.y
    if not instanceID or not x or not y then return end

    for _, pin in pairs(active) do
        if pin.instanceID == instanceID then
            local dist = HBD:GetWorldDistance(instanceID, x, y, pin.x, pin.y)
            if dist and dist <= DEDUP_RANGE then
                return
            end
        end
    end

    CreatePin(instanceID, x, y, data.approximateLocation, data.approximateTime,
        GetServerTime() + data.remaining, data.placedBy, data.layer, data.mapID, true)
end

function pins:RemovePin(id)
    local pin = active[id]
    if not pin then return end

    -- Stop the live countdown and hide the tooltip if it is showing for this pin
    if pin.worldIcon.ticker then
        pin.worldIcon.ticker:Cancel()
        pin.worldIcon.ticker = nil
    end
    if GameTooltip:GetOwner() == pin.worldIcon then
        GameTooltip:Hide()
    end

    HBDPins:RemoveWorldMapIcon(addonName, pin.worldIcon)
    HBDPins:RemoveMinimapIcon(addonName, pin.miniIcon)
    active[id] = nil

    -- A covered other-layer fire may now be shown
    pins:ApplyLayerVisibility()
end

C_Timer.NewTicker(SWEEP_INTERVAL, function()
    local now = GetServerTime()

    -- When not in combat, check for nearby campfire pins
    local px, py, pInstance, nearCampfire
    if not InCombatLockdown() then
        px, py, pInstance = HBD:GetPlayerWorldPosition()
        nearCampfire = addon.IsNearCampfire()
    end
    local currentLayer = addon.GetLayer()

    for id, pin in pairs(active) do
        local expired = now >= pin.expires

        -- Only prune a "missing" fire on our own (or an unknown) layer
        if not expired and not nearCampfire and pin.instanceID == pInstance
            and (pin.layer == nil or pin.layer == currentLayer) then
            local dist = HBD:GetWorldDistance(pInstance, px, py, pin.x, pin.y)
            if dist and dist <= 20 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff8000CozyFire:|r Nearby campfire not found, removed from map.")
                expired = true
            end
        end

        -- Remove expired pins
        if expired then
            pins:RemovePin(id)
        end
    end
end)

-- Persists pins to saved variables
function pins:Save()
    CozyFireDB = CozyFireDB or {}
    local saved = {}
    for _, pin in pairs(active) do
        saved[#saved + 1] = {
            instanceID = pin.instanceID,
            x = pin.x,
            y = pin.y,
            approximateLocation = pin.approximateLocation,
            approximateTime = pin.approximateTime,
            expires = pin.expires,
            placedBy = pin.placedBy,
            layer = pin.layer,
            mapID = pin.mapID,
            shared = pin.shared,
        }
    end
    CozyFireDB.pins = saved
end

-- Restores pins from saved variables
function pins:Restore()
    local saved = CozyFireDB and CozyFireDB.pins
    if not saved then return end
    local now = GetServerTime()
    for _, pin in ipairs(saved) do
        if pin.expires > now then
            CreatePin(pin.instanceID, pin.x, pin.y, pin.approximateLocation, pin.approximateTime, pin.expires, pin.placedBy, pin.layer, pin.mapID, pin.shared)
        end
    end
end

-- Save pins to saved variables on logout and restore them on login
-- This also covers reloading the UI
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        pins:Restore()
    else
        pins:Save()
    end
end)
