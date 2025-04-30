if getgenv().SkullHubDrBond then return end
getgenv().SkullHubDrBond = true

-- Main UI

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local blur = Instance.new("BlurEffect")
blur.Size = 20
blur.Parent = Lighting

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkullHubUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundTransparency = 1
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
mainFrame.Parent = screenGui

local compactButton = Instance.new("TextButton")
compactButton.Size = UDim2.new(0, 60, 0, 60)
compactButton.Position = UDim2.new(0.5, -30, 0, -80)
compactButton.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
compactButton.Text = "▲"
compactButton.TextColor3 = Color3.fromRGB(255, 255, 255)
compactButton.Font = Enum.Font.FredokaOne
compactButton.TextSize = 24
compactButton.Visible = false
compactButton.Parent = mainFrame

local compactCorner = Instance.new("UICorner")
compactCorner.CornerRadius = UDim.new(1, 0)
compactCorner.Parent = compactButton

local compactStroke = Instance.new("UIStroke")
compactStroke.Thickness = 2
compactStroke.Color = Color3.fromRGB(72, 138, 182)
compactStroke.Transparency = 0.3
compactStroke.Parent = compactButton

local uiContainer = Instance.new("Frame")
uiContainer.Size = UDim2.new(0, 450, 0, 240)
uiContainer.Position = UDim2.new(0.5, -225, 1, 100)
uiContainer.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
uiContainer.BackgroundTransparency = 0.1
uiContainer.Parent = mainFrame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = uiContainer

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(72, 138, 182)
stroke.Transparency = 0.3
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = uiContainer

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(72, 138, 182)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 35, 35))
})
gradient.Rotation = 45
gradient.Parent = uiContainer

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 30, 0, 30)
minimizeButton.Position = UDim2.new(1, -40, 0, 10)
minimizeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
minimizeButton.Text = "-"
minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.Font = Enum.Font.FredokaOne
minimizeButton.TextSize = 20
minimizeButton.Parent = uiContainer

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 8)
minimizeCorner.Parent = minimizeButton

local icon = Instance.new("ImageLabel")
icon.Size = UDim2.new(0, 64, 0, 64)
icon.Position = UDim2.new(0.5, -32, 0, 16)
icon.BackgroundTransparency = 1
icon.Image = "rbxassetid://95183678717613"
icon.Parent = uiContainer

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 40)
title.Position = UDim2.new(0, 10, 0, 90)
title.BackgroundTransparency = 1
title.Text = "Skull Hub"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.FredokaOne
title.TextSize = 32
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = uiContainer

local desc = Instance.new("TextLabel")
desc.Size = UDim2.new(1, -40, 0, 60)
desc.Position = UDim2.new(0, 20, 0, 140)
desc.BackgroundTransparency = 1
desc.Text = "Auto bonds beta version is running...\n(discord.gg/skullhub)"
desc.TextColor3 = Color3.fromRGB(180, 180, 180)
desc.Font = Enum.Font.FredokaOne
desc.TextSize = 16
desc.TextWrapped = true
desc.TextYAlignment = Enum.TextYAlignment.Top
desc.TextXAlignment = Enum.TextXAlignment.Center
desc.Parent = uiContainer

local isMinimized = false

local function toggleMinimize()
    isMinimized = not isMinimized
    
    if isMinimized then
        -- Minimize animation
        TweenService:Create(uiContainer, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -225, 0, -300),
            Size = UDim2.new(0, 450, 0, 0)
        }):Play()
        
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
            BackgroundTransparency = 1
        }):Play()
        
        task.wait(0.2)
        compactButton.Visible = true
        TweenService:Create(compactButton, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -30, 0, 10)
        }):Play()
        
        blur.Size = 0
        minimizeButton.Text = "+"
    else
        -- Maximize animation
        TweenService:Create(compactButton, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -30, 0, -80)
        }):Play()
        
        task.wait(0.2)
        compactButton.Visible = false
        
        TweenService:Create(uiContainer, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -225, 0.5, -120),
            Size = UDim2.new(0, 450, 0, 240)
        }):Play()
        
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.4
        }):Play()
        
        blur.Size = 20
        minimizeButton.Text = "-"
    end
