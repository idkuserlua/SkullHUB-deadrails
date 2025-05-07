--[[
    VERBAL Hub - Auto Bond Collector (Optimized for Speed, Externally Controlled)
    Focus: Faster execution, reduced unnecessary yields, robust cleanup, better collection.
]]

-- Services
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

-- Local Player & Character Variables
local player = Players.LocalPlayer
local char, hrp, humanoid

-- Script Configuration (Adjust SPEED values carefully based on game performance)
local CONFIG = {
    REMOTE_PATHS = {
        C_ActivateObject = "Shared.Network.RemotePromise.Remotes.C_ActivateObject", -- VERIFY THIS PATH!
        EquipObject_Object = "Remotes.Object.EquipObject", -- VERIFY!
        PickUpTool_Tool = "Remotes.Tool.PickUpTool", -- VERIFY!
        EndDecision = "Remotes.EndDecision" -- VERIFY!
    },
    SPEED = {
        pathNavigation = 3300, -- Player-like speed, adjust for balance
        teleportToBondSettleTime = 0.03, -- Minimal time for environment to load (approx 2 frames at 60fps)
        postCollectionAttemptDelay = 0.01, -- Very short delay after each bond attempt cycle
        bondPickupAttemptDuration = 0.20, -- Shorter total time to try collecting one bond
        bondPickupRetryDelay = 0.01, -- Quickest practical retry delay within an attempt cycle
        equipItemDelay = 0.15, -- Faster item equipping
        equipSequenceLoopDelay = 0.6 -- Faster loop for equipping sequence
    },
    BOND_COLLECTION_RADIUS = 75,
    MIN_PATH_SCAN_TIME = 18, -- Reduced minimum scan time if path traversal is quick
    MAX_TELEPORT_ATTEMPTS_PER_BOND = 3, -- Fewer attempts if collection is generally reliable
    EXTERNAL_TOGGLE_CHECK_INTERVAL = 0.4 -- Faster check for external toggle
}

-- State Variables
local foundBondsData = {}
local collectedBondsCount = 0
local totalBondsToCollect = 0
local mainProcessCoroutine = nil
local isScriptActive = false
local shouldScriptRunGlobal = true -- Master control switch

-- GUI Elements
local screenGui, uiContainer, bondStatusLabel
local notificationGuiStore, notificationContainer

-- Event Connections Storage
local eventConnections = {}

-- Forward declaration
local cleanupAndStopScript

-- Utility: Initialize Character Variables
local function initializeCharacter()
    char = player.Character or player.CharacterAdded:Wait() -- Wait if not immediately available
    hrp = char:WaitForChild("HumanoidRootPart", 7) -- Wait up to 7 seconds
    humanoid = char:WaitForChild("Humanoid", 7)

    if not hrp then warn("[VERBAL Hub] CRITICAL: HumanoidRootPart not found!") return false end
    if not humanoid then warn("[VERBAL Hub] CRITICAL: Humanoid not found!") return false end
    return true
end

-- Utility: Get Remote Instance
local function getRemote(baseObject, pathString)
    if not pathString or pathString == "" then return nil end
    local pathParts = pathString:split(".")
    local currentObject = baseObject
    for _, partName in ipairs(pathParts) do
        if not currentObject then return nil end
        currentObject = currentObject:FindFirstChild(partName, true) -- Recursive find
    end
    return currentObject
end

