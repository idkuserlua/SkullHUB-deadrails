

return function(Config, Utilities)
    local ESPConfig = {
    FadeStartMultiplier = 0.7, -- Fade starts at 70% of MaxDistance
    HealthBarDistance = 100,   -- Health bars visible under 100 studs
    SpatialFilterThreshold = 0.9, -- Skip updates beyond 90% MaxDistance
    SpatialMoveThreshold = 5,  -- Movement threshold for spatial filtering (studs)
    UpdateInterval = 0.2,      -- Update every 0.2 seconds
    RarityColors = {           -- Colors triggering rarity glow
        "Gold", "Silver", "Rare"
    }
}

    local ESPObject = loadstring(game:HttpGet("https://raw.githubusercontent.com/RENBex6969/SkullHUB-deadrails/refs/heads/main/ESPObject.lua"))()(Config, Utilities, ESPConfig)
    
    local ESPManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/RENBex6969/SkullHUB-deadrails/refs/heads/main/ESPManager.lua"))()(Config, Utilities, ESPObject, ESPConfig)
    
    local ESP = {}
    
    -- Expose public interface from ESPManager
    ESP.Initialize = ESPManager.Initialize
    ESP.Cleanup = ESPManager.Cleanup
    ESP.Update = ESPManager.Update
    ESP.SetEnabled = ESPManager.SetEnabled
    ESP.IsEnabled = ESPManager.IsEnabled
    ESP.HandleToggleKey = ESPManager.HandleToggleKey
    
    return ESP
end
