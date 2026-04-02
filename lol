-- Roblox 全能控制器 (增強版 v2.6 - 修復穿牆鏡頭 + 鏡頭距離優化)
-- 更新：
--   1. 穿牆鏡頭：改用穿透式多次 Raycast，透明度調整現在完全正確
--   2. 鏡頭距離：距離 > 10 時自動解除第一人稱鎖定，MinZoom 先設為目標值再改回 0

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

-- ====================
-- 核心變數與備份
-- ====================

-- 鎖定最原始的光照設定
local trueLightingBackup = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ColorShift_Bottom = Lighting.ColorShift_Bottom,
    ColorShift_Top = Lighting.ColorShift_Top,
    FogEnd = Lighting.FogEnd
}

-- 備份後處理效果與大氣的原始值
local postEffectBackups = {}
local atmosphereBackups = {}

-- 初始角色數值
local originalSpeed = 16
local originalJump = 50
local originalGravity = 196.2
local hasOriginalValues = false

-- 備份原始鏡頭設定
local originalCameraMaxZoom = player.CameraMaxZoomDistance
local originalCameraMinZoom = player.CameraMinZoomDistance
local originalCameraMode   = player.CameraMode  -- 備份原始 CameraMode

-- 功能狀態開關
local toggles = {
    speed      = false,
    jump       = false,
    infJump    = false,
    gravity    = false,
    fullbright = false,
    cameraDist = false,
    nofog      = false,
    brightness = false,
    noclipWall = false,
    noclip     = false,
    platform   = false,
    noFilter   = false
}

-- 數值設定
local values = {
    speed      = 70,
    jump       = 75,
    gravity    = 50,
    fullbright = 0.8,
    cameraDist = 15,
    brightness = 2,
    wallTrans  = 0.8,
    floatSpeed = 1
}

-- 連線儲存
local connections = {
    speed      = nil,
    jump       = nil,
    gravity    = nil,
    infJump    = nil,
    fullbright = nil,
    nofog      = nil,
    brightness = nil,
    noclipWall = nil,
    noclip     = nil,
    noFilter   = nil
}

-- 穿牆與透視緩存
local transparencyCache = {}
local noclipMode = "all"
local platform = nil
local isUpButtonPressed = false
local isDownButtonPressed = false

-- ====================
-- 核心邏輯函數
-- ====================

local function getOriginalValues()
    if toggles.speed or toggles.jump or toggles.gravity then return end
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

local function backupPostEffects()
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("PostEffect") and not postEffectBackups[v] then
            postEffectBackups[v] = { Enabled = v.Enabled }
            if v:IsA("BloomEffect") then
                postEffectBackups[v].Intensity  = v.Intensity
                postEffectBackups[v].Size       = v.Size
                postEffectBackups[v].Threshold  = v.Threshold
            elseif v:IsA("BlurEffect") then
                postEffectBackups[v].Size = v.Size
            elseif v:IsA("ColorCorrectionEffect") then
                postEffectBackups[v].Brightness = v.Brightness
                postEffectBackups[v].Contrast   = v.Contrast
                postEffectBackups[v].Saturation = v.Saturation
                postEffectBackups[v].TintColor  = v.TintColor
            elseif v:IsA("SunRaysEffect") then
                postEffectBackups[v].Intensity = v.Intensity
                postEffectBackups[v].Spread    = v.Spread
            end
        end
    end
    if Workspace.CurrentCamera then
        for _, v in pairs(Workspace.CurrentCamera:GetChildren()) do
            if v:IsA("PostEffect") and not postEffectBackups[v] then
                postEffectBackups[v] = { Enabled = v.Enabled }
                if v:IsA("BloomEffect") then
                    postEffectBackups[v].Intensity  = v.Intensity
                    postEffectBackups[v].Size       = v.Size
                    postEffectBackups[v].Threshold  = v.Threshold
                elseif v:IsA("BlurEffect") then
                    postEffectBackups[v].Size = v.Size
                elseif v:IsA("ColorCorrectionEffect") then
                    postEffectBackups[v].Brightness = v.Brightness
                    postEffectBackups[v].Contrast   = v.Contrast
                    postEffectBackups[v].Saturation = v.Saturation
                    postEffectBackups[v].TintColor  = v.TintColor
                elseif v:IsA("SunRaysEffect") then
                    postEffectBackups[v].Intensity = v.Intensity
                    postEffectBackups[v].Spread    = v.Spread
                end
            end
        end
    end
end