-- GUI Update Function
local function updateBondCountDisplay()
    if bondStatusLabel and bondStatusLabel.Parent then
        local totalText = (not isScriptActive and #foundBondsData == 0) and "N/A" or
                          (isScriptActive and totalBondsToCollect == 0 and #foundBondsData == 0) and "Scanning..." or
                          (totalBondsToCollect == math.huge) and "???" or -- Should not happen with current logic
                          tostring(totalBondsToCollect)
        bondStatusLabel.Text = string.format("Bonds: %d/%s", collectedBondsCount, totalText)
    end
end

-- Path for initial bond scanning
local pathPoints = {
    Vector3.new(13.66,120,29620.67),Vector3.new(-15.98,120,28227.97),Vector3.new(-63.54,120,26911.59),Vector3.new(-75.71,120,25558.11),Vector3.new(-49.51,120,24038.67),Vector3.new(-34.48,120,22780.89),Vector3.new(-63.71,120,21477.32),Vector3.new(-84.23,120,19970.94),Vector3.new(-84.76,120,18676.13),Vector3.new(-87.32,120,17246.92),Vector3.new(-95.48,120,15988.29),Vector3.new(-93.76,120,14597.43),Vector3.new(-86.29,120,13223.68),Vector3.new(-97.56,120,11824.61),Vector3.new(-92.71,120,10398.51),Vector3.new(-98.43,120,9092.45),Vector3.new(-90.89,120,7741.15),Vector3.new(-86.46,120,6482.59),Vector3.new(-77.49,120,5081.21),Vector3.new(-73.84,120,3660.66),Vector3.new(-73.84,120,2297.51),Vector3.new(-76.56,120,933.68),Vector3.new(-81.48,120,-429.93),Vector3.new(-83.47,120,-1683.45),Vector3.new(-94.18,120,-3035.25),Vector3.new(-109.96,120,-4317.15),Vector3.new(-119.63,120,-5667.43),Vector3.new(-118.63,120,-6942.88),Vector3.new(-118.09,120,-8288.66),Vector3.new(-132.12,120,-9690.39),Vector3.new(-122.83,120,-11051.38),Vector3.new(-117.53,120,-12412.74),Vector3.new(-119.81,120,-13762.14),Vector3.new(-126.27,120,-15106.33),Vector3.new(-134.45,120,-16563.82),Vector3.new(-129.85,120,-17884.73),Vector3.new(-127.23,120,-19234.89),Vector3.new(-133.49,120,-20584.07),Vector3.new(-137.89,120,-21933.47),Vector3.new(-139.93,120,-23272.51),Vector3.new(-144.12,120,-24612.54),Vector3.new(-142.93,120,-25962.13),Vector3.new(-149.21,120,-27301.58),Vector3.new(-156.19,120,-28640.93),Vector3.new(-164.87,120,-29990.78),Vector3.new(-177.65,120,-31340.21),Vector3.new(-184.67,120,-32689.24),Vector3.new(-208.92,120,-34027.44),Vector3.new(-227.96,120,-35376.88),Vector3.new(-239.45,120,-36726.59),Vector3.new(-250.48,120,-38075.91),Vector3.new(-260.28,120,-39425.56),Vector3.new(-274.86,120,-40764.67),Vector3.new(-297.45,120,-42103.61),Vector3.new(-321.64,120,-43442.59),Vector3.new(-356.78,120,-44771.52),Vector3.new(-387.68,120,-46100.94),Vector3.new(-415.83,120,-47429.85),Vector3.new(-452.39,120,-49407.44)
}
local RuntimeItemsCache = Workspace:WaitForChild("RuntimeItems", 10) -- Cache reference to RuntimeItems

-- Scan for Bonds (optimized for speed)
local function scanForBondsOnPath()
    if not shouldScriptRunGlobal or not hrp or not RuntimeItemsCache then return end
    local children = RuntimeItemsCache:GetChildren() -- Get children once per call
    for i = 1, #children do
        local m = children[i]
        if not shouldScriptRunGlobal then break end
        if m.Name == "Bond" and m:IsA("Model") and m.PrimaryPart then -- Check IsA("Model") early
            local bondPos = m.PrimaryPart.Position
            local exists = false
            for _, foundData in ipairs(foundBondsData) do
                if (foundData.position - bondPos).Magnitude < 0.25 then -- Increased precision for duplicate check
                    exists = true; break
                end
            end
            if not exists then
                table.insert(foundBondsData, {position = bondPos, model = m, collected = false, attempts = 0})
                totalBondsToCollect = #foundBondsData
                updateBondCountDisplay()
            end
        end
    end
end

-- Attempt to Collect a Specific Bond Model (optimized)
local function attemptCollectSpecificBondModel(bondModelInstance)
    if not shouldScriptRunGlobal or not bondModelInstance or not bondModelInstance.Parent then return false end
    local primaryPart = bondModelInstance.PrimaryPart or bondModelInstance:FindFirstChild("Part") or bondModelInstance:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then return false end

    -- Prioritize ClickDetector if available and fireclickdetector function exists
    if typeof(fireclickdetector) == "function" then
        local clickDetector = primaryPart:FindFirstChildWhichIsA("ClickDetector")
        if clickDetector then
            local suc_cd, err_cd = pcall(fireclickdetector, clickDetector) -- Direct pcall for minor efficiency
            if suc_cd then return true end -- If ClickDetector fires, assume action taken, let disappearance confirm
            warn("[VERBAL Hub] ClickDetector FAILED for", bondModelInstance.Name, ":", tostring(err_cd))
        end
    end

    -- Fallback to C_ActivateObject remote
    local C_ActivateObject = getRemote(ReplicatedStorage, CONFIG.REMOTE_PATHS.C_ActivateObject)
    if C_ActivateObject then
        local suc_remote, err_remote = pcall(C_ActivateObject.FireServer, C_ActivateObject, bondModelInstance) -- Pass C_ActivateObject as self
        if suc_remote then return true end -- If remote fires, assume action taken
        warn("[VERBAL Hub] C_ActivateObject FAILED for", bondModelInstance.Name, ":", tostring(err_remote))
    end
    return false -- No collection method succeeded
end

-- Main Process Logic
local function runMainBondCollectionProcess()
    if not initializeCharacter() then
        warn("[VERBAL Hub] Character/HRP/Humanoid not available. Aborting main process.")
        isScriptActive = false; shouldScriptRunGlobal = false; return
    end
    if not RuntimeItemsCache then -- Check if RuntimeItemsCache was successfully obtained
        warn("[VERBAL Hub] RuntimeItems folder not found. Aborting main process.")
        isScriptActive = false; shouldScriptRunGlobal = false; return
    end

    isScriptActive = true
    print("[VERBAL Hub] Starting main bond collection process...")

    foundBondsData = {}; collectedBondsCount = 0; totalBondsToCollect = 0
    updateBondCountDisplay()

    -- Ensure previous Heartbeat connection is disconnected before creating a new one
    if eventConnections["ScanHeartbeat"] and eventConnections["ScanHeartbeat"].Connected then
        eventConnections["ScanHeartbeat"]:Disconnect()
    end
    eventConnections["ScanHeartbeat"] = RunService.Heartbeat:Connect(scanForBondsOnPath)

    local pathScanActualStartTime = tick() -- Correctly placed for MIN_PATH_SCAN_TIME
    print("[VERBAL Hub] Navigating path to scan for bonds...")
    for i, targetPos in ipairs(pathPoints) do
        if not shouldScriptRunGlobal or not hrp or humanoid.Health <= 0 then
            warn("[VERBAL Hub] Aborting path navigation: script stop/character issue.")
            break
        end
        local dist = (hrp.Position - targetPos).Magnitude
        if dist < 0.5 then RunService.Heartbeat:Wait(); continue end -- Minimal yield if already very close

        local tweenDuration = dist / CONFIG.SPEED.pathNavigation
        -- Use a more complete TweenInfo constructor for clarity, though defaults are often fine
        local tween = TweenService:Create(hrp, TweenInfo.new(tweenDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 0, false, 0), {CFrame = CFrame.new(targetPos)})
        tween:Play()

        local startedWaiting = tick()
        while tween.PlaybackState == Enum.PlaybackState.Playing and (tick() - startedWaiting) < (tweenDuration + 1.5) do -- Reduced timeout buffer
            if not shouldScriptRunGlobal or not hrp or humanoid.Health <= 0 then
                tween:Cancel(); warn("[VERBAL Hub] Tween interrupted by script stop/character issue.")
                break
            end
            RunService.Heartbeat:Wait() -- Yield every frame using Heartbeat for responsiveness
        end
        if tween.PlaybackState == Enum.PlaybackState.Playing then tween:Cancel() end -- Ensure stopped if timed out
    end
    if eventConnections["ScanHeartbeat"] and eventConnections["ScanHeartbeat"].Connected then
        eventConnections["ScanHeartbeat"]:Disconnect(); eventConnections["ScanHeartbeat"] = nil
    end
    
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped during path scan phase."); isScriptActive = false; return end

    totalBondsToCollect = #foundBondsData
    updateBondCountDisplay()
    print("[VERBAL Hub] Path navigation complete. Found", totalBondsToCollect, "potential bond locations.")

    local timeTakenForPathScan = tick() - pathScanActualStartTime
    if timeTakenForPathScan < CONFIG.MIN_PATH_SCAN_TIME then
        local waitDuration = CONFIG.MIN_PATH_SCAN_TIME - timeTakenForPathScan
        if waitDuration > 0 then
             print("[VERBAL Hub] Path scan phase was quick, ensuring min time, waiting for", string.format("%.1fs", waitDuration))
             task.wait(waitDuration) -- task.wait is appropriate for longer, less frequent yields
        end
    end
    
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped after path scan wait period."); isScriptActive = false; return end

    if VirtualInputManager then
        print("[VERBAL Hub] Simulating KeyCode.Two press.")
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
            task.wait() -- Minimal yield
            if not shouldScriptRunGlobal then return end
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
        end)
    end
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped during KeyCode.Two simulation."); isScriptActive = false; return end

    print("[VERBAL Hub] Loading external castle TP script...")
    pcall(function()
        local castleScriptUrl = "https://raw.githubusercontent.com/ringtaa/castletpfast.github.io/main/FASTCASTLE.lua"
        loadstring(game:HttpGet(castleScriptUrl, true))() -- true for nocache
    end)
    task.wait(2.0) -- Reduced wait after TP script attempt
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped after castle TP attempt."); isScriptActive = false; return end

    local function equipItem(itemNameQuery)
        if not shouldScriptRunGlobal or not hrp or not RuntimeItemsCache then return false end
        local itemModel
        local children = RuntimeItemsCache:GetChildren()
        for i = 1, #children do
            local m = children[i]
            if m:IsA("Model") and m.Name:lower():find(itemNameQuery:lower()) then itemModel = m; break end
        end
        if itemModel then
            local equipRemote = getRemote(ReplicatedStorage, CONFIG.REMOTE_PATHS.EquipObject_Object) or getRemote(ReplicatedStorage, CONFIG.REMOTE_PATHS.PickUpTool_Tool)
            if equipRemote then
                local suc, err = pcall(equipRemote.FireServer, equipRemote, itemModel)
                if not suc then warn("[VERBAL Hub] Equip remote FAILED for", itemModel.Name, ":", err); return false end
                return true
            else warn("[VERBAL Hub] Could not find a suitable equip remote for", itemNameQuery) end
        end
        return false
    end

    for i = 1, 2 do -- Loop for equipping sequence
        if not shouldScriptRunGlobal or not hrp or humanoid.Health <= 0 then break end
        equipItem("shovel"); task.wait(CONFIG.SPEED.equipItemDelay); if not shouldScriptRunGlobal then break end
        equipItem("sack"); task.wait(CONFIG.SPEED.equipItemDelay); if not shouldScriptRunGlobal then break end
        if VirtualInputManager then
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game)
                task.wait() -- Minimal yield
                if not shouldScriptRunGlobal then return end
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
            end)
        end
        if not shouldScriptRunGlobal then break end
        task.wait(CONFIG.SPEED.equipSequenceLoopDelay)
    end
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped during item equipping sequence."); isScriptActive = false; return end
    print("[VERBAL Hub] Item equipping sequence finished.")

    print("[VERBAL Hub] Starting bond collection sequence...")
    if #foundBondsData == 0 then print("[VERBAL Hub] No bonds found to collect.") end

    for bondIdx, bondData in ipairs(foundBondsData) do
        if not shouldScriptRunGlobal or not hrp or humanoid.Health <= 0 then break end
        if bondData.collected then continue end
        
        hrp.CFrame = CFrame.new(bondData.position + Vector3.new(0, 3.2, 0)) -- Slightly lower teleport target
        task.wait(CONFIG.SPEED.teleportToBondSettleTime) -- Wait for teleport to settle and parts to stream
        if not shouldScriptRunGlobal then break end

        local collectionAttemptStartTime = tick()
        bondData.attempts = 0
        repeat
            bondData.attempts += 1
            if bondData.model and bondData.model.Parent then
                attemptCollectSpecificBondModel(bondData.model) -- This attempts, disappearance confirms
            end
            
            RunService.Heartbeat:Wait() -- CRUCIAL: Yield one frame for game to process model removal

            if not bondData.model or not bondData.model.Parent then -- Check for disappearance AFTER yield
                if not bondData.collected then
                    print("[VERBAL Hub] Bond model", bondIdx, "disappeared. Confirmed collected.")
                    bondData.collected = true
                    collectedBondsCount += 1 -- Use += for brevity
                    updateBondCountDisplay()
                end
                break -- Exit repeat loop for this bond
            end
            
            if bondData.collected then break end -- Should be redundant if above check is effective
            
            task.wait(CONFIG.SPEED.bondPickupRetryDelay) -- Only wait more if model still exists and not collected
        until not shouldScriptRunGlobal or bondData.collected or (tick() - collectionAttemptStartTime > CONFIG.SPEED.bondPickupAttemptDuration) or bondData.attempts >= CONFIG.MAX_TELEPORT_ATTEMPTS_PER_BOND
        
        if not bondData.collected and shouldScriptRunGlobal then
            warn("[VERBAL Hub] Failed to confirm collection for bond", bondIdx, "at", bondData.position, "after", bondData.attempts, "attempts.")
        end
        task.wait(CONFIG.SPEED.postCollectionAttemptDelay) -- Minimal delay before next bond
    end
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped during bond collection sequence."); isScriptActive = false; return end
    print("[VERBAL Hub] Bond collection sequence finished. Collected:", collectedBondsCount, "/", totalBondsToCollect)

    local function safeReset()
        if player and player.Character and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0 then
            print("[VERBAL Hub] Performing safe character reset.")
            pcall(function() player.Character.Humanoid.Health = 0 end)
        end
    end
    safeReset(); task.wait(1.0) -- Slightly shorter wait for reset
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped after reset."); isScriptActive = false; return end

    updateBondCountDisplay(); task.wait(0.5) -- Shorter wait

    print("[VERBAL Hub] Waiting 12 seconds before firing EndDecision.") -- Reduced final wait
    task.wait(12)
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped before EndDecision."); isScriptActive = false; return end
    local endDecisionRemote = getRemote(ReplicatedStorage, CONFIG.REMOTE_PATHS.EndDecision)
    if endDecisionRemote then
        print("[VERBAL Hub] Firing EndDecision remote.")
        pcall(endDecisionRemote.FireServer, endDecisionRemote, false)
    else warn("[VERBAL Hub] EndDecision remote not found.") end

    print("[VERBAL Hub] Main process finished a cycle.")
    isScriptActive = false
    getgenv().VerbalHubDrBondActive = false -- Allow re-activation if toggle is flipped by external script
