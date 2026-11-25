---@class CozyFire
local addon = select(2, ...)
local campObjects = addon.campObjects

local SHARED_CAMP_OBJECTS = {
    ["Anvil"] = true,
    ["Chair"] = true,
}
local tooltipHasShiftDetails = false

---Returns a camp object's buff lines, marking the one for the player's current level
---@param buff string|table # the object's buff text, or its level ranges
---@param expand boolean? # include every level range
---@return { text: string, isCurrent: boolean }[]
local function GetBuffLines(buff, expand)
    -- For non-level-dependent buffs, just return the string
    if type(buff) ~= "table" then
        return { { text = buff, isCurrent = true } }
    end

    -- Get the players current level to determine which buff line applies
    local level = UnitLevel("player")
    local currentIndex = 1
    for i, entry in ipairs(buff) do
        if level >= entry.minLevel then
            currentIndex = i
        end
    end

    -- By default, only the currently applicable buff line is returned
    if not expand then
        return { { text = buff[currentIndex].buff, isCurrent = true } }
    end

    -- If expand is true, all level ranges are returned with one marked as the current (active)
    local lines = {}
    for i, entry in ipairs(buff) do
        local nextEntry = buff[i + 1]
        local maxLevel = nextEntry and nextEntry.minLevel - 1 or 60
        local range = entry.minLevel
        if maxLevel ~= entry.minLevel then
            range = range .. "-" .. maxLevel
        end
        lines[i] = { text = entry.buff .. " (" .. range .. ")", isCurrent = i == currentIndex }
    end

    return lines
end

local function AddCampingDetails(tooltip, data)
    if tooltip == GameTooltip then
        tooltipHasShiftDetails = false
    end

    local firstLine = data and data.lines and data.lines[1]
    local objectName = firstLine and firstLine.leftText

    -- World-cursor tooltip text can be a secret value (Patch 12.0+)
    if not objectName or issecretvalue(objectName) then
        return
    end

    -- Do nothing for non-camp objects
    local entry = campObjects[objectName]
    if not entry then
        return
    end

    -- Some camp objects (e.g., Anvil) share a name with other objects
    -- for those objects only show the tooltip if near a campfire
    if SHARED_CAMP_OBJECTS[objectName] and not InCombatLockdown() and not addon.PlayerNearCampfire() then
        return
    end

    -- When mousing over a camp object, update any nearby pins
    local pin
    if tooltip == GameTooltip then
        pin = addon.pins:ObserveCampObject(entry)
        tooltipHasShiftDetails = true
    end

    -- The perk is displayed in light blue text immediately after the object name
    if entry.perk then
        tooltip:AddLine(entry.perk, 0.4, 0.65, 0.95, true)
    end

    -- Add the object count and buffs to the campfire tooltip
    if pin and entry.profession == "Cooking" then
        GameTooltipTextRight1:SetText(addon.pins.FormatObjectCount(pin))
        GameTooltipTextRight1:SetTextColor(0.6, 0.6, 0.6)
        GameTooltipTextRight1:Show()

        for _, code in ipairs(pin.objects or {}) do
            local object = addon.campObjectsByCode[code]
            local icon = object.icon and ("|T%s:18:18|t "):format(object.icon) or ""
            if object.buff then
                tooltip:AddLine(icon .. GetBuffLines(object.buff)[1].text, 0.25, 1, 0.25, true)
            else
                tooltip:AddLine(icon .. object.name, 1, 0.77, 0.3, true)
            end
        end

        -- Remaining time
        tooltip:AddLine(" ")
        tooltip:AddLine(addon.pins.FormatRemainingTime(pin), 1, 1, 1)
    end

    -- The buff provided is displayed in green text, if Shift is held all level ranges are shown
    if entry.buff then
        tooltip:AddLine(" ")
        for _, line in ipairs(GetBuffLines(entry.buff, IsShiftKeyDown())) do
            if line.isCurrent then
                tooltip:AddLine(line.text, 0.25, 1, 0.25, true)
            else
                tooltip:AddLine(line.text, 0.65, 0.65, 0.65, true)
            end
        end
        if entry.buffDetail and IsShiftKeyDown() then
            tooltip:AddLine(entry.buffDetail, 0.65, 0.65, 0.65, true)
        end

        -- The exclusivity information is displayed in red and white text immediately after the buff
        if entry.buffExclusiveWith then
            tooltip:AddLine("|cffff8080Exclusive with: |r" .. entry.buffExclusiveWith, 1, 1, 1, true)
        end
    end

    -- When holding shift, show the profession, and required skill (if defined)
    if IsShiftKeyDown() then
        local profession = entry.profession
        if entry.requiredSkill then
            profession = profession .. " (" .. entry.requiredSkill .. ")"
        end
        tooltip:AddLine(profession, 0.5, 0.5, 0.5, true)
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, AddCampingDetails)
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddCampingDetails)

-- Rebuild the active tooltip when Shift is pressed or released
local shiftWatcher = CreateFrame("Frame")
shiftWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
shiftWatcher:SetScript("OnEvent", function(_, _, key)
    if (key == "LSHIFT" or key == "RSHIFT") and tooltipHasShiftDetails and GameTooltip:IsShown() then
        GameTooltip:RefreshData()
    end
end)