local function backupAtmospheres()
    for _, v in pairs(Lighting:GetDescendants()) do
        if v:IsA("Atmosphere") and not atmosphereBackups[v] then
            atmosphereBackups[v] = {
                Density = v.Density,
                Offset  = v.Offset,
                Color   = v.Color,
                Decay   = v.Decay,
                Glare   = v.Glare,
                Haze    = v.Haze
            }
        end
    end
end

-- 智能光照管理器
local function updateLighting()
    if toggles.fullbright then
        if connections.brightness  then connections.brightness:Disconnect()  end
        if connections.fullbright  then connections.fullbright:Disconnect()  end
        connections.fullbright = RunService.RenderStepped:Connect(function()
            local a = math.min(values.fullbright, 1)
            Lighting.Ambient          = Color3.new(a, a, a)
            Lighting.Brightness       = values.fullbright
            Lighting.ColorShift_Bottom = Color3.new(a, a, a)
            Lighting.ColorShift_Top   = Color3.new(a, a, a)
            Lighting.OutdoorAmbient   = Color3.new(a, a, a)
        end)
    elseif toggles.brightness then
        if connections.fullbright then connections.fullbright:Disconnect() end
        if connections.brightness then connections.brightness:Disconnect() end
        Lighting.Ambient          = trueLightingBackup.Ambient
        Lighting.OutdoorAmbient   = trueLightingBackup.OutdoorAmbient
        Lighting.ColorShift_Bottom = trueLightingBackup.ColorShift_Bottom
        Lighting.ColorShift_Top   = trueLightingBackup.ColorShift_Top
        connections.brightness = RunService.RenderStepped:Connect(function()
            Lighting.Brightness = values.brightness
        end)
    else
        if connections.fullbright then connections.fullbright:Disconnect() end
        if connections.brightness then connections.brightness:Disconnect() end
        Lighting.Ambient          = trueLightingBackup.Ambient
        Lighting.Brightness       = trueLightingBackup.Brightness
        Lighting.OutdoorAmbient   = trueLightingBackup.OutdoorAmbient
        Lighting.ColorShift_Bottom = trueLightingBackup.ColorShift_Bottom
        Lighting.ColorShift_Top   = trueLightingBackup.ColorShift_Top
    end
end

local function applySpeed(char)
    if not char then char = player.Character end
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    if connections.speed then connections.speed:Disconnect() end
    if toggles.speed then
        hum.WalkSpeed = values.speed
        connections.speed = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if toggles.speed then hum.WalkSpeed = values.speed end
        end)
    else
        hum.WalkSpeed = originalSpeed
    end
end

local function applyJump(char)
    if not char then char = player.Character end
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    if connections.jump then connections.jump:Disconnect() end
    if toggles.jump then
        if hum.UseJumpPower then
            hum.JumpPower = values.jump
            connections.jump = hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
                if toggles.jump then hum.JumpPower = values.jump end
            end)
        else
            hum.JumpHeight = values.jump
            connections.jump = hum:GetPropertyChangedSignal("JumpHeight"):Connect(function()
                if toggles.jump then hum.JumpHeight = values.jump end
            end)
        end
    else
        if hum.UseJumpPower then hum.JumpPower = originalJump else hum.JumpHeight = originalJump end
    end
end

local function applyNoclip(char)
    if connections.noclip then connections.noclip:Disconnect() end
    if toggles.noclip then
        connections.noclip = RunService.Stepped:Connect(function()
            local c = player.Character
            if not c then return end
            if noclipMode == "all" then
                for _, part in pairs(c:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            elseif noclipMode == "players" then
                for _, part in pairs(c:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                local hrp = c:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0) end
            end
        end)
    else
        local c = player.Character
        if c then
            for _, part in pairs(c:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
end

player.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    if toggles.speed  then applySpeed(newChar)  end
    if toggles.jump   then applyJump(newChar)   end
    if toggles.noclip then applyNoclip(newChar) end
    if toggles.platform then
        if platform then platform:Destroy() end
    end
end)

-- ====================
-- UI 建構
-- ====================
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

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, 262)
mainFrame.Position = UDim2.new(0.5, -130, 0.5, -131)
mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = Color3.fromRGB(102, 126, 234)
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0)
title.BackgroundTransparency = 1
title.Text = "🎮 貓玲的全能控制器 v2.6"
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Parent = titleBar

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 24, 0, 24)
minimizeButton.Position = UDim2.new(1, -54, 0, 4)
minimizeButton.BackgroundColor3 = Color3.fromRGB(158, 158, 158)
minimizeButton.Text = "─"
minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.Parent = titleBar
Instance.new("UICorner", minimizeButton).CornerRadius = UDim.new(0, 5)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 24, 0, 24)
closeButton.Position = UDim2.new(1, -28, 0, 4)
closeButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Parent = titleBar
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 5)

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
local tab2 = createTab("視野燈光", 2)
local tab3 = createTab("穿牆飄浮", 3)

