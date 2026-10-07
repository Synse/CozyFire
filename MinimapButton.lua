local addonName, addon = ...

local ICON_TEXTURE = "Interface\\AddOns\\CozyFire\\Media\\CozyFire.tga"

-- Create the minimap button
local dataObject = LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
    type = "data source",
    text = "CozyFire",
    icon = ICON_TEXTURE,
    OnClick = function(_, mouseButton)
        if mouseButton == "LeftButton" then
            addon.MarkCampfire()
            if addon.IsNearCampfire and addon.IsNearCampfire() then
                C_ChatInfo.PerformEmote("SIT", nil, true)
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("CozyFire")
        tooltip:AddLine("|cffffbf00Left-click|r to |cff6eb2ea/sit|r at a campfire", 1, 1, 1)
    end,
})

local DBIcon = LibStub("LibDBIcon-1.0")

-- Register the minimap button so the button position persists
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    CozyFireDB = CozyFireDB or {}
    CozyFireDB.minimap = CozyFireDB.minimap or {}
    DBIcon:Register(addonName, dataObject, CozyFireDB.minimap)
end)
