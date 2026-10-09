local addonName, addon = ...
local campObjects = addon.campObjects

local SHARED_CAMP_OBJECTS = {
    ["Anvil"] = true,
}

local function AddCampingDetails(tooltip, data)
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
    if not InCombatLockdown() and addon.IsNearCampfire and not addon.IsNearCampfire() and SHARED_CAMP_OBJECTS[objectName] then
        return
    end

    -- The perk is displayed in light blue text immediately after the object name
    if entry.perk then
        tooltip:AddLine(entry.perk, 0.4, 0.65, 0.95, true)
    end

    -- The buff provided is displayed in green text, if Shift is held all level ranges are shown
    if entry.buff then
        tooltip:AddLine(" ")
        for _, line in ipairs(addon.GetCampObjectBuffLines(entry, IsShiftKeyDown())) do
            if line.isCurrent then
                tooltip:AddLine(line.text, 0.25, 1, 0.25, true)
            else
                tooltip:AddLine(line.text, 0.65, 0.65, 0.65, true)
            end
        end

        -- The exclusivity information is displayed in red and white text immediately after the buff
        if entry.buffExclusiveWith then
            tooltip:AddLine("|cffff8080Exclusive with: |r" .. entry.buffExclusiveWith, 1, 1, 1, true)
        end
    end

    -- Show the profession, and required skill (if defined)
    tooltip:AddLine(" ")
    local profession = entry.profession
    if entry.requiredSkill then
        profession = profession .. " (" .. entry.requiredSkill .. ")"
    end
    tooltip:AddLine(profession, 0.5, 0.5, 0.5, true)
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, AddCampingDetails)
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddCampingDetails)

-- Rebuild the active tooltip when Shift is pressed or released
local shiftWatcher = CreateFrame("Frame")
shiftWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
shiftWatcher:SetScript("OnEvent", function(_, _, key)
    if (key == "LSHIFT" or key == "RSHIFT") and GameTooltip:IsShown() then
        GameTooltip:RefreshData()
    end
end)
