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

    tooltip:AddLine(" ")
    tooltip:AddLine(entry.buff, 0.25, 1, 0.25, true)
    tooltip:AddLine(entry.profession, 0.6, 0.6, 0.6, true)

    if entry.exclusiveWith then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cffff8080Exclusive with: |r" .. entry.exclusiveWith, 1, 1, 1, true)
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, AddCampingDetails)
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddCampingDetails)
