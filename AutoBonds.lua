-- Utility: Get Remote Instance
local function getRemote(baseObject, pathString)
    if not pathString or pathString == "" then return nil end
    local pathParts = pathString:split(".")
    local currentObject = baseObject
    for _, partName in ipairs(pathParts) do
        if not currentObject then return nil end
        currentObject = currentObject:FindFirstChild(partName, true)
    end
    if currentObject then
        -- print("[VERBAL Hub Debug] Found remote:", currentObject:GetFullName())
    else
        -- warn("[VERBAL Hub Debug] Did NOT find remote at path:", pathString, "from base", baseObject:GetFullName())
    end
    return currentObject
end
