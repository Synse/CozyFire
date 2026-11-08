local addonName, addon = ...

local DBIcon = LibStub("LibDBIcon-1.0")

-- Create the CozyFire category
local category = Settings.RegisterVerticalLayoutCategory(addonName)
Settings.RegisterAddOnCategory(category)

function addon.OpenOptions()
    Settings.OpenToCategory(category:GetID())
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    -- Register a handler for toggling the minimap button
    local showMinimap = Settings.RegisterProxySetting(category, "CozyFire_ShowMinimapButton",
        Settings.VarType.Boolean, "Show minimap button", true,
        function() return not CozyFireDB.minimap.hide end,
        function(value)
            CozyFireDB.minimap.hide = not value
            if value then DBIcon:Show(addonName) else DBIcon:Hide(addonName) end
        end)

    -- Add the minimap button checkbox
    Settings.CreateCheckbox(category, showMinimap, "Show the CozyFire button on the minimap.")
end)
