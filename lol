-- Roblox 全能控制器 (增強版 v2.4)
-- 更新：全亮範圍改為0~99、優化鏡頭距離設定邏輯(強制瞬移後釋放)

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- 防止重複執行
if CoreGui:FindFirstChild("SpeedJumpController") then CoreGui.SpeedJumpController:Destroy() end
if playerGui:FindFirstChild("SpeedJumpController") then playerGui.SpeedJumpController:Destroy() end

-- 初始值變數
local originalSpeed = 16
local originalJump = 50
local originalGravity = 196.2
local hasOriginalValues = false

-- 光照備份
local lightingBackup = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ColorShift_Bottom = Lighting.ColorShift_Bottom,
    ColorShift_Top = Lighting.ColorShift_Top
}

-- 功能開關變數
local fullbrightEnabled = false
local fullbrightConnection = nil
local fullbrightValue = 0.8
local cameraDistanceEnabled = false
local cameraDistanceValue = 15
local nofogEnabled = false
local nofogConnection = nil
local brightnessEnabled = false
local brightnessValue = 2
local brightnessConnection = nil

-- 鏡頭穿牆變數
local noclipWallEnabled = false
local noclipWallConnection = nil
local wallTransparency = 0.8
local transparencyCache = {}
local noclipCamEnabled = false
local originalCameraOffset = nil

-- 角色穿牆與速度變數
local noclipEnabled = false
local noclipMode = "all"
local noclipConnection = nil

-- 飄浮變數
local platform = nil
local platformEnabled = false
local isUpButtonPressed = false
local isDownButtonPressed = false
local floatSpeed = 1

-- 邏輯變數
local speedActive = false
local jumpActive = false
local gravActive = false
local infJumpActive = false
local speedValue = 70
local jumpValue = 75
local gravValue = 50

-- 連線變數
local speedConnection = nil
local jumpConnection = nil
local gravConnection = nil
local infJumpConnection = nil

-- 獲取初始值
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

-- UI 建構
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpeedJumpController"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.DisplayOrder = 10001

local function parentUI(g)
    local success = pcall(function()
        if gethui then g.Parent = gethui()
        elseif CoreGui then g.Parent = CoreGui
        else g.Parent = playerGui end
    end)
    if not success then g.Parent = playerGui end
end
parentUI(screenGui)

-- 主視窗
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, 262)
mainFrame.Position = UDim2.new(0.5, -130, 0.5, -131)
mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

-- 標題欄
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = Color3.fromRGB(102, 126, 234)
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleBarBottom = Instance.new("Frame")
titleBarBottom.Size = UDim2.new(1, 0, 0, 10)
titleBarBottom.Position = UDim2.new(0, 0, 1, -10)
titleBarBottom.BackgroundColor3 = Color3.fromRGB(102, 126, 234)
titleBarBottom.BorderSizePixel = 0
titleBarBottom.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0)
title.BackgroundTransparency = 1
title.Text = "🎮 貓玲的全能控制器 v2.4"
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Parent = titleBar

-- 視窗控制按鈕
local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 24, 0, 24)
minimizeButton.Position = UDim2.new(1, -54, 0, 4)
minimizeButton.BackgroundColor3 = Color3.fromRGB(158, 158, 158)
minimizeButton.Text = "─"
minimizeButton.TextSize = 15
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.Parent = titleBar
Instance.new("UICorner", minimizeButton).CornerRadius = UDim.new(0, 5)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 24, 0, 24)
closeButton.Position = UDim2.new(1, -28, 0, 4)
closeButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
closeButton.Text = "X"
closeButton.TextSize = 15
closeButton.Font = Enum.Font.GothamBold
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Parent = titleBar
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 5)

-- 分頁欄
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(0.9, 0, 0, 28)
tabBar.Position = UDim2.new(0.05, 0, 0, 38)
tabBar.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
tabBar.Parent = mainFrame
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 6)

