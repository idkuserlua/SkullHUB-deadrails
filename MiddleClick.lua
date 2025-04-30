local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Player = Players.LocalPlayer

local MiddleClick = {
    Enabled = false, -- Controlled by UI
    RecordedTargets = {} -- Store targets and their original properties
}

-- Check if a target is a humanoid
local function isHumanoid(target)
    local model = target:FindFirstAncestorOfClass("Model")
    return model and model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- Record and modify a part’s properties
local function modifyPart(part)
    if not part:IsA("BasePart") or MiddleClick.RecordedTargets[part] then return end
    
    -- Record original properties
    local original = {
        Transparency = part.Transparency,
        Color = part.Color,
        CanCollide = part.CanCollide
    }
    MiddleClick.RecordedTargets[part] = original
    
    -- Apply changes
    part.Transparency = 0.9 -- 90% transparent
    part.Color = Color3.fromRGB(255, 0, 0) -- Red
    part.CanCollide = false -- Disable collisions
    
    -- Revert after 10 seconds
    task.delay(10, function()
        if part and part.Parent then
            part.Transparency = original.Transparency
            part.Color = original.Color
            part.CanCollide = original.CanCollide
        end
        MiddleClick.RecordedTargets[part] = nil
    end)
end

-- Initialize middle-click detection
function MiddleClick.Initialize()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not MiddleClick.Enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton3 then -- Middle click
            local mouse = Player:GetMouse()
            local target = mouse.Target
            if not target then return end
            
            -- Do nothing for humanoids
            if isHumanoid(target) then return end
            
            -- Modify part if it’s not a humanoid
            modifyPart(target)
        end
    end)
end

return MiddleClick
