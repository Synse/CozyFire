---@class CozyFire
local addon = select(2, ...)

local CAMPFIRE_NEARBY_SPELL = 1283391  -- "Campfire Nearby" aura, 100-yard radius
local VIOLET_FLAMES_SPELL = 1328375  -- "Violet Flames" aura

---Prints a chat message with the CozyFire prefix
---@param msg string
function addon.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8000CozyFire:|r " .. msg)
end

---Prints a formatted chat message with the CozyFireDebug prefix (no-op in release builds)
---@param fmt string
---@param ... any
function addon.PrintDebug(fmt, ...)
    --@debug@
    DEFAULT_CHAT_FRAME:AddMessage("|cffffc44dCozyFireDebug:|r " .. fmt:format(...))
    --@end-debug@
end

---Checks for the "Violet Flames" aura from the "Pouch of Violet Dust" toy
---@return boolean? # nil in combat
function addon.PlayerHasVioletFlames()
    if not InCombatLockdown() and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        return C_UnitAuras.GetPlayerAuraBySpellID(VIOLET_FLAMES_SPELL) ~= nil
    end
end

---Checks for the "Campfire Nearby" aura (100-yard radius)
---@return boolean? # nil if unknown
function addon.PlayerNearCampfire()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        return C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_NEARBY_SPELL) ~= nil
    end

    return nil
end
