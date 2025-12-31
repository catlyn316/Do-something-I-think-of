-- Roblox 速度/跳躍/無限跳/重力控制器
-- 功能：自定義移動速度、跳躍力、無限跳躍、重力修改

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

-- 防止重複執行清理舊介面
if CoreGui:FindFirstChild("SpeedJumpController") then CoreGui.SpeedJumpController:Destroy() end
if playerGui:FindFirstChild("SpeedJumpController") then playerGui.SpeedJumpController:Destroy() end

-- 初始值
local originalSpeed = 16
local originalJump = 50
local originalGravity = 196.2
local hasOriginalValues = false

local function getOriginalValues()
    if speedActive or jumpActive or gravActive or infJumpActive then return end
    
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            originalSpeed = humanoid.WalkSpeed
            if humanoid.UseJumpPower then
                originalJump = humanoid.JumpPower
            else
                originalJump = humanoid.JumpHeight
            end
        end
    end
    originalGravity = Workspace.Gravity
    hasOriginalValues = true
end

-- UI 容器
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpeedJumpController"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.DisplayOrder = 10001

local function parentUI(g)
    local success, err = pcall(function()
        if gethui then
            g.Parent = gethui()
        elseif game:GetService("CoreGui") then
            g.Parent = game:GetService("CoreGui")
        else
            g.Parent = playerGui
        end
    end)
    if not success then g.Parent = playerGui end
end
parentUI(screenGui)

-- 主框架
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, 250)
mainFrame.Position = UDim2.new(0.5, -130, 0.5, -125)
mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

-- 標題欄
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = Color3.fromRGB(102, 126, 234)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
local titleBarCorner = Instance.new("UICorner"); titleBarCorner.CornerRadius = UDim.new(0, 10); titleBarCorner.Parent = titleBar
local titleBarBottom = Instance.new("Frame"); titleBarBottom.Size = UDim2.new(1, 0, 0, 10); titleBarBottom.Position = UDim2.new(0, 0, 1, -10); titleBarBottom.BackgroundColor3 = Color3.fromRGB(102, 126, 234); titleBarBottom.BorderSizePixel = 0; titleBarBottom.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0)
title.BackgroundTransparency = 1
title.Text = "🎮 貓玲的全能控制器"
title.TextSize = 15
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Parent = titleBar

-- 縮小/關閉按鈕
local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 24, 0, 24)
minimizeButton.Position = UDim2.new(1, -54, 0, 4)
minimizeButton.BackgroundColor3 = Color3.fromRGB(158, 158, 158)
minimizeButton.Text = "─"; minimizeButton.TextSize = 15; minimizeButton.Font = Enum.Font.GothamBold; minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255); minimizeButton.Parent = titleBar
local minCorner = Instance.new("UICorner"); minCorner.CornerRadius = UDim.new(0, 5); minCorner.Parent = minimizeButton

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 24, 0, 24)
closeButton.Position = UDim2.new(1, -28, 0, 4)
closeButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
closeButton.Text = "X"; closeButton.TextSize = 15; closeButton.Font = Enum.Font.GothamBold; closeButton.TextColor3 = Color3.fromRGB(255, 255, 255); closeButton.Parent = titleBar
local closeCorner = Instance.new("UICorner"); closeCorner.CornerRadius = UDim.new(0, 5); closeCorner.Parent = closeButton

-- 通用函數：創建控制行
local function createControlRow(parent, yPos, labelText, placeholder, defaultVal, isInput)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 32)
    frame.Position = UDim2.new(0.05, 0, 0, yPos)
    frame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    local fCorner = Instance.new("UICorner"); fCorner.CornerRadius = UDim.new(0, 6); fCorner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 45, 1, 0)
    label.Position = UDim2.new(0, 6, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(85, 85, 85)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local input
    if isInput then
        input = Instance.new("TextBox")
        input.Size = UDim2.new(0, 70, 0, 22)
        input.Position = UDim2.new(0, 54, 0, 5)
        input.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        input.BorderColor3 = Color3.fromRGB(221, 221, 221)
        input.BorderSizePixel = 1
        input.Text = defaultVal
        input.TextSize = 13
        input.Font = Enum.Font.Gotham
        input.TextColor3 = Color3.fromRGB(50, 50, 50)
        input.PlaceholderText = placeholder
        input.Parent = frame
        local iCorner = Instance.new("UICorner"); iCorner.CornerRadius = UDim.new(0, 5); iCorner.Parent = input
    else
        input = Instance.new("TextLabel")
        input.Size = UDim2.new(0, 70, 0, 22)
        input.Position = UDim2.new(0, 54, 0, 5)
        input.BackgroundTransparency = 1
        input.Text = "關閉"
        input.TextSize = 13
        input.Font = Enum.Font.Gotham
        input.TextColor3 = Color3.fromRGB(150, 150, 150)
        input.TextXAlignment = Enum.TextXAlignment.Center
        input.Parent = frame
    end

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 56, 0, 22)
    btn.Position = UDim2.new(1, -60, 0, 5)
    btn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
    btn.BorderSizePixel = 0
    btn.Text = "啟動"
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Parent = frame
    local bCorner = Instance.new("UICorner"); bCorner.CornerRadius = UDim.new(0, 5); bCorner.Parent = btn

    return frame, input, btn
