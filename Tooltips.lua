local addonName, addon = ...
local campObjects = addon.campObjects

local function AddCampingDetails(tooltip, data)
    local firstLine = data and data.lines and data.lines[1]
    local objectName = firstLine and firstLine.leftText

    -- World-cursor tooltip text can be a secret value (Patch 12.0+) that
    -- cannot index a table; bail before the lookup to avoid a Lua error.
    if not objectName or issecretvalue(objectName) then
        return
    end

    local entry = campObjects[objectName]
    if not entry then
        return
    end

    -- List the perk immediately after the object name
    if entry.perk then
        tooltip:AddLine(entry.perk, 0.4, 0.65, 0.95, true)
    end

    -- Add a blank line for spacing and then list the buff and exclusivity information
    -- followed by the profession at the end
    tooltip:AddLine(" ")
    if entry.buff then
        tooltip:AddLine("|cff40ff40" .. addon.GetCampObjectBuff(entry) .. "|r", 0.7, 0.7, 0.7, true)
    end
    if entry.buffExclusiveWith then
        tooltip:AddLine("|cffff8080Exclusive with: |r" .. entry.buffExclusiveWith, 1, 1, 1, true)
    end
    tooltip:AddLine(entry.profession, 0.6, 0.6, 0.6, true)
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, AddCampingDetails)
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddCampingDetails)
