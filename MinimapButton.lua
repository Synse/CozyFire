local addonName = ...
---@class CozyFire
local addon = select(2, ...)

local ICON_TEXTURE = "Interface\\AddOns\\CozyFire\\Media\\CozyFire.tga"

---Emotes that trigger the "Welcoming Campfire" buff
addon.CAMPING_EMOTES = {
    { name = "KNEEL", command = "/kneel" },
    { name = "LAYDOWN", command = "/lay" },
    { name = "SIT", command = "/sit" },
    { name = "SLEEP", command = "/sleep" },
}

local EMOTE_COMMANDS = {}
for _, emote in ipairs(addon.CAMPING_EMOTES) do
    EMOTE_COMMANDS[emote.name] = emote.command
end

-- Create the minimap button
local dataObject = LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
    type = "data source",
    text = "CozyFire",
    icon = ICON_TEXTURE,
    OnClick = function(_, mouseButton)
        if mouseButton == "LeftButton" then
            if not InCombatLockdown() and addon.PlayerNearCampfire() then
                if IsShiftKeyDown() then
                    addon.MarkCampfire()
                end
                C_ChatInfo.PerformEmote(CozyFireDB.minimapEmote, nil, true)
            else
                addon.Print("No nearby campfire found.")
            end
        elseif mouseButton == "RightButton" then
            addon.OpenOptions()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("CozyFire")
        tooltip:AddLine("|cffffbf00Left-click|r to |cff6eb2ea" .. EMOTE_COMMANDS[CozyFireDB.minimapEmote] .. "|r at a campfire", 1, 1, 1)
        tooltip:AddLine("|cffffbf00Right-click|r for options", 1, 1, 1)
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
    CozyFireDB.minimap.minimapPos = CozyFireDB.minimap.minimapPos or 245
    CozyFireDB.minimapEmote = CozyFireDB.minimapEmote or "SIT"

    DBIcon:Register(addonName, dataObject, CozyFireDB.minimap)
end)