local contentContainer = Instance.new("Frame")
contentContainer.Size = UDim2.new(0.9, 0, 0, 150)
contentContainer.Position = UDim2.new(0.05, 0, 0, 72)
contentContainer.BackgroundTransparency = 1
contentContainer.Parent = mainFrame
contentContainer.ClipsDescendants = true

local function createScrollingPage(parent)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = parent
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = page
    local padding = Instance.new("UIPadding")
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
    tab1.BackgroundColor3 = (pageNum == 1) and Color3.fromRGB(102,126,234) or Color3.fromRGB(200,200,200)
    tab1.TextColor3 = (pageNum == 1) and Color3.new(1,1,1) or Color3.fromRGB(100,100,100)
    tab2.BackgroundColor3 = (pageNum == 2) and Color3.fromRGB(102,126,234) or Color3.fromRGB(200,200,200)
    tab2.TextColor3 = (pageNum == 2) and Color3.new(1,1,1) or Color3.fromRGB(100,100,100)
    tab3.BackgroundColor3 = (pageNum == 3) and Color3.fromRGB(102,126,234) or Color3.fromRGB(200,200,200)
    tab3.TextColor3 = (pageNum == 3) and Color3.new(1,1,1) or Color3.fromRGB(100,100,100)
end
tab1.MouseButton1Click:Connect(function() switchTab(1) end)
tab2.MouseButton1Click:Connect(function() switchTab(2) end)
tab3.MouseButton1Click:Connect(function() switchTab(3) end)

local function createControlRow(parent, labelText, placeholder, defaultVal, isInput, order)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 32)
    frame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
    frame.LayoutOrder = order or 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 75, 1, 0)
    label.Position = UDim2.new(0, 6, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextSize = 12
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(85, 85, 85)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local input
    if isInput then
        input = Instance.new("TextBox")
        input.Size = UDim2.new(0, 65, 0, 22)
        input.Position = UDim2.new(0, 80, 0, 5)
        input.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        input.BorderSizePixel = 1
        input.BorderColor3 = Color3.fromRGB(221, 221, 221)
        input.Text = defaultVal
        input.PlaceholderText = placeholder
        input.TextSize = 13
        input.Font = Enum.Font.Gotham
        input.TextColor3 = Color3.fromRGB(50, 50, 50)
        input.Parent = frame
        Instance.new("UICorner", input).CornerRadius = UDim.new(0, 5)
    else
        input = Instance.new("TextLabel")
        input.Size = UDim2.new(0, 65, 0, 22)
        input.Position = UDim2.new(0, 80, 0, 5)
        input.BackgroundTransparency = 1
        input.Text = "關閉"
        input.TextSize = 13
        input.Font = Enum.Font.Gotham
        input.TextColor3 = Color3.fromRGB(150, 150, 150)
        input.Parent = frame
    end

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 50, 0, 22)
    btn.Position = UDim2.new(1, -55, 0, 5)
    btn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
    btn.Text = "啟動"
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    return frame, input, btn
end

-- 頁面 1
local speedFrame,      speedInput,      speedButton      = createControlRow(page1, "速度:",   "70",  "70",  true,  1)
local jumpFrame,       jumpInput,       jumpButton       = createControlRow(page1, "跳躍:",   "75",  "75",  true,  2)
local infJumpFrame,    infJumpStatus,   infJumpButton    = createControlRow(page1, "無限跳:", "",    "",    false, 3)
local gravFrame,       gravInput,       gravButton       = createControlRow(page1, "重力:",   "50",  "50",  true,  4)

-- 頁面 2
local fullbrightFrame,  fullbrightInput,  fullbrightButton  = createControlRow(page2, "全亮:",    "0.8", "0.8", true,  1)
local cameraDistFrame,  cameraDistInput,  cameraDistButton  = createControlRow(page2, "鏡頭距離:", "80",  "80",  true,  2)
local nofogFrame,       nofogStatus,      nofogButton       = createControlRow(page2, "除霧:",    "",    "",    false, 3)
local noFilterFrame,    noFilterStatus,   noFilterButton    = createControlRow(page2, "無濾鏡:",  "",    "",    false, 4)
local noclipWallFrame,  noclipWallInput,  noclipWallButton  = createControlRow(page2, "穿牆鏡頭:", "0.8", "0.8", true,  5)
local brightnessFrame,  brightnessInput,  brightnessButton  = createControlRow(page2, "燈光:",    "2",   "2",   true,  6)

