--[[
    VERBAL Hub - Auto Bond Collector (Auto-Start, Externally Controlled)
    Focus: Auto-starts, controlled by external getgenv flag, robust cleanup, performance enhancements.
    Version: 2.0 (Refactored for Speed and Reliability)
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

-- Script Configuration
local CONFIG = {
    REMOTE_PATHS = {
        C_ActivateObject = "Shared.Network.RemotePromise.Remotes.C_ActivateObject", -- VERIFY THIS PATH!
        EquipObject_Object = "Remotes.Object.EquipObject", -- VERIFY!
        PickUpTool_Tool = "Remotes.Tool.PickUpTool", -- VERIFY!
        EndDecision = "Remotes.EndDecision" -- VERIFY!
    },
    SPEED = {
        pathNavigation = 3200, -- Increased for potentially faster path traversal, adjust if issues occur
        teleportToBondSettleTime = 0.05,
        postCollectionAttemptDelay = 0.03,
        bondPickupAttemptDuration = 0.25,
        bondPickupRetryDelay = 0.02,
        equipItemDelay = 0.15, -- Slightly reduced
        equipSequenceLoopDelay = 0.6 -- Slightly reduced
    },
    BOND_COLLECTION_RADIUS = 75, -- Original value, seems fine for teleport strategy
    MIN_PATH_SCAN_TIME = 15, -- Reduced slightly, assumes faster scanning or quicker bond appearance
    MAX_TELEPORT_ATTEMPTS_PER_BOND = 3, -- Slightly reduced; if teleport is accurate, fewer attempts needed
    EXTERNAL_TOGGLE_CHECK_INTERVAL = 0.5 -- Seconds
}

-- State Variables
local foundBondsData = {} -- List of bond data to maintain collection order
local knownBondInstances = {} -- Set (table used as a set) for fast lookup of already found bond models
local collectedBondsCount = 0
local totalBondsToCollect = 0 -- Total unique bonds identified during scan
local mainProcessCoroutine = nil
local isScriptActive = false -- Internal flag for main process
local shouldScriptRunGlobal = true -- Master control switch

-- GUI Elements (forward declaration)
local screenGui, uiContainer, bondStatusLabel
local notificationGuiStore, notificationContainer

-- Event Connections Storage
local eventConnections = {}
local warnedMissingRemotes = {} -- To avoid spamming warnings for the same missing remote

-- Forward declaration for cleanup
local cleanupAndStopScript

-- Utility: Initialize Character Variables
local function initializeCharacter()
    char = player.Character
    if not char then
        -- print("[VERBAL Hub] Waiting for character to load...")
        char = player.CharacterAdded:Wait()
        -- print("[VERBAL Hub] Character loaded.")
    end
    if not char then
        warn("[VERBAL Hub] CRITICAL: Character is nil even after CharacterAdded:Wait().")
        return false
    end

    hrp = char:WaitForChild("HumanoidRootPart", 7) -- Reduced timeout slightly
    humanoid = char:WaitForChild("Humanoid", 7)   -- Reduced timeout slightly

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
        if not currentObject then
            if not warnedMissingRemotes[pathString] then
                -- warn("[VERBAL Hub Debug] Failed to find part of path: '", partName, "' in '", pathString, "' starting from ", baseObject:GetFullName())
                warnedMissingRemotes[pathString] = true
            end
            return nil
        end
        currentObject = currentObject:FindFirstChild(partName, false) -- Changed recursive to false for slight optimization if structure is known
    end
    if currentObject then
        -- print("[VERBAL Hub Debug] Found remote:", currentObject:GetFullName())
    elseif not warnedMissingRemotes[pathString] then
        -- warn("[VERBAL Hub Debug] Did NOT find remote at path:", pathString, "from base", baseObject:GetFullName())
        warnedMissingRemotes[pathString] = true
    end
    return currentObject
end

-- GUI Update Function
local function updateBondCountDisplay()
    if bondStatusLabel and bondStatusLabel.Parent then
        local totalText
        if not isScriptActive and totalBondsToCollect == 0 then
            totalText = "N/A"
        elseif isScriptActive and totalBondsToCollect == 0 and #foundBondsData == 0 then -- Or use a specific "scanning" state
            totalText = "Scanning..."
        else
            totalText = tostring(totalBondsToCollect)
        end
        bondStatusLabel.Text = string.format("Bonds: %d/%s", collectedBondsCount, totalText)
    end
end

-- Path for initial bond scanning (remains the same)
local pathPoints = {
    Vector3.new(13.66,120,29620.67),Vector3.new(-15.98,120,28227.97),Vector3.new(-63.54,120,26911.59),Vector3.new(-75.71,120,25558.11),Vector3.new(-49.51,120,24038.67),Vector3.new(-34.48,120,22780.89),Vector3.new(-63.71,120,21477.32),Vector3.new(-84.23,120,19970.94),Vector3.new(-84.76,120,18676.13),Vector3.new(-87.32,120,17246.92),Vector3.new(-95.48,120,15988.29),Vector3.new(-93.76,120,14597.43),Vector3.new(-86.29,120,13223.68),Vector3.new(-97.56,120,11824.61),Vector3.new(-92.71,120,10398.51),Vector3.new(-98.43,120,9092.45),Vector3.new(-90.89,120,7741.15),Vector3.new(-86.46,120,6482.59),Vector3.new(-77.49,120,5081.21),Vector3.new(-73.84,120,3660.66),Vector3.new(-73.84,120,2297.51),Vector3.new(-76.56,120,933.68),Vector3.new(-81.48,120,-429.93),Vector3.new(-83.47,120,-1683.45),Vector3.new(-94.18,120,-3035.25),Vector3.new(-109.96,120,-4317.15),Vector3.new(-119.63,120,-5667.43),Vector3.new(-118.63,120,-6942.88),Vector3.new(-118.09,120,-8288.66),Vector3.new(-132.12,120,-9690.39),Vector3.new(-122.83,120,-11051.38),Vector3.new(-117.53,120,-12412.74),Vector3.new(-119.81,120,-13762.14),Vector3.new(-126.27,120,-15106.33),Vector3.new(-134.45,120,-16563.82),Vector3.new(-129.85,120,-17884.73),Vector3.new(-127.23,120,-19234.89),Vector3.new(-133.49,120,-20584.07),Vector3.new(-137.89,120,-21933.47),Vector3.new(-139.93,120,-23272.51),Vector3.new(-144.12,120,-24612.54),Vector3.new(-142.93,120,-25962.13),Vector3.new(-149.21,120,-27301.58),Vector3.new(-156.19,120,-28640.93),Vector3.new(-164.87,120,-29990.78),Vector3.new(-177.65,120,-31340.21),Vector3.new(-184.67,120,-32689.24),Vector3.new(-208.92,120,-34027.44),Vector3.new(-227.96,120,-35376.88),Vector3.new(-239.45,120,-36726.59),Vector3.new(-250.48,120,-38075.91),Vector3.new(-260.28,120,-39425.56),Vector3.new(-274.86,120,-40764.67),Vector3.new(-297.45,120,-42103.61),Vector3.new(-321.64,120,-43442.59),Vector3.new(-356.78,120,-44771.52),Vector3.new(-387.68,120,-46100.94),Vector3.new(-415.83,120,-47429.85),Vector3.new(-452.39,120,-49407.44)
}

-- Scan for Bonds (during path navigation) - OPTIMIZED
local function scanForBondsOnPath()
    if not shouldScriptRunGlobal or not hrp or not Workspace:FindFirstChild("RuntimeItems") then return end

    local runtimeItems = Workspace.RuntimeItems
    for _, m in ipairs(runtimeItems:GetChildren()) do
        if not shouldScriptRunGlobal then break end
        -- Check if it's a bond and has a primary part, and we haven't seen this specific instance before
        if m:IsA("Model") and m.Name == "Bond" and m.PrimaryPart and not knownBondInstances[m] then
            knownBondInstances[m] = true -- Mark this instance as known
            table.insert(foundBondsData, {position = m.PrimaryPart.Position, model = m, collected = false, attempts = 0})
            totalBondsToCollect = totalBondsToCollect + 1 -- Increment total unique bonds
            updateBondCountDisplay() -- Update display only when a new bond is added
        end
    end
end

-- Attempt to Collect a Specific Bond Model
local function attemptCollectSpecificBondModel(bondModelInstance)
    if not shouldScriptRunGlobal or not bondModelInstance or not bondModelInstance.Parent then return false end
    local collected = false
    local primaryPart = bondModelInstance.PrimaryPart or bondModelInstance:FindFirstChild("Part") or bondModelInstance:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        warn("[VERBAL Hub] Bond model", bondModelInstance:GetFullName(), "missing primary part for collection.")
        return false
    end

    -- Try ClickDetector first if available
    if typeof(fireclickdetector) == "function" then
        local clickDetector = primaryPart:FindFirstChildWhichIsA("ClickDetector")
        if clickDetector then
            local suc_cd, err_cd = pcall(fireclickdetector, clickDetector)
            if suc_cd then
                collected = true
                -- print("[VERBAL Hub] Collected via ClickDetector:", bondModelInstance.Name)
            else
                warn("[VERBAL Hub] ClickDetector FAILED for", bondModelInstance.Name, ":", tostring(err_cd))
            end
        end
    end

    -- Fallback to C_ActivateObject remote if ClickDetector didn't work or isn't present
    if not collected then
        local C_ActivateObject = getRemote(ReplicatedStorage, CONFIG.REMOTE_PATHS.C_ActivateObject)
        if C_ActivateObject then
            local suc_remote, err_remote = pcall(C_ActivateObject.FireServer, C_ActivateObject, bondModelInstance)
            if suc_remote then
                collected = true
                -- print("[VERBAL Hub] Collected via C_ActivateObject:", bondModelInstance.Name)
            else
                warn("[VERBAL Hub] C_ActivateObject FAILED for", bondModelInstance.Name, ":", tostring(err_remote))
            end
        else
            warn("[VERBAL Hub] C_ActivateObject remote not found for collection.")
        end
    end
    return collected
end


-- Main Process Logic
local function runMainBondCollectionProcess()
    if not initializeCharacter() then
        warn("[VERBAL Hub] Character/HRP/Humanoid not available at main process start. Aborting.")
        isScriptActive = false
        shouldScriptRunGlobal = false
        cleanupAndStopScript() -- Critical failure, stop entirely
        return
    end
    isScriptActive = true
    print("[VERBAL Hub] Starting main bond collection process...")

    -- Reset state for this run
    foundBondsData = {}
    knownBondInstances = {}
    collectedBondsCount = 0
    totalBondsToCollect = 0
    updateBondCountDisplay()

    -- Connect bond scanning to Heartbeat during path navigation
    if eventConnections["ScanHeartbeat"] then eventConnections["ScanHeartbeat"]:Disconnect() end
    eventConnections["ScanHeartbeat"] = RunService.Heartbeat:Connect(scanForBondsOnPath)

    print("[VERBAL Hub] Navigating path to scan for bonds...")
    local pathScanStartTime = tick()
    for i, targetPos in ipairs(pathPoints) do
        if not shouldScriptRunGlobal or not hrp or not humanoid or humanoid.Health <= 0 then
            warn("[VERBAL Hub] Aborting path navigation: script stopped or character issue.")
            break
        end
        local dist = (hrp.Position - targetPos).Magnitude
        if dist < 5 then task.wait(); continue end -- Allow small threshold

        local tweenDuration = dist / CONFIG.SPEED.pathNavigation
        local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(targetPos)})
        tween:Play()

        local startedWaiting = tick()
        while tween.PlaybackState == Enum.PlaybackState.Playing and (tick() - startedWaiting) < (tweenDuration + 1.5) do -- Reduced timeout buffer
            if not shouldScriptRunGlobal or not hrp or not humanoid or humanoid.Health <= 0 then
                tween:Cancel()
                warn("[VERBAL Hub] Tween interrupted during path navigation.")
                break
            end
            task.wait() -- Yield every frame while tweening
        end
        if tween.PlaybackState == Enum.PlaybackState.Playing then tween:Cancel() end
    end

    -- Disconnect Heartbeat scan once path navigation is complete
    if eventConnections["ScanHeartbeat"] then eventConnections["ScanHeartbeat"]:Disconnect(); eventConnections["ScanHeartbeat"] = nil end
    
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped during path scan."); isScriptActive = false; return end

    updateBondCountDisplay() -- Final update after scan phase
    print("[VERBAL Hub] Path navigation complete. Found", totalBondsToCollect, "potential bond locations.")

    local timeTakenForPathScan = tick() - pathScanStartTime
    if timeTakenForPathScan < CONFIG.MIN_PATH_SCAN_TIME then
        local waitDuration = CONFIG.MIN_PATH_SCAN_TIME - timeTakenForPathScan
        if waitDuration > 0 then
            print(string.format("[VERBAL Hub] Path scan finished in %.1fs. Waiting an additional %.1fs for min scan time.", timeTakenForPathScan, waitDuration))
            task.wait(waitDuration)
        end
    end
    
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped after path scan wait."); isScriptActive = false; return end

    -- Key simulation (e.g., for tool equip or mode switch)
    if VirtualInputManager then
        print("[VERBAL Hub] Simulating KeyCode.Two press.")
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
            task.wait(0.05); if not shouldScriptRunGlobal then return end
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
        end)
    end
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped during key simulation."); isScriptActive = false; return end

    -- External Castle TP Script
    print("[VERBAL Hub] Loading external castle TP script...")
    local castleTpSuccess = pcall(function()
        local castleScriptUrl = "https://raw.githubusercontent.com/ringtaa/castletpfast.github.io/main/FASTCASTLE.lua"
        local scriptContent, err = game:HttpGet(castleScriptUrl, true)
        if not scriptContent then 
            warn("[VERBAL Hub] Failed to HttpGet castle TP script:", err)
            return 
        end
        local loadedFunc, loadErr = loadstring(scriptContent)
        if not loadedFunc then
            warn("[VERBAL Hub] Failed to loadstring castle TP script:", loadErr)
            return
        end
        loadedFunc()
    end)
    if not castleTpSuccess then warn("[VERBAL Hub] Error occurred during castle TP script execution.") end

    task.wait(2.5); if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped after castle TP attempt."); isScriptActive = false; return end

    -- Equip Items
    local function equipItem(itemNameQuery)
        if not shouldScriptRunGlobal or not hrp or not Workspace:FindFirstChild("RuntimeItems") then return false end
        local itemModel = nil
        for _, m in ipairs(Workspace.RuntimeItems:GetChildren()) do
            if m:IsA("Model") and m.Name:lower():find(itemNameQuery:lower()) then itemModel = m; break end
        end
        if itemModel then
            local equipRemote = getRemote(ReplicatedStorage, CONFIG.REMOTE_PATHS.EquipObject_Object) or getRemote(ReplicatedStorage, CONFIG.REMOTE_PATHS.PickUpTool_Tool)
            if equipRemote then
                local suc, err = pcall(equipRemote.FireServer, equipRemote, itemModel)
                if not suc then warn("[VERBAL Hub] Equip remote FAILED for", itemModel.Name, ":", err); return false end
                return true
            else warn("[VERBAL Hub] Could not find a suitable equip remote for '", itemNameQuery, "'. Searched paths: ", CONFIG.REMOTE_PATHS.EquipObject_Object, " & ", CONFIG.REMOTE_PATHS.PickUpTool_Tool) end
        else
            -- warn("[VERBAL Hub] Could not find item model containing '", itemNameQuery, "' in RuntimeItems.")
        end
        return false
    end

    print("[VERBAL Hub] Starting item equipping sequence...")
    for i = 1, 2 do -- Loop twice for equip sequence
        if not shouldScriptRunGlobal or not hrp or not humanoid or humanoid.Health <= 0 then break end
        equipItem("shovel"); task.wait(CONFIG.SPEED.equipItemDelay); if not shouldScriptRunGlobal then break end
        equipItem("sack"); task.wait(CONFIG.SPEED.equipItemDelay); if not shouldScriptRunGlobal then break end
        if VirtualInputManager then
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game)
                task.wait(0.05); if not shouldScriptRunGlobal then return end
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
            end)
        end
        if not shouldScriptRunGlobal then break end
        task.wait(CONFIG.SPEED.equipSequenceLoopDelay)
    end
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped during equipping."); isScriptActive = false; return end
    print("[VERBAL Hub] Item equipping sequence finished.")

    -- Collect Bonds
    print("[VERBAL Hub] Starting bond collection sequence...")
    if #foundBondsData == 0 then
        print("[VERBAL Hub] No bonds found to collect after scan and setup.")
    end

    for bondIdx, bondData in ipairs(foundBondsData) do
        if not shouldScriptRunGlobal or not hrp or not humanoid or humanoid.Health <= 0 then break end
        if bondData.collected then continue end -- Already marked as collected (e.g. if collected during scan somehow)

        -- Teleport to bond
        hrp.CFrame = CFrame.new(bondData.position + Vector3.new(0, 3.5, 0)) -- Small offset above bond
        task.wait(CONFIG.SPEED.teleportToBondSettleTime)
        if not shouldScriptRunGlobal then break end

        local collectionAttemptStartTime = tick()
        bondData.attempts = 0
        repeat
            bondData.attempts = bondData.attempts + 1
            if bondData.model and bondData.model.Parent then -- Check if model still exists
                attemptCollectSpecificBondModel(bondData.model)
            else -- Model disappeared before we could try, or after a failed try
                if not bondData.collected then
                    -- print("[VERBAL Hub] Bond model", bondIdx, "is nil or parented to nil before/during collection attempt. Assuming collected.")
                    bondData.collected = true
                    collectedBondsCount = collectedBondsCount + 1
                    updateBondCountDisplay()
                end
                break
            end
            task.wait(0.01) -- Tiny yield to allow game state (like model removal) to update

            if not bondData.model or not bondData.model.Parent then -- Check again if model disappeared after attempt
                if not bondData.collected then
                    print("[VERBAL Hub] Bond model", bondIdx, "disappeared. Confirmed collected.")
                    bondData.collected = true
                    collectedBondsCount = collectedBondsCount + 1
                    updateBondCountDisplay()
                end
                break
            end
            if bondData.collected then break end -- In case attemptCollect marks it
            task.wait(CONFIG.SPEED.bondPickupRetryDelay)
        until not shouldScriptRunGlobal or bondData.collected or (tick() - collectionAttemptStartTime > CONFIG.SPEED.bondPickupAttemptDuration) or bondData.attempts >= CONFIG.MAX_TELEPORT_ATTEMPTS_PER_BOND
        
        if not bondData.collected and shouldScriptRunGlobal then
            warn("[VERBAL Hub] Failed to confirm collection for bond", bondIdx, "at", bondData.position, "after", bondData.attempts, "attempts.")
        elseif bondData.collected and not (bondData.model and bondData.model.Parent) then
             -- Successfully collected and model is gone
        elseif bondData.collected then
            -- print("[VERBAL Hub] Bond", bondIdx, "collected, but model instance might still exist (or was re-parented unexpectedly).")
        end
        task.wait(CONFIG.SPEED.postCollectionAttemptDelay)
    end
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped during bond collection."); isScriptActive = false; return end
    print("[VERBAL Hub] Bond collection sequence finished. Collected:", collectedBondsCount, "/", totalBondsToCollect)

    -- Reset Character
    local function safeReset()
        if player and player.Character and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0 then
            print("[VERBAL Hub] Performing safe character reset.")
            pcall(function() player.Character.Humanoid.Health = 0 end)
        end
    end
    safeReset(); task.wait(1.5) -- Increased wait slightly for reset to process
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped after reset."); isScriptActive = false; return end

    updateBondCountDisplay() -- Update display after reset if needed
    task.wait(1)

    -- End Decision
    print("[VERBAL Hub] Waiting 15 seconds before firing EndDecision.")
    task.wait(15)
    if not shouldScriptRunGlobal then print("[VERBAL Hub] Script stopped before EndDecision."); isScriptActive = false; return end
    local endDecisionRemote = getRemote(ReplicatedStorage, CONFIG.REMOTE_PATHS.EndDecision)
    if endDecisionRemote then
        print("[VERBAL Hub] Firing EndDecision remote.")
        local suc, err = pcall(endDecisionRemote.FireServer, endDecisionRemote, false)
        if not suc then warn("[VERBAL Hub] EndDecision remote fire FAILED:", err) end
    else warn("[VERBAL Hub] EndDecision remote not found (Path: ", CONFIG.REMOTE_PATHS.EndDecision, ")") end

    print("[VERBAL Hub] Main process finished a cycle.")
    isScriptActive = false
    getgenv().VerbalHubDrBondActive = false -- Signal that this cycle is complete

    -- The external toggle monitor will handle full shutdown or allow re-activation
    -- if the main getgenv().DeadRails.Farm.Enabled is still true and the loader re-runs the script.
