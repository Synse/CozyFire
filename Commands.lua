local addonName, addon = ...

local HBD = LibStub("HereBeDragons-2.0")
local CAMPFIRE_NEARBY_SPELL = 1283391  -- "Campfire Nearby" aura, 100-yard radius

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8000CozyFire:|r " .. msg)
end

local function PlayerNearCampfire()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        return C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_NEARBY_SPELL) ~= nil
    end
    return true  -- fail open if the aura API is unavailable
end

local function Mark()
    -- Aura data is a restricted/secret value in combat (Patch 12.0+), so we can't read the buff
    if InCombatLockdown() then
        Print("Campfires can't be marked while in combat.")
        return
    end

    if not PlayerNearCampfire() then
        Print("No campfire found.")
        return
    end

    local x, y, instanceID = HBD:GetPlayerWorldPosition()
    if not x or not y then
        Print("Couldn't determine your position.")
        return
    end

    local _, created = addon.pins:AddPin(instanceID, x, y, "Campfire")
    if created then
        Print("Campfire marked.")
    else
        Print("Campfire already marked.")
    end
end

addon.MarkCampfire = Mark

SLASH_COZYFIRE1 = "/cf"
SLASH_COZYFIRE2 = "/cozyfire"
SlashCmdList["COZYFIRE"] = function(msg)
    local cmd = msg:lower():match("^%s*(%S*)")
    if cmd == "mark" then
        Mark()
    else
        Print("Commands: /cf mark")
    end
end