local function createTab(text, index)
    local tab = Instance.new("TextButton")
    tab.Size = UDim2.new(0.33, -4, 1, -4)
    tab.Position = UDim2.new((index-1) * 0.33, 2, 0, 2)
    tab.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    tab.Text = text
    tab.TextSize = 12
    tab.Font = Enum.Font.GothamBold
    tab.TextColor3 = Color3.fromRGB(100, 100, 100)
    tab.Parent = tabBar
    Instance.new("UICorner", tab).CornerRadius = UDim.new(0, 4)
    return tab
end

local tab1 = createTab("基礎移動", 1)
local tab2 = createTab("視野", 2)
local tab3 = createTab("穿牆+飄浮", 3)

-- 內容容器
local contentContainer = Instance.new("Frame")
contentContainer.Size = UDim2.new(0.9, 0, 0, 150) 
contentContainer.Position = UDim2.new(0.05, 0, 0, 72)
contentContainer.BackgroundTransparency = 1
contentContainer.Parent = mainFrame
contentContainer.ClipsDescendants = true 

-- 創建滾動頁面的函數
local function createScrollingPage(parent)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Color3.fromRGB(180, 180, 180)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = parent
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = page
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 2)
    padding.PaddingBottom = UDim.new(0, 2)
    padding.PaddingLeft = UDim.new(0, 2)
    padding.PaddingRight = UDim.new(0, 6)
    padding.Parent = page
    
    return page
end

local page1 = createScrollingPage(contentContainer)
local page2 = createScrollingPage(contentContainer)
local page3 = createScrollingPage(contentContainer)
page1.Visible = true

local function switchTab(pageNum)
    page1.Visible = (pageNum == 1)
    page2.Visible = (pageNum == 2)
    page3.Visible = (pageNum == 3)
    
    local activeColor = Color3.fromRGB(102, 126, 234)
    local inactiveColor = Color3.fromRGB(200, 200, 200)
    
    tab1.BackgroundColor3 = (pageNum == 1) and activeColor or inactiveColor
    tab1.TextColor3 = (pageNum == 1) and Color3.new(1,1,1) or Color3.fromRGB(100,100,100)
    tab2.BackgroundColor3 = (pageNum == 2) and activeColor or inactiveColor
    tab2.TextColor3 = (pageNum == 2) and Color3.new(1,1,1) or Color3.fromRGB(100,100,100)
    tab3.BackgroundColor3 = (pageNum == 3) and activeColor or inactiveColor
    tab3.TextColor3 = (pageNum == 3) and Color3.new(1,1,1) or Color3.fromRGB(100,100,100)
end

tab1.MouseButton1Click:Connect(function() switchTab(1) end)
tab2.MouseButton1Click:Connect(function() switchTab(2) end)
tab3.MouseButton1Click:Connect(function() switchTab(3) end)

-- 狀態顯示區域
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.9, 0, 0, 26)
statusLabel.Position = UDim2.new(0.05, 0, 1, -32)
statusLabel.BackgroundColor3 = Color3.fromRGB(255, 235, 238)
statusLabel.Text = "系統未啟動"
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextColor3 = Color3.fromRGB(198, 40, 40)
statusLabel.Parent = mainFrame
Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 5)

-- 通用控制行函數
local function createControlRow(parent, labelText, placeholder, defaultVal, isInput, order)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 32)
    frame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
    frame.LayoutOrder = order or 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

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
        Instance.new("UICorner", input).CornerRadius = UDim.new(0, 5)
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
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    return frame, input, btn
end

-- 頁面內容 1
local speedFrame, speedInput, speedButton = createControlRow(page1, "速度:", "輸入速度", "70", true, 1)
local jumpFrame, jumpInput, jumpButton = createControlRow(page1, "跳躍:", "輸入跳躍", "75", true, 2)
local infJumpFrame, infJumpStatus, infJumpButton = createControlRow(page1, "無限跳:", "", "", false, 3)
local gravFrame, gravInput, gravButton = createControlRow(page1, "重力:", "輸入重力", "50", true, 4)

-- 頁面內容 2
local fullbrightFrame, fullbrightInput, fullbrightButton = createControlRow(page2, "全亮:", "亮度", "0.8", true, 1)
local cameraDistFrame, cameraDistInput, cameraDistButton = createControlRow(page2, "鏡頭:", "距離", "80", true, 2)
local nofogFrame, nofogStatus, nofogButton = createControlRow(page2, "除霧:", "", "", false, 3)
local brightnessFrame, brightnessInput, brightnessButton = createControlRow(page2, "燈光:", "亮度", "2", true, 4)
local noclipWallFrame, noclipWallInput, noclipWallButton = createControlRow(page2, "透視:", "透明度", "0.8", true, 5)