-- 頁面 3
local noclipMainFrame = Instance.new("Frame")
noclipMainFrame.Size = UDim2.new(1, 0, 0, 32)
noclipMainFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
noclipMainFrame.LayoutOrder = 1
noclipMainFrame.Parent = page3
Instance.new("UICorner", noclipMainFrame).CornerRadius = UDim.new(0, 6)

local noclipLabel = Instance.new("TextLabel")
noclipLabel.Text = "Noclip:"
noclipLabel.Size = UDim2.new(0, 55, 1, 0)
noclipLabel.Position = UDim2.new(0, 6, 0, 0)
noclipLabel.BackgroundTransparency = 1
noclipLabel.Font = Enum.Font.GothamBold
noclipLabel.TextSize = 13
noclipLabel.TextColor3 = Color3.fromRGB(85, 85, 85)
noclipLabel.TextXAlignment = Enum.TextXAlignment.Left
noclipLabel.Parent = noclipMainFrame

local noclipModeButton = Instance.new("TextButton")
noclipModeButton.Text = "全部"
noclipModeButton.Size = UDim2.new(0, 65, 0, 22)
noclipModeButton.Position = UDim2.new(0, 60, 0, 5)
noclipModeButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
noclipModeButton.TextColor3 = Color3.fromRGB(50, 50, 50)
noclipModeButton.Font = Enum.Font.Gotham
noclipModeButton.TextSize = 11
noclipModeButton.Parent = noclipMainFrame
Instance.new("UICorner", noclipModeButton).CornerRadius = UDim.new(0, 5)

local noclipButton = Instance.new("TextButton")
noclipButton.Text = "啟動"
noclipButton.Size = UDim2.new(0, 56, 0, 22)
noclipButton.Position = UDim2.new(1, -60, 0, 5)
noclipButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
noclipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
noclipButton.Font = Enum.Font.GothamBold
noclipButton.TextSize = 13
noclipButton.Parent = noclipMainFrame
Instance.new("UICorner", noclipButton).CornerRadius = UDim.new(0, 5)

local floatToggleFrame, floatStatus, floatButton = createControlRow(page3, "飄浮:", "", "", false, 2)

local floatControlFrame = Instance.new("Frame")
floatControlFrame.Size = UDim2.new(1, 0, 0, 70)
floatControlFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
floatControlFrame.Visible = false
floatControlFrame.LayoutOrder = 3
floatControlFrame.Parent = page3
Instance.new("UICorner", floatControlFrame).CornerRadius = UDim.new(0, 6)

local floatUpButton = Instance.new("TextButton")
floatUpButton.Text = "↑ 上升"
floatUpButton.Size = UDim2.new(0.48, 0, 0, 28)
floatUpButton.Position = UDim2.new(0.02, 0, 0, 4)
floatUpButton.BackgroundColor3 = Color3.fromRGB(70, 130, 200)
floatUpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
floatUpButton.Font = Enum.Font.GothamBold
floatUpButton.TextSize = 13
floatUpButton.Parent = floatControlFrame
Instance.new("UICorner", floatUpButton).CornerRadius = UDim.new(0, 5)

local floatDownButton = Instance.new("TextButton")
floatDownButton.Text = "↓ 下降"
floatDownButton.Size = UDim2.new(0.48, 0, 0, 28)
floatDownButton.Position = UDim2.new(0.5, 0, 0, 4)
floatDownButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
floatDownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
floatDownButton.Font = Enum.Font.GothamBold
floatDownButton.TextSize = 13
floatDownButton.Parent = floatControlFrame
Instance.new("UICorner", floatDownButton).CornerRadius = UDim.new(0, 5)

local floatSpeedInput = Instance.new("TextBox")
floatSpeedInput.Text = "1"
floatSpeedInput.Size = UDim2.new(0.6, 0, 0, 28)
floatSpeedInput.Position = UDim2.new(0.2, 0, 0, 38)
floatSpeedInput.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
floatSpeedInput.TextColor3 = Color3.fromRGB(50, 50, 50)
floatSpeedInput.Font = Enum.Font.Gotham
floatSpeedInput.TextSize = 13
floatSpeedInput.Parent = floatControlFrame
Instance.new("UICorner", floatSpeedInput).CornerRadius = UDim.new(0, 5)

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

-- ====================
-- 功能實作
-- ====================

local function updateStatus()
    local active = {}
    if toggles.speed     then table.insert(active, "速度")   end
    if toggles.fullbright then table.insert(active, "全亮")  end
    if toggles.noclip    then table.insert(active, "穿牆")   end
    if toggles.noFilter  then table.insert(active, "無濾鏡") end
    if #active > 0 then
        statusLabel.Text = "✅ " .. table.concat(active, " | ")
        statusLabel.BackgroundColor3 = Color3.fromRGB(232, 245, 233)
        statusLabel.TextColor3 = Color3.fromRGB(46, 125, 50)
    else
        statusLabel.Text = "系統就緒"
        statusLabel.BackgroundColor3 = Color3.fromRGB(255, 235, 238)
        statusLabel.TextColor3 = Color3.fromRGB(198, 40, 40)
    end
