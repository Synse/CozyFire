local addonName, addon = ...

local PREFIX = "CozyFire"
local MSG_TYPE = "CF1"   -- payload version; bump when the format below changes
local MAX_TTL = 900      -- limit shared pin lifetimes to 15 minutes

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

-- Remove escape sequences and limit the length to prevent markup injection in tooltips
local function Sanitize(name)
    if type(name) ~= "string" or name == "" then return nil end

    name = name:gsub("|", "")
    if name == "" then return nil end

    return name:sub(1, 48)
end

-- Serialize a pin for broadcast
local function Serialize(pin)
    local remaining = math.ceil((pin.expires or 0) - GetServerTime())
    if remaining <= 0 then return nil end

    return table.concat({
        MSG_TYPE,
        pin.instanceID or "",
        math.floor(pin.x or 0),
        math.floor(pin.y or 0),
        pin.approximateLocation and 1 or 0,
        pin.approximateTime and 1 or 0,
        remaining,
        pin.mapID or "",
        pin.layer or "",
        pin.placedBy or "",
    }, ":")
end

-- Deserialize an incoming pin and validate it
local function Deserialize(text)
    local msgType, rawInstance, rawX, rawY, aLoc, aTime, rawRemaining, rawMap, rawLayer, placedBy = strsplit(":", text or "")
    if msgType ~= MSG_TYPE then return nil end

    local instanceID = tonumber(rawInstance)
    local x = tonumber(rawX)
    local y = tonumber(rawY)
    local remaining = tonumber(rawRemaining)

    if not instanceID or not x or not y or not remaining then return nil end
    if instanceID < 0 or math.abs(x) > 100000 or math.abs(y) > 100000 then return nil end
    if remaining <= 0 or remaining > MAX_TTL then return nil end

    return {
        instanceID = instanceID,
        x = x,
        y = y,
        approximateLocation = aLoc == "1",
        approximateTime = aTime == "1",
        remaining = remaining,
        mapID = tonumber(rawMap),
        layer = tonumber(rawLayer),
        placedBy = Sanitize(placedBy),
    }
end

local function GroupChannel()
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
end

-- Broadcast a pin to guild and group channels
function addon.BroadcastPin(pin)
    local msg = Serialize(pin)
    if not msg then return end

    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(PREFIX, msg, "GUILD")
    end

    local group = GroupChannel()
    if group then
        C_ChatInfo.SendAddonMessage(PREFIX, msg, group)
    end
end

local function PlayerName()
    local firstName, lastName = UnitName("player")
    if lastName and lastName ~= "" then
        return firstName .. " " .. lastName
    end
    return firstName
end

local function IsSelf(sender)
    return sender and Ambiguate(sender, "none") == PlayerName()
end

-- Frame to listen for incoming addon messages
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, _, prefix, text, _, sender)
    if prefix ~= PREFIX or IsSelf(sender) then return end

    local data = Deserialize(text)
    if data then
        addon.pins:AddSharedPin(data)
    end
end)
