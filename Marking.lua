---@class CozyFire
local addon = select(2, ...)

local CAMPFIRE_SPELLS = {
    [1229739] = true,  -- Welcoming Campfire
    [1289723] = true,  -- Welcoming Campfire
}
local VIOLET_DUST_SPELL = 1328348  -- Throw Violet Dust (Pouch of Violet Dust)
local CAMPFIRE_KIT_SPELLS = {
    [1307227] = 1,  -- Basic Campfire Kit
    [1307252] = 2,  -- Journeyman Campfire Kit
    [1307237] = 3,  -- Expert Campfire Kit
}

---Marks and shares a nearby campfire on the map
---@param auto boolean? # true when triggered by the Welcoming Campfire buff; exact location and only reports success
local function MarkCampfire(auto)
    local message
    -- Aura data is a restricted/secret value in combat (Patch 12.0+), so we can't read the buff
    if InCombatLockdown() then
        message = "Campfires can't be marked while in combat."
    elseif UnitOnTaxi("player") then
        message = "Campfires can't be marked while on a flight path."
    elseif not addon.PlayerNearCampfire() then
        message = "No nearby campfire found."
    else
        local action, pin = addon.pins:AddLocalPin(not auto, true, addon.GetLayer())
        if action == "created" or action == "replaced" then
            addon.Print("Campfire marked.")
            addon.BroadcastPin(pin)
            return
        end
        message = action == "exists" and "Campfire is already marked." or "Couldn't determine your position."
    end

    if not auto then
        addon.Print(message)
    end
end
addon.MarkCampfire = MarkCampfire

SLASH_COZYFIRE1 = "/cf"
SLASH_COZYFIRE2 = "/cozyfire"
SlashCmdList["COZYFIRE"] = function(msg)
    local cmd = msg:lower():match("^%s*(%S*)")
    if cmd == "mark" then
        MarkCampfire()
    elseif cmd == "options" or cmd == "config" then
        addon.OpenOptions()
    else
        addon.Print("Commands: /cf mark, /cf options")
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
    if issecretvalue(updateInfo.addedAuras) then
        return
    end
    for _, aura in ipairs(updateInfo.addedAuras) do
        local spellId = aura and aura.spellId
        if spellId and not issecretvalue(spellId) and CAMPFIRE_SPELLS[spellId] then
            MarkCampfire(true)
            return
        end
    end
end)

-- Mark the campfire when the player uses a campfire kit, or Pouch of Violet Dust
local function CampfireCast(castGUID, tier, violetDust)
    if InCombatLockdown() then
        return
    end

    -- The cast GUID carries the exact layer the fire was lit on; fall back to the tracked layer
    local layer = addon.GetLayerFromGUID(castGUID) or addon.GetLayer()

    local action, pin = addon.pins:AddLocalPin(false, violetDust, layer, tier, violetDust)
    if action == "created" or action == "replaced" then
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
        CampfireCast(castGUID, tier, false)
    elseif spellID == VIOLET_DUST_SPELL then
        CampfireCast(castGUID, nil, true)
    end
end)