end

local function toggleUIState(btn, frame, input, isActive)
    if isActive then
        btn.Text = "解除"; btn.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
        frame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
        if input and input:IsA("TextBox") then input.TextEditable = false end
    else
        btn.Text = "啟動"; btn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        frame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
        if input and input:IsA("TextBox") then input.TextEditable = true end
    end
    updateStatus()
end

-- 速度
speedButton.MouseButton1Click:Connect(function()
    toggles.speed = not toggles.speed
    if toggles.speed then
        if not hasOriginalValues then getOriginalValues() end
        values.speed = tonumber(speedInput.Text) or 70
    end
    applySpeed()
    toggleUIState(speedButton, speedFrame, speedInput, toggles.speed)
end)

-- 跳躍
jumpButton.MouseButton1Click:Connect(function()
    toggles.jump = not toggles.jump
    if toggles.jump then
        if not hasOriginalValues then getOriginalValues() end
        values.jump = tonumber(jumpInput.Text) or 75
    end
    applyJump()
    toggleUIState(jumpButton, jumpFrame, jumpInput, toggles.jump)
end)

-- 無限跳
local infJumpConnection = UserInputService.JumpRequest:Connect(function()
    if toggles.infJump then
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end
end)
infJumpButton.MouseButton1Click:Connect(function()
    toggles.infJump = not toggles.infJump
    infJumpStatus.Text = toggles.infJump and "開啟" or "關閉"
    infJumpStatus.TextColor3 = toggles.infJump and Color3.fromRGB(46,125,50) or Color3.fromRGB(150,150,150)
    toggleUIState(infJumpButton, infJumpFrame, infJumpStatus, toggles.infJump)
end)

-- 重力
gravButton.MouseButton1Click:Connect(function()
    toggles.gravity = not toggles.gravity
    if toggles.gravity then
        if not hasOriginalValues then getOriginalValues() end
        values.gravity = tonumber(gravInput.Text) or 50
        Workspace.Gravity = values.gravity
        if connections.gravity then connections.gravity:Disconnect() end
        connections.gravity = Workspace:GetPropertyChangedSignal("Gravity"):Connect(function()
            if toggles.gravity then Workspace.Gravity = values.gravity end
        end)
    else
        Workspace.Gravity = originalGravity
        if connections.gravity then connections.gravity:Disconnect() end
    end
    toggleUIState(gravButton, gravFrame, gravInput, toggles.gravity)
end)

-- 全亮
fullbrightButton.MouseButton1Click:Connect(function()
    toggles.fullbright = not toggles.fullbright
    if toggles.fullbright then
        local val = tonumber(fullbrightInput.Text) or 0.8
        values.fullbright = math.clamp(val, 0, 99)
        if val ~= values.fullbright then fullbrightInput.Text = tostring(values.fullbright) end
    end
    updateLighting()
    toggleUIState(fullbrightButton, fullbrightFrame, fullbrightInput, toggles.fullbright)
end)

-- 燈光
brightnessButton.MouseButton1Click:Connect(function()
    toggles.brightness = not toggles.brightness
    if toggles.brightness then
        values.brightness = tonumber(brightnessInput.Text) or 2
    end
    updateLighting()
    toggleUIState(brightnessButton, brightnessFrame, brightnessInput, toggles.brightness)
end)

