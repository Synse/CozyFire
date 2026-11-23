local addonName = ...
---@class CozyFire
local addon = select(2, ...)

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

local DEDUP_RANGE = 100    -- yards; only one campfire per 100 yds
local CAMPFIRE_HOVER_RANGE = 200  -- yards; how far away a hovered campfire tooltip will show buffs
local CAMPFIRE_OBJECT_LIMITS = { 3, 5, 10 }
local PIN_TEXTURE = "Interface\\AddOns\\CozyFire\\Media\\CozyFire.tga"
local PIN_TEXTURE_VIOLET_FLAMES = "Interface\\AddOns\\CozyFire\\Media\\VioletFlames.tga"
local SWEEP_INTERVAL = 5   -- seconds; how often to cleanup expired pins
local OTHER_LAYER_DESATURATION = 0.75  -- color removed from pins on a different layer

local pins = {}
addon.pins = pins

local active = {}
local nextId = 1

---Checks whether a pin is on a different layer
---@param pin table
---@return boolean # false when either layer is unknown
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
    local texture = pin.violetFlames and PIN_TEXTURE_VIOLET_FLAMES or PIN_TEXTURE
    pin.worldIcon.texture:SetTexture(texture)
    pin.miniIcon.texture:SetTexture(texture)

    local other = IsOtherLayer(pin)
    local hidden = other and CoveredByCurrentLayer(pin)
    local worldHidden = hidden or CozyFireDB.hideWorldMapPins
    local miniHidden = hidden or CozyFireDB.hideMinimapPins

    -- Pins on other layers are hidden if they are covered by a pin on the current layer
    -- HBD shows icons when the maps update them, so hide with alpha instead
    pin.worldIcon:SetAlpha(worldHidden and 0 or 1)
    pin.miniIcon:SetAlpha(miniHidden and 0 or 1)
    pin.worldIcon:EnableMouse(not worldHidden)

    local worldSize = CozyFireDB.worldMapPinSize or addon.PIN_SIZE_WORLDMAP
    pin.worldIcon:SetSize(worldSize, worldSize)
    local miniSize = CozyFireDB.minimapPinSize or addon.PIN_SIZE_MINIMAP
    pin.miniIcon:SetSize(miniSize, miniSize)

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
    icon.texture = tex
    return icon
end

-- Return a nearby pin, preferring an exact layer match over an unknown one
local function FindNearby(instanceID, x, y, layer, mapID)
    local fallbackId

    for id, pin in pairs(active) do
        if pin.instanceID == instanceID then
            local dist = HBD:GetWorldDistance(instanceID, x, y, pin.x, pin.y)

            if dist and dist <= DEDUP_RANGE then
                -- zoneUIDs differ per map, so a mismatch across maps doesn't mean another layer
                local sameMap = pin.mapID == mapID

                -- exact layer match
                if sameMap and pin.layer == layer then
                    return id, pin
                end

                -- fallback to unknown layer
                if not sameMap or pin.layer == nil or layer == nil then
                    fallbackId = fallbackId or id
                end
            end
        end
    end

    return fallbackId, active[fallbackId]
end