end

-- 創建控制行
local speedFrame, speedInput, speedButton = createControlRow(mainFrame, 44, "速度:", "輸入速度", "70", true)
local jumpFrame, jumpInput, jumpButton = createControlRow(mainFrame, 84, "跳躍:", "輸入跳躍", "75", true)
local infJumpFrame, infJumpStatus, infJumpButton = createControlRow(mainFrame, 124, "無限跳:", "", "", false)
local gravFrame, gravInput, gravButton = createControlRow(mainFrame, 164, "重力:", "輸入重力", "50", true)

-- 狀態顯示
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.9, 0, 0, 26)
statusLabel.Position = UDim2.new(0.05, 0, 1, -32)
statusLabel.BackgroundColor3 = Color3.fromRGB(255, 235, 238)
statusLabel.BorderSizePixel = 0
statusLabel.Text = "系統未啟動"
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextColor3 = Color3.fromRGB(198, 40, 40)
statusLabel.Parent = mainFrame
local statCorner = Instance.new("UICorner"); statCorner.CornerRadius = UDim.new(0, 5); statCorner.Parent = statusLabel

-- 小視窗
local miniFrame = Instance.new("Frame")
miniFrame.Size = UDim2.new(0, 130, 0, 32)
miniFrame.Position = UDim2.new(0.5, -65, 0, 30)
miniFrame.BackgroundColor3 = Color3.fromRGB(102, 126, 234)
miniFrame.Visible = false
miniFrame.Parent = screenGui
local mCorner = Instance.new("UICorner"); mCorner.CornerRadius = UDim.new(0, 6); mCorner.Parent = miniFrame
local miniTitle = Instance.new("TextLabel"); miniTitle.Size = UDim2.new(1, -36, 1, 0); miniTitle.BackgroundTransparency = 1; miniTitle.Text = "🎮 控制器"; miniTitle.TextSize = 13; miniTitle.Font = Enum.Font.GothamBold; miniTitle.TextColor3 = Color3.fromRGB(255, 255, 255); miniTitle.Parent = miniFrame
local expandButton = Instance.new("TextButton"); expandButton.Size = UDim2.new(0, 24, 0, 24); expandButton.Position = UDim2.new(1, -28, 0, 4); expandButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80); expandButton.Text = "+"; expandButton.TextSize = 18; expandButton.Font = Enum.Font.GothamBold; expandButton.TextColor3 = Color3.fromRGB(255, 255, 255); expandButton.Parent = miniFrame; local eCorner = Instance.new("UICorner"); eCorner.CornerRadius = UDim.new(0, 5); eCorner.Parent = expandButton

-- 邏輯變數
local speedActive = false
local jumpActive = false
local gravActive = false
local infJumpActive = false

local speedValue = 70
local jumpValue = 75
local gravValue = 50

local speedConnection = nil
local jumpConnection = nil
local gravConnection = nil
local infJumpConnection = nil

task.spawn(function()
    if player.Character then
        task.wait(0.1)
        getOriginalValues()
    end
end)

local function updateStatus()
    local parts = {}
    if speedActive then table.insert(parts, "速度") end
    if jumpActive then table.insert(parts, "跳躍") end
    if infJumpActive then table.insert(parts, "無限跳") end
    if gravActive then table.insert(parts, "重力") end
    
    if #parts > 0 then
        statusLabel.Text = "✅ " .. table.concat(parts, " | ") .. " 已啟動"
        statusLabel.BackgroundColor3 = Color3.fromRGB(232, 245, 233)
        statusLabel.TextColor3 = Color3.fromRGB(46, 125, 50)
    else
        statusLabel.Text = "系統未啟動"
        statusLabel.BackgroundColor3 = Color3.fromRGB(255, 235, 238)
        statusLabel.TextColor3 = Color3.fromRGB(198, 40, 40)
    end
end

-- 速度控制
speedButton.MouseButton1Click:Connect(function()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    if not speedActive then
        if not hasOriginalValues then getOriginalValues() end
        speedValue = tonumber(speedInput.Text) or 70
        speedActive = true
        speedButton.Text = "解除"
        speedButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
        speedInput.TextEditable = false
        speedFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
        
        hum.WalkSpeed = speedValue
        if speedConnection then speedConnection:Disconnect() end
        speedConnection = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if speedActive then hum.WalkSpeed = speedValue end
        end)
    else
        speedActive = false
        speedButton.Text = "啟動"
        speedButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        speedInput.TextEditable = true
        speedFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
        hum.WalkSpeed = originalSpeed
        if speedConnection then speedConnection:Disconnect() end
    end
    updateStatus()
