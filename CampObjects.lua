local addonName, addon = ...

-- All camp objects by profession
local professions = {
    Alchemy = {
        objects = {
            { name = "Mana Well" },
            { name = "Fermenter", perk = "Required for certain reagents" },
            { name = "Alchemy Laboratory", perk = "Required for certain recipes" },
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
            { name = "Anvil", perk = "Required for certain recipes" },
            { name = "Master Forge", perk = "Required for certain recipes" },
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
            { name = "Basic Campfire", perk = "Allows Cooking and up to 3 camp features" },
            { name = "Journeyman Campfire", perk = "Allows Cooking and up to 5 camp features" },
            { name = "Expert Campfire", perk = "Allows Cooking and up to 10 camp features" },
        },
    },
    Enchanting = {
        objects = {
            { name = "Enchanted Lute" },
            { name = "Arcane Salvager", perk = "More efficient Disenchanting" },
            { name = "Arcane Forge", perk = "Required for certain recipes" },
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
            { name = "Reagent Bot", perk = "Buy reagents" },
            { name = "Repair Bot", perk = "Buy reagents and repair gear" },
            { name = "Anarchist's Workbench", perk = "Required for certain recipes" },
        },
    },
    ["First Aid"] = {
        objects = {
            { name = "First Aid Kit" },
            { name = "Toxin Study", perk = "Contains healing potions and anti-venom" },
            { name = "Plague Doctor's Laboratory", perk = "Contains healing potions and poultices" },
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
            { name = "Fishing Rack", perk = "Allows catching uncommon fish for 1 hour\nContains fishing lures" },
            { name = "Fishing Hut", perk = "Allows catching rare fish for 1 hour\nContains fishing lures" },
        },
        buff = "+8% All Stats",
        buffExclusiveWith = "Blessing of Kings",
    },
    Herbalism = {
        objects = {
            { name = "Incense Candle" },
            { name = "Greenhouse", perk = "Grow herbs from planted seeds" },
            { name = "Seed Hybridizer", perk = "Multiply or combine seeds" },
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
            { name = "Tanning Rack", perk = "Required for certain reagents" },
            { name = "Sewing Machine", perk = "Required for certain recipes" },
        },
        buff = "Rested experience (up to 5% of a level)",
    },
    Mining = {
        objects = {
            { name = "Lodestone" },
            { name = "Rock Garden", perk = "Spawns a common mining node" },
            { name = "Molten Foundry", perk = "Required for certain recipes" },
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
            { name = "Field Guide", perk = "Grants Track Beasts" },
            { name = "Trapper's Workbench", perk = "Contains 1 trap" },
        },
        buff = "+2% Critical Strike",
        buffExclusiveWith = "Moonkin Aura",
    },
    Tailoring = {
        objects = {
            { name = "Faction Banner" },
            { name = "Spinning Wheel", perk = "Required for certain reagents" },
            { name = "Loom", perk = "Required for certain recipes" },
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

-- Returns the buff(s) for a camp object as { { text, isCurrent }, ... } or nil if the object has no buff
-- For level dependent buffs, isCurrent indicates which line corresponds to the player's current level
function addon.GetCampObjectBuffLines(object, expand)
    local buff = object.buff
    if buff == nil then
        return nil
    end

    -- For non-level-dependent buffs, just return the string
    if type(buff) ~= "table" then
        return { { text = buff, isCurrent = true } }
    end

    -- Get the players current level to determine which buff line applies
    local level = UnitLevel("player")
    local currentIndex = 1
    for i, scaled in ipairs(buff) do
        if level >= scaled.minLevel then
            currentIndex = i
        end
    end

    -- By default, only the currently applicable buff line is returned
    if not expand then
        return { { text = buff[currentIndex].buff, isCurrent = true } }
    end

    -- If expand is true, all level ranges are returned with one marked as the current (active)
    local lines = {}
    for i, scaled in ipairs(buff) do
        local nextEntry = buff[i + 1]
        local maxLevel = nextEntry and nextEntry.minLevel - 1 or 60
        local range = scaled.minLevel
        if maxLevel ~= scaled.minLevel then
            range = range .. "-" .. maxLevel
        end
        lines[i] = { text = scaled.buff .. " (" .. range .. ")", isCurrent = i == currentIndex }
    end

    return lines
end