-- 頁面內容 3
local noclipMainFrame = Instance.new("Frame")
noclipMainFrame.Size = UDim2.new(1, 0, 0, 32)
noclipMainFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
noclipMainFrame.LayoutOrder = 1
noclipMainFrame.Parent = page3
Instance.new("UICorner", noclipMainFrame).CornerRadius = UDim.new(0, 6)
local noclipLabel = Instance.new("TextLabel"); noclipLabel.Size = UDim2.new(0, 55, 1, 0); noclipLabel.Position = UDim2.new(0, 6, 0, 0); noclipLabel.BackgroundTransparency = 1; noclipLabel.Text = "Noclip:"; noclipLabel.TextSize = 13; noclipLabel.Font = Enum.Font.GothamBold; noclipLabel.TextColor3 = Color3.fromRGB(85, 85, 85); noclipLabel.TextXAlignment = Enum.TextXAlignment.Left; noclipLabel.Parent = noclipMainFrame
local noclipModeButton = Instance.new("TextButton"); noclipModeButton.Size = UDim2.new(0, 65, 0, 22); noclipModeButton.Position = UDim2.new(0, 60, 0, 5); noclipModeButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255); noclipModeButton.BorderColor3 = Color3.fromRGB(221, 221, 221); noclipModeButton.BorderSizePixel = 1; noclipModeButton.Text = "全部"; noclipModeButton.TextSize = 11; noclipModeButton.Font = Enum.Font.Gotham; noclipModeButton.TextColor3 = Color3.fromRGB(50, 50, 50); noclipModeButton.Parent = noclipMainFrame; Instance.new("UICorner", noclipModeButton).CornerRadius = UDim.new(0, 5)
local noclipButton = Instance.new("TextButton"); noclipButton.Size = UDim2.new(0, 56, 0, 22); noclipButton.Position = UDim2.new(1, -60, 0, 5); noclipButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80); noclipButton.Text = "啟動"; noclipButton.TextSize = 13; noclipButton.Font = Enum.Font.GothamBold; noclipButton.TextColor3 = Color3.fromRGB(255, 255, 255); noclipButton.Parent = noclipMainFrame; Instance.new("UICorner", noclipButton).CornerRadius = UDim.new(0, 5)

local floatToggleFrame = Instance.new("Frame")
floatToggleFrame.Size = UDim2.new(1, 0, 0, 32)
floatToggleFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
floatToggleFrame.LayoutOrder = 2
floatToggleFrame.Parent = page3
Instance.new("UICorner", floatToggleFrame).CornerRadius = UDim.new(0, 6)
local floatLabel = Instance.new("TextLabel"); floatLabel.Size = UDim2.new(0, 55, 1, 0); floatLabel.Position = UDim2.new(0, 6, 0, 0); floatLabel.BackgroundTransparency = 1; floatLabel.Text = "飄浮:"; floatLabel.TextSize = 13; floatLabel.Font = Enum.Font.GothamBold; floatLabel.TextColor3 = Color3.fromRGB(85, 85, 85); floatLabel.TextXAlignment = Enum.TextXAlignment.Left; floatLabel.Parent = floatToggleFrame
local floatStatus = Instance.new("TextLabel"); floatStatus.Size = UDim2.new(0, 65, 0, 22); floatStatus.Position = UDim2.new(0, 60, 0, 5); floatStatus.BackgroundTransparency = 1; floatStatus.Text = "關閉"; floatStatus.TextSize = 13; floatStatus.Font = Enum.Font.Gotham; floatStatus.TextColor3 = Color3.fromRGB(150, 150, 150); floatStatus.TextXAlignment = Enum.TextXAlignment.Center; floatStatus.Parent = floatToggleFrame
local floatButton = Instance.new("TextButton"); floatButton.Size = UDim2.new(0, 56, 0, 22); floatButton.Position = UDim2.new(1, -60, 0, 5); floatButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80); floatButton.Text = "啟動"; floatButton.TextSize = 13; floatButton.Font = Enum.Font.GothamBold; floatButton.TextColor3 = Color3.fromRGB(255, 255, 255); floatButton.Parent = floatToggleFrame; Instance.new("UICorner", floatButton).CornerRadius = UDim.new(0, 5)