end

-- === VERBAL Hub GUI Setup (Minimal changes from previous, ensure it's lean) ===
local function setupVerbalHubGui()
    if CoreGui:FindFirstChild("VERBAL Hub/dead rails") then
        screenGui = CoreGui:FindFirstChild("VERBAL Hub/dead rails")
        local mainFrame = screenGui:FindFirstChild("MainFrame")
        if mainFrame then uiContainer = mainFrame:FindFirstChild("UIContainer") end
        if uiContainer then bondStatusLabel = uiContainer:FindFirstChild("BondStatusLabel") end
        if bondStatusLabel then return print("[VERBAL Hub] GUI already exists.") end
        screenGui:Destroy() -- Destroy incomplete or old GUI to ensure fresh setup
    end

    screenGui = Instance.new("ScreenGui", CoreGui); screenGui.Name = "VERBAL Hub/dead rails"; screenGui.ResetOnSpawn = false; screenGui.IgnoreGuiInset = true; screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local mainFrame = Instance.new("Frame", screenGui); mainFrame.Name = "MainFrame"; mainFrame.Size = UDim2.fromScale(1,1); mainFrame.BackgroundTransparency = 1
    local blur = Instance.new("BlurEffect", Lighting); blur.Name = "VerbalHubBlur"; blur.Size = 0; blur.Enabled = false -- Initially disabled

    uiContainer = Instance.new("Frame", mainFrame); uiContainer.Name = "UIContainer"; uiContainer.Size = UDim2.new(0,450,0,220); uiContainer.Position = UDim2.new(0.5,-225,1,120); uiContainer.BackgroundColor3 = Color3.fromRGB(24,24,24); uiContainer.BackgroundTransparency = 0.05; uiContainer.ClipsDescendants = true
    Instance.new("UICorner", uiContainer).CornerRadius = UDim.new(0,16)
    local stroke = Instance.new("UIStroke", uiContainer); stroke.Thickness = 2; stroke.Color = Color3.fromRGB(57,255,20); stroke.Transparency = 0.3; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local gradient = Instance.new("UIGradient", uiContainer); gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(57,255,20)),ColorSequenceKeypoint.new(1,Color3.fromRGB(35,35,35))}); gradient.Rotation = 45

    local minimizeButton = Instance.new("TextButton",uiContainer); minimizeButton.Name = "MinimizeButton"; minimizeButton.Size = UDim2.new(0,30,0,30); minimizeButton.Position = UDim2.new(1,-40,0,10); minimizeButton.BackgroundColor3 = Color3.fromRGB(50,50,50); minimizeButton.Text = "-"; minimizeButton.TextColor3 = Color3.fromRGB(255,255,255); minimizeButton.Font = Enum.Font.FredokaOne; minimizeButton.TextSize = 20
    Instance.new("UICorner",minimizeButton).CornerRadius = UDim.new(0,8)

    local icon = Instance.new("ImageLabel",uiContainer); icon.Name = "Icon"; icon.Size = UDim2.new(0,64,0,64); icon.Position = UDim2.new(0.5,-32,0,16); icon.BackgroundTransparency = 1; icon.Image = "rbxassetid://9884857489" -- VERIFY ASSET ID

    local titleLabel = Instance.new("TextLabel",uiContainer); titleLabel.Name = "Title"; titleLabel.Size = UDim2.new(1,-20,0,40); titleLabel.Position = UDim2.new(0,10,0,90); titleLabel.BackgroundTransparency = 1; titleLabel.Text = "VERBAL Hub"; titleLabel.TextColor3 = Color3.fromRGB(255,255,255); titleLabel.Font = Enum.Font.FredokaOne; titleLabel.TextSize = 32; titleLabel.TextXAlignment = Enum.TextXAlignment.Center

    bondStatusLabel = Instance.new("TextLabel",uiContainer); bondStatusLabel.Name = "BondStatusLabel"; bondStatusLabel.Size = UDim2.new(1,-40,0,30); bondStatusLabel.Position = UDim2.new(0,20,0,140); bondStatusLabel.BackgroundTransparency = 1; bondStatusLabel.Text = "Bonds: N/A"; bondStatusLabel.TextColor3 = Color3.fromRGB(230,230,230); bondStatusLabel.Font = Enum.Font.FredokaOne; bondStatusLabel.TextSize = 20; bondStatusLabel.TextWrapped = true; bondStatusLabel.TextYAlignment = Enum.TextYAlignment.Center; bondStatusLabel.TextXAlignment = Enum.TextXAlignment.Center

    local descriptionText = Instance.new("TextLabel",uiContainer); descriptionText.Name = "Description"; descriptionText.Size = UDim2.new(1,-40,0,40); descriptionText.Position = UDim2.new(0,20,0,180); descriptionText.BackgroundTransparency = 1; descriptionText.Text = "Dead Rails - Auto Farming Bonds..."; descriptionText.TextColor3 = Color3.fromRGB(180,180,180); descriptionText.Font = Enum.Font.FredokaOne; descriptionText.TextSize = 14; descriptionText.TextWrapped = true; descriptionText.TextYAlignment = Enum.TextYAlignment.Top; descriptionText.TextXAlignment = Enum.TextXAlignment.Center
    
    local compactButton = Instance.new("TextButton",mainFrame); compactButton.Name = "CompactButton"; compactButton.Size = UDim2.new(0,60,0,60); compactButton.Position = UDim2.new(0.5,-30,0,-80); compactButton.BackgroundColor3 = Color3.fromRGB(24,24,24); compactButton.Text = "▲"; compactButton.TextColor3 = Color3.fromRGB(255,255,255); compactButton.Font = Enum.Font.FredokaOne; compactButton.TextSize = 24; compactButton.Visible = false
    Instance.new("UICorner",compactButton).CornerRadius = UDim.new(1,0)
    local compactStroke = Instance.new("UIStroke",compactButton); compactStroke.Thickness = 2; compactStroke.Color = Color3.fromRGB(72,138,182); compactStroke.Transparency = 0.3

    local isMinimized = false
    local function toggleMinimize()
        isMinimized = not isMinimized
        if not uiContainer or not uiContainer.Parent then return end 
        local uiContainerSizeY = uiContainer.AbsoluteSize.Y > 0 and uiContainer.AbsoluteSize.Y or 220 -- Use defined size
        local uiContainerSizeX = uiContainer.AbsoluteSize.X > 0 and uiContainer.AbsoluteSize.X or 450
        local targetPos, targetSize = isMinimized and UDim2.new(0.5,-uiContainerSizeX/2,0,-uiContainerSizeY-30) or UDim2.new(0.5,-uiContainerSizeX/2,0.5,-uiContainerSizeY/2), isMinimized and UDim2.new(0,uiContainerSizeX,0,0) or UDim2.new(0,uiContainerSizeX,0,uiContainerSizeY)
        local targetBlur, targetMainFrameTransparency = isMinimized and 0 or 20, isMinimized and 1 or 0.4
        local compactTargetPos, compactVisible = isMinimized and UDim2.new(0.5,-30,0,10) or UDim2.new(0.5,-30,0,-80), isMinimized
        minimizeButton.Text = isMinimized and "+" or "-"
        TweenService:Create(uiContainer,TweenInfo.new(0.35,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Position=targetPos,Size=targetSize}):Play()
        TweenService:Create(mainFrame,TweenInfo.new(0.35,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=targetMainFrameTransparency}):Play()
        if blur and blur.Parent then blur.Enabled=(targetBlur>0); TweenService:Create(blur,TweenInfo.new(0.35),{Size=targetBlur}):Play() end
        if compactButton and compactButton.Parent then 
            if compactVisible then compactButton.Visible=true end
            TweenService:Create(compactButton,TweenInfo.new(0.3,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Position=compactTargetPos}):Play()
            if not compactVisible then task.delay(0.3,function() if not isMinimized and compactButton.Parent then compactButton.Visible=false end end) end 
        end
    end
    if minimizeButton and minimizeButton.Parent then eventConnections["MinimizeClick"] = minimizeButton.MouseButton1Click:Connect(toggleMinimize) end
    if compactButton and compactButton.Parent then eventConnections["CompactClick"] = compactButton.MouseButton1Click:Connect(toggleMinimize) end

    task.wait(0.1) -- Allow AbsoluteSize to update
    if uiContainer and uiContainer.Parent and Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.Y > 0 then -- Check ViewportSize > 0
        local initialYPos = 0.5 - (uiContainer.AbsoluteSize.Y / 2 / Workspace.CurrentCamera.ViewportSize.Y)
        TweenService:Create(mainFrame,TweenInfo.new(0.5,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{BackgroundTransparency = 0.4}):Play()
        TweenService:Create(uiContainer,TweenInfo.new(0.6,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position = UDim2.new(0.5,-uiContainer.AbsoluteSize.X/2,initialYPos,0)}):Play()
        if blur and blur.Parent then blur.Size = 20; blur.Enabled = true end
    end
end

-- Notification System (largely unchanged, ensure it's efficient)
local function setupNotificationSystem()
    notificationGuiStore = CoreGui:FindFirstChild("ModernNotificationUI_Verbal") or Instance.new("ScreenGui", CoreGui)
    notificationGuiStore.Name = "ModernNotificationUI_Verbal"; notificationGuiStore.ResetOnSpawn = false; notificationGuiStore.IgnoreGuiInset = true; notificationGuiStore.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; notificationGuiStore.DisplayOrder = 999999
    notificationContainer = notificationGuiStore:FindFirstChild("NotificationContainer") or Instance.new("Frame", notificationGuiStore)
    if not notificationContainer:FindFirstChild("UIListLayout") then -- Simplified setup check
        notificationContainer.Name = "NotificationContainer"; notificationContainer.AnchorPoint = Vector2.new(1,1); notificationContainer.Size = UDim2.new(0,320,1,-20); notificationContainer.Position = UDim2.new(1,-20,1,-20); notificationContainer.BackgroundTransparency = 1
        Instance.new("UIScale",notificationContainer).Name = "Scale" -- Ensure scale exists
        local layout = Instance.new("UIListLayout",notificationContainer); layout.Padding = UDim.new(0,10); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    end
end
local function notify(titleText, messageText, duration)
    if not notificationContainer or not notificationContainer.Parent then setupNotificationSystem() end
    duration = duration or 5
    local notif = Instance.new("Frame",notificationContainer); notif.Size=UDim2.new(1,0,0,0); notif.BackgroundColor3=Color3.fromRGB(30,30,30); notif.BackgroundTransparency=1; notif.LayoutOrder=-tick(); notif.ClipsDescendants=true
    Instance.new("UICorner",notif).CornerRadius=UDim.new(0,12); local stroke=Instance.new("UIStroke",notif); stroke.Color=Color3.fromRGB(57,255,20); stroke.Thickness=1; stroke.Transparency=0.5
    local title=Instance.new("TextLabel",notif); title.Size=UDim2.new(1,-40,0,22); title.Position=UDim2.new(0,14,0,10); title.BackgroundTransparency=1; title.Text=titleText; title.TextColor3=Color3.fromRGB(255,255,255); title.Font=Enum.Font.FredokaOne; title.TextSize=18; title.TextXAlignment=Enum.TextXAlignment.Left
    local message=Instance.new("TextLabel",notif); message.Size=UDim2.new(1,-40,0,40); message.Position=UDim2.new(0,14,0,32); message.BackgroundTransparency=1; message.Text=messageText; message.TextColor3=Color3.fromRGB(200,200,200); message.Font=Enum.Font.FredokaOne; message.TextSize=14; message.TextWrapped=true; message.TextXAlignment=Enum.TextXAlignment.Left; message.TextYAlignment=Enum.TextYAlignment.Top
    local closeBtn=Instance.new("TextButton",notif); closeBtn.Size=UDim2.new(0,22,0,22); closeBtn.Position=UDim2.new(1,-30,0,10); closeBtn.Text="✕"; closeBtn.TextColor3=Color3.fromRGB(255,100,100); closeBtn.BackgroundTransparency=1; closeBtn.Font=Enum.Font.FredokaOne; closeBtn.TextSize=18; closeBtn.ZIndex=2
    local progressBar=Instance.new("Frame",notif); progressBar.Size=UDim2.new(1,-16,0,4); progressBar.Position=UDim2.new(0,8,1,-8); progressBar.BackgroundColor3=Color3.fromRGB(128,128,128); progressBar.BackgroundTransparency=0.7; progressBar.ZIndex=2
    Instance.new("UICorner",progressBar).CornerRadius=UDim.new(0,2); local progressFill=Instance.new("Frame",progressBar); progressFill.Size=UDim2.new(1,0,1,0); progressFill.BackgroundTransparency=0
    Instance.new("UIGradient",progressFill).Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(80,160,200)),ColorSequenceKeypoint.new(1,Color3.fromRGB(50,100,140))}); Instance.new("UICorner",progressFill).CornerRadius=UDim.new(0,2)
    TweenService:Create(notif,TweenInfo.new(0.25,Enum.EasingStyle.Quad),{Size=UDim2.new(1,0,0,80),BackgroundTransparency=0}):Play(); TweenService:Create(progressFill,TweenInfo.new(duration,Enum.EasingStyle.Linear),{Size=UDim2.new(0,0,1,0)}):Play()
    local function closeNotif() if notif and notif.Parent then local tween=TweenService:Create(notif,TweenInfo.new(0.25,Enum.EasingStyle.Quad),{Size=UDim2.new(1,0,0,0),BackgroundTransparency=1}); tween:Play(); tween.Completed:Wait(); notif:Destroy() end end
    if closeBtn and closeBtn.Parent then eventConnections["NotifClose_"..notif:GetFullName()] = closeBtn.MouseButton1Click:Connect(closeNotif) end
    task.delay(duration,function() if notif and notif.Parent then closeNotif() end end)