-- 無濾鏡
noFilterButton.MouseButton1Click:Connect(function()
    toggles.noFilter = not toggles.noFilter
    if toggles.noFilter then
        noFilterStatus.Text = "開啟"
        noFilterStatus.TextColor3 = Color3.fromRGB(46, 125, 50)
        backupPostEffects()
        if connections.noFilter then connections.noFilter:Disconnect() end
        connections.noFilter = RunService.RenderStepped:Connect(function()
            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("BloomEffect") then
                    v.Intensity = 0; v.Size = 0; v.Threshold = 2
                elseif v:IsA("BlurEffect") then
                    v.Size = 0
                elseif v:IsA("ColorCorrectionEffect") then
                    v.Brightness = 0; v.Contrast = 0; v.Saturation = 0
                    v.TintColor = Color3.fromRGB(255, 255, 255)
                elseif v:IsA("SunRaysEffect") then
                    v.Intensity = 0; v.Spread = 0
                elseif v:IsA("DepthOfFieldEffect") then
                    v.FarIntensity = 0; v.NearIntensity = 0
                end
            end
            if Workspace.CurrentCamera then
                for _, v in pairs(Workspace.CurrentCamera:GetChildren()) do
                    if v:IsA("BloomEffect") then
                        v.Intensity = 0; v.Size = 0; v.Threshold = 2
                    elseif v:IsA("BlurEffect") then
                        v.Size = 0
                    elseif v:IsA("ColorCorrectionEffect") then
                        v.Brightness = 0; v.Contrast = 0; v.Saturation = 0
                        v.TintColor = Color3.fromRGB(255, 255, 255)
                    elseif v:IsA("SunRaysEffect") then
                        v.Intensity = 0; v.Spread = 0
                    elseif v:IsA("DepthOfFieldEffect") then
                        v.FarIntensity = 0; v.NearIntensity = 0
                    end
                end
            end
        end)
    else
        noFilterStatus.Text = "關閉"
        noFilterStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
        if connections.noFilter then connections.noFilter:Disconnect() end
        for effect, backup in pairs(postEffectBackups) do
            if effect and effect.Parent then
                for prop, value in pairs(backup) do
                    pcall(function() effect[prop] = value end)
                end
            end
        end
        postEffectBackups = {}
    end
    toggleUIState(noFilterButton, noFilterFrame, noFilterStatus, toggles.noFilter)
end)

-- 除霧
nofogButton.MouseButton1Click:Connect(function()
    toggles.nofog = not toggles.nofog
    if toggles.nofog then
        nofogStatus.Text = "開啟"
        nofogStatus.TextColor3 = Color3.fromRGB(46, 125, 50)
        backupAtmospheres()
        if connections.nofog then connections.nofog:Disconnect() end
        connections.nofog = RunService.RenderStepped:Connect(function()
            Lighting.FogEnd = 100000
            for _, v in pairs(Lighting:GetDescendants()) do
                if v:IsA("Atmosphere") then
                    v.Density = 0; v.Offset = 0; v.Glare = 0; v.Haze = 0
                end
            end
        end)
    else
        nofogStatus.Text = "關閉"
        nofogStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
        if connections.nofog then connections.nofog:Disconnect() end
        Lighting.FogEnd = trueLightingBackup.FogEnd or 100000
        for atmosphere, backup in pairs(atmosphereBackups) do
            if atmosphere and atmosphere.Parent then
                for prop, value in pairs(backup) do
                    pcall(function() atmosphere[prop] = value end)
                end
            end
        end
        atmosphereBackups = {}
    end
    toggleUIState(nofogButton, nofogFrame, nofogStatus, toggles.nofog)
end)

-- ============================================================
-- 鏡頭距離（v2.6 更新）
--   1. 距離 > 10 時，若原本是第一人稱鎖定，自動切成第三人稱
--   2. MaxZoom / MinZoom 皆設為目標值，確保鏡頭立即跳到正確位置
--      短暫等待後再把 MinZoom 改回 0，讓玩家仍可自由縮近
-- ============================================================
cameraDistButton.MouseButton1Click:Connect(function()
    toggles.cameraDist = not toggles.cameraDist

    if toggles.cameraDist then
        -- 每次啟動時重新備份當前值（以防玩家中途更換設定）
        originalCameraMaxZoom = player.CameraMaxZoomDistance
        originalCameraMinZoom = player.CameraMinZoomDistance
        originalCameraMode    = player.CameraMode

        values.cameraDist = tonumber(cameraDistInput.Text) or 15

        -- 距離 > 10：若原本鎖定第一人稱，自動解除並切換成 Classic（第三人稱）
        if values.cameraDist > 10 then
            if player.CameraMode == Enum.CameraMode.LockFirstPerson then
                player.CameraMode = Enum.CameraMode.Classic
            end
        end

        -- 先把 Max 與 Min 都鎖到目標值，讓引擎立即把鏡頭拉到那個距離
        player.CameraMaxZoomDistance = values.cameraDist
        player.CameraMinZoomDistance = values.cameraDist

        -- 等一個很短的時間（確保鏡頭已經移動後），把 MinZoom 改回 0
        -- 這樣玩家仍然可以縮近，但 Max 維持在設定值
        task.delay(0.15, function()
            if toggles.cameraDist then
                player.CameraMinZoomDistance = 0
            end
        end)

        if player.Character then
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.CameraOffset = Vector3.new(0, 0, 0) end
        end
    else
        -- 還原所有備份的鏡頭設定
        player.CameraMaxZoomDistance = originalCameraMaxZoom
        player.CameraMinZoomDistance = originalCameraMinZoom
        player.CameraMode            = originalCameraMode
    end

    toggleUIState(cameraDistButton, cameraDistFrame, cameraDistInput, toggles.cameraDist)
end)

