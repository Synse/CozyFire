local addonName, addon = ...

-- All camp objects by profession
local professions = {
    Alchemy = {
        objects = {
            { name = "Mana Well" },
            { name = "Fermenter" },
            { name = "Alchemy Laboratory" },
        },
        buff = {
            { minLevel = 1,  buff = "+10 Mana every 5 sec" },
            { minLevel = 24, buff = "+15 Mana every 5 sec" },
            { minLevel = 34, buff = "+20 Mana every 5 sec" },
            { minLevel = 44, buff = "+24 Mana every 5 sec" },
            { minLevel = 54, buff = "+29 Mana every 5 sec" },
        },
        buffExclusiveWith = "Blessing of Wisdom",
    },
    Blacksmithing = {
        objects = {
            { name = "Sharpening Wheel" },
        },
        buff = {
            { minLevel = 1,  buff = "+6 Strength" },
            { minLevel = 24, buff = "+11 Strength" },
            { minLevel = 38, buff = "+20 Strength" },
            { minLevel = 52, buff = "+34 Strength" },
        },
        buffExclusiveWith = "Strength of Earth Totem",
    },
    Cooking = {
        objects = {
            { name = "Basic Campfire", perk = "Allows up to 3 camp features" },
            { name = "Journeyman Campfire", perk = "Allows up to 5 camp features" },
        },
    },
    Enchanting = {
        objects = {
            { name = "Enchanted Lute" },
        },
        buff = {
            { minLevel = 1,  buff = "+28 Armor" },
            { minLevel = 10, buff = "+71 Armor, +2 All Stats" },
            { minLevel = 20, buff = "+114 Armor, +4 All Stats" },
            { minLevel = 30, buff = "+163 Armor, +7 All Stats, +6 All Resist" },
            { minLevel = 40, buff = "+211 Armor, +9 All Stats, +12 All Resist" },
            { minLevel = 50, buff = "+260 Armor, +12 All Stats, +16 All Resist" },
            { minLevel = 60, buff = "+308 Armor, +13 All Stats, +22 All Resist" },
        },
        buffExclusiveWith = "Mark of the Wild",
    },
    Engineering = {
        objects = {
            { name = "Reagent Bot", perk = "Purchase Reagents" },
        },
    },
    ["First Aid"] = {
        objects = {
            { name = "First Aid Kit" },
        },
        buff = {
            { minLevel = 1,  buff = "+3 Stamina" },
            { minLevel = 12, buff = "+8 Stamina" },
            { minLevel = 24, buff = "+21 Stamina" },
            { minLevel = 36, buff = "+34 Stamina" },
            { minLevel = 48, buff = "+45 Stamina" },
            { minLevel = 60, buff = "+56 Stamina" },
        },
        buffExclusiveWith = "Power Word: Fortitude",
    },
    Fishing = {
        objects = {
            { name = "Fish Bowl" },
        },
        buff = "+8% All Stats",
        buffExclusiveWith = "Blessing of Kings",
    },
    Herbalism = {
        objects = {
            { name = "Incense Candle" },
        },
        buff = {
            { minLevel = 1,  buff = "+2 Intellect" },
            { minLevel = 14, buff = "+6 Intellect" },
            { minLevel = 28, buff = "+12 Intellect" },
            { minLevel = 42, buff = "+18 Intellect" },
            { minLevel = 56, buff = "+25 Intellect" },
        },
        buffExclusiveWith = "Arcane Intellect",
    },
    Leatherworking = {
        objects = {
            { name = "Camp Tent" },
            { name = "Tanning Rack" },
        },
        buff = "Rested XP up to 5% of a level",
    },
    Mining = {
        objects = {
            { name = "Lodestone" },
        },
        buff = {
            { minLevel = 1,  buff = "+12 Melee Attack Power" },
            { minLevel = 12, buff = "+20 Melee Attack Power" },
            { minLevel = 22, buff = "+32 Melee Attack Power" },
            { minLevel = 32, buff = "+49 Melee Attack Power" },
            { minLevel = 42, buff = "+67 Melee Attack Power" },
            { minLevel = 52, buff = "+90 Melee Attack Power" },
        },
        buffExclusiveWith = "Blessing of Might",
    },
    Skinning = {
        objects = {
            -- The used item is "Camp Chair" but it appears as just "Chair" when placed
            { name = "Chair" },
        },
        buff = "+2% Critical Strike",
        buffExclusiveWith = "Moonkin Aura",
    },
    Tailoring = {
        objects = {
            { name = "Faction Banner" },
        },
        buff = {
            { minLevel = 1,  buff = "+14 Spirit" },
            { minLevel = 40, buff = "+19 Spirit" },
            { minLevel = 50, buff = "+27 Spirit" },
            { minLevel = 60, buff = "+32 Spirit" },
        },
        buffExclusiveWith = "Divine Spirit",
    },
}

-- Objects are flattened into a display-name-keyed index for O(1) tooltip lookup
-- Each object inherits the profession level buff/buffExclusiveWith unless it defines its own
addon.campObjects = {}
for profession, data in pairs(professions) do
    for _, object in ipairs(data.objects) do
        object.profession = profession

        -- Inherit buff from the profession
        if object.buff == nil then
            object.buff = data.buff
        end

        -- Inherit buffExclusiveWith from the profession
        if object.buffExclusiveWith == nil then
            object.buffExclusiveWith = data.buffExclusiveWith
        end

        addon.campObjects[object.name] = object
    end
end

-- Returns a level-scaled buff when buff is a scaled list, otherwise the flat buff, or nil
function addon.GetCampObjectBuff(object)
    if type(object.buff) == "table" then
        local level = UnitLevel("player")
        local buff
        for _, scaled in ipairs(object.buff) do
            if level < scaled.minLevel then
                break
            end
            buff = scaled.buff .. " (at level " .. level .. ")"
        end
        return buff
    end

    return object.buff
end