end)

-- 跳躍控制
jumpButton.MouseButton1Click:Connect(function()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    if not jumpActive then
        if not hasOriginalValues then getOriginalValues() end
        jumpValue = tonumber(jumpInput.Text) or 75
        jumpActive = true
        jumpButton.Text = "解除"
        jumpButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
        jumpInput.TextEditable = false
        jumpFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
        
        if hum.UseJumpPower then
            hum.JumpPower = jumpValue
            if jumpConnection then jumpConnection:Disconnect() end
            jumpConnection = hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
                if jumpActive then hum.JumpPower = jumpValue end
            end)
        else
            hum.JumpHeight = jumpValue
            if jumpConnection then jumpConnection:Disconnect() end
            jumpConnection = hum:GetPropertyChangedSignal("JumpHeight"):Connect(function()
                if jumpActive then hum.JumpHeight = jumpValue end
            end)
        end
    else
        jumpActive = false
        jumpButton.Text = "啟動"
        jumpButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        jumpInput.TextEditable = true
        jumpFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
        
        if hum.UseJumpPower then hum.JumpPower = originalJump else hum.JumpHeight = originalJump end
        if jumpConnection then jumpConnection:Disconnect() end
    end
    updateStatus()
end)

-- 無限跳控制
infJumpConnection = UserInputService.JumpRequest:Connect(function()
    if infJumpActive then
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

infJumpButton.MouseButton1Click:Connect(function()
    if not infJumpActive then
        infJumpActive = true
        infJumpButton.Text = "解除"
        infJumpButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
        infJumpStatus.Text = "開啟"
        infJumpStatus.TextColor3 = Color3.fromRGB(46, 125, 50)
        infJumpFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
    else
        infJumpActive = false
        infJumpButton.Text = "啟動"
        infJumpButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        infJumpStatus.Text = "關閉"
        infJumpStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
        infJumpFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
    end
    updateStatus()
end)

-- 重力控制
gravButton.MouseButton1Click:Connect(function()
    if not gravActive then
        if not hasOriginalValues then getOriginalValues() end
        gravValue = tonumber(gravInput.Text) or 50
        gravActive = true
        gravButton.Text = "解除"
        gravButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
        gravInput.TextEditable = false
        gravFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
        
        Workspace.Gravity = gravValue
        
        if gravConnection then gravConnection:Disconnect() end
        gravConnection = Workspace:GetPropertyChangedSignal("Gravity"):Connect(function()
            if gravActive and Workspace.Gravity ~= gravValue then
                Workspace.Gravity = gravValue
            end
        end)
    else
        gravActive = false
        gravButton.Text = "啟動"
        gravButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        gravInput.TextEditable = true
        gravFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
        
        Workspace.Gravity = originalGravity
        if gravConnection then gravConnection:Disconnect() end
    end
    updateStatus()
end)

-- 視窗控制
minimizeButton.MouseButton1Click:Connect(function() mainFrame.Visible = false; miniFrame.Visible = true end)
expandButton.MouseButton1Click:Connect(function() miniFrame.Visible = false; mainFrame.Visible = true end)
closeButton.MouseButton1Click:Connect(function()
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if speedActive then hum.WalkSpeed = originalSpeed end
            if jumpActive then
                if hum.UseJumpPower then hum.JumpPower = originalJump else hum.JumpHeight = originalJump end
            end
        end
    end
    if gravActive then Workspace.Gravity = originalGravity end
    
    if speedConnection then speedConnection:Disconnect() end
    if jumpConnection then jumpConnection:Disconnect() end
    if gravConnection then gravConnection:Disconnect() end
    if infJumpConnection then infJumpConnection:Disconnect() end
    
    screenGui:Destroy()
end)

-- 重生處理
player.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    hasOriginalValues = false
    task.wait(0.2)
    if not (speedActive or jumpActive or gravActive or infJumpActive) then getOriginalValues() end
    
    if speedActive then
        hum.WalkSpeed = speedValue
        if speedConnection then speedConnection:Disconnect() end
        speedConnection = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if speedActive then hum.WalkSpeed = speedValue end
        end)
    end
    
    if jumpActive then
        if hum.UseJumpPower then
            hum.JumpPower = jumpValue
            if jumpConnection then jumpConnection:Disconnect() end
            jumpConnection = hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
                if jumpActive then hum.JumpPower = jumpValue end
            end)
        else
            hum.JumpHeight = jumpValue
            if jumpConnection then jumpConnection:Disconnect() end
            jumpConnection = hum:GetPropertyChangedSignal("JumpHeight"):Connect(function()
                if jumpActive then hum.JumpHeight = jumpValue end
            end)
        end
    end
end)

-- 拖曳功能
local function enableDrag(frame, handle)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

enableDrag(mainFrame, titleBar)
enableDrag(miniFrame, miniFrame)

print("✅ 速度/跳躍/無限跳/重力控制器已載入")