end


-- === VERBAL Hub GUI Setup (Largely unchanged, minor tweaks for robustness) ===
local function setupVerbalHubGui()
    if CoreGui:FindFirstChild("VERBAL Hub/dead rails") then
        screenGui = CoreGui:FindFirstChild("VERBAL Hub/dead rails")
        -- Attempt to find existing components, if not, it will be recreated
        local mainFrame = screenGui:FindFirstChild("MainFrame")
        if mainFrame then uiContainer = mainFrame:FindFirstChild("UIContainer") end
        if uiContainer then bondStatusLabel = uiContainer:FindFirstChild("BondStatusLabel") end

        if bondStatusLabel and bondStatusLabel.Parent then -- Check if a key component exists
            print("[VERBAL Hub] GUI seems to already exist and is partially intact.")
            return -- Assume it's usable
        end
        print("[VERBAL Hub] Found old/incomplete GUI, destroying and recreating.")
        screenGui:Destroy() -- Destroy incomplete or old GUI
        screenGui, uiContainer, bondStatusLabel = nil,nil,nil -- Clear variables
    end

    screenGui = Instance.new("ScreenGui", CoreGui); screenGui.Name = "VERBAL Hub/dead rails"; screenGui.ResetOnSpawn = false; screenGui.IgnoreGuiInset = true; screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local mainFrame = Instance.new("Frame", screenGui); mainFrame.Name = "MainFrame"; mainFrame.Size = UDim2.fromScale(1,1); mainFrame.BackgroundTransparency = 1
    
    local blurEffectName = "VerbalHubBlur_DR" -- Make blur name more specific to this script
    local blur = Lighting:FindFirstChild(blurEffectName) or Instance.new("BlurEffect", Lighting)
    blur.Name = blurEffectName; blur.Size = 0; blur.Enabled = false

    uiContainer = Instance.new("Frame", mainFrame); uiContainer.Name = "UIContainer"; uiContainer.Size = UDim2.new(0,450,0,250); uiContainer.Position = UDim2.new(0.5,-225,1,120); uiContainer.BackgroundColor3 = Color3.fromRGB(24,24,24); uiContainer.BackgroundTransparency = 0.05; uiContainer.ClipsDescendants = true
    Instance.new("UICorner", uiContainer).CornerRadius = UDim.new(0,16)
    local stroke = Instance.new("UIStroke", uiContainer); stroke.Thickness = 2; stroke.Color = Color3.fromRGB(57,255,20); stroke.Transparency = 0.3; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local gradient = Instance.new("UIGradient", uiContainer); gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(57,255,20)),ColorSequenceKeypoint.new(1,Color3.fromRGB(35,35,35))}); gradient.Rotation = 45

    local minimizeButton = Instance.new("TextButton",uiContainer); minimizeButton.Name = "MinimizeButton"; minimizeButton.Size = UDim2.new(0,30,0,30); minimizeButton.Position = UDim2.new(1,-40,0,10); minimizeButton.BackgroundColor3 = Color3.fromRGB(50,50,50); minimizeButton.Text = "-"; minimizeButton.TextColor3 = Color3.fromRGB(255,255,255); minimizeButton.Font = Enum.Font.FredokaOne; minimizeButton.TextSize = 20
    Instance.new("UICorner",minimizeButton).CornerRadius = UDim.new(0,8)

    local icon = Instance.new("ImageLabel",uiContainer); icon.Name = "Icon"; icon.Size = UDim2.new(0,64,0,64); icon.Position = UDim2.new(0.5,-32,0,16); icon.BackgroundTransparency = 1; icon.Image = "rbxassetid://9884857489"

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
        local uiAbsSize = uiContainer.AbsoluteSize
        local viewportSize = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720) -- Fallback

        local containerWidth = uiAbsSize.X > 0 and uiAbsSize.X or 450
        local containerHeight = uiAbsSize.Y > 0 and uiAbsSize.Y or 250

        local targetPos, targetSize = isMinimized and UDim2.new(0.5, -containerWidth / 2, 0, -containerHeight - 10) or UDim2.new(0.5, -containerWidth / 2, 0.5, -containerHeight / 2), 
                                      isMinimized and UDim2.fromOffset(containerWidth, 0) or UDim2.fromOffset(containerWidth, containerHeight)
        
        local targetBlurSize, targetMainFrameTransparency = isMinimized and 0 or 20, isMinimized and 1 or 0.4
        local compactTargetPos, compactVisible = isMinimized and UDim2.new(0.5,-30,0,10) or UDim2.new(0.5,-30,0,-80), isMinimized
        
        minimizeButton.Text = isMinimized and "➕" or "➖" -- Using different symbols
        
        TweenService:Create(uiContainer,TweenInfo.new(0.35,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Position=targetPos,Size=targetSize}):Play()
        TweenService:Create(mainFrame,TweenInfo.new(0.35,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=targetMainFrameTransparency}):Play()
        
        if blur and blur.Parent then 
            blur.Enabled = (targetBlurSize > 0)
            TweenService:Create(blur,TweenInfo.new(0.35),{Size=targetBlurSize}):Play()
        end
        
        if compactButton and compactButton.Parent then 
            if compactVisible then compactButton.Visible=true end
            TweenService:Create(compactButton,TweenInfo.new(0.3,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Position=compactTargetPos}):Play()
            if not compactVisible then task.delay(0.3,function() if compactButton.Parent and not isMinimized then compactButton.Visible=false end end) end
        end
    end
    if minimizeButton and minimizeButton.Parent then eventConnections["MinimizeClick"] = minimizeButton.MouseButton1Click:Connect(toggleMinimize) end
    if compactButton and compactButton.Parent then eventConnections["CompactClick"] = compactButton.MouseButton1Click:Connect(toggleMinimize) end

    task.wait(0.1) -- Ensure elements are rendered for AbsoluteSize
    if uiContainer and uiContainer.Parent and Workspace.CurrentCamera then
        local initialContainerWidth = uiContainer.AbsoluteSize.X > 0 and uiContainer.AbsoluteSize.X or 450
        local initialContainerHeight = uiContainer.AbsoluteSize.Y > 0 and uiContainer.AbsoluteSize.Y or 250
        local initialYPosScalar = 0.5 - (initialContainerHeight / 2 / Workspace.CurrentCamera.ViewportSize.Y)
        
        uiContainer.Position = UDim2.new(0.5, -initialContainerWidth/2, 1, 20) -- Start off-screen below
        mainFrame.BackgroundTransparency = 1 -- Start fully transparent

        TweenService:Create(mainFrame,TweenInfo.new(0.5,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{BackgroundTransparency = 0.4}):Play()
        TweenService:Create(uiContainer,TweenInfo.new(0.6,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position = UDim2.new(0.5,-initialContainerWidth/2, initialYPosScalar, 0)}):Play()
        
        if blur and blur.Parent then blur.Size = 0; blur.Enabled = true; TweenService:Create(blur, TweenInfo.new(0.6), {Size=20}):Play() end
    end
    print("[VERBAL Hub] GUI Setup Complete.")
end

-- Notification System (Largely unchanged)
local function setupNotificationSystem()
    notificationGuiStore = CoreGui:FindFirstChild("ModernNotificationUI_Verbal_DR") or Instance.new("ScreenGui", CoreGui)
    notificationGuiStore.Name = "ModernNotificationUI_Verbal_DR"; notificationGuiStore.ResetOnSpawn = false; notificationGuiStore.IgnoreGuiInset = true; notificationGuiStore.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; notificationGuiStore.DisplayOrder = 999999
    
    notificationContainer = notificationGuiStore:FindFirstChild("NotificationContainer")
    if not notificationContainer then
        notificationContainer = Instance.new("Frame", notificationGuiStore)
        notificationContainer.Name = "NotificationContainer"; notificationContainer.AnchorPoint = Vector2.new(1,1); notificationContainer.Size = UDim2.new(0,320,1,0); notificationContainer.Position = UDim2.new(1,-10,1,-10); notificationContainer.BackgroundTransparency = 1
        local layout = Instance.new("UIListLayout",notificationContainer); layout.Padding = UDim.new(0,8); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.VerticalAlignment = Enum.VerticalAlignment.Bottom; layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    end
end
local function notify(titleText, messageText, duration)
    if not notificationContainer or not notificationContainer.Parent then setupNotificationSystem() end
    duration = duration or 5
    
    local notif = Instance.new("Frame"); notif.Name = "NotificationItem"; notif.Size=UDim2.new(1,0,0,0); notif.BackgroundColor3=Color3.fromRGB(30,30,30); notif.BackgroundTransparency=1; notif.LayoutOrder=-tick(); notif.ClipsDescendants=true; notif.Parent = notificationContainer
    Instance.new("UICorner",notif).CornerRadius=UDim.new(0,10)
    local stroke=Instance.new("UIStroke",notif); stroke.Color=Color3.fromRGB(57,255,20); stroke.Thickness=1; stroke.Transparency=0.5
    
    local title=Instance.new("TextLabel",notif); title.Size=UDim2.new(1,-30,0,20); title.Position=UDim2.new(0,10,0,8); title.BackgroundTransparency=1; title.Text=titleText; title.TextColor3=Color3.fromRGB(255,255,255); title.Font=Enum.Font.FredokaOne; title.TextSize=16; title.TextXAlignment=Enum.TextXAlignment.Left
    local message=Instance.new("TextLabel",notif); message.Size=UDim2.new(1,-30,0,35); message.Position=UDim2.new(0,10,0,28); message.BackgroundTransparency=1; message.Text=messageText; message.TextColor3=Color3.fromRGB(200,200,200); message.Font=Enum.Font.FredokaOne; message.TextSize=13; message.TextWrapped=true; message.TextXAlignment=Enum.TextXAlignment.Left; message.TextYAlignment=Enum.TextYAlignment.Top
    
    local closeBtn=Instance.new("TextButton",notif); closeBtn.Size=UDim2.new(0,20,0,20); closeBtn.Position=UDim2.new(1,-25,0,5); closeBtn.Text="✕"; closeBtn.TextColor3=Color3.fromRGB(200,200,200); closeBtn.BackgroundTransparency=1; closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=16; closeBtn.ZIndex=2
    
    local progressBar=Instance.new("Frame",notif); progressBar.Size=UDim2.new(1,0,0,3); progressBar.Position=UDim2.new(0,0,1,-3); progressBar.BackgroundColor3=Color3.fromRGB(57,255,20); progressBar.BackgroundTransparency=0.3; progressBar.ZIndex=1; progressBar.BorderSizePixel = 0
    Instance.new("UICorner",progressBar).CornerRadius=UDim.new(0,3)
    local progressFill=Instance.new("Frame",progressBar); progressFill.Size=UDim2.new(1,0,1,0); progressFill.BackgroundColor3=Color3.fromRGB(57,255,20); progressFill.BackgroundTransparency=0; progressFill.BorderSizePixel = 0
    Instance.new("UICorner",progressFill).CornerRadius=UDim.new(0,3)
    
    TweenService:Create(notif,TweenInfo.new(0.3,Enum.EasingStyle.Quint, Enum.EasingDirection.Out),{Size=UDim2.new(1,0,0,70),BackgroundTransparency=0.1}):Play()
    TweenService:Create(progressFill,TweenInfo.new(duration,Enum.EasingStyle.Linear),{Size=UDim2.new(0,0,1,0)}):Play()
    
    local connectionId = "NotifClose_" .. notif:GetDebugId() -- More unique ID
    local function closeNotif()
        if eventConnections[connectionId] then eventConnections[connectionId]:Disconnect(); eventConnections[connectionId] = nil end
        if notif and notif.Parent then 
            local tween=TweenService:Create(notif,TweenInfo.new(0.3,Enum.EasingStyle.Quint, Enum.EasingDirection.In),{Size=UDim2.new(1,0,0,0),BackgroundTransparency=1}); 
            tween:Play()
            tween.Completed:Once(function() notif:Destroy() end)
        end 
    end
    eventConnections[connectionId] = closeBtn.MouseButton1Click:Connect(closeNotif)
    task.delay(duration, function() if notif and notif.Parent then closeNotif() end end)
end


-- Cleanup Function
cleanupAndStopScript = function()
    print("[VERBAL Hub] Initiating cleanup and stopping script...")
    shouldScriptRunGlobal = false -- Signal all loops and processes to stop
    isScriptActive = false
    if typeof(getgenv) == "function" then
      getgenv().VerbalHubDrBondActive = false
    end

    if mainProcessCoroutine and coroutine.status(mainProcessCoroutine) ~= "dead" then
        print("[VERBAL Hub] Main process coroutine was active. It should stop based on flags.")
        -- Note: Lua coroutines cannot be forcibly killed externally in a standard way.
        -- The 'shouldScriptRunGlobal' flag is the primary mechanism for graceful shutdown.
    end
    mainProcessCoroutine = nil

    for name, conn in pairs(eventConnections) do
        if conn and conn.Connected then
            pcall(function() conn:Disconnect() end)
        end
    end
    eventConnections = {} -- Clear stored connections
    warnedMissingRemotes = {} -- Clear warned remotes for next potential run

    if screenGui and screenGui.Parent then pcall(function() screenGui:Destroy() end); screenGui = nil end
    if notificationGuiStore and notificationGuiStore.Parent then pcall(function() notificationGuiStore:Destroy() end); notificationGuiStore = nil end
    
    local blurEffect = Lighting:FindFirstChild("VerbalHubBlur_DR")
    if blurEffect then pcall(function() blurEffect:Destroy() end) end

    if typeof(getgenv) == "function" then
      getgenv().VerbalHubDrBondLoaded = false -- Allow script to be reloaded by external toggle
    end
    print("[VERBAL Hub] Cleanup complete. Script stopped.")
end

-- Monitor External Toggle
local function monitorExternalToggle()
    print("[VERBAL Hub] External toggle monitor started.")
    while true do -- Loop indefinitely until script is fully cleaned up
        local farmEnabled = false
        if typeof(getgenv) == "function" and getgenv().DeadRails and getgenv().DeadRails.Farm then
            farmEnabled = getgenv().DeadRails.Farm.Enabled == true
        end

        if not farmEnabled and shouldScriptRunGlobal then -- If toggle was turned OFF while script was meant to run
            print("[VERBAL Hub] External toggle (DeadRails.Farm.Enabled) is now false. Initiating full script shutdown.")
            cleanupAndStopScript()
            break -- Exit monitor loop as script is shutting down
        elseif farmEnabled and not shouldScriptRunGlobal and typeof(getgenv) == "function" and not getgenv().VerbalHubDrBondLoaded then
            -- This case implies the script was shut down, but the toggle is on.
            -- The external loader script should handle reloading this script.
            -- This monitor loop will break after cleanup if it was triggered by the above condition.
            -- If script is just loaded but toggle is on, the main init will handle starting.
        end
        
        if not task.wait(CONFIG.EXTERNAL_TOGGLE_CHECK_INTERVAL) then break end -- In case task.wait is interrupted
        if not shouldScriptRunGlobal and not (typeof(getgenv) == "function" and getgenv().VerbalHubDrBondLoaded) then
            -- If script is fully cleaned up (DrBondLoaded = false), stop monitoring.
            break
        end
    end
    print("[VERBAL Hub] External toggle monitor stopped.")
end

-- Initialization Guard & Script Start
if typeof(getgenv) == "function" and getgenv().VerbalHubDrBondLoaded then
    notify("Verbal Hub", "Script already loaded. External toggle controls it.", 5)
    -- If it's already loaded, the monitor should be running or the script active.
    -- Avoid re-initializing everything.
    return
end

if typeof(getgenv) == "function" then
    getgenv().VerbalHubDrBondLoaded = true
    getgenv().VerbalHubDrBondActive = false
else
    warn("[VERBAL Hub] getgenv() is not available. External toggle and state saving will not work.")
end
shouldScriptRunGlobal = true -- Assume script should run initially if loaded

if not initializeCharacter() then
    notify("Verbal Hub Error", "CRITICAL: Failed to initialize character on start. Script cannot run.", 10)
    warn("[VERBAL Hub] CRITICAL FAILURE: Could not initialize character on script start. Cleaning up.")
    cleanupAndStopScript()
    return
end

-- Event connections crucial for script lifecycle
if not eventConnections["CharacterAdded"] then
    eventConnections["CharacterAdded"] = player.CharacterAdded:Connect(function(newChar)
        print("[VERBAL Hub] Player character respawned/added.")
        task.wait(0.75) -- Give some time for humanoid and other parts to be fully available
        if not initializeCharacter() then
            warn("[VERBAL Hub] Failed to re-initialize character on CharacterAdded. This may cause issues.")
            if shouldScriptRunGlobal then -- If script was supposed to be running, this is a critical failure
                notify("Verbal Hub Error", "Character re-init failed. Stopping.", 7)
                cleanupAndStopScript()
            end
        else
            print("[VERBAL Hub] Character re-initialized successfully after respawn.")
            -- If the main process was running and interrupted by death, the loader/toggle logic should restart it.
            -- For now, ensure 'isScriptActive' reflects it's not running the core loop if it died.
            if mainProcessCoroutine and coroutine.status(mainProcessCoroutine) ~= "dead" and isScriptActive then
                 -- This situation is tricky. A character respawn usually means the old process is invalid.
                 -- The 'shouldScriptRunGlobal' flag and checks within the main loop should handle termination.
                 -- isScriptActive might need to be reset by the main loop itself upon such failures.
            end
        end
    end)
end

if not eventConnections["PlayerRemoving"] then
    eventConnections["PlayerRemoving"] = Players.PlayerRemoving:Connect(function(leavingPlayer)
        if leavingPlayer == player then
            print("[VERBAL Hub] Local player is leaving. Cleaning up.")
            cleanupAndStopScript()
        end
    end)
end

-- Humanoid Died connection (more specific than CharacterAdded for interruptions)
if humanoid and not eventConnections["HumanoidDied"] then
    eventConnections["HumanoidDied"] = humanoid.Died:Connect(function()
        print("[VERBAL Hub] Humanoid died. Main process will be interrupted if active.")
        -- isScriptActive will be set to false by the main loop when it detects humanoid.Health <= 0
        -- or shouldScriptRunGlobal is false.
        -- No need to call cleanupAndStopScript() here directly, as the main loop and CharacterAdded
        -- should handle the state. Forcing a full cleanup here might be too aggressive if a
        -- quick respawn and continuation (via external toggle logic) is expected.
        -- The main loop should break, and VerbalHubDrBondActive would become false.
    end)
end


-- Setup GUI and Notifications
local guiSetupOk = pcall(setupVerbalHubGui)
if not guiSetupOk then warn("[VERBAL Hub] Error setting up main GUI.") end
local notifSetupOk = pcall(setupNotificationSystem)
if not notifSetupOk then warn("[VERBAL Hub] Error setting up notification system.") end
updateBondCountDisplay() -- Initial update

notify("VERBAL Hub", "Auto Bond (Externally Controlled) Initialized.", 7)
print("[VERBAL Hub] Auto Bond script ready. Logic controlled by external DeadRails.Farm.Enabled toggle.")

-- Main logic start based on external toggle
local initialFarmEnabled = false
if typeof(getgenv) == "function" and getgenv().DeadRails and getgenv().DeadRails.Farm then
    initialFarmEnabled = getgenv().DeadRails.Farm.Enabled == true
end

if initialFarmEnabled then
    if typeof(getgenv) == "function" and not getgenv().VerbalHubDrBondActive then
        print("[VERBAL Hub] External toggle is ON. Auto-starting main bond collection process.")
        getgenv().VerbalHubDrBondActive = true
        mainProcessCoroutine = coroutine.create(runMainBondCollectionProcess)
        local success, err = coroutine.resume(mainProcessCoroutine)
        if not success then
            warn("[VERBAL Hub] CRITICAL: Failed to start main process coroutine:", err)
            notify("Verbal Hub Error", "Main process failed to start. Check console.", 10)
            getgenv().VerbalHubDrBondActive = false
            isScriptActive = false
            shouldScriptRunGlobal = false
            cleanupAndStopScript() -- Cleanup if auto-start fails critically
        end
    elseif typeof(getgenv) == "function" and getgenv().VerbalHubDrBondActive then
        print("[VERBAL Hub] External toggle is ON, but main process already marked active. Not starting new instance.")
    else
         print("[VERBAL Hub] External toggle is ON, but getgenv() not available to check active state. Assuming should start.")
         -- This case is if getgenv isn't available, so we can't check VerbalHubDrBondActive
         isScriptActive = true -- Assume we should try
         mainProcessCoroutine = coroutine.create(runMainBondCollectionProcess)
         local success, err = coroutine.resume(mainProcessCoroutine)
         if not success then
            warn("[VERBAL Hub] CRITICAL: Failed to start main process coroutine (no getgenv):", err)
            isScriptActive = false
            shouldScriptRunGlobal = false
            cleanupAndStopScript()
         end
    end
else
    print("[VERBAL Hub] External toggle DeadRails.Farm.Enabled is initially false or not found. Script will idle.")
    shouldScriptRunGlobal = false -- Don't run main logic if toggle is initially off.
    isScriptActive = false
    if bondStatusLabel and bondStatusLabel.Parent then bondStatusLabel.Text = "Bonds: Waiting for toggle" end
end

-- Start monitoring the external toggle regardless of initial state
-- If the script is loaded, it should always monitor its control flag.
coroutine.wrap(monitorExternalToggle)()

print("[VERBAL Hub] Script initialization sequence complete.")

-- Ensure a final check for cleanup if script was meant to be off from the start but something went wrong.
if not shouldScriptRunGlobal and not isScriptActive and (typeof(getgenv) == "function" and getgenv().VerbalHubDrBondLoaded) and not initialFarmEnabled then
    -- If the toggle was off, and script is loaded but not active, ensure flags are consistent.
    -- This state is mostly okay, means it's waiting.
    print("[VERBAL Hub] Initial state: Loaded, toggle OFF, process inactive. Monitoring active.")
end
