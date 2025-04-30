local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local Player = Players.LocalPlayer
local Drawing = Drawing or require(game:GetService("ReplicatedStorage"):WaitForChild("DrawingModule"))

local Aimbot = {
    Enabled = false, -- Controlled by UI
    Aiming = false, -- Tracks right-click state
    Target = nil,   -- Current NPC target
    RenderConnection = nil, -- Store RenderStepped connection
    FOVCircle = nil, -- Stores the FOV circle
    Settings = {
        AimKey = Enum.UserInputType.MouseButton2, -- RightClick
        FOV = 100 -- Aimbot Field of View
    }
}

-- Create the FOV circle
local function createFOVCircle()
    local circle = Drawing.new("Circle")
    circle.Thickness = 1
    circle.Filled = false
    circle.Radius = Aimbot.Settings.FOV
    circle.Color = Color3.fromRGB(0, 0, 0) -- Set color to black
    circle.Transparency = 1
    circle.Visible = true -- Ensure it is visible
    return circle
end

Aimbot.FOVCircle = createFOVCircle()

-- Update FOV circle position
local function updateFOVCircle()
    if Aimbot.FOVCircle then
        local mousePos = UserInputService:GetMouseLocation()
        Aimbot.FOVCircle.Position = mousePos
        Aimbot.FOVCircle.Radius = Aimbot.Settings.FOV
        Aimbot.FOVCircle.Visible = Aimbot.Enabled
    end
end

RunService.RenderStepped:Connect(updateFOVCircle)

-- Utility function to get NPC models (non-player humanoids)
local function getNPCs()
    local npcs = {}
    for _, humanoid in pairs(workspace:GetDescendants()) do
        if humanoid:IsA("Model") and humanoid:FindFirstChildOfClass("Humanoid") and humanoid ~= Player.Character then
            local isPlayer = Players:GetPlayerFromCharacter(humanoid)
            if not isPlayer and humanoid:FindFirstChildOfClass("Humanoid").Health > 0 then
                table.insert(npcs, humanoid)
            end
        end
    end
    return npcs
end

-- Check if there is a direct line of sight to the NPC (wall check)
local function isVisible(target)
    if not target or not target.PrimaryPart then return false end
    local targetPos = target.PrimaryPart.Position
    local origin = Camera.CFrame.Position
    local direction = (targetPos - origin).Unit * (targetPos - origin).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {Player.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local raycastResult = workspace:Raycast(origin, direction, raycastParams)
    return raycastResult and raycastResult.Instance and raycastResult.Instance:IsDescendantOf(target)
end

-- Check if NPC is within the Aimbot FOV
local function isWithinFOV(target)
    if not target or not target.PrimaryPart then return false end
    local head = target:FindFirstChild("Head") or target.PrimaryPart
    if not head then return false end
    
    local screenPos, onScreen = Camera:WorldToScreenPoint(head.Position)
    if not onScreen then return false end
    
    local mousePos = UserInputService:GetMouseLocation()
    local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
    
    return distance <= Aimbot.Settings.FOV
end

-- Find closest NPC to crosshair (excluding players and checking visibility and FOV)
local function findClosestNPC()
    local mouse = UserInputService:GetMouseLocation()
    local ray = Camera:ScreenPointToRay(mouse.X, mouse.Y)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {Player.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local closestNPC, closestDistance = nil, math.huge
    local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
    
    if raycastResult and raycastResult.Instance then
        local model = raycastResult.Instance:FindFirstAncestorOfClass("Model")
        if model and model:FindFirstChildOfClass("Humanoid") and model ~= Player.Character then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local isPlayer = Players:GetPlayerFromCharacter(model)
            if hum and hum.Health > 0 and not isPlayer and isVisible(model) and isWithinFOV(model) then
                closestNPC = model
                closestDistance = (Camera.CFrame.Position - raycastResult.Position).Magnitude
            end
        end
    end

    -- Fallback: Check all NPCs for closest to crosshair
    for _, npc in pairs(getNPCs()) do
        local head = npc:FindFirstChild("Head") or npc.PrimaryPart
        if head and isVisible(npc) and isWithinFOV(npc) then
            local screenPos, onScreen = Camera:WorldToScreenPoint(head.Position)
            if onScreen then
                local distance = (Vector2.new(screenPos.X, screenPos.Y) - mouse).Magnitude
                if distance < closestDistance then
                    closestNPC = npc
                    closestDistance = distance
                end
            end
        end
    end
    
    return closestNPC
end

-- Aim at target’s head instantly
local function aimAtTarget()
    if not Aimbot.Target or not Aimbot.Target.PrimaryPart then return end
    
    local head = Aimbot.Target:FindFirstChild("Head") or Aimbot.Target.PrimaryPart
    if not head then return end
    
    local targetPos = head.Position -- Direct head targeting, no offset
    local lookVector = (targetPos - Camera.CFrame.Position).Unit
    local newCFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + lookVector)
    
    -- Instant aim (no smoothing)
    Camera.CFrame = newCFrame
end

-- Handle input for aimbot
function Aimbot.Initialize()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not Aimbot.Enabled then return end
        if input.UserInputType == Aimbot.Settings.AimKey then
            Aimbot.Aiming = true
            Aimbot.Target = findClosestNPC()
            if Aimbot.Target then
                Aimbot.RenderConnection = RunService.RenderStepped:Connect(aimAtTarget)
            end
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed or not Aimbot.Enabled then return end
        if input.UserInputType == Aimbot.Settings.AimKey then
            Aimbot.Aiming = false
            Aimbot.Target = nil
            if Aimbot.RenderConnection then
                Aimbot.RenderConnection:Disconnect()
                Aimbot.RenderConnection = nil
            end
        end
    end)
end

return Aimbot