end

minimizeButton.MouseButton1Click:Connect(toggleMinimize)
compactButton.MouseButton1Click:Connect(toggleMinimize)

task.wait(0.1)

TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
    BackgroundTransparency = 0.4
}):Play()

TweenService:Create(uiContainer, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Position = UDim2.new(0.5, -225, 0.5, -120)
}):Play()

-- Notification UI
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local gui = CoreGui:FindFirstChild("ModernNotificationUI") or Instance.new("ScreenGui")
gui.Name = "ModernNotificationUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999999
gui.Parent = CoreGui

local container = gui:FindFirstChild("NotificationContainer") or Instance.new("Frame")
container.Name = "NotificationContainer"
container.AnchorPoint = Vector2.new(1, 1)
container.Size = UDim2.new(0, 320, 1, -20)
container.Position = UDim2.new(1, -20, 1, -20)
container.BackgroundTransparency = 1
container.Parent = gui

if not container:FindFirstChild("Scale") then
	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Scale = 1
	scale.Parent = container
end

local layout = container:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.Parent = container

local function notify(titleText, messageText, duration)
	duration = duration or 5

	local notif = Instance.new("Frame")
	notif.Size = UDim2.new(1, 0, 0, 0)
	notif.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	notif.BackgroundTransparency = 1
	notif.LayoutOrder = -tick()
	notif.ClipsDescendants = true
	notif.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = notif

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 160, 200)
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = notif

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -40, 0, 22)
	title.Position = UDim2.new(0, 14, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = notif

	local message = Instance.new("TextLabel")
	message.Size = UDim2.new(1, -40, 0, 40)
	message.Position = UDim2.new(0, 14, 0, 32)
	message.BackgroundTransparency = 1
	message.Text = messageText
	message.TextColor3 = Color3.fromRGB(200, 200, 200)
	message.Font = Enum.Font.FredokaOne
	message.TextSize = 14
	message.TextWrapped = true
	message.TextXAlignment = Enum.TextXAlignment.Left
	message.TextYAlignment = Enum.TextYAlignment.Top
	message.Parent = notif

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 22, 0, 22)
	closeBtn.Position = UDim2.new(1, -30, 0, 10)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.TextSize = 18
	closeBtn.ZIndex = 2
	closeBtn.Parent = notif

	local progressBar = Instance.new("Frame")
	progressBar.Size = UDim2.new(1, -16, 0, 4)
	progressBar.Position = UDim2.new(0, 8, 1, -8)
	progressBar.BackgroundColor3 = Color3.fromRGB(128, 128, 128)
	progressBar.BackgroundTransparency = 0.7
	progressBar.ZIndex = 2
	progressBar.Parent = notif

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 2)
	progressCorner.Parent = progressBar

	local progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.new(1, 0, 1, 0)
	progressFill.BackgroundTransparency = 0
	progressFill.Parent = progressBar

	local progressGradient = Instance.new("UIGradient")
	progressGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 160, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 100, 140))
	})
	progressGradient.Parent = progressFill

	local progressFillCorner = Instance.new("UICorner")
	progressFillCorner.CornerRadius = UDim.new(0, 2)
	progressFillCorner.Parent = progressFill

	TweenService:Create(notif, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
		Size = UDim2.new(1, 0, 0, 80),
		BackgroundTransparency = 0
	}):Play()

	TweenService:Create(progressFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(0, 0, 1, 0)
	}):Play()

	local function close()
		local tween = TweenService:Create(notif, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1
		})
		tween:Play()
		tween.Completed:Wait()
		notif:Destroy()
	end

	closeBtn.MouseButton1Click:Connect(close)
	task.delay(duration, function()
		if notif and notif.Parent then close() end
	end)
end

notify("Auto Bond", "This's just beta version, so there may be some errors/bugs.", 10)