end

-- Cleanup Function
cleanupAndStopScript = function()
    print("[VERBAL Hub] Initiating cleanup and stopping script...")
    shouldScriptRunGlobal = false
    isScriptActive = false
    getgenv().VerbalHubDrBondActive = false

    if mainProcessCoroutine and coroutine.status(mainProcessCoroutine) ~= "dead" then
        print("[VERBAL Hub] Main process coroutine was active; will stop based on flags.")
    end
    mainProcessCoroutine = nil

    for name, conn in pairs(eventConnections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    eventConnections = {}

    if screenGui and screenGui.Parent then screenGui:Destroy(); screenGui = nil end
    if notificationGuiStore and notificationGuiStore.Parent then notificationGuiStore:Destroy(); notificationGuiStore = nil end
    
    local blurEffect = Lighting:FindFirstChild("VerbalHubBlur")
    if blurEffect then blurEffect:Destroy() end

    getgenv().VerbalHubDrBondLoaded = false
    print("[VERBAL Hub] Cleanup complete. Script stopped.")
end

-- Monitor External Toggle
local function monitorExternalToggle()
    while shouldScriptRunGlobal and task.wait(CONFIG.EXTERNAL_TOGGLE_CHECK_INTERVAL) do -- Loop as long as script is globally supposed to run
        local deadRailsEnv = getgenv().DeadRails
        local farmEnabled = deadRailsEnv and deadRailsEnv.Farm and typeof(deadRailsEnv.Farm.Enabled) == "boolean" and deadRailsEnv.Farm.Enabled or false

        if not farmEnabled then -- If toggle was turned OFF (and script was running or supposed to run)
            print("[VERBAL Hub] External toggle is now false. Stopping script.")
            cleanupAndStopScript() -- This sets shouldScriptRunGlobal to false, breaking this loop
            break 
        end
    end
    print("[VERBAL Hub] External toggle monitor stopped.")
end

-- Initialization Guard & Script Start
if getgenv().VerbalHubDrBondLoaded then
    notify("Verbal Hub", "Script already loaded. External toggle controls it.", 5)
    return
end
getgenv().VerbalHubDrBondLoaded = true
getgenv().VerbalHubDrBondActive = false
shouldScriptRunGlobal = true -- Assume script should run initially if loaded

if not initializeCharacter() then
    notify("Verbal Hub Error", "Failed to initialize character. Script may not function.", 10)
    warn("[VERBAL Hub] CRITICAL FAILURE: Could not initialize character on script start.")
    cleanupAndStopScript()
    return
end

if not eventConnections["CharacterAdded"] then
    eventConnections["CharacterAdded"] = player.CharacterAdded:Connect(function(newChar)
        task.wait(0.2) -- Shorter wait for char parts
        if not initializeCharacter() then
            warn("[VERBAL Hub] Failed to re-initialize character. May affect stability.")
            if shouldScriptRunGlobal then cleanupAndStopScript() end
        end
    end)
end

if not eventConnections["PlayerRemoving"] then
     eventConnections["PlayerRemoving"] = Players.PlayerRemoving:Connect(function(leavingPlayer)
        if leavingPlayer == player then
            print("[VERBAL Hub] Local player removing. Cleaning up.")
            cleanupAndStopScript()
        end
    end)
end

pcall(setupVerbalHubGui)
pcall(setupNotificationSystem) -- Ensure this is called
updateBondCountDisplay()

notify("VERBAL Hub", "Auto Bond (Optimized V6) Initialized.", 7)
print("[VERBAL Hub] Auto Bond script ready. Controlled by external toggle.")

-- Start the main process if the toggle implies it should run
local initialFarmEnabled = getgenv().DeadRails and getgenv().DeadRails.Farm and typeof(getgenv().DeadRails.Farm.Enabled) == "boolean" and getgenv().DeadRails.Farm.Enabled or false

if initialFarmEnabled then
    if not getgenv().VerbalHubDrBondActive then
        getgenv().VerbalHubDrBondActive = true
        mainProcessCoroutine = coroutine.create(runMainBondCollectionProcess)
        local success, err = coroutine.resume(mainProcessCoroutine)
        if not success then
            warn("[VERBAL Hub] Failed to auto-start main process coroutine:", err)
            getgenv().VerbalHubDrBondActive = false; isScriptActive = false; shouldScriptRunGlobal = false
            cleanupAndStopScript()
        end
    else
        print("[VERBAL Hub] Main process already marked active by getgenv flag.")
    end
else
    print("[VERBAL Hub] External toggle is initially false. Script will wait.")
    shouldScriptRunGlobal = false -- Don't run main logic if toggle is initially off
    isScriptActive = false
    if bondStatusLabel and bondStatusLabel.Parent then bondStatusLabel.Text = "Bonds: Waiting" end
end

-- Start monitoring the external toggle only if the script is meant to run based on initial check
if shouldScriptRunGlobal or initialFarmEnabled then -- Start monitor if initially on, or if it was meant to be on but failed
    coroutine.wrap(monitorExternalToggle)()
else
    -- If initially off, the monitor will start if the toggle script re-runs this script when it's turned on.
    -- However, to be safe, if this script instance persists, it should still monitor.
    -- The current logic in monitorExternalToggle will break if cleanupAndStopScript is called.
    -- If the script is loaded while toggle is off, shouldScriptRunGlobal is set to false.
    -- The monitor loop condition `while shouldScriptRunGlobal` will prevent it from running uselessly.
    -- Let's refine the monitor start: always start it, its internal logic will handle state.
    coroutine.wrap(monitorExternalToggle)()
end

print("[VERBAL Hub] Script initialization sequence complete.")