local floatControlFrame = Instance.new("Frame")
floatControlFrame.Size = UDim2.new(1, 0, 0, 70)
floatControlFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
floatControlFrame.Visible = false
floatControlFrame.LayoutOrder = 3
floatControlFrame.Parent = page3
Instance.new("UICorner", floatControlFrame).CornerRadius = UDim.new(0, 6)
local floatUpButton = Instance.new("TextButton"); floatUpButton.Size = UDim2.new(0.48, 0, 0, 28); floatUpButton.Position = UDim2.new(0.02, 0, 0, 4); floatUpButton.BackgroundColor3 = Color3.fromRGB(70, 130, 200); floatUpButton.Text = "↑ 上升"; floatUpButton.TextSize = 13; floatUpButton.Font = Enum.Font.GothamBold; floatUpButton.TextColor3 = Color3.fromRGB(255, 255, 255); floatUpButton.Parent = floatControlFrame; Instance.new("UICorner", floatUpButton).CornerRadius = UDim.new(0, 5)
local floatDownButton = Instance.new("TextButton"); floatDownButton.Size = UDim2.new(0.48, 0, 0, 28); floatDownButton.Position = UDim2.new(0.5, 0, 0, 4); floatDownButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70); floatDownButton.Text = "↓ 下降"; floatDownButton.TextSize = 13; floatDownButton.Font = Enum.Font.GothamBold; floatDownButton.TextColor3 = Color3.fromRGB(255, 255, 255); floatDownButton.Parent = floatControlFrame; Instance.new("UICorner", floatDownButton).CornerRadius = UDim.new(0, 5)
local floatSpeedInput = Instance.new("TextBox"); floatSpeedInput.Size = UDim2.new(0.6, 0, 0, 28); floatSpeedInput.Position = UDim2.new(0.2, 0, 0, 38); floatSpeedInput.BackgroundColor3 = Color3.fromRGB(255, 255, 255); floatSpeedInput.BorderColor3 = Color3.fromRGB(221, 221, 221); floatSpeedInput.BorderSizePixel = 1; floatSpeedInput.Text = "1"; floatSpeedInput.PlaceholderText = "速度"; floatSpeedInput.TextSize = 13; floatSpeedInput.Font = Enum.Font.Gotham; floatSpeedInput.TextColor3 = Color3.fromRGB(50, 50, 50); floatSpeedInput.Parent = floatControlFrame; Instance.new("UICorner", floatSpeedInput).CornerRadius = UDim.new(0, 5)

-- 狀態更新
local function updateStatus()
    local parts = {}
    if speedActive then table.insert(parts, "速度") end
    if jumpActive then table.insert(parts, "跳躍") end
    if infJumpActive then table.insert(parts, "無限跳") end
    if gravActive then table.insert(parts, "重力") end
    if fullbrightEnabled then table.insert(parts, "全亮") end
    if nofogEnabled then table.insert(parts, "除霧") end
    if noclipEnabled then table.insert(parts, "穿牆") end
    if platformEnabled then table.insert(parts, "飄浮") end
    
    if #parts > 0 then
        statusLabel.Text = "✅ " .. table.concat(parts, " | ")
        statusLabel.BackgroundColor3 = Color3.fromRGB(232, 245, 233)
        statusLabel.TextColor3 = Color3.fromRGB(46, 125, 50)
    else
        statusLabel.Text = "系統未啟動"
        statusLabel.BackgroundColor3 = Color3.fromRGB(255, 235, 238)
        statusLabel.TextColor3 = Color3.fromRGB(198, 40, 40)
    end
end

-- 功能邏輯 (初始化)
task.spawn(function()
    if player.Character then task.wait(0.1); getOriginalValues() end
end)

-- 速度功能
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

-- 跳躍功能
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