-- 穿牆鏡頭（v2.6 更新：穿透式多次 Raycast，透明度正確）
noclipWallButton.MouseButton1Click:Connect(function()
    toggles.noclipWall = not toggles.noclipWall
    if toggles.noclipWall then
        values.wallTrans = tonumber(noclipWallInput.Text) or 0.8

        if connections.noclipWall then connections.noclipWall:Disconnect() end
        connections.noclipWall = RunService.RenderStepped:Connect(function()
            local cam  = Workspace.CurrentCamera
            local char = player.Character
            if not char then return end
            local head = char:FindFirstChild("Head")
            if not head then return end

            local camPos  = cam.CFrame.Position
            local headPos = head.Position
            local direction = camPos - headPos
            local distance  = direction.Magnitude

            -- 收集這一幀被遮擋的物件
            local hitThisFrame = {}

            -- 穿透式連續 Raycast：找出頭到鏡頭之間所有障礙物
            local origin      = headPos
            local remaining   = distance
            local tempExclude = {char}

            while remaining > 0.1 do
                local params = RaycastParams.new()
                params.FilterDescendantsInstances = tempExclude
                params.FilterType = Enum.RaycastFilterType.Exclude

                local result = Workspace:Raycast(origin, direction.Unit * remaining, params)
                if not result then break end

                local part = result.Instance
                if part:IsA("BasePart") then
                    hitThisFrame[part] = true
                    -- 只在第一次遇到時備份原始透明度
                    if not transparencyCache[part] then
                        transparencyCache[part] = part.Transparency
                    end
                    part.Transparency = values.wallTrans
                    table.insert(tempExclude, part)
                end

                remaining = (camPos - result.Position).Magnitude
                origin    = result.Position
            end

            -- 還原這一幀不再被遮擋的物件
            for part, originalTrans in pairs(transparencyCache) do
                if not hitThisFrame[part] then
                    if part and part.Parent then
                        part.Transparency = originalTrans
                    end
                    transparencyCache[part] = nil
                end
            end
        end)

        player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
    else
        if connections.noclipWall then connections.noclipWall:Disconnect() end
        -- 還原所有已快取物件的透明度
        for part, originalTrans in pairs(transparencyCache) do
            if part and part.Parent then
                part.Transparency = originalTrans
            end
        end
        transparencyCache = {}
        player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
    end
    toggleUIState(noclipWallButton, noclipWallFrame, noclipWallInput, toggles.noclipWall)
end)

-- 穿牆（Noclip）
noclipModeButton.MouseButton1Click:Connect(function()
    if noclipMode == "all" then
        noclipMode = "players"; noclipModeButton.Text = "僅玩家"
    else
        noclipMode = "all"; noclipModeButton.Text = "全部"
    end
end)
noclipButton.MouseButton1Click:Connect(function()
    toggles.noclip = not toggles.noclip
    applyNoclip()
    if toggles.noclip then
        noclipButton.Text = "解除"; noclipButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
        noclipMainFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
    else
        noclipButton.Text = "啟動"; noclipButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        noclipMainFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
    end
    updateStatus()
end)

-- 飄浮平台
local function createPlatform()
    if platform then platform:Destroy() end
    platform = Instance.new("Part")
    platform.Name = "FloatPlatform"
    platform.Size = Vector3.new(10, 0.5, 10)
    platform.Anchored = true
    platform.CanCollide = true
    platform.Transparency = 1
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            platform.Position = Vector3.new(hrp.Position.X, hrp.Position.Y - 3.5, hrp.Position.Z)
        end
    end
    platform.Parent = Workspace
end

local function movePlatform(amount)
    if platform and toggles.platform then
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                platform.Position = platform.Position + Vector3.new(0, amount, 0)
                hrp.CFrame = CFrame.new(hrp.Position.X, platform.Position.Y + 3.5, hrp.Position.Z)
            end
        end
    end
end

floatButton.MouseButton1Click:Connect(function()
    toggles.platform = not toggles.platform
    if toggles.platform then
        floatButton.Text = "解除"; floatButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
        floatStatus.Text = "開啟"; floatStatus.TextColor3 = Color3.fromRGB(46, 125, 50)
        floatToggleFrame.BackgroundColor3 = Color3.fromRGB(227, 242, 253)
        floatControlFrame.Visible = true
        createPlatform()
    else
        floatButton.Text = "啟動"; floatButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        floatStatus.Text = "關閉"; floatStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
        floatToggleFrame.BackgroundColor3 = Color3.fromRGB(248, 249, 250)
        floatControlFrame.Visible = false
        if platform then platform:Destroy() end
    end
    updateStatus()
end)

