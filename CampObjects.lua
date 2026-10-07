local addonName, addon = ...

-- All camp objects by profession
local professions = {
    Alchemy = {
        {
            name = "Mana Well",
            buffScaled = {
                { minLevel = 1,  buff = "+10 Mana every 5 sec" },
                { minLevel = 24, buff = "+15 Mana every 5 sec" },
                { minLevel = 34, buff = "+20 Mana every 5 sec" },
                { minLevel = 44, buff = "+24 Mana every 5 sec" },
                { minLevel = 54, buff = "+29 Mana every 5 sec" },
            },
            exclusiveWith = "Blessing of Wisdom",
        },
        {
            name = "Fermenter",
            buffScaled = {
                { minLevel = 1,  buff = "+10 Mana every 5 sec" },
                { minLevel = 24, buff = "+15 Mana every 5 sec" },
                { minLevel = 34, buff = "+20 Mana every 5 sec" },
                { minLevel = 44, buff = "+24 Mana every 5 sec" },
                { minLevel = 54, buff = "+29 Mana every 5 sec" },
            },
            exclusiveWith = "Blessing of Wisdom",
        },
        {
            name = "Alchemy Laboratory",
            buffScaled = {
                { minLevel = 1,  buff = "+10 Mana every 5 sec" },
                { minLevel = 24, buff = "+15 Mana every 5 sec" },
                { minLevel = 34, buff = "+20 Mana every 5 sec" },
                { minLevel = 44, buff = "+24 Mana every 5 sec" },
                { minLevel = 54, buff = "+29 Mana every 5 sec" },
            },
            exclusiveWith = "Blessing of Wisdom",
        },
    },
    Blacksmithing = {
        {
            name = "Sharpening Wheel",
            buffScaled = {
                { minLevel = 1,  buff = "+6 Strength" },
                { minLevel = 24, buff = "+11 Strength" },
                { minLevel = 38, buff = "+20 Strength" },
                { minLevel = 52, buff = "+34 Strength" },
            },
            exclusiveWith = "Strength of Earth Totem",
        },
    },
    Cooking = {
        { name = "Basic Campfire", buff = "Allows up to 3 camp features" },
        { name = "Journeyman Campfire", buff = "Allows up to 5 camp features" }
    },
    Enchanting = {
        {
            name = "Enchanted Lute",
            buffScaled = {
                { minLevel = 1,  buff = "+28 Armor" },
                { minLevel = 10, buff = "+71 Armor, +2 All Stats" },
                { minLevel = 20, buff = "+114 Armor, +4 All Stats" },
                { minLevel = 30, buff = "+163 Armor, +7 All Stats, +6 All Resist" },
                { minLevel = 40, buff = "+211 Armor, +9 All Stats, +12 All Resist" },
                { minLevel = 50, buff = "+260 Armor, +12 All Stats, +16 All Resist" },
                { minLevel = 60, buff = "+308 Armor, +13 All Stats, +22 All Resist" },
            },
            exclusiveWith = "Mark of the Wild",
        },
    },
    Engineering = {
        { name = "Reagent Bot", buff = "Purchase Reagents" },
    },
    ["First Aid"] = {
        {
            name = "First Aid Kit",
            buffScaled = {
                { minLevel = 1,  buff = "+3 Stamina" },
                { minLevel = 12, buff = "+8 Stamina" },
                { minLevel = 24, buff = "+21 Stamina" },
                { minLevel = 36, buff = "+34 Stamina" },
                { minLevel = 48, buff = "+45 Stamina" },
                { minLevel = 60, buff = "+56 Stamina" },
            },
            exclusiveWith = "Power Word: Fortitude",
        },
    },
    Fishing = {
        { name = "Fish Bowl", buff = "+8% All Stats", exclusiveWith = "Blessing of Kings" },
    },
    Herbalism = {
        {
            name = "Incense Candle",
            buffScaled = {
                { minLevel = 1,  buff = "+2 Intellect" },
                { minLevel = 14, buff = "+6 Intellect" },
                { minLevel = 28, buff = "+12 Intellect" },
                { minLevel = 42, buff = "+18 Intellect" },
                { minLevel = 56, buff = "+25 Intellect" },
            },
            exclusiveWith = "Arcane Intellect",
        },
    },
    Leatherworking = {
        { name = "Camp Tent", buff = "Rested XP up to 5% of a level" },
        { name = "Tanning Rack", buff = "Rested XP up to 5% of a level" }
    },
    Mining = {
        {
            name = "Lodestone",
            buffScaled = {
                { minLevel = 1,  buff = "+12 Melee Attack Power" },
                { minLevel = 12, buff = "+20 Melee Attack Power" },
                { minLevel = 22, buff = "+32 Melee Attack Power" },
                { minLevel = 32, buff = "+49 Melee Attack Power" },
                { minLevel = 42, buff = "+67 Melee Attack Power" },
                { minLevel = 52, buff = "+90 Melee Attack Power" },
            },
            exclusiveWith = "Blessing of Might",
        },
    },
    Skinning = {
        -- The used item is "Camp Chair" but it appears as just "Chair" when placed
        { name = "Chair", buff = "+2% Critical Strike", exclusiveWith = "Moonkin Aura" },
    },
    Tailoring = {
        {
            name = "Faction Banner",
            buffScaled = {
                { minLevel = 1,  buff = "+14 Spirit" },
                { minLevel = 40, buff = "+19 Spirit" },
                { minLevel = 50, buff = "+27 Spirit" },
                { minLevel = 60, buff = "+32 Spirit" },
            },
            exclusiveWith = "Divine Spirit",
        },
    },
}

-- Objects are flattened into a display-name-keyed index for O(1) tooltip lookup
addon.campObjects = {}
for profession, objects in pairs(professions) do
    for _, object in ipairs(objects) do
        object.profession = profession
        addon.campObjects[object.name] = object
    end
end

-- Returns the buff scaled to the player's level, the base buff, or nil if neither exists
function addon.GetCampObjectBuff(object)
    if object.buffScaled then
        local level = UnitLevel("player")
        local buff
        for _, scaled in ipairs(object.buffScaled) do
            if level < scaled.minLevel then
                break
            end
            buff = scaled.buff .. " (at level " .. level .. ")"
        end
        return buff
    end

    return object.buff
end
