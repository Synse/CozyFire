local addonName = ...
---@class CozyFire
local addon = select(2, ...)

local DBIcon = LibStub("LibDBIcon-1.0")

-- A canvas keeps our controls out of the shared Settings list frames and search, which taint
-- Blizzard settings when they run addon code (Stanzilla/WoWUIBugs#873, Synse/CozyFire#1)
local panel = CreateFrame("Frame")
local category = Settings.RegisterCanvasLayoutCategory(panel, addonName)
Settings.RegisterAddOnCategory(category)

function addon.OpenOptions()
    Settings.OpenToCategory(category:GetID())
end

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(addonName)

local refreshers = {}
local function Refresh()
    for _, refresh in ipairs(refreshers) do
        refresh()
    end
end
panel:SetScript("OnShow", Refresh)

-- Adds a row label and returns the vertical offset for the row's control
local nextY = -56
local function AddRow(label)
    local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 32, nextY - 6)
    text:SetText(label)
    local y = nextY
    nextY = nextY - 36
    return y
end

local function AddCheckbox(label, get, set)
    local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", 260, AddRow(label))
    checkbox:SetScript("OnClick", function(self)
        set(self:GetChecked())
        Refresh()
    end)
    refreshers[#refreshers + 1] = function() checkbox:SetChecked(get()) end
    return checkbox
end

-- Pin size slider beside its checkbox, only enabled while checked
local function AddSizeSlider(get, set, checkbox)
    local slider = CreateFrame("Frame", nil, panel, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
    slider:SetWidth(250)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value) set(value) end, panel)
    refreshers[#refreshers + 1] = function()
        slider:Init(get(), 16, 30, 7, { [MinimalSliderWithSteppersMixin.Label.Right] = tostring })
        slider:SetEnabled(checkbox:GetChecked())
    end
end

AddCheckbox("Show minimap button",
    function() return not CozyFireDB.minimap.hide end,
    function(value)
        CozyFireDB.minimap.hide = not value
        if value then DBIcon:Show(addonName) else DBIcon:Hide(addonName) end
    end)

local emoteDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
emoteDropdown:SetPoint("TOPLEFT", 264, AddRow("Minimap button emote"))
emoteDropdown:SetWidth(200)
local function SetupEmoteMenu(_, rootDescription)
    for _, emote in ipairs(addon.CAMPING_EMOTES) do
        rootDescription:CreateRadio(emote.command,
            function() return CozyFireDB.minimapEmote == emote.name end,
            function() CozyFireDB.minimapEmote = emote.name end)
    end
end

-- SetupMenu reads CozyFireDB immediately, which isn't loaded yet in the main chunk
refreshers[#refreshers + 1] = function() emoteDropdown:SetupMenu(SetupEmoteMenu) end

local showWorldMap = AddCheckbox("Show campfires on world map",
    function() return not CozyFireDB.hideWorldMapPins end,
    function(value)
        CozyFireDB.hideWorldMapPins = not value
        addon.pins:ApplyAppearance()
    end)
AddSizeSlider(
    function() return CozyFireDB.worldMapPinSize or addon.PIN_SIZE_WORLDMAP end,
    function(value)
        CozyFireDB.worldMapPinSize = value
        addon.pins:ApplyAppearance()
    end,
    showWorldMap)

local showMinimapPins = AddCheckbox("Show campfires on minimap",
    function() return not CozyFireDB.hideMinimapPins end,
    function(value)
        CozyFireDB.hideMinimapPins = not value
        addon.pins:ApplyAppearance()
    end)
AddSizeSlider(
    function() return CozyFireDB.minimapPinSize or addon.PIN_SIZE_MINIMAP end,
    function(value)
        CozyFireDB.minimapPinSize = value
        addon.pins:ApplyAppearance()
    end,
    showMinimapPins)