-- 無限跳
infJumpConnection = UserInputService.JumpRequest:Connect(function()
    if infJumpActive then
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end
end)

infJumpButton.MouseButton1Click:Connect(function()
    infJumpActive = not infJumpActive
    if infJumpActive then
        infJumpButton.Text = "解除"; infJumpButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54); infJumpStatus.Text = "開啟"; infJumpStatus.TextColor3 = Color3.fromRGB(46, 125, 50); infJumpFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
    else
        infJumpButton.Text = "啟動"; infJumpButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80); infJumpStatus.Text = "關閉"; infJumpStatus.TextColor3 = Color3.fromRGB(150, 150, 150); infJumpFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
    end
    updateStatus()
end)

-- 重力
gravButton.MouseButton1Click:Connect(function()
    if not gravActive then
        if not hasOriginalValues then getOriginalValues() end
        gravValue = tonumber(gravInput.Text) or 50
        gravActive = true
        gravButton.Text = "解除"; gravButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54); gravInput.TextEditable = false; gravFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
        Workspace.Gravity = gravValue
        if gravConnection then gravConnection:Disconnect() end
        gravConnection = Workspace:GetPropertyChangedSignal("Gravity"):Connect(function()
            if gravActive and Workspace.Gravity ~= gravValue then Workspace.Gravity = gravValue end
        end)
    else
        gravActive = false
        gravButton.Text = "啟動"; gravButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80); gravInput.TextEditable = true; gravFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
        Workspace.Gravity = originalGravity
        if gravConnection then gravConnection:Disconnect() end
    end
    updateStatus()
end)

-- 全亮功能（修改：範圍 0~99）
fullbrightButton.MouseButton1Click:Connect(function()
    fullbrightEnabled = not fullbrightEnabled
    if fullbrightEnabled then
        local inputVal = tonumber(fullbrightInput.Text) or 0.8
        -- 修正：範圍改為 0 到 99
        fullbrightValue = math.clamp(inputVal, 0, 99)
        if inputVal ~= fullbrightValue then
            fullbrightInput.Text = tostring(fullbrightValue)
        end
        
        lightingBackup.Ambient = Lighting.Ambient
        lightingBackup.OutdoorAmbient = Lighting.OutdoorAmbient
        lightingBackup.Brightness = Lighting.Brightness
        lightingBackup.ColorShift_Bottom = Lighting.ColorShift_Bottom
        lightingBackup.ColorShift_Top = Lighting.ColorShift_Top
        
        fullbrightButton.Text = "解除"
        fullbrightButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
        fullbrightInput.TextEditable = false
        fullbrightFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
        
        if fullbrightConnection then fullbrightConnection:Disconnect() end
        fullbrightConnection = RunService.RenderStepped:Connect(function()
            local ambientValue = math.min(fullbrightValue, 1) -- Ambient 顏色部分不能超過1
            Lighting.Ambient = Color3.new(ambientValue, ambientValue, ambientValue)
            Lighting.Brightness = fullbrightValue -- 亮度可以使用高於1的數值
            Lighting.ColorShift_Bottom = Color3.new(ambientValue, ambientValue, ambientValue)
            Lighting.ColorShift_Top = Color3.new(ambientValue, ambientValue, ambientValue)
            Lighting.OutdoorAmbient = Color3.new(ambientValue, ambientValue, ambientValue)
        end)
    else
        fullbrightButton.Text = "啟動"
        fullbrightButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        fullbrightInput.TextEditable = true
        fullbrightFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
        
        if fullbrightConnection then fullbrightConnection:Disconnect() end
        Lighting.Ambient = lightingBackup.Ambient
        Lighting.Brightness = lightingBackup.Brightness
        Lighting.ColorShift_Bottom = lightingBackup.ColorShift_Bottom
        Lighting.ColorShift_Top = lightingBackup.ColorShift_Top
        Lighting.OutdoorAmbient = lightingBackup.OutdoorAmbient
    end
    updateStatus()
end)

