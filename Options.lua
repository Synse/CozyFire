local addonName, addon = ...

local category = Settings.RegisterVerticalLayoutCategory(addonName)
Settings.RegisterAddOnCategory(category)
addon.optionsCategory = category

function addon.OpenOptions()
    Settings.OpenToCategory(category:GetID())
end