---Updates the nearest campfire pin with information from a camp object
---@param entry table # camp object from addon.campObjects
---@return table? # the nearest pin, if any
function pins:ObserveCampObject(entry)
    if InCombatLockdown() or not entry.tier then return end

    local x, y, instanceID = HBD:GetPlayerWorldPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not x or not y or not mapID then return end

    local layer = addon.GetLayer()
    local now = GetServerTime()
    local nearest, nearestDistance

    -- Find the nearest campfire pin that isn't known to be on another layer
    for _, pin in pairs(active) do
        -- zoneUIDs differ per map, so a mismatch across maps doesn't mean another layer
        local sameMap = pin.mapID == mapID
        if pin.instanceID == instanceID and pin.expires > now
            and (not sameMap or pin.layer == nil or layer == nil or pin.layer == layer) then
            local distance = HBD:GetWorldDistance(instanceID, x, y, pin.x, pin.y)
            if distance and distance <= CAMPFIRE_HOVER_RANGE and (not nearest or distance < nearestDistance) then
                nearest, nearestDistance = pin, distance
            end
        end
    end

    -- Only pins within 20 yards are updated
    if nearest and nearestDistance <= 20 then
        -- Update the campfire tier
        if entry.profession == "Cooking" and entry.tier > nearest.tier then
            nearest.tier = entry.tier
            addon.PrintDebug("Set campfire tier=%s", entry.tier)
        end

        if not nearest.violetFlames and addon.PlayerHasVioletFlames() then
            nearest.violetFlames = true
            ApplyPinAppearance(nearest)
            addon.PrintDebug("Set campfire violetFlames=true")
        end

        -- Update the campfire layer
        if nearest.layer == nil and layer ~= nil and nearest.mapID == mapID then
            nearest.layer = layer
            self:ApplyAppearance()
            addon.PrintDebug("Set campfire layer=%s", layer)
        end

        if entry.profession == "Cooking" then return nearest end

        -- Get the camp objects for this pin and add/update the list with this object
        nearest.objects = nearest.objects or {}
        local objects = nearest.objects
        for index, code in ipairs(objects) do
            if addon.campObjectsByCode[code].profession == entry.profession then
                if code ~= entry.code then
                    objects[index] = entry.code
                end
                return nearest
            end
        end

        -- Add the new camp object
        objects[#objects + 1] = entry.code
        addon.PrintDebug("Found %s (%s)", entry.name, entry.code)

        -- Truncate the list of objects if it is longer than the limit for this campfire
        if #objects > CAMPFIRE_OBJECT_LIMITS[nearest.tier] then
            table.remove(objects, 1)
        end
    end

    return nearest
end

---Returns a formatted string for the pins object count, e.g. "(2/3)"
---@param pin table # the campfire pin
---@return string
function pins.FormatObjectCount(pin)
    return ("(%d/%d)"):format(pin.objects and #pin.objects or 0, CAMPFIRE_OBJECT_LIMITS[pin.tier])
end

-- Render the tooltip for a map pin
local function RenderPinTooltip(pin)
    local remaining = math.max(0, pin.expires - GetServerTime())
    local objects = pin.objects
    GameTooltip:ClearLines()
    GameTooltip:AddDoubleLine("|cffff8000CozyFire|r", pins.FormatObjectCount(pin), 1, 1, 1, 0.6, 0.6, 0.6)

    if pin.violetFlames then
        GameTooltip:AddLine("|cffb469ffViolet Flames|r |cff999999(2 hour buffs)|r")
    end

    -- Add the camp objects to the tooltip
    if objects then
        for _, code in ipairs(objects) do
            local object = addon.campObjectsByCode[code]
            local text = object.name
            -- For the Camp Chair the placed object is just "Chair"
            if text == "Chair" then
                text = "Camp Chair"
            end
            -- Prepend the icon if defined
            if object.icon then
                text = ("|T%s:18:18|t |cffffc44d%s|r"):format(object.icon, text)
            end
            if object.buffTip then
                text = text .. (" |cff999999(%s)|r"):format(object.buffTip)
            end
            GameTooltip:AddLine(text, 1, 1, 1, true)
        end
        GameTooltip:AddLine(" ")
    end

    -- Remaining time is approximate unless a CozyFire user placed the campfire
    local remainingTime = "|cff6eb2ea" .. SecondsToTime(remaining) .. "|r"
    if pin.approximateTime then
        GameTooltip:AddLine("Less than " .. remainingTime .. " remaining", 1, 1, 1)
    else
        GameTooltip:AddLine(remainingTime .. " remaining", 1, 1, 1)
    end

    -- Manually placed pins have an approximate location
    if pin.approximateLocation then
        GameTooltip:AddLine("Location is approximate", 1, 1, 1)
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
            addon.PrintDebug("tooltip no longer owned by this pin")
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

---Create a pin representing a campfire on the map
---@param pin table
local function CreatePin(pin)
    pin.shared = pin.shared == true
    pin.tier = (pin.tier == 2 or pin.tier == 3) and pin.tier or 1
    pin.violetFlames = pin.violetFlames == true or nil

    -- Objects are the camp fixtures that provide buffs
    pin.objects = type(pin.objects) == "table" and pin.objects or nil
    if pin.objects then
        for index = #pin.objects, 1, -1 do
            local object = addon.campObjectsByCode[pin.objects[index]]
            if not object or object.profession == "Cooking" then
                table.remove(pin.objects, index)
            end
        end
        while #pin.objects > CAMPFIRE_OBJECT_LIMITS[pin.tier] do
            table.remove(pin.objects, 1)
        end
    end

    pin.worldIcon = CreateIcon(addon.PIN_SIZE_WORLDMAP)
    pin.miniIcon = CreateIcon(addon.PIN_SIZE_MINIMAP)

    -- PIN_FRAME_LEVEL_TOPMOST draws the world map pin above the player arrow
    HBDPins:AddWorldMapIconWorld(addonName, pin.worldIcon, pin.instanceID, pin.x, pin.y, HBD_PINS_WORLDMAP_SHOW_PARENT, "PIN_FRAME_LEVEL_TOPMOST")
    HBDPins:AddMinimapIconWorld(addonName, pin.miniIcon, pin.instanceID, pin.x, pin.y, false)

    active[nextId] = pin
    nextId = nextId + 1

    pin.worldIcon.pin = pin
    pin.worldIcon:EnableMouse(true)
    pin.worldIcon:SetScript("OnEnter", ShowPinTooltip)
    pin.worldIcon:SetScript("OnLeave", HidePinTooltip)

    pins:ApplyAppearance()
end

---Reapplies texture, layer visibility, and world map settings to every pin
function pins:ApplyAppearance()
    for _, pin in pairs(active) do
        ApplyPinAppearance(pin)
    end
end

-- Add a campfire pin at world coordinates. `approximateLocation` is true for manual marks and false when the
-- player gains the "Welcoming Campfire" buff. `approximateTime` is false when the player places the campfire,
-- and true otherwise. `layer` is the zoneUID of the layer the fire was seen on, if known.
-- Returns action ("created"/"replaced"/"exists") for local pins, plus the pin when created or replaced
local function AddPin(data, source)
    if not data.instanceID or not data.x or not data.y then return end

    local isLocal = source == "local"
    local existingId, existing = FindNearby(data.instanceID, data.x, data.y, data.layer, data.mapID)

    -- Remove the existing pin if expired
    if existing and existing.expires <= GetServerTime() then
        pins:RemovePin(existingId)
        existing = nil
    end

    -- zoneUIDs differ per map, so only carry layers between pins on the same map
    local existingLayer = existing and existing.mapID == data.mapID and existing.layer or nil

    local replaceExisting = false
    if existing then
        if isLocal then
            data.layer = data.layer or existingLayer

            -- Placing a campfire replaces any nearby pins
            local isPlacement = not data.approximateLocation and not data.approximateTime
            local improvesLocation = not data.approximateLocation and existing.approximateLocation
            replaceExisting = isPlacement or improvesLocation

            -- Sitting at a campfire replaces nearby approximate pins, but retains their original expiration time
            if replaceExisting and not isPlacement then
                data.expires = existing.expires
                data.approximateTime = existing.approximateTime
                data.tier = existing.tier
                data.objects = existing.objects
                data.violetFlames = data.violetFlames or existing.violetFlames
            end
        elseif not existing.approximateTime and not data.approximateTime then
            -- Ignore reports for older fires in this location
            if data.expires < existing.expires then return end

            -- Remove the current pin if this report is a new fire
            if data.expires > existing.expires then
                data.layer = data.layer or existingLayer
                replaceExisting = true
            end
        end
    end

    if existing and not replaceExisting then
        local upgradeLocation = not isLocal and existing.approximateLocation and not data.approximateLocation
        local upgradeLayer = existing.mapID == data.mapID and existing.layer == nil and data.layer ~= nil

        if data.violetFlames == true and not existing.violetFlames then
            existing.violetFlames = true
            ApplyPinAppearance(existing)
        end

        if not isLocal then
            if upgradeLocation then
                existing.x, existing.y = data.x, data.y
                existing.approximateLocation = false
                HBDPins:RemoveWorldMapIcon(addonName, existing.worldIcon)
                HBDPins:AddWorldMapIconWorld(addonName, existing.worldIcon, data.instanceID, data.x, data.y, HBD_PINS_WORLDMAP_SHOW_PARENT, "PIN_FRAME_LEVEL_TOPMOST")
                HBDPins:AddMinimapIconWorld(addonName, existing.miniIcon, data.instanceID, data.x, data.y, false)
            end

            if existing.approximateTime then
                if not data.approximateTime then
                    existing.expires = data.expires
                    existing.approximateTime = false
                else
                    existing.expires = math.min(existing.expires, data.expires)
                end
            end

        end

        -- Upgrade the existing pin's unknown layer to a known layer
        if upgradeLayer then
            existing.layer = data.layer
            addon.PrintDebug("Upgraded pin to known layer: %s", data.layer)
        end

        if upgradeLocation or upgradeLayer then
            pins:ApplyAppearance()
        end

        if isLocal then
            return "exists"
        end

        addon.PrintDebug("Pin received is |cff6eb2eaalready known|r")

        return
    end

    if replaceExisting then
        pins:RemovePin(existingId)
    end

    data.shared = not isLocal
    CreatePin(data)
    if isLocal then
        return replaceExisting and "replaced" or "created", data
    end
end

-- Add a pin at the player's position for a locally marked campfire
function pins:AddLocalPin(approximateLocation, approximateTime, layer, tier, violetFlames)
    local x, y, instanceID = HBD:GetPlayerWorldPosition()
    return AddPin({
        instanceID = instanceID,
        x = x,
        y = y,
        mapID = C_Map.GetBestMapForUnit("player"),
        expires = GetServerTime() + addon.PIN_TTL,
        approximateLocation = approximateLocation,
        approximateTime = approximateTime,
        layer = layer,
        tier = tier,
        violetFlames = violetFlames or addon.PlayerHasVioletFlames(),
    }, "local")
end

---Adds (or updates) a pin received via addon comms
---@param data table # deserialized pin from comms
function pins:AddSharedPin(data)
    AddPin(data, "shared")
end

---Removes a pin from the map
---@param id number
function pins:RemovePin(id)
    local pin = active[id]
    if not pin then return end

    -- Hide the tooltip for this pin
    if GameTooltip:GetOwner() == pin.worldIcon then
        HidePinTooltip(pin.worldIcon)
    end

    HBDPins:RemoveWorldMapIcon(addonName, pin.worldIcon)
    HBDPins:RemoveMinimapIcon(addonName, pin.miniIcon)
    pin.worldIcon.pin = nil
    active[id] = nil

    -- A covered other-layer fire may now be shown
    pins:ApplyAppearance()
end

C_Timer.NewTicker(SWEEP_INTERVAL, function()
    local now = GetServerTime()

    -- When not in combat, and not on a flight path, check for nearby campfire pins to cleanup
    local px, py, pInstance, nearCampfire
    if not InCombatLockdown() and not UnitOnTaxi("player") then
        px, py, pInstance = HBD:GetPlayerWorldPosition()
        nearCampfire = addon.PlayerNearCampfire()
    end
    local currentLayer = addon.GetLayer()

    for id, pin in pairs(active) do
        local expired = now >= pin.expires

        -- Only campfires on our current layer that we are in close proximity to are considered for removal
        if not expired and nearCampfire == false and pin.instanceID == pInstance
            and currentLayer and pin.layer == currentLayer then
            local dist = HBD:GetWorldDistance(pInstance, px, py, pin.x, pin.y)
            if dist and dist <= 20 then
                addon.Print("Nearby campfire not found, removed from map.")
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
            layer = pin.layer,
            mapID = pin.mapID,
            shared = pin.shared,
            tier = pin.tier,
            objects = pin.objects,
            violetFlames = pin.violetFlames,
        }
    end
    CozyFireDB.pins = saved
end

---Restores pins from saved variables
---@param isInitialLogin boolean # zoneUIDs are per-session
function pins:Restore(isInitialLogin)
    local saved = CozyFireDB and CozyFireDB.pins
    if not saved then return end

    addon.PrintDebug("Considering %s pins for restoration, isInitialLogin: %s", #saved, tostring(isInitialLogin))
    local now = GetServerTime()
    for _, pin in ipairs(saved) do
        if pin.expires > now then
            if isInitialLogin then
                pin.layer = nil
            end
            CreatePin(pin)

            --@debug@
            local mapInfo = C_Map.GetMapInfo(pin.mapID or 0)
            addon.PrintDebug("Restored pin in |cff6eb2ea%s|r", mapInfo and mapInfo.name)
            --@end-debug@
        end
    end
end

-- Save pins to saved variables on logout and restore them on login
-- This also covers reloading the UI
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", function(self, event, isInitialLogin)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        pins:Restore(isInitialLogin)
    else
        pins:Save()
    end
end)
