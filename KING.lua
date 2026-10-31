local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- [1] ระบบ Anti-AFK และ Bypass พับจอ
LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), Camera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), Camera.CFrame)
end)
if setfpscap then setfpscap(60) end

-- [2] ตัวแปรติดตามสถิติ
local startTime = tick()
local totalKills = 0
local startMoney = 0
local currentTarget = nil

-- ลองหาจำนวนเงิน (เพิ่มคำว่า Points ที่หลายเกมชอบใช้)
local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
if leaderstats then
    local moneyStat = leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Money") or leaderstats:FindFirstChild("Coins") or leaderstats:FindFirstChild("Points")
    if moneyStat then startMoney = moneyStat.Value end
end

-- [3] สร้าง UI (Dark Modern Theme)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AltemisLite_Clone"
ScreenGui.ResetOnSpawn = false
local success = pcall(function() ScreenGui.Parent = CoreGui end)
if not success then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 180)
MainFrame.Position = UDim2.new(0.5, -150, 0.8, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local function createLabel(text, yPos)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -40, 0, 30)
    label.Position = UDim2.new(0, 20, 0, yPos)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 14
    label.Text = text
    label.Parent = MainFrame
    return label
end

local TitleLabel = createLabel("✨ AUTO FARM STATUS", 10)
TitleLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
local TimeLabel = createLabel("⏱️ Time Elapsed: 00:00", 50)
local KillLabel = createLabel("💀 Zombies Killed: 0", 85)
local MoneyLabel = createLabel("💰 Money/Min: 0", 120)

local HideHint = createLabel("Press [Right Ctrl] to Toggle UI", 155)
HideHint.TextSize = 11
HideHint.TextColor3 = Color3.fromRGB(100, 120, 100)
HideHint.TextXAlignment = Enum.TextXAlignment.Center

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.RightControl then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- ลูปอัปเดตสถิติ UI
task.spawn(function()
    while task.wait(1) do
        local elapsed = tick() - startTime
        local mins = math.floor(elapsed / 60)
        local secs = math.floor(elapsed % 60)
        TimeLabel.Text = string.format("⏱️ Time Elapsed: %02d:%02d", mins, secs)
        
        KillLabel.Text = "💀 Zombies Killed: " .. tostring(totalKills)
        
        local currentMoney = startMoney
        if leaderstats then
            local stat = leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Money") or leaderstats:FindFirstChild("Coins") or leaderstats:FindFirstChild("Points")
            if stat then currentMoney = stat.Value end
        else
            currentMoney = startMoney + (totalKills * 50) -- ประเมินเงินถ้าเกมใช้ GUI พิเศษแบบในภาพ
        end
        
        local earned = currentMoney - startMoney
        local moneyPerMin = mins > 0 and math.floor(earned / (elapsed / 60)) or earned
        MoneyLabel.Text = "💰 Money/Min: " .. tostring(moneyPerMin)
    end
end)

-- [4] ระบบ Auto-Aim & Shoot
local RaycastParamsCheck = RaycastParams.new()
RaycastParamsCheck.FilterType = Enum.RaycastFilterType.Exclude
RaycastParamsCheck.FilterDescendantsInstances = {LocalPlayer.Character} 
local SMOOTHNESS = 0.15 
local lastShot = tick()
local currentDelay = math.random(80, 150) / 1000 

-- ฟังก์ชันค้นหาเป้าหมาย (แก้ให้หาศัตรูแบบครอบจักรวาล ไม่สนชื่อโมเดล)
local function getTarget()
    local bestTarget, shortestDist = nil, math.huge
    -- ใช้ GetDescendants เพื่อควานหาเป้าหมายแม้ว่าเกมจะเอาซอมบี้ไปซ่อนไว้ใน Folder
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= LocalPlayer.Character and obj:FindFirstChild("Head") then
            local hum = obj:FindFirstChild("Humanoid")
            -- เงื่อนไข: มีชีวิตอยู่ และ "ไม่ใช่ผู้เล่นในเกม"
            if hum and hum.Health > 0 and not Players:GetPlayerFromCharacter(obj) then
                local headPos = obj.Head.Position
                local _, onScreen = Camera:WorldToViewportPoint(headPos)
                if onScreen then
                    local origin = Camera.CFrame.Position
                    local dir = (headPos - origin).Unit * (headPos - origin).Magnitude
                    local ray = Workspace:Raycast(origin, dir, RaycastParamsCheck)
                    if not ray or ray.Instance:IsDescendantOf(obj) then
                        local dist = (headPos - origin).Magnitude
                        if dist < shortestDist then shortestDist, bestTarget = dist, obj end
                    end
                end
            end
        end
    end
    return bestTarget
end

RunService.Heartbeat:Connect(function()
    -- แก้บัคระบบนับคิล (ต้องเช็คก่อนที่จะหาเป้าหมายใหม่)
    if currentTarget then
        local hum = currentTarget:FindFirstChild("Humanoid")
        -- ถ้าร่างซอมบี้หายไป หรือ เลือดเหลือ 0 แปลว่าตายแล้ว
        if not currentTarget:IsDescendantOf(Workspace) or (hum and hum.Health <= 0) then
            totalKills = totalKills + 1
            currentTarget = nil
        end
    end

    local targetModel = getTarget()
    if targetModel and targetModel:FindFirstChild("Head") then
        currentTarget = targetModel
        local targetHead = targetModel.Head
        
        local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, targetHead.Position)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, SMOOTHNESS)
        
        if (Camera.CFrame.LookVector - targetCFrame.LookVector).Magnitude < 0.1 then
            if tick() - lastShot >= currentDelay then
                lastShot = tick()
                currentDelay = math.random(80, 150) / 1000
                if mouse1click then mouse1click() end
            end
        end
    end
end)

-- [5] ระบบ Auto-Loot
Workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("ProximityPrompt") then
        if fireproximityprompt then
            task.wait(0.2)
            fireproximityprompt(descendant)
        end
    end
end)