floatUpButton.MouseButton1Down:Connect(function()   isUpButtonPressed   = true  end)
floatUpButton.MouseButton1Up:Connect(function()     isUpButtonPressed   = false end)
floatDownButton.MouseButton1Down:Connect(function() isDownButtonPressed = true  end)
floatDownButton.MouseButton1Up:Connect(function()   isDownButtonPressed = false end)

floatSpeedInput.FocusLost:Connect(function()
    values.floatSpeed = tonumber(floatSpeedInput.Text) or 1
    floatSpeedInput.Text = tostring(values.floatSpeed)
end)

RunService.RenderStepped:Connect(function()
    if toggles.platform and platform then
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                platform.Position = Vector3.new(hrp.Position.X, platform.Position.Y, hrp.Position.Z)
                if isUpButtonPressed   then movePlatform( values.floatSpeed) end
                if isDownButtonPressed then movePlatform(-values.floatSpeed) end
            end
        end
    end
end)

-- ====================
-- 拖曳（完美支援電腦滑鼠與手機觸控）
-- ====================
local function enableDrag(frame, dragHandle)
    local dragging = false
    local dragInput, dragStart, startPos

    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then update(input) end
    end)
end

enableDrag(mainFrame, titleBar)

-- 最小化視窗
local miniFrame = Instance.new("Frame")
miniFrame.Size = UDim2.new(0, 130, 0, 32)
miniFrame.Position = UDim2.new(0.5, -65, 0, 30)
miniFrame.BackgroundColor3 = Color3.fromRGB(102, 126, 234)
miniFrame.Visible = false
miniFrame.Parent = screenGui
Instance.new("UICorner", miniFrame).CornerRadius = UDim.new(0, 6)

local miniTitle = Instance.new("TextLabel")
miniTitle.Text = "🎮 控制器"
miniTitle.Size = UDim2.new(1, -36, 1, 0)
miniTitle.BackgroundTransparency = 1
miniTitle.Font = Enum.Font.GothamBold
miniTitle.TextSize = 16
miniTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
miniTitle.Parent = miniFrame

local expandButton = Instance.new("TextButton")
expandButton.Text = "+"
expandButton.Size = UDim2.new(0, 24, 0, 24)
expandButton.Position = UDim2.new(1, -28, 0, 4)
expandButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
expandButton.TextColor3 = Color3.fromRGB(255, 255, 255)
expandButton.Parent = miniFrame
Instance.new("UICorner", expandButton).CornerRadius = UDim.new(0, 5)

enableDrag(miniFrame, miniFrame)

minimizeButton.MouseButton1Click:Connect(function() mainFrame.Visible = false; miniFrame.Visible = true  end)
expandButton.MouseButton1Click:Connect(function()   miniFrame.Visible = false; mainFrame.Visible = true  end)

-- 關閉按鈕：完整還原所有設定
closeButton.MouseButton1Click:Connect(function()
    screenGui:Destroy()
    for _, v in pairs(connections) do if v then v:Disconnect() end end

    -- 還原光照
    Lighting.Ambient           = trueLightingBackup.Ambient
    Lighting.Brightness        = trueLightingBackup.Brightness
    Lighting.OutdoorAmbient    = trueLightingBackup.OutdoorAmbient
    Lighting.ColorShift_Top    = trueLightingBackup.ColorShift_Top
    Lighting.ColorShift_Bottom = trueLightingBackup.ColorShift_Bottom
    Lighting.FogEnd            = trueLightingBackup.FogEnd

    -- 還原後處理效果
    for effect, backup in pairs(postEffectBackups) do
        if effect and effect.Parent then
            for prop, value in pairs(backup) do
                pcall(function() effect[prop] = value end)
            end
        end
    end

    -- 還原大氣效果
    for atmosphere, backup in pairs(atmosphereBackups) do
        if atmosphere and atmosphere.Parent then
            for prop, value in pairs(backup) do
                pcall(function() atmosphere[prop] = value end)
            end
        end
    end

    -- 還原鏡頭設定
    player.CameraMaxZoomDistance = originalCameraMaxZoom
    player.CameraMinZoomDistance = originalCameraMinZoom
    player.CameraMode            = originalCameraMode

    -- 還原平台
    if platform then platform:Destroy() end

    -- 還原角色
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = originalSpeed
            if hum.UseJumpPower then hum.JumpPower = originalJump else hum.JumpHeight = originalJump end
        end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end)

-- 初始化
task.spawn(function()
    if player.Character then task.wait(0.1); getOriginalValues() end
end)