-- 鏡頭距離（修改：啟動後瞬移至該距離，隨後解鎖手動調整）
cameraDistButton.MouseButton1Click:Connect(function()
    cameraDistanceEnabled = not cameraDistanceEnabled
    if cameraDistanceEnabled then
        cameraDistanceValue = tonumber(cameraDistInput.Text) or 15
        cameraDistButton.Text = "解除"
        cameraDistButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
        cameraDistInput.TextEditable = false
        cameraDistFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
        
        -- 第一步：將最大距離設為輸入值（限制最遠距離）
        player.CameraMaxZoomDistance = cameraDistanceValue
        
        -- 第二步：將最小距離也設為輸入值（這會強制鏡頭縮放至該距離，因為 Min 和 Max 一樣）
        player.CameraMinZoomDistance = cameraDistanceValue
        
        -- 強制重置鏡頭偏移
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.CameraOffset = Vector3.new(0, 0, 0)
        end

        -- 第三步：延遲一小段時間後，解鎖最小距離，讓玩家可以手動拉近
        task.delay(0.1, function()
            if cameraDistanceEnabled then
                player.CameraMinZoomDistance = 0.5 
            end
        end)
    else
        cameraDistButton.Text = "啟動"
        cameraDistButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        cameraDistInput.TextEditable = true
        cameraDistFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
        
        player.CameraMaxZoomDistance = 128
        player.CameraMinZoomDistance = 0.5
    end
end)

-- 除霧
nofogButton.MouseButton1Click:Connect(function()
    nofogEnabled = not nofogEnabled
    if nofogEnabled then
        nofogButton.Text = "解除"; nofogButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54); nofogStatus.Text = "開啟"; nofogStatus.TextColor3 = Color3.fromRGB(46, 125, 50); nofogFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
        if nofogConnection then nofogConnection:Disconnect() end
        nofogConnection = RunService.RenderStepped:Connect(function()
            Lighting.FogEnd = 100000
            for _, v in pairs(Lighting:GetDescendants()) do
                if v:IsA("Atmosphere") then v.Density = 0; v.Offset = 0 end
            end
        end)
    else
        nofogButton.Text = "啟動"; nofogButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80); nofogStatus.Text = "關閉"; nofogStatus.TextColor3 = Color3.fromRGB(150, 150, 150); nofogFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
        if nofogConnection then nofogConnection:Disconnect() end
        Lighting.FogEnd = 100000
    end
    updateStatus()
end)

-- 燈光
brightnessButton.MouseButton1Click:Connect(function()
    brightnessEnabled = not brightnessEnabled
    if brightnessEnabled then
        brightnessValue = tonumber(brightnessInput.Text) or 2
        brightnessButton.Text = "解除"; brightnessButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54); brightnessInput.TextEditable = false; brightnessFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
        if brightnessConnection then brightnessConnection:Disconnect() end
        brightnessConnection = RunService.RenderStepped:Connect(function() Lighting.Brightness = brightnessValue end)
    else
        brightnessButton.Text = "啟動"; brightnessButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80); brightnessInput.TextEditable = true; brightnessFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
        if brightnessConnection then brightnessConnection:Disconnect() end
        Lighting.Brightness = lightingBackup.Brightness or 1
    end
end)

