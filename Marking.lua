---@class CozyFire
local addon = select(2, ...)

local HBD = LibStub("HereBeDragons-2.0")
local CAMPFIRE_SPELLS = {
    [1229739] = true,  -- Welcoming Campfire
    [1289723] = true,  -- Welcoming Campfire
}
local CAMPFIRE_KIT_SPELLS = {
    [1307227] = 1,  -- Basic Campfire Kit
    [1307252] = 2,  -- Journeyman Campfire Kit
    [1307237] = 3,  -- Expert Campfire Kit
}

---Marks and shares a nearby campfire on the map
local function MarkCampfire()
    -- Aura data is a restricted/secret value in combat (Patch 12.0+), so we can't read the buff
    if InCombatLockdown() then
        addon.Print("Campfires can't be marked while in combat.")
        return
    end

    if not addon.PlayerNearCampfire() then
        addon.Print("No nearby campfire found.")
        return
    end

    local x, y, instanceID = HBD:GetPlayerWorldPosition()
    if not x or not y then
        addon.Print("Couldn't determine your position.")
        return
    end

    local _, action, pin = addon.pins:AddLocalPin(instanceID, x, y, true, true, addon.GetLayer())
    if action == "created" or action == "replaced" then
        addon.Print("Campfire marked.")
        addon.BroadcastPin(pin)
    elseif action == "exists" then
        addon.Print("Campfire is already marked.")
    end
end
addon.MarkCampfire = MarkCampfire

SLASH_COZYFIRE1 = "/cf"
SLASH_COZYFIRE2 = "/cozyfire"
SlashCmdList["COZYFIRE"] = function(msg)
    local cmd = msg:lower():match("^%s*(%S*)")
    if cmd == "mark" then
        addon.MarkCampfire()
    elseif cmd == "options" or cmd == "config" then
        addon.OpenOptions()
    else
        addon.Print("Commands: /cf mark, /cf options")
    end
end

-- Auto-mark whenever the Welcoming Campfire buff is gained if the player is near a campfire
local function AutoMark()
    if InCombatLockdown() then
        return
    end

    if not addon.PlayerNearCampfire() then
        return
    end

    local x, y, instanceID = HBD:GetPlayerWorldPosition()
    if not x or not y then
        return
    end

    local _, action, pin = addon.pins:AddLocalPin(instanceID, x, y, false, true, addon.GetLayer())
    if action == "created" or action == "replaced" then
        addon.Print("Campfire automatically marked.")
        addon.BroadcastPin(pin)
    end
end

-- Create a frame to listen for aura changes on the player
local auraFrame = CreateFrame("Frame")
auraFrame:RegisterUnitEvent("UNIT_AURA", "player")
auraFrame:SetScript("OnEvent", function(_, _, _, updateInfo)
    if not updateInfo or not updateInfo.addedAuras then
        return
    end
    -- addedAuras is a secret table in combat and can't be iterated; we can't mark in combat anyway
    if issecretvalue and issecretvalue(updateInfo.addedAuras) then
        return
    end
    for _, aura in ipairs(updateInfo.addedAuras) do
        local spellId = aura and aura.spellId
        if spellId and not (issecretvalue and issecretvalue(spellId)) and CAMPFIRE_SPELLS[spellId] then
            AutoMark()
            return
        end
    end
end)

-- Mark the campfire when the player uses a campfire kit
local function CampfirePlaced(castGUID, tier)
    if InCombatLockdown() then
        return
    end

    local x, y, instanceID = HBD:GetPlayerWorldPosition()
    if not x or not y then
        return
    end

    -- The cast GUID carries the exact layer the fire was lit on; fall back to the tracked layer
    local layer = addon.GetLayerFromGUID(castGUID) or addon.GetLayer()

    local _, action, pin = addon.pins:AddLocalPin(instanceID, x, y, false, false, layer)
    if action == "created" or action == "replaced" then
        pin.tier = tier
        addon.Print("Campfire marked.")
        addon.BroadcastPin(pin)
    end
end

-- Create a frame to listen for spell casts
local castFrame = CreateFrame("Frame")
castFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
castFrame:SetScript("OnEvent", function(_, _, _, castGUID, spellID)
    local tier = spellID and CAMPFIRE_KIT_SPELLS[spellID]
    if tier then
        CampfirePlaced(castGUID, tier)
    end
end)
