local addonName, addon = ...

-- All camp objects by profession
local professions = {
    Alchemy = {
        { name = "Mana Well", buff = "+10 Mana every 5 sec", exclusiveWith = "Blessing of Wisdom" },
    },
    Blacksmithing = {
        { name = "Sharpening Wheel", buff = "+6 Strength", exclusiveWith = "Strength of Earth Totem" },
    },
    Cooking = {
        { name = "Basic Campfire", buff = "Allows up to 3 camp features" },
    },
    Enchanting = {
        { name = "Enchanted Lute", buff = "+71 Armor, +2 All Stats", exclusiveWith = "Mark of the Wild" },
    },
    Engineering = {
        { name = "Reagent Bot", buff = "Purchase Reagents" },
    },
    ["First Aid"] = {
        { name = "First Aid Kit", buff = "+8 Stamina", exclusiveWith = "Power Word: Fortitude" },
    },
    Fishing = {
        { name = "Fish Bowl", buff = "+8% All Stats", exclusiveWith = "Blessing of Kings" },
    },
    Herbalism = {
        { name = "Incense Candle", buff = "+6 Intellect", exclusiveWith = "Arcane Intellect" },
    },
    Leatherworking = {
        { name = "Camp Tent", buff = "Rested XP up to 5% of a level" },
    },
    Mining = {
        { name = "Lodestone", buff = "+20 Melee Attack Power", exclusiveWith = "Blessing of Might" },
    },
    Skinning = {
        -- The used item is "Camp Chair" but it appears as just "Chair" when placed
        { name = "Chair", buff = "+2% Critical Strike", exclusiveWith = "Moonkin Aura" },
    },
    Tailoring = {
        { name = "Faction Banner", buff = "+14 Spirit", exclusiveWith = "Divine Spirit" },
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