-- 鏡頭穿牆透視功能
noclipWallButton.MouseButton1Click:Connect(function()
    noclipWallEnabled = not noclipWallEnabled
    
    if noclipWallEnabled then
        wallTransparency = tonumber(noclipWallInput.Text) or 0.8
        noclipWallButton.Text = "解除"
        noclipWallButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
        noclipWallInput.TextEditable = false
        noclipWallFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
        
        noclipCamEnabled = true
        local cam = Workspace.CurrentCamera
        
        if noclipWallConnection then noclipWallConnection:Disconnect() end
        noclipWallConnection = RunService.RenderStepped:Connect(function()
            local char = player.Character
            if not char then return end
            local head = char:FindFirstChild("Head")
            local hum = char:FindFirstChild("Humanoid")
            if not head or not hum then return end
            
            local camPos = cam.CFrame.Position
            local headPos = head.Position
            local distance = (camPos - headPos).Magnitude
            
            for _, part in pairs(Workspace:GetDescendants()) do
                if part:IsA("BasePart") and not part:IsDescendantOf(char) then
                    local hit = Workspace:Raycast(headPos, (camPos - headPos), RaycastParams.new())
                    if hit and hit.Instance == part then
                        if not transparencyCache[part] then
                            transparencyCache[part] = part.Transparency
                        end
                        part.Transparency = wallTransparency
                    elseif transparencyCache[part] then
                        part.Transparency = transparencyCache[part]
                        transparencyCache[part] = nil
                    end
                end
            end
            
            if hum then
                local params = RaycastParams.new()
                params.FilterDescendantsInstances = {char}
                params.FilterType = Enum.RaycastFilterType.Blacklist
                local result = Workspace:Raycast(headPos, (camPos - headPos), params)
                if result then
                    hum.CameraOffset = Vector3.new(0, 0, 0)
                end
            end
        end)
        
        cam.CameraType = Enum.CameraType.Custom
        player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
        
    else
        noclipWallButton.Text = "啟動"
        noclipWallButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        noclipWallInput.TextEditable = true
        noclipWallFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
        
        noclipCamEnabled = false
        
        if noclipWallConnection then noclipWallConnection:Disconnect() end
        for part, originalTrans in pairs(transparencyCache) do
            part.Transparency = originalTrans
        end
        transparencyCache = {}
        
        player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
        local cam = Workspace.CurrentCamera
        cam.CameraType = Enum.CameraType.Custom
    end
end)

-- 穿牆功能
noclipModeButton.MouseButton1Click:Connect(function()
    if noclipMode == "all" then noclipMode = "players"; noclipModeButton.Text = "僅玩家"
    else noclipMode = "all"; noclipModeButton.Text = "全部" end
end)

noclipButton.MouseButton1Click:Connect(function()
    noclipEnabled = not noclipEnabled
    if noclipEnabled then
        noclipButton.Text = "解除"
        noclipButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
        noclipMainFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
        
        if noclipConnection then noclipConnection:Disconnect() end
        
        noclipConnection = RunService.Stepped:Connect(function()
            local char = player.Character
            if not char then return end
            local hum = char:FindFirstChild("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            
            if noclipMode == "all" then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                
                if hum and speedActive then
                    if hum.WalkSpeed ~= speedValue then
                        hum.WalkSpeed = speedValue
                    end
                end
            elseif noclipMode == "players" then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                
                if hrp then
                    hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
                end
            end
        end)
    else
        noclipButton.Text = "啟動"
        noclipButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        noclipMainFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
        
        if noclipConnection then noclipConnection:Disconnect() end
        local char = player.Character
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
    updateStatus()
end)

-- 飄浮功能
local function createPlatform()
    if platform then platform:Destroy() end
    platform = Instance.new("Part")
    platform.Name = "FloatPlatform"
    platform.Size = Vector3.new(10, 0.5, 10)
    platform.Anchored = true; platform.CanCollide = true; platform.Transparency = 1; platform.Material = Enum.Material.SmoothPlastic
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then platform.Position = Vector3.new(hrp.Position.X, hrp.Position.Y - 3.5, hrp.Position.Z) end
    end
    platform.Parent = Workspace
end

local function movePlatformWithPlayer(amount)
    if platform and platformEnabled then
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local currentPlatformPos = platform.Position
                platform.Position = Vector3.new(currentPlatformPos.X, currentPlatformPos.Y + amount, currentPlatformPos.Z)
                hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y + amount, hrp.Position.Z)
            end
        end
    end
end

floatButton.MouseButton1Click:Connect(function()
    platformEnabled = not platformEnabled
    if platformEnabled then
        floatButton.Text = "解除"; floatButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54); floatStatus.Text = "開啟"; floatStatus.TextColor3 = Color3.fromRGB(46, 125, 50); floatToggleFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253); floatControlFrame.Visible = true; createPlatform()
    else
        floatButton.Text = "啟動"; floatButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80); floatStatus.Text = "關閉"; floatStatus.TextColor3 = Color3.fromRGB(150, 150, 150); floatToggleFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250); floatControlFrame.Visible = false; if platform then platform:Destroy() end
    end
    updateStatus()
end)

