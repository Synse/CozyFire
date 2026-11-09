local addonName, addon = ...

local DBIcon = LibStub("LibDBIcon-1.0")

-- Create the CozyFire category
local category = Settings.RegisterVerticalLayoutCategory(addonName)
Settings.RegisterAddOnCategory(category)

function addon.OpenOptions()
    Settings.OpenToCategory(category:GetID())
end

-- Settings: what each option reads and writes
local function RegisterSettings()
    return {
        showMinimap = Settings.RegisterProxySetting(category, "CozyFire_ShowMinimapButton",
            Settings.VarType.Boolean, "Show minimap button", true,
            function() return not CozyFireDB.minimap.hide end,
            function(value)
                CozyFireDB.minimap.hide = not value
                if value then DBIcon:Show(addonName) else DBIcon:Hide(addonName) end
            end),
    }
end

-- Layout: the controls shown on the options page
local function BuildLayout(settings)
    Settings.CreateCheckbox(category, settings.showMinimap, "Show the CozyFire button on the minimap.")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    BuildLayout(RegisterSettings())
end)
