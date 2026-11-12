local addonName = ...
---@class CozyFire
local addon = select(2, ...)

local DBIcon = LibStub("LibDBIcon-1.0")

-- Create the CozyFire category
local category, layout = Settings.RegisterVerticalLayoutCategory(addonName)
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
        showWorldMap = Settings.RegisterProxySetting(category, "CozyFire_ShowWorldMapPins",
            Settings.VarType.Boolean, "Show campfires on world map", true,
            function() return not CozyFireDB.hideWorldMapPins end,
            function(value)
                CozyFireDB.hideWorldMapPins = not value
                addon.pins:ApplyAppearance()
            end),
        worldMapPinSize = Settings.RegisterProxySetting(category, "CozyFire_WorldMapPinSize",
            Settings.VarType.Number, "World map icon size", addon.WORLDMAP_PIN_SIZE,
            function() return CozyFireDB.worldMapPinSize or addon.WORLDMAP_PIN_SIZE end,
            function(value)
                CozyFireDB.worldMapPinSize = value
                addon.pins:ApplyAppearance()
            end),
        showMinimapPins = Settings.RegisterProxySetting(category, "CozyFire_ShowMinimapPins",
            Settings.VarType.Boolean, "Show campfires on minimap", true,
            function() return not CozyFireDB.hideMinimapPins end,
            function(value)
                CozyFireDB.hideMinimapPins = not value
                addon.pins:ApplyAppearance()
            end),
        minimapPinSize = Settings.RegisterProxySetting(category, "CozyFire_MinimapPinSize",
            Settings.VarType.Number, "Minimap icon size", addon.MINIMAP_PIN_SIZE,
            function() return CozyFireDB.minimapPinSize or addon.MINIMAP_PIN_SIZE end,
            function(value)
                CozyFireDB.minimapPinSize = value
                addon.pins:ApplyAppearance()
            end),
    }
end

-- Layout: the controls shown on the options page
local function BuildLayout(settings)
    Settings.CreateCheckbox(category, settings.showMinimap, "Show the CozyFire button on the minimap.")

    local sizeOptions = Settings.CreateSliderOptions(16, 30, 2)
    sizeOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    layout:AddInitializer(CreateSettingsCheckboxSliderInitializer(
        settings.showWorldMap, "Show campfires on world map", "Show campfire pins on the world map.",
        settings.worldMapPinSize, sizeOptions, "World map icon size", "Size of campfire pins on the world map."))
    layout:AddInitializer(CreateSettingsCheckboxSliderInitializer(
        settings.showMinimapPins, "Show campfires on minimap", "Show campfire pins on the minimap.",
        settings.minimapPinSize, sizeOptions, "Minimap icon size", "Size of campfire pins on the minimap."))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    BuildLayout(RegisterSettings())
end)
