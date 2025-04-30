local Config = {
    Enabled = true,
    MaxDistance = 1000,
    Colors = {
        -- Humanoid Colors
        Player = Color3.fromRGB(0, 0, 255),    -- Blue for players
        NPC = Color3.fromRGB(255, 0, 0),       -- Red for NPCs
        
        -- Item Colors
        Default = Color3.fromRGB(200, 200, 200), -- Gray for unidentified/junk items
        Corpse = Color3.fromRGB(139, 69, 19),   -- Brown for corpses
        Fuel = Color3.fromRGB(255, 165, 0),     -- Orange for fuel
        Ammo = Color3.fromRGB(0, 255, 255),     -- Cyan for ammo
        Weapon = Color3.fromRGB(255, 0, 255),   -- Magenta for guns, weapons, melee
        Junk = Color3.fromRGB(100, 100, 100),   -- Dark gray for junk
        Healing = Color3.fromRGB(0, 255, 0),    -- Green for bandages and snake oil
        Gold = Color3.fromRGB(255, 215, 0),     -- Yellow for gold (high value)
        Silver = Color3.fromRGB(192, 192, 192), -- Silver for silver (high value)
        Rare = Color3.fromRGB(160, 32, 240)     -- Purple for rare items (Holy Water, Crucifix, Bond)
    }
}

return Config
