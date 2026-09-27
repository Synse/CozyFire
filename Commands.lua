local addonName, addon = ...

local HBD = LibStub("HereBeDragons-2.0")
local CAMPFIRE_NEARBY_SPELL = 1283391  -- "Campfire Nearby" aura, 100-yard radius
local WELCOMING_CAMPFIRE_SPELLS = {
    [1229739] = true,
    [1289723] = true,
}

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

    local _, action = addon.pins:AddPin(instanceID, x, y, "Campfire", true)
    if action == "created" then
        Print("Campfire marked.")
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

-- Auto-mark whenever the Welcoming Campfire buff is gained
local function AutoMark()
    if InCombatLockdown() then
        return
    end

    local x, y, instanceID = HBD:GetPlayerWorldPosition()
    if not x or not y then
        return
    end

    local _, action = addon.pins:AddPin(instanceID, x, y, "Campfire", false)
    if action == "created" then
        Print("Campfire automatically marked.")
    end
end

-- Create a frame to listen for aura changes on the player
local auraFrame = CreateFrame("Frame")
auraFrame:RegisterUnitEvent("UNIT_AURA", "player")
auraFrame:SetScript("OnEvent", function(_, _, _, updateInfo)
    if not updateInfo or not updateInfo.addedAuras then
        return
    end
    for _, aura in ipairs(updateInfo.addedAuras) do
        local spellId = aura and aura.spellId
        if spellId and not (issecretvalue and issecretvalue(spellId)) and WELCOMING_CAMPFIRE_SPELLS[spellId] then
            AutoMark()
            return
        end
    end
end)