local Notif = loadstring(game:HttpGet("https://raw.githubusercontent.com/hungquan99/Interface/main/Notify.lua"))()
if game.PlaceId == 70876832253163 or game.PlaceId == 98018823628597 then
    Notif.New("[Skull Hub] Auto Bond Loaded!", 5)

    local args = {
        [1] = false
    }
    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("EndDecision"):FireServer(unpack(args))

    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local tweenService = game:GetService("TweenService")
    local runService = game:GetService("RunService")

    -- Default walk speed for tweening (matches Roblox default)
    local WALK_SPEED = 16
    -- Maximum distance for tweening to a Bond on first seat detection
    local MAX_BOND_DISTANCE = 24
    -- Counter for seat detections
    local seatCount = 0

    -- Function to reset character
    local function resetCharacter()
        if humanoid and humanoid.Health > 0 then
            print("[Skull Hub] Resetting character...")
            humanoid.Health = 0 -- Kills character to trigger respawn
        else
            warn("[Skull Hub] Cannot reset: Character already dead or invalid!")
        end
    end

    -- Function to find the closest Bond
    local function findClosestBond(useDistanceLimit)
        local bonds = workspace.RuntimeItems:GetChildren()
        local closestBond = nil
        local minDistance = math.huge
        local playerPos = character.HumanoidRootPart.Position

        for _, bond in ipairs(bonds) do
            if bond.Name == "Bond" and bond:IsA("Model") then
                local bondPart = bond.PrimaryPart or bond:FindFirstChild("MainPart")
                if bondPart and bondPart:IsA("BasePart") then
                    local distance = (playerPos - bondPart.Position).Magnitude
                    if useDistanceLimit and distance > MAX_BOND_DISTANCE then
                        continue
                    end
                    if distance < minDistance then
                        minDistance = distance
                        closestBond = bond
                    end
                end
            end
        end

        return closestBond, minDistance
    end

    -- Function to tween to a Bond with walk speed and handle disappearance
    local function tweenToBond(bond, distance)
        if not bond or not character or not character.HumanoidRootPart then return false end

        local bondPart = bond.PrimaryPart or bond:FindFirstChild("MainPart")
        if not bondPart or not bondPart:IsA("BasePart") then return false end

        -- Calculate tween duration based on walk speed
        local tweenTime = distance / WALK_SPEED
        local tweenInfo = TweenInfo.new(
            tweenTime,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.InOut
        )
        
        -- Create tween
        local tween = tweenService:Create(
            character.HumanoidRootPart,
            tweenInfo,
            {CFrame = CFrame.new(bondPart.Position)}
        )
        
        -- Monitor Bond and character existence
        local connection
        connection = runService.Heartbeat:Connect(function()
            if not bond:IsDescendantOf(workspace) or not bondPart:IsDescendantOf(workspace) or not character or not character.Parent then
                tween:Cancel()
                if connection then connection:Disconnect() end
            end
        end)
        
        -- Play tween and handle completion
        tween:Play()
        local completed = false
        tween.Completed:Connect(function(playbackState)
            completed = true
            if playbackState == Enum.PlaybackState.Cancelled then
                completed = false
            end
        end)
        
        -- Wait until tween completes or is cancelled
        while not completed and tween.PlaybackState == Enum.PlaybackState.Playing do
            runService.Heartbeat:Wait()
        end
        
        if connection then connection:Disconnect() end
        return completed
    end

    -- Function to handle the seat-bond sequence
    local function handleSeatAndBond()
        if humanoid.Sit then
            seatCount = seatCount + 1
            task.wait(1.5) -- Wait 1.5 seconds
            humanoid.Sit = false -- Get out of seat
            
            if seatCount == 1 then
                -- First seat detection: Tween to Bonds within 24 studs
                while true do
                    if not character or not character.HumanoidRootPart then break end
                    local bond, distance = findClosestBond(true) -- Use distance limit
                    if not bond then
                        warn("[Skull Hub] Detected vampire castle, tp to it...")
                        local oldPrint = print
                        local oldWarn = warn

                        print = function(...) end
                        warn = function(...) end

                        loadstring(game:HttpGet('https://raw.githubusercontent.com/idksuss/teslafff/main/castle'))()
                        break
                    end
                    
                    -- Tween to current Bond
                    local success = tweenToBond(bond, distance)
                    if not success then
                        continue
                    end
                end
            elseif seatCount == 2 then
                -- Second seat detection: Tween to all Bonds in RuntimeItems (no distance limit)
                while true do
                    if not character or not character.HumanoidRootPart then break end
                    local bond, distance = findClosestBond(false) -- No distance limit
                    if not bond then
                        pcall(resetCharacter) -- Reset character when no Bonds remain
                        break
                    end
                    
                    -- Tween to current Bond
                    local success = tweenToBond(bond, distance)
                    if not success then
                        continue
                    end
                end
            end
        end
    end

    -- Run in parallel using coroutine
    local function startMonitoring()
        coroutine.wrap(function()
            while true do
                if humanoid and character and character.Parent then
                    handleSeatAndBond()
                end
                task.wait(0.1) -- Prevent excessive CPU usage
            end
        end)()
    end

    -- Start the coroutine when character spawns
    player.CharacterAdded:Connect(function(newCharacter)
        character = newCharacter
        humanoid = character:WaitForChild("Humanoid")
        startMonitoring()
    end)

    -- Start immediately if character exists
    if character then
        startMonitoring()
    end

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")

    -- Try multiple possible remote names
    local possibleRemotes = {
        ReplicatedStorage:FindFirstChild("Packages") and
            ReplicatedStorage.Packages:FindFirstChild("RemotePromise") and
            ReplicatedStorage.Packages.RemotePromise:FindFirstChild("Remotes") and
            ReplicatedStorage.Packages.RemotePromise.Remotes:FindFirstChild("C_ActivateObject"),
        ReplicatedStorage:FindFirstChild("Packages") and
            ReplicatedStorage.Packages:FindFirstChild("ActivateObjectClient"),
        ReplicatedStorage:FindFirstChild("ActivateObject"),
        ReplicatedStorage:FindFirstChild("Interact"),
        ReplicatedStorage:FindFirstChild("C_Interact")
    }

    local remote = nil
    for i, r in ipairs(possibleRemotes) do
        if r then
            remote = r
            break
        end
    end

    if not remote then
        return
    end

    local function collectBonds()
        local player = Players.LocalPlayer
        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            warn("[Skull Hub] Character or HumanoidRootPart not found!")
            return
        end

        -- Search for bonds in RuntimeItems or workspace
        local items = Workspace:FindFirstChild("RuntimeItems") and Workspace.RuntimeItems:GetChildren() or Workspace:GetDescendants()
        local bondFound = false

        for _, item in ipairs(items) do
            if item.Name == "Bond" or item.Name == "BondCalculated" then
                bondFound = true
                -- Try multiple FireServer argument formats
                pcall(function()
                    remote:FireServer(item)
                end)
                pcall(function()
                    local bondPart = item:FindFirstChild("Part") or item:FindFirstChildOfClass("BasePart")
                    if bondPart then
                        remote:FireServer(bondPart)
                    end
                end)
                pcall(function()
                    remote:FireServer(item.Position)
                end)
                pcall(function()
                    local prompt = item:FindFirstChildOfClass("ProximityPrompt")
                    if prompt then
                        remote:FireServer(prompt)
                    end
                end)
                task.wait(0.2) -- Delay to avoid rate limits
            end
        end

        if not bondFound then
        else
        end
    end

    -- Auto-pickup using Heartbeat
    local lastRun = 0
    local connection
    connection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        if currentTime - lastRun >= 0.5 then
            lastRun = currentTime
            task.spawn(function() -- Run in parallel
                pcall(collectBonds)
            end)
        end
    end)

    -- Clean up when the player leaves
    local player = Players.LocalPlayer
    local cleanupConnection = player.AncestryChanged:Connect(function()
        if not player:IsDescendantOf(game) then
            if connection then
                connection:Disconnect()
                connection = nil
            end
            cleanupConnection:Disconnect()
        end
    end)

    loadstring(game:HttpGet('https://skullhub.xyz/tptfport.lua'))()

    task.delay(160, function()
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("Humanoid") then
            character.Humanoid.Health = 0
            task.wait(40)
        end
    end)
