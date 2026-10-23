local addonName, addon = ...

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

local PIN_TTL = 900        -- seconds; campfires despawn 15 minutes after being placed
local DEDUP_RANGE = 100    -- yards; only one campfire per 100 yds
local CAMPFIRE_OBJECT_LIMITS = { 3, 5, 10 }
local PIN_TEXTURE = "Interface\\AddOns\\CozyFire\\Media\\CozyFire.tga"
local WORLD_PIN_SIZE = 20  -- world map pin size
local MINI_PIN_SIZE = 20   -- minimap pin size
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

-- Return a nearby pin on the same map, preferring an exact layer match over an unknown one
local function FindNearby(instanceID, x, y, layer, mapID)
    local fallbackId

    for id, pin in pairs(active) do
        if pin.instanceID == instanceID and pin.mapID == mapID
            and (pin.layer == layer or pin.layer == nil or layer == nil) then
            local dist = HBD:GetWorldDistance(instanceID, x, y, pin.x, pin.y)

            if dist and dist <= DEDUP_RANGE then
                -- exact layer match
                if pin.layer == layer then
                    return id, pin
                end

                -- fallback to unknown layer
                fallbackId = fallbackId or id
            end
        end
    end

    return fallbackId, active[fallbackId]
end

-- Called when mousing over a campfire or camping object to update nearby pins
-- Campfires will update unknown tier and layer information
-- Camping objects will update the buffs provided
function pins:ObserveCampObject(entry)
    if InCombatLockdown() or not entry.tier then return end

    local x, y, instanceID = HBD:GetPlayerWorldPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not x or not y or not mapID then return end

    local layer = addon.GetLayer()
    local now = GetServerTime()
    local nearest, nearestDistance, nearestIsExactLayer

    for _, pin in pairs(active) do
        if pin.instanceID == instanceID and pin.mapID == mapID and pin.expires > now
            and (pin.layer == nil or pin.layer == layer) then
            local distance = HBD:GetWorldDistance(instanceID, x, y, pin.x, pin.y)
            local isExactLayer = pin.layer == layer
            if distance and distance <= 20 and (not nearest
                or isExactLayer and not nearestIsExactLayer
                or isExactLayer == nearestIsExactLayer and distance < nearestDistance) then
                nearest, nearestDistance, nearestIsExactLayer = pin, distance, isExactLayer
            end
        end
    end

    if nearest then
        -- Update the campfire tier
        if entry.profession == "Cooking" and nearest.tier == nil then
            nearest.tier = entry.tier
        end

        -- Update the campfire layer
        if nearest.layer == nil and layer ~= nil then
            nearest.layer = layer
            self:ApplyLayerVisibility()
        end

        if entry.profession == "Cooking" then return end

        -- Get the camp objects for this pin and add/update the list with this object
        nearest.objects = nearest.objects or {}
        local objects = nearest.objects
        for index, code in ipairs(objects) do
            if addon.campObjectsByCode[code].profession == entry.profession then
                if code ~= entry.code then
                    objects[index] = entry.code
                end
                return
            end
        end

        -- Truncate the list of objects if it exceeds the limit for this campfire tier
        objects[#objects + 1] = entry.code
        if #objects > CAMPFIRE_OBJECT_LIMITS[nearest.tier or 1] then
            table.remove(objects, 1)
        end
    end
end

-- Render the tooltip for a map pin
local function RenderPinTooltip(pin)
    local remaining = math.max(0, pin.expires - GetServerTime())
    GameTooltip:ClearLines()
    GameTooltip:AddLine("|cffff8000CozyFire|r")

    -- Add the camp objects to the tooltip
    local objects = pin.objects
    if objects then
        for _, code in ipairs(objects) do
            local object = addon.campObjectsByCode[code]
            local text = object.name
            -- Prepend the icon if defined
            if object.icon then
                text = ("|T%s:18:18|t %s"):format(object.icon, text)
            end
            GameTooltip:AddLine(text, 0.25, 1, 0.25, true)
        end
        GameTooltip:AddLine(" ")
    end

    -- Remaining time is approximate unless a CozyFire user placed the campfire
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
local function CreatePin(instanceID, x, y, approximateLocation, approximateTime, expires, placedBy, layer, mapID, shared, tier, objects)
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
        shared = shared == true,
        tier = (tier == 1 or tier == 2 or tier == 3) and tier or nil,
        objects = type(objects) == "table" and objects or nil,
    }
    if pin.objects then
        for index = #pin.objects, 1, -1 do
            local object = addon.campObjectsByCode[pin.objects[index]]
            if not object or object.profession == "Cooking" then
                table.remove(pin.objects, index)
            end
        end
        while #pin.objects > CAMPFIRE_OBJECT_LIMITS[pin.tier or 1] do
            table.remove(pin.objects, 1)
        end
    end
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
-- Returns id, action ("created"/"replaced"/"exists"), and the pin when created or replaced
local function AddPin(data, source)
    local instanceID, x, y = data.instanceID, data.x, data.y
    if not instanceID or not x or not y then return end

    local isLocal = source == "local"
    local mapID, now
    if isLocal then
        mapID = C_Map.GetBestMapForUnit("player")
    else
        now = GetServerTime()
        mapID = data.mapID
    end
    local expires = data.expires
    local layer = data.layer
    local approximateLocation = data.approximateLocation
    local approximateTime = data.approximateTime
    local placedBy = data.placedBy
    local tier = data.tier
    local objects = data.objects
    local existingId, existing = FindNearby(instanceID, x, y, layer, mapID)

    -- Remove the existing pin if expired
    if not isLocal and existing and existing.expires <= now then
        pins:RemovePin(existingId)
        existing = nil
    end

    local replaceExisting = false
    if existing then
        if isLocal then
            layer = layer or existing.layer

            -- Placing a campfire replaces any nearby pins
            local isPlacement = not approximateLocation and not approximateTime
            local improvesLocation = not approximateLocation and existing.approximateLocation
            replaceExisting = isPlacement or improvesLocation

            -- Sitting at a campfire replaces nearby approximate pins, but retains their original expiration time
            if replaceExisting and not isPlacement then
                expires = existing.expires
                approximateTime = existing.approximateTime
                placedBy = existing.placedBy
                tier = existing.tier
                objects = existing.objects
            end
        elseif not existing.approximateTime and not approximateTime then
            -- Ignore reports for older fires in this location
            if expires < existing.expires then return end

            -- Remove the current pin if this report is a new fire
            if expires > existing.expires then
                layer = layer or existing.layer
                replaceExisting = true
            end
        end
    end

    if existing and not replaceExisting then
        local upgradeLocation = not isLocal and existing.approximateLocation and not approximateLocation
        local upgradeLayer = existing.layer == nil and layer ~= nil

        if not isLocal then
            if upgradeLocation then
                existing.x, existing.y = x, y
                existing.approximateLocation = false
                HBDPins:RemoveWorldMapIcon(addonName, existing.worldIcon)
                HBDPins:AddWorldMapIconWorld(addonName, existing.worldIcon, instanceID, x, y, HBD_PINS_WORLDMAP_SHOW_PARENT, "PIN_FRAME_LEVEL_TOPMOST")
                HBDPins:AddMinimapIconWorld(addonName, existing.miniIcon, instanceID, x, y, false)
            end

            if existing.approximateTime then
                if not approximateTime then
                    existing.expires = expires
                    existing.approximateTime = false
                else
                    existing.expires = math.min(existing.expires, expires)
                end
            end

            existing.placedBy = existing.placedBy or placedBy
        end

        -- Upgrade the existing pin's unknown layer to a known layer
        if upgradeLayer then
            existing.layer = layer
        end

        if upgradeLocation or upgradeLayer then
            pins:ApplyLayerVisibility()
        end

        if isLocal then
            return existingId, "exists"
        end
        return
    end

    if replaceExisting then
        pins:RemovePin(existingId)
    end

    if isLocal then
        expires = expires or (GetServerTime() + PIN_TTL)
    end

    local id = CreatePin(instanceID, x, y, approximateLocation, approximateTime, expires, placedBy, layer, mapID, not isLocal, tier, objects)
    if isLocal then
        return id, replaceExisting and "replaced" or "created", active[id]
    end
end

-- Add a pin for a locally marked campfire
function pins:AddLocalPin(instanceID, x, y, approximateLocation, approximateTime, placedBy, layer)
    return AddPin({
        instanceID = instanceID,
        x = x,
        y = y,
        approximateLocation = approximateLocation,
        approximateTime = approximateTime,
        placedBy = placedBy,
        layer = layer,
    }, "local")
end

-- Add or improve a shared pin
function pins:AddSharedPin(data)
    AddPin(data, "shared")
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
    pin.worldIcon.pin = nil
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
        nearCampfire = addon.PlayerNearCampfire()
    end
    local currentLayer = addon.GetLayer()

    for id, pin in pairs(active) do
        local expired = now >= pin.expires

        -- Only prune a "missing" fire on our own (or an unknown) layer
        if not expired and nearCampfire == false and pin.instanceID == pInstance
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
            tier = pin.tier,
            objects = pin.objects,
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
            CreatePin(pin.instanceID, pin.x, pin.y, pin.approximateLocation, pin.approximateTime, pin.expires, pin.placedBy, pin.layer, pin.mapID, pin.shared, pin.tier, pin.objects)
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
