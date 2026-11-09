local addonName, addon = ...

local CAMPFIRE_NEARBY_SPELL = 1283391  -- "Campfire Nearby" aura, 100-yard radius
local VIOLET_FLAMES_SPELL = 1328375  -- "Violet Flames" aura

function addon.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8000CozyFire:|r " .. msg)
end

-- Determine if the player has the "Violet Flames" aura from the "Pouch of Violet Dust" toy
function addon.PlayerHasVioletFlames()
    if not InCombatLockdown() and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        return C_UnitAuras.GetPlayerAuraBySpellID(VIOLET_FLAMES_SPELL) ~= nil
    end
end

-- Determine if the player is near a campfire, returns nil if unknown
function addon.PlayerNearCampfire()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        return C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_NEARBY_SPELL) ~= nil
    end

    return nil
end
