local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local Utilities = {}

function Utilities.getDistance(position)
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return 9999 end
    return (Player.Character.HumanoidRootPart.Position - position).Magnitude
end

function Utilities.getPosition(object)
    if object:IsA("Model") then
        local primaryPart = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
        return primaryPart and primaryPart.Position or Vector3.new(0, 0, 0)
    end
    return object:IsA("BasePart") and object.Position or Vector3.new(0, 0, 0)
end

function Utilities.isPlayerCharacter(model)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character == model then return true end
    end
    return false
end

function Utilities.safeDestroy(instance)
    pcall(function()
        if instance and instance.Parent then
            instance:Destroy()
        end
    end)
end

-- Assign colors to items based on name or TextLabel content
function Utilities.getItemColor(object, Config)
    local name = object.Name:lower()
    
    -- Check high-value items first (Gold, Silver, Rare take priority)
    if name:find("gold") then return Config.Colors.Gold end
    if name:find("silver") then return Config.Colors.Silver end
    if name:find("holy water") or name:find("crucifix") or name:find("bond") then return Config.Colors.Rare end
    
    -- Check TextLabels and name for other categories
    for _, child in pairs(object:GetDescendants()) do
        if child:IsA("TextLabel") and child.Text ~= "" then
            local labelText = child.Text:lower()
            if labelText == "corpse" or name:find("corpse") then return Config.Colors.Corpse end
            if labelText == "fuel" or name:find("fuel") or name:find("gas") then return Config.Colors.Fuel end
            if labelText == "ammo" or name:find("ammo") or name:find("bullet") then return Config.Colors.Ammo end
            if labelText == "gun" or labelText == "weapon" or labelText == "melee" or 
               name:find("gun") or name:find("weapon") or name:find("melee") then return Config.Colors.Weapon end
            if labelText == "junk" or name:find("junk") then return Config.Colors.Junk end
            if name:find("bandage") or name:find("snake oil") then return Config.Colors.Healing end
        end
    end
    
    -- Check name if no TextLabel matches
    if name:find("corpse") then return Config.Colors.Corpse end
    if name:find("fuel") or name:find("gas") then return Config.Colors.Fuel end
    if name:find("ammo") or name:find("bullet") then return Config.Colors.Ammo end
    if name:find("gun") or name:find("weapon") or name:find("melee") then return Config.Colors.Weapon end
    if name:find("junk") then return Config.Colors.Junk end
    if name:find("bandage") or name:find("snake oil") then return Config.Colors.Healing end
    
    return Config.Colors.Default -- Fallback for uncategorized items
end

-- Get health information for a humanoid
function Utilities.getHealth(model)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return {
            Current = humanoid.Health,
            Max = humanoid.MaxHealth
        }
    end
    return { Current = 0, Max = 100 } -- Fallback if no humanoid found
end

return Utilities