floatUpButton.MouseButton1Down:Connect(function() isUpButtonPressed = true end)
floatUpButton.MouseButton1Up:Connect(function() isUpButtonPressed = false end)
floatDownButton.MouseButton1Down:Connect(function() isDownButtonPressed = true end)
floatDownButton.MouseButton1Up:Connect(function() isDownButtonPressed = false end)
floatSpeedInput.FocusLost:Connect(function() local newSpeed = tonumber(floatSpeedInput.Text); if newSpeed and newSpeed >= 0.1 then floatSpeed = newSpeed else floatSpeedInput.Text = tostring(floatSpeed) end end)

RunService.RenderStepped:Connect(function()
    if platformEnabled and platform then
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local currentY = platform.Position.Y
                platform.Position = Vector3.new(hrp.Position.X, currentY, hrp.Position.Z)
                if isUpButtonPressed then movePlatformWithPlayer(floatSpeed) end
                if isDownButtonPressed then movePlatformWithPlayer(-floatSpeed) end
            end
        end
    end
end)

-- 迷你視窗
local miniFrame = Instance.new("Frame"); miniFrame.Size = UDim2.new(0, 130, 0, 32); miniFrame.Position = UDim2.new(0.5, -65, 0, 30); miniFrame.BackgroundColor3 = Color3.fromRGB(102, 126, 234); miniFrame.Visible = false; miniFrame.Parent = screenGui; Instance.new("UICorner", miniFrame).CornerRadius = UDim.new(0, 6)
local miniTitle = Instance.new("TextLabel"); miniTitle.Size = UDim2.new(1, -36, 1, 0); miniTitle.BackgroundTransparency = 1; miniTitle.Text = "🎮 控制器"; miniTitle.TextSize = 13; miniTitle.Font = Enum.Font.GothamBold; miniTitle.TextColor3 = Color3.fromRGB(255, 255, 255); miniTitle.Parent = miniFrame
local expandButton = Instance.new("TextButton"); expandButton.Size = UDim2.new(0, 24, 0, 24); expandButton.Position = UDim2.new(1, -28, 0, 4); expandButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80); expandButton.Text = "+"; expandButton.TextSize = 18; expandButton.Font = Enum.Font.GothamBold; expandButton.TextColor3 = Color3.fromRGB(255, 255, 255); expandButton.Parent = miniFrame; Instance.new("UICorner", expandButton).CornerRadius = UDim.new(0, 5)

minimizeButton.MouseButton1Click:Connect(function() mainFrame.Visible = false; miniFrame.Visible = true end)
expandButton.MouseButton1Click:Connect(function() miniFrame.Visible = false; mainFrame.Visible = true end)

closeButton.MouseButton1Click:Connect(function()
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if speedActive then hum.WalkSpeed = originalSpeed end
            if jumpActive then if hum.UseJumpPower then hum.JumpPower = originalJump else hum.JumpHeight = originalJump end end
        end
    end
    if gravActive then Workspace.Gravity = originalGravity end
    if speedConnection then speedConnection:Disconnect() end; if jumpConnection then jumpConnection:Disconnect() end; if gravConnection then gravConnection:Disconnect() end; if infJumpConnection then infJumpConnection:Disconnect() end
    if fullbrightConnection then fullbrightConnection:Disconnect() end; if nofogConnection then nofogConnection:Disconnect() end; if brightnessConnection then brightnessConnection:Disconnect() end; if noclipWallConnection then noclipWallConnection:Disconnect() end
    if noclipConnection then noclipConnection:Disconnect() end; if platform then platform:Destroy() end
    
    Lighting.Ambient = lightingBackup.Ambient; Lighting.Brightness = lightingBackup.Brightness; Lighting.OutdoorAmbient = lightingBackup.OutdoorAmbient
    for part, originalTrans in pairs(transparencyCache) do part.Transparency = originalTrans end
    screenGui:Destroy()
end)

local function enableDrag(frame, handle)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; dragStart = input.Position; startPos = frame.Position; input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) end end)
    UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then local delta = input.Position - dragStart; frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
end
enableDrag(mainFrame, titleBar)
enableDrag(miniFrame, miniFrame)

print("✅ 全能控制器 v2.4 已載入 (全亮0~99 + 鏡頭瞬移/解鎖優化)")
