local addonName, addon = ...

function addon.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8000CozyFire:|r " .. msg)
end