else
    Notif.New("[Skull Hub] Auto Bond Loaded!", 5)
    local TweenService = game:GetService("TweenService")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")

    local player = Players.LocalPlayer

    local function getCharacter()
        return player.Character or player.CharacterAdded:Wait()
    end

    local function getHumanoidRootPart()
        local character = getCharacter()
        return character:WaitForChild("HumanoidRootPart")
    end

    local function getHumanoid()
        local character = getCharacter()
        return character:WaitForChild("Humanoid")
    end

    local function findTeleportZone()
        while true do
            for _, zone in ipairs(workspace.TeleportZones:GetChildren()) do
                local stateLabel = zone:FindFirstChild("BillboardGui") and zone.BillboardGui:FindFirstChild("StateLabel")
                if stateLabel and stateLabel.Text == "Waiting for players..." then
                    return zone.PrimaryPart
                end
            end
            task.wait(1)
        end
    end

    local function walkTo(destination)
        local humanoidRootPart = getHumanoidRootPart()
        local humanoid = getHumanoid()
        
        if not humanoidRootPart or not humanoid or humanoid.Health <= 0 then
            return
        end

        local startPosition = humanoidRootPart.Position
        local targetPosition = Vector3.new(destination.Position.X, startPosition.Y, destination.Position.Z)
        
        local character = getCharacter()
        local originalCollisions = {}
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                originalCollisions[part] = part.CanCollide
                part.CanCollide = false
            end
        end

        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then
                input:Destroy()
            end
        end)
        humanoid.Jump = false
        humanoid.WalkSpeed = 16

        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(math.huge, 0, math.huge)
        bodyVelocity.Velocity = (targetPosition - startPosition).Unit * 16
        bodyVelocity.Parent = humanoidRootPart

        humanoid:MoveTo(targetPosition)

        local running = true
        local connection
        connection = RunService.Heartbeat:Connect(function()
            if not humanoid.Parent or humanoid.Health <= 0 or not humanoidRootPart.Parent then
                running = false
                connection:Disconnect()
                bodyVelocity:Destroy()
                for part, canCollide in pairs(originalCollisions) do
                    if part.Parent then
                        part.CanCollide = canCollide
                    end
                end
                return
            end

            local foundValidZone = false
            for _, zone in ipairs(workspace.TeleportZones:GetChildren()) do
                local stateLabel = zone:FindFirstChild("BillboardGui") and zone.BillboardGui:FindFirstChild("StateLabel")
                if stateLabel and stateLabel.Text == "Waiting for players..." then
                    foundValidZone = true
                    break
                end
            end

            if not foundValidZone then
                running = false
                humanoid:MoveTo(humanoidRootPart.Position)
                bodyVelocity:Destroy()
                connection:Disconnect()
                for part, canCollide in pairs(originalCollisions) do
                    if part.Parent then
                        part.CanCollide = canCollide
                    end
                end
            end
        end)

        humanoid.MoveToFinished:Wait()
        running = false
        connection:Disconnect()
        bodyVelocity:Destroy()

        for part, canCollide in pairs(originalCollisions) do
            if part.Parent then
                part.CanCollide = canCollide
            end
        end

        humanoid:MoveTo(targetPosition)
    end

    local lastCheck = 0
    RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - lastCheck >= 1 then
            lastCheck = now

            local teleportDestination = findTeleportZone()
            walkTo(teleportDestination)

            local stateLabel = teleportDestination.Parent:FindFirstChild("BillboardGui") and teleportDestination.Parent.BillboardGui:FindFirstChild("StateLabel")
            if stateLabel and stateLabel.Text == "Waiting for players..." then
                local args = {
                    [1] = {
                        ["maxPlayers"] = 1,
                        ["gameMode"] = "Normal"
                    }
                }
                ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemotePromise"):WaitForChild("Remotes"):WaitForChild("C_CreateParty"):FireServer(unpack(args))
            end
        end
    end)

    player.CharacterAdded:Connect(function(character)
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end)
end

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

-- Function to handle death detection
local function onCharacterAdded1(character)
	local humanoid = character:WaitForChild("Humanoid")
	
	humanoid.Died:Connect(function()
		task.wait(40)
	end)
end

-- Listen for new character spawns
if Player.Character then
	onCharacterAdded1(Player.Character)
end
Player.CharacterAdded:Connect(onCharacterAdded1)