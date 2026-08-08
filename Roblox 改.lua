-- ============================================
-- 服务获取
-- ============================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- 等待本地玩家加载
repeat wait() until LocalPlayer and LocalPlayer.Character
local Character = LocalPlayer.Character
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- 角色变化监听
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
end)

-- ============================================
-- 全局变量
-- ============================================
local ToggleStates = {}       -- 存储所有开关状态
local SliderValues = {}       -- 存储所有滑块值
local ActiveConnections = {}  -- 存储活跃的连接
local PanelOpen = false
local PanelVisible = true     -- 用于记录是否被最小化
local DraggingButton = false
local DraggingPanel = false
local DragStart = nil
local ButtonStartPos = nil
local PanelStartPos = nil

-- ============================================
-- 颜色主题配置（不变）
-- ============================================
local Theme = {
    Background = Color3.fromRGB(22, 22, 40),
    PanelBg = Color3.fromRGB(18, 18, 35),
    CardBg = Color3.fromRGB(30, 30, 55),
    CardBgAlt = Color3.fromRGB(35, 35, 60),
    Accent1 = Color3.fromRGB(130, 50, 240),    -- 紫色
    Accent2 = Color3.fromRGB(80, 120, 255),    -- 蓝色
    Accent3 = Color3.fromRGB(180, 60, 255),    -- 亮紫
    TextPrimary = Color3.fromRGB(240, 240, 255),
    TextSecondary = Color3.fromRGB(170, 170, 200),
    ToggleOn = Color3.fromRGB(130, 50, 240),
    ToggleOff = Color3.fromRGB(60, 60, 80),
    Danger = Color3.fromRGB(255, 70, 90),
    Success = Color3.fromRGB(50, 220, 120),
    Warning = Color3.fromRGB(255, 180, 50),
    GlowColor = Color3.fromRGB(150, 80, 255),
}

-- ============================================
-- 动画辅助函数
-- ============================================
local function TweenObject(obj, props, duration, easing, direction, repeats, delayTime)
    local tweenInfo = TweenInfo.new(
        duration or 0.3,
        easing or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out,
        repeats or 0,
        false,
        delayTime or 0
    )
    local tween = TweenService:Create(obj, tweenInfo, props)
    tween:Play()
    return tween
end

-- ============================================
-- 创建UI容器
-- ============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NebulaUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

-- 防止重复创建
if CoreGui:FindFirstChild("NebulaUI_Loaded") then
    CoreGui:FindFirstChild("NebulaUI_Loaded"):Destroy()
end
local loadMarker = Instance.new("Folder")
loadMarker.Name = "NebulaUI_Loaded"
loadMarker.Parent = CoreGui

-- ============================================
-- 创建悬浮打开按钮（横向条状）
-- ============================================
local FloatingButton = Instance.new("TextButton")
FloatingButton.Name = "FloatingButton"
FloatingButton.Parent = ScreenGui
FloatingButton.Size = UDim2.new(0, 100, 0, 36)
FloatingButton.Position = UDim2.new(0.82, 0, 0.75, 0)
FloatingButton.AnchorPoint = Vector2.new(0.5, 0.5)
FloatingButton.BackgroundColor3 = Theme.Accent1
FloatingButton.Text = "☰ 弑ℳ笙"
FloatingButton.TextColor3 = Color3.fromRGB(255, 255, 255)
FloatingButton.TextSize = 16
FloatingButton.Font = Enum.Font.GothamBold
FloatingButton.BorderSizePixel = 0
FloatingButton.AutoButtonColor = false
FloatingButton.ZIndex = 100

local FBCorner = Instance.new("UICorner")
FBCorner.CornerRadius = UDim.new(0, 18)
FBCorner.Parent = FloatingButton

local FBGradient = Instance.new("UIGradient")
FBGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Accent1),
    ColorSequenceKeypoint.new(0.5, Theme.Accent3),
    ColorSequenceKeypoint.new(1, Theme.Accent2),
})
FBGradient.Rotation = 45
FBGradient.Parent = FloatingButton

local FBStroke = Instance.new("UIStroke")
FBStroke.Color = Theme.GlowColor
FBStroke.Thickness = 2
FBStroke.Transparency = 0.3
FBStroke.Parent = FloatingButton

local FBShadow = Instance.new("Frame")
FBShadow.Name = "Shadow"
FBShadow.Size = UDim2.new(1, 8, 1, 8)
FBShadow.Position = UDim2.new(0, -4, 0, -4)
FBShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
FBShadow.BackgroundTransparency = 0.6
FBShadow.BorderSizePixel = 0
FBShadow.ZIndex = 99
FBShadow.Parent = FloatingButton
local FBShadowCorner = Instance.new("UICorner")
FBShadowCorner.CornerRadius = UDim.new(1, 0)
FBShadowCorner.Parent = FBShadow

local function StartPulseAnimation()
    spawn(function()
        while true do
            if not PanelOpen and FloatingButton and FloatingButton.Parent and FloatingButton.Visible then
                TweenObject(FloatingButton, {Size = UDim2.new(0, 110, 0, 42)}, 0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                wait(0.6)
                TweenObject(FloatingButton, {Size = UDim2.new(0, 100, 0, 36)}, 0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
                wait(0.6)
            else
                wait(1)
            end
        end
    end)
end
StartPulseAnimation()

-- ============================================
-- 创建主面板（屏幕正上方居中）
-- ============================================
local MainPanel = Instance.new("Frame")
MainPanel.Name = "MainPanel"
MainPanel.Parent = ScreenGui
MainPanel.Size = UDim2.new(0, 0, 0, 0)
MainPanel.Position = UDim2.new(0.5, 0, 0, 10) 
MainPanel.AnchorPoint = Vector2.new(0.5, 0)           
MainPanel.BackgroundColor3 = Theme.PanelBg
MainPanel.BackgroundTransparency = 0.05
MainPanel.BorderSizePixel = 0
MainPanel.ClipsDescendants = true
MainPanel.ZIndex = 50
MainPanel.Visible = false

local PanelCorner = Instance.new("UICorner")
PanelCorner.CornerRadius = UDim.new(0, 20)
PanelCorner.Parent = MainPanel

local PanelStroke = Instance.new("UIStroke")
PanelStroke.Color = Theme.Accent1
PanelStroke.Thickness = 1
PanelStroke.Transparency = 0.6
PanelStroke.Parent = MainPanel

-- ============================================
-- 标题栏（左侧标题，中间时钟，右侧按钮）
-- ============================================
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Parent = MainPanel
TitleBar.Size = UDim2.new(1, 0, 0, 45)
TitleBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
TitleBar.BackgroundTransparency = 0.7
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex = 55

local TitleBarCorner = Instance.new("UICorner")
TitleBarCorner.CornerRadius = UDim.new(0, 20)
TitleBarCorner.Parent = TitleBar

local TitleBarBottom = Instance.new("Frame")
TitleBarBottom.Size = UDim2.new(1, 0, 0.5, 0)
TitleBarBottom.Position = UDim2.new(0, 0, 0.5, 0)
TitleBarBottom.BackgroundColor3 = TitleBar.BackgroundColor3
TitleBarBottom.BackgroundTransparency = TitleBar.BackgroundTransparency
TitleBarBottom.BorderSizePixel = 0
TitleBarBottom.Parent = TitleBar
TitleBarBottom.ZIndex = 55

local TitleGradient = Instance.new("UIGradient")
TitleGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Accent1),
    ColorSequenceKeypoint.new(0.5, Theme.Accent3),
    ColorSequenceKeypoint.new(1, Theme.Accent2),
})
TitleGradient.Rotation = 90
TitleGradient.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Parent = TitleBar
TitleLabel.Size = UDim2.new(0.4, 0, 1, 0)
TitleLabel.Position = UDim2.new(0.05, 0, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "弑ℳ笙"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 18
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 56

-- 时钟
local ClockLabel = Instance.new("TextLabel")
ClockLabel.Size = UDim2.new(0, 60, 0, 20)
ClockLabel.Position = UDim2.new(0.6, 0, 0.25, 0)
ClockLabel.BackgroundTransparency = 1
ClockLabel.Text = "00:00"
ClockLabel.TextColor3 = Theme.TextSecondary
ClockLabel.TextSize = 12
ClockLabel.Font = Enum.Font.GothamMedium
ClockLabel.TextXAlignment = Enum.TextXAlignment.Center
ClockLabel.ZIndex = 56
ClockLabel.Parent = TitleBar

spawn(function()
    while true do
        if ClockLabel and ClockLabel.Parent then
            ClockLabel.Text = os.date("%H:%M")
        end
        wait(1)
    end
end)

-- 最小化按钮（用于"窗口隐藏"）
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Parent = TitleBar
MinimizeButton.Size = UDim2.new(0, 28, 0, 28)
MinimizeButton.Position = UDim2.new(0.82, 0, 0.20, 0)
MinimizeButton.BackgroundColor3 = Theme.Warning
MinimizeButton.BackgroundTransparency = 0.15
MinimizeButton.Text = "─"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 16
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.BorderSizePixel = 0
MinimizeButton.ZIndex = 58
MinimizeButton.AutoButtonColor = false
local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(1, 0)
MinCorner.Parent = MinimizeButton

-- 关闭按钮
local CloseButton = Instance.new("TextButton")
CloseButton.Parent = TitleBar
CloseButton.Size = UDim2.new(0, 28, 0, 28)
CloseButton.Position = UDim2.new(0.92, 0, 0.20, 0)
CloseButton.BackgroundColor3 = Color3.fromRGB(255, 70, 90)
CloseButton.BackgroundTransparency = 0.15
CloseButton.Text = "✕"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 14
CloseButton.Font = Enum.Font.GothamBold
CloseButton.BorderSizePixel = 0
CloseButton.ZIndex = 58
CloseButton.AutoButtonColor = false
local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(1, 0)
CloseCorner.Parent = CloseButton

-- ============================================
-- 标签栏
-- ============================================
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Parent = MainPanel
TabBar.Size = UDim2.new(1, 0, 0, 38)
TabBar.Position = UDim2.new(0, 0, 0, 45)
TabBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
TabBar.BackgroundTransparency = 0.85
TabBar.BorderSizePixel = 0
TabBar.ZIndex = 55

local TabButtonsFrame = Instance.new("Frame")
TabButtonsFrame.Parent = TabBar
TabButtonsFrame.Size = UDim2.new(0.94, 0, 1, 0)
TabButtonsFrame.Position = UDim2.new(0.03, 0, 0, 0)
TabButtonsFrame.BackgroundTransparency = 1
TabButtonsFrame.ZIndex = 56

local TabScrollingFrame = Instance.new("ScrollingFrame")
TabScrollingFrame.Parent = TabButtonsFrame
TabScrollingFrame.Size = UDim2.new(1, 0, 1, 0)
TabScrollingFrame.BackgroundTransparency = 1
TabScrollingFrame.BorderSizePixel = 0
TabScrollingFrame.ScrollBarThickness = 0
TabScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
TabScrollingFrame.ScrollingDirection = Enum.ScrollingDirection.X
TabScrollingFrame.ZIndex = 56

local TabButtonsList = Instance.new("UIListLayout")
TabButtonsList.Parent = TabScrollingFrame
TabButtonsList.FillDirection = Enum.FillDirection.Horizontal
TabButtonsList.HorizontalAlignment = Enum.HorizontalAlignment.Left
TabButtonsList.VerticalAlignment = Enum.VerticalAlignment.Center
TabButtonsList.Padding = UDim.new(0, 4)
TabButtonsList.SortOrder = Enum.SortOrder.LayoutOrder

-- ============================================
-- 内容区域
-- ============================================
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Parent = MainPanel
ContentArea.Size = UDim2.new(1, 0, 0.6, -100)
ContentArea.Position = UDim2.new(0, 0, 0, 83)
ContentArea.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ContentArea.BackgroundTransparency = 0.9
ContentArea.BorderSizePixel = 0
ContentArea.ZIndex = 52

local ContentScrolling = Instance.new("ScrollingFrame")
ContentScrolling.Name = "ContentScrolling"
ContentScrolling.Parent = ContentArea
ContentScrolling.Size = UDim2.new(1, -8, 1, -4)
ContentScrolling.Position = UDim2.new(0, 4, 0, 2)
ContentScrolling.BackgroundTransparency = 1
ContentScrolling.BorderSizePixel = 0
ContentScrolling.ScrollBarThickness = 3
ContentScrolling.ScrollBarImageColor3 = Theme.Accent1
ContentScrolling.ScrollBarImageTransparency = 0.5
ContentScrolling.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentScrolling.ScrollingDirection = Enum.ScrollingDirection.Y
ContentScrolling.ZIndex = 53
ContentScrolling.ElasticBehavior = Enum.ElasticBehavior.Always
ContentScrolling.ScrollingEnabled = true

local ContentList = Instance.new("UIListLayout")
ContentList.Parent = ContentScrolling
ContentList.FillDirection = Enum.FillDirection.Vertical
ContentList.HorizontalAlignment = Enum.HorizontalAlignment.Center
ContentList.VerticalAlignment = Enum.VerticalAlignment.Top
ContentList.Padding = UDim.new(0, 6)
ContentList.SortOrder = Enum.SortOrder.LayoutOrder

-- ============================================
-- 底部状态栏
-- ============================================
local StatusBar = Instance.new("Frame")
StatusBar.Name = "StatusBar"
StatusBar.Parent = MainPanel
StatusBar.Size = UDim2.new(1, 0, 0, 22)
StatusBar.Position = UDim2.new(0, 0, 1, -22)
StatusBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
StatusBar.BackgroundTransparency = 0.75
StatusBar.BorderSizePixel = 0
StatusBar.ZIndex = 55

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Parent = StatusBar
StatusLabel.Size = UDim2.new(1, -20, 1, 0)
StatusLabel.Position = UDim2.new(0, 10, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "✨ 弑ℳ笙 UI v1.0 | 忍者注入器"
StatusLabel.TextColor3 = Theme.TextSecondary
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.ZIndex = 56

-- ============================================
-- 标签和功能管理系统
-- ============================================
local Tabs = {}
local CurrentTab = nil
local TabButtons = {}
local AllFunctions = {}

local function UpdateCanvasSize()
    local totalHeight = 0
    if ContentScrolling and ContentList then
        local count = 0
        for _, child in ipairs(ContentScrolling:GetChildren()) do
            if child:IsA("Frame") and child.Name ~= "EmptyState" then
                count = count + 1
            end
        end
        totalHeight = count * 54 + (count - 1) * 6 + 12
        ContentScrolling.CanvasSize = UDim2.new(0, 0, 0, math.max(totalHeight, 10))
    end
end

local function CreateToggleSwitch(parent, initialState, callback)
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(0, 48, 0, 26)
    ToggleFrame.BackgroundColor3 = initialState and Theme.ToggleOn or Theme.ToggleOff
    ToggleFrame.BorderSizePixel = 0
    ToggleFrame.ZIndex = 60
    ToggleFrame.Parent = parent
    
    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(1, 0)
    ToggleCorner.Parent = ToggleFrame
    
    local ToggleKnob = Instance.new("Frame")
    ToggleKnob.Size = UDim2.new(0, 20, 0, 20)
    ToggleKnob.Position = initialState and UDim2.new(0, 25, 0, 3) or UDim2.new(0, 3, 0, 3)
    ToggleKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ToggleKnob.BorderSizePixel = 0
    ToggleKnob.ZIndex = 61
    ToggleKnob.Parent = ToggleFrame
    
    local KnobCorner = Instance.new("UICorner")
    KnobCorner.CornerRadius = UDim.new(1, 0)
    KnobCorner.Parent = ToggleKnob
    
    local KnobShadow = Instance.new("UIStroke")
    KnobShadow.Color = Color3.fromRGB(0, 0, 0)
    KnobShadow.Thickness = 1
    KnobShadow.Transparency = 0.6
    KnobShadow.Parent = ToggleKnob
    
    local isOn = initialState or false
    
    local function SetState(newState, animate)
        isOn = newState
        if animate then
            TweenObject(ToggleFrame, {BackgroundColor3 = newState and Theme.ToggleOn or Theme.ToggleOff}, 0.25)
            TweenObject(ToggleKnob, {Position = newState and UDim2.new(0, 25, 0, 3) or UDim2.new(0, 3, 0, 3)}, 0.25, Enum.EasingStyle.Quart)
        else
            ToggleFrame.BackgroundColor3 = newState and Theme.ToggleOn or Theme.ToggleOff
            ToggleKnob.Position = newState and UDim2.new(0, 25, 0, 3) or UDim2.new(0, 3, 0, 3)
        end
        if callback then
            callback(newState)
        end
    end
    
    ToggleFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            SetState(not isOn, true)
        end
    end)
    
    return {
        Frame = ToggleFrame,
        SetState = SetState,
        GetState = function() return isOn end,
    }
end

local function CreateFunctionCard(funcData, parent)
    local Card = Instance.new("Frame")
    Card.Name = funcData.Name or "FunctionCard"
    Card.Size = UDim2.new(0.92, 0, 0, 48)
    Card.BackgroundColor3 = Theme.CardBg
    Card.BorderSizePixel = 0
    Card.ZIndex = 54
    Card.Parent = parent
    Card.LayoutOrder = funcData.Order or 99
    
    local CardCorner = Instance.new("UICorner")
    CardCorner.CornerRadius = UDim.new(0, 12)
    CardCorner.Parent = Card
    
    -- 功能名称
    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(0.5, 0, 1, 0)
    NameLabel.Position = UDim2.new(0, 16, 0, 0)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = funcData.DisplayName or funcData.Name or "功能"
    NameLabel.TextColor3 = Theme.TextPrimary
    NameLabel.TextSize = 14
    NameLabel.Font = Enum.Font.GothamSemibold
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.ZIndex = 55
    NameLabel.Parent = Card
    
    if funcData.Description then
        local DescLabel = Instance.new("TextLabel")
        DescLabel.Size = UDim2.new(0.5, 0, 0.4, 0)
        DescLabel.Position = UDim2.new(0, 16, 0.55, 0)
        DescLabel.BackgroundTransparency = 1
        DescLabel.Text = funcData.Description
        DescLabel.TextColor3 = Theme.TextSecondary
        DescLabel.TextSize = 10
        DescLabel.Font = Enum.Font.GothamMedium
        DescLabel.TextXAlignment = Enum.TextXAlignment.Left
        DescLabel.ZIndex = 55
        DescLabel.Parent = Card
    end
    
    local ControlObject = nil
    
    if funcData.Type == "Toggle" then
        local toggleContainer = Instance.new("Frame")
        toggleContainer.Size = UDim2.new(0, 52, 0, 30)
        toggleContainer.Position = UDim2.new(0.88, 0, 0.18, 0)
        toggleContainer.BackgroundTransparency = 1
        toggleContainer.ZIndex = 56
        toggleContainer.Parent = Card
        
        local initialState = funcData.DefaultState or false
        ToggleStates[funcData.Name] = initialState
        
        ControlObject = CreateToggleSwitch(toggleContainer, initialState, function(newState)
            ToggleStates[funcData.Name] = newState
            if funcData.Callback then
                local success, err = pcall(funcData.Callback, newState)
                if not success then
                    warn("功能 [" .. funcData.Name .. "] 执行错误: " .. tostring(err))
                end
            end
        end)
        
    elseif funcData.Type == "Button" then
        local ActionButton = Instance.new("TextButton")
        ActionButton.Size = UDim2.new(0, 60, 0, 28)
        ActionButton.Position = UDim2.new(0.82, 0, 0.2, 0)
        ActionButton.BackgroundColor3 = Theme.Accent1
        ActionButton.Text = funcData.ButtonText or "执行"
        ActionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        ActionButton.TextSize = 12
        ActionButton.Font = Enum.Font.GothamBold
        ActionButton.BorderSizePixel = 0
        ActionButton.ZIndex = 56
        ActionButton.AutoButtonColor = false
        ActionButton.Parent = Card
        
        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 8)
        BtnCorner.Parent = ActionButton
        
        local BtnGradient = Instance.new("UIGradient")
        BtnGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent1),
            ColorSequenceKeypoint.new(1, Theme.Accent2),
        })
        BtnGradient.Rotation = 45
        BtnGradient.Parent = ActionButton
        
        ActionButton.MouseButton1Click:Connect(function()
            TweenObject(ActionButton, {Size = UDim2.new(0, 56, 0, 26)}, 0.1)
            wait(0.1)
            TweenObject(ActionButton, {Size = UDim2.new(0, 60, 0, 28)}, 0.1)
            
            if funcData.Callback then
                local success, err = pcall(funcData.Callback)
                if not success then
                    warn("功能 [" .. funcData.Name .. "] 执行错误: " .. tostring(err))
                end
            end
        end)
        
        ControlObject = ActionButton
        
    elseif funcData.Type == "Slider" then
        local sliderContainer = Instance.new("Frame")
        sliderContainer.Size = UDim2.new(0.35, 0, 0.6, 0)
        sliderContainer.Position = UDim2.new(0.60, 0, 0.2, 0)
        sliderContainer.BackgroundTransparency = 1
        sliderContainer.ZIndex = 56
        sliderContainer.Parent = Card
        
        local sliderValue = funcData.DefaultValue or funcData.Min or 50
        SliderValues[funcData.Name] = sliderValue
        
        local ValueLabel = Instance.new("TextLabel")
        ValueLabel.Size = UDim2.new(0, 40, 0, 18)
        ValueLabel.Position = UDim2.new(0.78, 0, 0.08, 0)
        ValueLabel.BackgroundTransparency = 1
        ValueLabel.Text = tostring(sliderValue)
        ValueLabel.TextColor3 = Theme.Accent3
        ValueLabel.TextSize = 12
        ValueLabel.Font = Enum.Font.GothamBold
        ValueLabel.ZIndex = 57
        ValueLabel.Parent = Card
        
        local MinusBtn = Instance.new("TextButton")
        MinusBtn.Size = UDim2.new(0, 22, 0, 22)
        MinusBtn.Position = UDim2.new(0.50, 0, 0.12, 0)
        MinusBtn.BackgroundColor3 = Theme.CardBgAlt
        MinusBtn.Text = "−"
        MinusBtn.TextColor3 = Theme.TextPrimary
        MinusBtn.TextSize = 16
        MinusBtn.Font = Enum.Font.GothamBold
        MinusBtn.BorderSizePixel = 0
        MinusBtn.ZIndex = 57
        MinusBtn.AutoButtonColor = false
        MinusBtn.Parent = Card
        
        local MinusCorner = Instance.new("UICorner")
        MinusCorner.CornerRadius = UDim.new(0, 6)
        MinusCorner.Parent = MinusBtn
        
        local PlusBtn = Instance.new("TextButton")
        PlusBtn.Size = UDim2.new(0, 22, 0, 22)
        PlusBtn.Position = UDim2.new(0.68, 0, 0.12, 0)
        PlusBtn.BackgroundColor3 = Theme.CardBgAlt
        PlusBtn.Text = "+"
        PlusBtn.TextColor3 = Theme.TextPrimary
        PlusBtn.TextSize = 16
        PlusBtn.Font = Enum.Font.GothamBold
        PlusBtn.BorderSizePixel = 0
        PlusBtn.ZIndex = 57
        PlusBtn.AutoButtonColor = false
        PlusBtn.Parent = Card
        
        local PlusCorner = Instance.new("UICorner")
        PlusCorner.CornerRadius = UDim.new(0, 6)
        PlusCorner.Parent = PlusBtn
        
        local function UpdateSlider(newVal)
            newVal = math.clamp(newVal, funcData.Min or 0, funcData.Max or 100)
            SliderValues[funcData.Name] = newVal
            ValueLabel.Text = tostring(newVal)
            if funcData.Callback then
                local success, err = pcall(funcData.Callback, newVal)
                if not success then
                    warn("功能 [" .. funcData.Name .. "] 滑块回调错误: " .. tostring(err))
                end
            end
        end
        
        MinusBtn.MouseButton1Click:Connect(function()
            UpdateSlider(SliderValues[funcData.Name] - (funcData.Step or 1))
        end)
        
        PlusBtn.MouseButton1Click:Connect(function()
            UpdateSlider(SliderValues[funcData.Name] + (funcData.Step or 1))
        end)
        
        ControlObject = {Minus = MinusBtn, Plus = PlusBtn, Update = UpdateSlider}
    end
    
    return Card
end

local function RefreshContent(tabName)
    for _, child in ipairs(ContentScrolling:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "EmptyState" then
            child:Destroy()
        end
    end
    
    local tabData = Tabs[tabName]
    if not tabData then
        UpdateCanvasSize()
        return
    end
    
    local hasFunctions = false
    for _, funcData in ipairs(tabData.Functions) do
        if funcData then
            CreateFunctionCard(funcData, ContentScrolling)
            hasFunctions = true
        end
    end
    
    if not hasFunctions then
        local EmptyState = Instance.new("Frame")
        EmptyState.Name = "EmptyState"
        EmptyState.Size = UDim2.new(0.9, 0, 0, 60)
        EmptyState.BackgroundTransparency = 1
        EmptyState.ZIndex = 54
        EmptyState.Parent = ContentScrolling
        
        local EmptyLabel = Instance.new("TextLabel")
        EmptyLabel.Size = UDim2.new(1, 0, 1, 0)
        EmptyLabel.BackgroundTransparency = 1
        EmptyLabel.Text = "📭 此分类暂无功能\n请在脚本中添加"
        EmptyLabel.TextColor3 = Theme.TextSecondary
        EmptyLabel.TextSize = 13
        EmptyLabel.Font = Enum.Font.GothamMedium
        EmptyLabel.TextWrapped = true
        EmptyLabel.ZIndex = 55
        EmptyLabel.Parent = EmptyState
    end
    
    UpdateCanvasSize()
    ContentScrolling.CanvasPosition = Vector2.new(0, 0)
end

local function SwitchTab(tabName)
    if CurrentTab == tabName then return end
    CurrentTab = tabName
    
    for name, btn in pairs(TabButtons) do
        if name == tabName then
            btn.BackgroundTransparency = 0.1
            btn.BackgroundColor3 = Theme.Accent1
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundTransparency = 0.7
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            btn.TextColor3 = Theme.TextSecondary
        end
    end
    
    RefreshContent(tabName)
end

local function CreateTab(tabName, displayName, icon)
    if Tabs[tabName] then return end
    
    Tabs[tabName] = {
        Name = tabName,
        DisplayName = displayName or tabName,
        Icon = icon or "📌",
        Functions = {},
    }
    
    local TabButton = Instance.new("TextButton")
    TabButton.Name = tabName
    TabButton.Size = UDim2.new(0, 75, 0, 28)
    TabButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    TabButton.BackgroundTransparency = 0.7
    TabButton.Text = (icon or "📌") .. " " .. (displayName or tabName)
    TabButton.TextColor3 = Theme.TextSecondary
    TabButton.TextSize = 12
    TabButton.Font = Enum.Font.GothamSemibold
    TabButton.BorderSizePixel = 0
    TabButton.ZIndex = 57
    TabButton.AutoButtonColor = false
    TabButton.Parent = TabScrollingFrame
    
    local TabBtnCorner = Instance.new("UICorner")
    TabBtnCorner.CornerRadius = UDim.new(0, 8)
    TabBtnCorner.Parent = TabButton
    
    TabButton.MouseButton1Click:Connect(function()
        SwitchTab(tabName)
    end)
    
    TabButtons[tabName] = TabButton
    
    local totalWidth = 0
    for _, _ in pairs(Tabs) do
        totalWidth = totalWidth + 79
    end
    TabScrollingFrame.CanvasSize = UDim2.new(0, totalWidth, 0, 0)
    
    if not CurrentTab then
        SwitchTab(tabName)
    end
    
    return tabName
end

local function AddFunction(tabName, funcData)
    if not Tabs[tabName] then
        warn("标签 [" .. tabName .. "] 不存在，请先创建标签")
        return false
    end
    
    if not funcData.Name then
        warn("功能必须有一个Name字段")
        return false
    end
    
    funcData.Type = funcData.Type or "Toggle"
    funcData.Order = funcData.Order or 99
    
    table.insert(Tabs[tabName].Functions, funcData)
    AllFunctions[funcData.Name] = funcData
    
    if CurrentTab == tabName then
        RefreshContent(tabName)
    end
    
    return true
end

-- ============================================
-- 面板动画（窗口逻辑）
-- ============================================
local function OpenPanel()
    if PanelOpen then return end
    PanelOpen = true
    
    MainPanel.Visible = true
    MainPanel.Size = UDim2.new(0, 0, 0, 0)
    MainPanel.BackgroundTransparency = 1
    
    local targetWidth = 360
    local targetHeight = 440
    
    TweenObject(MainPanel, {
        Size = UDim2.new(0, targetWidth, 0, targetHeight),
        BackgroundTransparency = 0.05,
    }, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    
    FloatingButton.Visible = false
    
    StatusLabel.Text = "✨ 弑ℳ笙 UI v1.0 | 已就绪"
end

local function ClosePanel()
    if not PanelOpen then return end
    PanelOpen = false
    
    TweenObject(MainPanel, {
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
    }, 0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
    
    wait(0.3)
    MainPanel.Visible = false
    
    FloatingButton.Visible = true
    
    StatusLabel.Text = "✨ 弑ℳ笙 UI v1.0 | 忍者注入器"
end

local function MinimizePanel()
    if not PanelOpen then return end
    PanelOpen = false
    MainPanel.Visible = false
    FloatingButton.Visible = true
    StatusLabel.Text = "📌 窗口已隐藏 | 点击【☰ 弑ℳ笙】恢复"
end

-- ============================================
-- 事件绑定
-- ============================================
FloatingButton.MouseButton1Click:Connect(function()
    if DraggingPanel then return end
    if not PanelOpen then
        OpenPanel()
    else
        ClosePanel()
    end
end)

CloseButton.MouseButton1Click:Connect(function()
    ClosePanel()
end)

MinimizeButton.MouseButton1Click:Connect(function()
    MinimizePanel()
end)

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        if not ContentArea.Visible and PanelOpen then
            ContentArea.Visible = true
            TabBar.Visible = true
            TweenObject(MainPanel, {
                Size = UDim2.new(0, 360, 0, 440),
            }, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            StatusLabel.Text = "✨ 弑ℳ笙 UI v1.0 | 已就绪"
        end
    end
end)

-- ============================================
-- 拖拽系统
-- ============================================
FloatingButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        DraggingButton = true
        DragStart = input.Position
        ButtonStartPos = FloatingButton.Position
        input.UserInputState = Enum.UserInputState.Begin
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if DraggingButton and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - DragStart
        local screenSize = workspace.CurrentCamera.ViewportSize
        local newX = math.clamp(ButtonStartPos.X.Scale + delta.X / screenSize.X, 0.05, 0.92)
        local newY = math.clamp(ButtonStartPos.Y.Scale + delta.Y / screenSize.Y, 0.05, 0.92)
        FloatingButton.Position = UDim2.new(newX, 0, newY, 0)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        DraggingButton = false
        DragStart = nil
        ButtonStartPos = nil
    end
end)

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        DraggingPanel = true
        DragStart = input.Position
        PanelStartPos = MainPanel.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if DraggingPanel and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - DragStart
        local screenSize = workspace.CurrentCamera.ViewportSize
        local newX = math.clamp(PanelStartPos.X.Scale + delta.X / screenSize.X, 0.08, 0.92)
        local newY = math.clamp(PanelStartPos.Y.Scale + delta.Y / screenSize.Y, 0.08, 0.92)
        MainPanel.Position = UDim2.new(newX, 0, newY, 0)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        DraggingPanel = false
        DragStart = nil
        PanelStartPos = nil
    end
end)

-- ============================================
-- ============================================
--  ★★★ 功能配置区 ★★★
--  在此处添加你的标签和功能
--  重新执行脚本即可看到更新
-- ============================================
-- ============================================

-- 创建标签页
CreateTab("Movement", "移动", "🏃")
CreateTab("Combat", "战斗", "⚔️")
CreateTab("Visual", "视觉", "👁️")
CreateTab("Utility", "工具", "🔧")

-- ============ 原有功能保持不变 ============
-- 提示不是电脑或者没有键盘代码的不要用飞行

AddFunction("Movement", {
    Name = "Fly",
    DisplayName = "飞行模式",
    Description = "在空中自由飞行",
    Type = "Toggle",
    DefaultState = false,
    Order = 1,
    Callback = function(state)
        if state then
            local flySpeed = SliderValues["FlySpeed"] or 30
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            if not hrp or not hum then return end
            
            hum.PlatformStand = true
            
            local flyConnection
            flyConnection = RunService.Heartbeat:Connect(function()
                if not ToggleStates["Fly"] then
                    flyConnection:Disconnect()
                    if hum and hum.Parent then
                        hum.PlatformStand = false
                    end
                    return
                end
                
                local currentChar = LocalPlayer.Character
                if not currentChar then
                    flyConnection:Disconnect()
                    return
                end
                local currentHrp = currentChar:FindFirstChild("HumanoidRootPart")
                if not currentHrp then
                    flyConnection:Disconnect()
                    return
                end
                
                local speed = SliderValues["FlySpeed"] or 30
                local moveDirection = Vector3.new(0, 0, 0)
                
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDirection = moveDirection + workspace.CurrentCamera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDirection = moveDirection - workspace.CurrentCamera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDirection = moveDirection - workspace.CurrentCamera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDirection = moveDirection + workspace.CurrentCamera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDirection = moveDirection + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveDirection = moveDirection - Vector3.new(0, 1, 0)
                end
                
                if moveDirection.Magnitude > 0 then
                    currentHrp.CFrame = currentHrp.CFrame + moveDirection.Unit * speed * 0.05
                else
                    currentHrp.Velocity = Vector3.new(0, 0, 0)
                end
            end)
            
            ActiveConnections["Fly"] = flyConnection
        else
            if ActiveConnections["Fly"] then
                ActiveConnections["Fly"]:Disconnect()
                ActiveConnections["Fly"] = nil
            end
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    hum.PlatformStand = false
                end
            end
        end
    end
})

AddFunction("Movement", {
    Name = "FlySpeed",
    DisplayName = "飞行速度",
    Description = "调节飞行移动速度",
    Type = "Slider",
    DefaultValue = 30,
    Min = 5,
    Max = 100,
    Step = 5,
    Order = 2,
    Callback = function(value) end
})

AddFunction("Movement", {
    Name = "SpeedBoost",
    DisplayName = "超级加速",
    Description = "大幅提升移动速度",
    Type = "Toggle",
    DefaultState = false,
    Order = 3,
    Callback = function(state)
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then return end
        
        if state then
            hum.WalkSpeed = SliderValues["WalkSpeed"] or 40
        else
            hum.WalkSpeed = 16
        end
    end
})

AddFunction("Movement", {
    Name = "WalkSpeed",
    DisplayName = "行走速度",
    Description = "调节行走速度数值",
    Type = "Slider",
    DefaultValue = 40,
    Min = 16,
    Max = 999999,
    Step = 4,
    Order = 4,
    Callback = function(value)
        if ToggleStates["SpeedBoost"] then
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    hum.WalkSpeed = value
                end
            end
        end
    end
})

AddFunction("Movement", {
    Name = "NoClip",
    DisplayName = "穿墙模式",
    Description = "穿越所有墙壁和障碍物",
    Type = "Toggle",
    DefaultState = false,
    Order = 5,
    Callback = function(state)
        local function setCollision(char, enabled)
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = enabled
                end
            end
        end
        
        if state then
            local char = LocalPlayer.Character
            if char then
                setCollision(char, false)
            end
            
            local noclipConnection
            noclipConnection = RunService.Stepped:Connect(function()
                if not ToggleStates["NoClip"] then
                    noclipConnection:Disconnect()
                    return
                end
                local currentChar = LocalPlayer.Character
                if currentChar then
                    setCollision(currentChar, false)
                end
            end)
            
            ActiveConnections["NoClip"] = noclipConnection
        else
            if ActiveConnections["NoClip"] then
                ActiveConnections["NoClip"]:Disconnect()
                ActiveConnections["NoClip"] = nil
            end
            local char = LocalPlayer.Character
            if char then
                setCollision(char, true)
            end
        end
    end
})

AddFunction("Movement", {
    Name = "InfiniteJump",
    DisplayName = "无限跳跃",
    Description = "可以无限连跳",
    Type = "Toggle",
    DefaultState = false,
    Order = 6,
    Callback = function(state)
        if state then
            local jumpConnection
            jumpConnection = UserInputService.JumpRequest:Connect(function()
                if not ToggleStates["InfiniteJump"] then return end
                local char = LocalPlayer.Character
                if char then
                    local hum = char:FindFirstChild("Humanoid")
                    if hum then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end
            end)
            ActiveConnections["InfiniteJump"] = jumpConnection
        else
            if ActiveConnections["InfiniteJump"] then
                ActiveConnections["InfiniteJump"]:Disconnect()
                ActiveConnections["InfiniteJump"] = nil
            end
        end
    end
})

AddFunction("Movement", {
    Name = "JumpPower",
    DisplayName = "跳跃高度",
    Description = "调节跳跃力度",
    Type = "Slider",
    DefaultValue = 50,
    Min = 20,
    Max = 300,
    Step = 10,
    Order = 7,
    Callback = function(value)
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then
                hum.JumpPower = value
            end
        end
    end
})

AddFunction("Combat", {
    Name = "GodMode",
    DisplayName = "无敌模式",
    Description = "免疫所有伤害",
    Type = "Toggle",
    DefaultState = false,
    Order = 1,
    Callback = function(state)
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then
                if state then
                    hum.MaxHealth = math.huge
                    hum.Health = math.huge
                    local godConnection
                    godConnection = RunService.Heartbeat:Connect(function()
                        if not ToggleStates["GodMode"] then
                            godConnection:Disconnect()
                            return
                        end
                        local c = LocalPlayer.Character
                        if c then
                            local h = c:FindFirstChild("Humanoid")
                            if h and h.Health < h.MaxHealth then
                                h.Health = h.MaxHealth
                            end
                        end
                    end)
                    ActiveConnections["GodMode"] = godConnection
                else
                    if ActiveConnections["GodMode"] then
                        ActiveConnections["GodMode"]:Disconnect()
                        ActiveConnections["GodMode"] = nil
                    end
                    hum.MaxHealth = 100
                    hum.Health = math.min(hum.Health, 100)
                end
            end
        end
    end
})

--  新增：自瞄功能（战斗标签）
-- ============================================
AddFunction("Combat", {
    Name = "Aimbot",
    DisplayName = "自动瞄准",
    Description = "自动锁定最近敌人",
    Type = "Toggle",
    DefaultState = false,
    Order = 3,
    Callback = function(state)
        local camera = workspace.CurrentCamera
        if not camera then return end

        if state then
            local aimbotConnection
            aimbotConnection = RunService.RenderStepped:Connect(function()
                -- 找到最近的敌人
                local closestPlayer = nil
                local closestDistance = math.huge
                local localChar = LocalPlayer.Character
                if not localChar then return end
                local localRoot = localChar:FindFirstChild("HumanoidRootPart")
                if not localRoot then return end

                for _, player in ipairs(Players:GetPlayers()) do
                    if player == LocalPlayer then continue end
                    local char = player.Character
                    if char then
                        local root = char:FindFirstChild("HumanoidRootPart")
                        if root then
                            local dist = (root.Position - localRoot.Position).Magnitude
                            if dist < closestDistance then
                                closestDistance = dist
                                closestPlayer = root
                            end
                        end
                    end
                end

                -- 锁定最近敌人的躯干（也可改成头部：Head 部件）
                if closestPlayer then
                    camera.CFrame = CFrame.new(camera.CFrame.Position, closestPlayer.Position)
                end
            end)

            ActiveConnections["Aimbot"] = aimbotConnection
        else
            if ActiveConnections["Aimbot"] then
                ActiveConnections["Aimbot"]:Disconnect()
                ActiveConnections["Aimbot"] = nil
            end
        end
    end
})

AddFunction("Combat", {
    Name = "KillAura",
    DisplayName = "击杀光环",
    Description = "对附近敌人造成伤害",
    Type = "Button",
    ButtonText = "激活",
    Order = 2,
    Callback = function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local targetChar = player.Character
                if targetChar then
                    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
                    if targetHrp and (targetHrp.Position - hrp.Position).Magnitude < 20 then
                        local targetHum = targetChar:FindFirstChild("Humanoid")
                        if targetHum then
                            targetHum.Health = 0
                        end
                    end
                end
            end
        end
    end
})

-- 新增：无限子弹
AddFunction("Combat", {
    Name = "InfiniteAmmo",
    DisplayName = "无限子弹",
  local player = game:GetService("Players").LocalPlayer
local backpack = player.PlayerGui.Backpack

local function setInfiniteAmmo(weapon)
    local config = weapon:FindFirstChild("Config")
    if config then
        local ammo = config:FindFirstChild("Ammo")
        if ammo then
            ammo:GetPropertyChangedSignal("Value"):Connect(function()
                ammo.Value = math.huge
            end)
            ammo.Value = math.huge
        end
        
        local totalAmmo = config:FindFirstChild("TotalAmmo")
        if totalAmmo then
            totalAmmo:GetPropertyChangedSignal("Value"):Connect(function()
                totalAmmo.Value = math.huge
            end)
            totalAmmo.Value = math.huge
        end
    end
end

for _, weapon in pairs(backpack:GetChildren()) do
    setInfiniteAmmo(weapon)
end

backpack.ChildAdded:Connect(function(weapon)
    task.wait(0.1)
    setInfiniteAmmo(weapon)
end)

-- 新增：射速加快
AddFunction("Combat", {
    Name = "RapidFire",
    DisplayName = "射速加快",
    Description = "大幅提高武器射速",
    Type = "Toggle",
    DefaultState = false,
    Order = 5,
    Callback = function(state)
        if state then
            local firerateConnection
            firerateConnection = RunService.Heartbeat:Connect(function()
                if not ToggleStates["RapidFire"] then
                    firerateConnection:Disconnect()
                    return
                end
                local char = LocalPlayer.Character
                if not char then return end
                local tool = char:FindFirstChildOfClass("Tool")
                if not tool then return end
                for _, v in ipairs(tool:GetDescendants()) do
                    if v.Name == "FireRate" or v.Name == "Cooldown" or v.Name == "Delay" then
                        if v:IsA("NumberValue") or v:IsA("IntValue") then
                            v.Value = 0.05
                        end
                    end
                end
            end)
            ActiveConnections["RapidFire"] = firerateConnection
        else
            if ActiveConnections["RapidFire"] then
                ActiveConnections["RapidFire"]:Disconnect()
                ActiveConnections["RapidFire"] = nil
            end
        end
    end
})

AddFunction("Visual", {
    Name = "NightVision",
    DisplayName = "夜视模式",
    Description = "在黑暗中看清一切",
    Type = "Toggle",
    DefaultState = false,
    Order = 1,
    Callback = function(state)
        if state then
            local lighting = game:GetService("Lighting")
            if lighting then
                lighting.Brightness = 3
                lighting.ClockTime = 14
                lighting.FogEnd = 100000
                lighting.GlobalShadows = false
            end
        else
            local lighting = game:GetService("Lighting")
            if lighting then
                lighting.Brightness = 1
                lighting.ClockTime = 14
                lighting.FogEnd = 100000
                lighting.GlobalShadows = true
            end
        end
    end
})

AddFunction("Visual", {
    Name = "FullBright",
    DisplayName = "全图高亮",
    Description = "最大化地图亮度",
    Type = "Toggle",
    DefaultState = false,
    Order = 2,
    Callback = function(state)
        local lighting = game:GetService("Lighting")
        if not lighting then return end
        if state then
            lighting.Ambient = Color3.fromRGB(255, 255, 255)
            lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            lighting.Brightness = 5
            lighting.ExposureCompensation = 2
        else
            lighting.Ambient = Color3.fromRGB(0, 0, 0)
            lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
            lighting.Brightness = 1
            lighting.ExposureCompensation = 0
        end
    end
})

-- 新增：透视功能
AddFunction("Visual", {
    Name = "ESP",
    DisplayName = "透视显示",
    Description = "高亮显示所有玩家位置",
    Type = "Toggle",
    DefaultState = false,
    Order = 3,
    Callback = function(state)
        local espHighlights = {}

        local function highlightCharacter(char)
            if not char then return end
            if char:FindFirstChild("ESP_Highlight") then return end
            local highlight = Instance.new("Highlight")
            highlight.Name = "ESP_Highlight"
            highlight.FillColor = Color3.fromRGB(255, 0, 0)
            highlight.FillTransparency = 0.5
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.OutlineTransparency = 0
            highlight.Parent = char
            table.insert(espHighlights, highlight)
        end

        local function unhighlightCharacter(char)
            if not char then return end
            local hl = char:FindFirstChild("ESP_Highlight")
            if hl then hl:Destroy() end
        end

        local function clearAll()
            for _, hl in ipairs(espHighlights) do
                if hl and hl.Parent then hl:Destroy() end
            end
            espHighlights = {}
        end

        if state then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    highlightCharacter(player.Character)
                end
            end

            local playerAddedConn = Players.PlayerAdded:Connect(function(player)
                if player == LocalPlayer then return end
                local charAddedConn
                charAddedConn = player.CharacterAdded:Connect(function(char)
                    highlightCharacter(char)
                end)
                if player.Character then
                    highlightCharacter(player.Character)
                end
                player.CharacterAddedConn = charAddedConn
            end)

            local playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
                if player.Character then
                    unhighlightCharacter(player.Character)
                end
                if player.CharacterAddedConn then
                    player.CharacterAddedConn:Disconnect()
                    player.CharacterAddedConn = nil
                end
            end)

            ActiveConnections["ESP_PlayerAdded"] = playerAddedConn
            ActiveConnections["ESP_PlayerRemoving"] = playerRemovingConn
        else
            clearAll()
            if ActiveConnections["ESP_PlayerAdded"] then
                ActiveConnections["ESP_PlayerAdded"]:Disconnect()
                ActiveConnections["ESP_PlayerAdded"] = nil
            end
            if ActiveConnections["ESP_PlayerRemoving"] then
                ActiveConnections["ESP_PlayerRemoving"]:Disconnect()
                ActiveConnections["ESP_PlayerRemoving"] = nil
            end
        end
    end
})

AddFunction("Utility", {
    Name = "TeleportToWaypoint",
    DisplayName = "传送到标记点",
    Description = "点击后传送到地图标记",
    Type = "Button",
    ButtonText = "传送",
    Order = 1,
    Callback = function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local waypoint = workspace:FindFirstChild("Waypoint")
        if not waypoint then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj.Name == "Waypoint" or obj.Name == "Marker" then
                    waypoint = obj
                    break
                end
            end
        end
        
        if waypoint and waypoint:IsA("BasePart") then
            hrp.CFrame = waypoint.CFrame + Vector3.new(0, 3, 0)
        elseif waypoint and waypoint:IsA("Model") then
            local primary = waypoint.PrimaryPart or waypoint:FindFirstChild("HumanoidRootPart")
            if primary then
                hrp.CFrame = primary.CFrame + Vector3.new(0, 3, 0)
            end
        end
    end
})

AddFunction("Utility", {
    Name = "Respawn",
    DisplayName = "重置角色",
    Description = "重新生成你的角色",
    Type = "Button",
    ButtonText = "重置",
    Order = 2,
    Callback = function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then
                hum.Health = 0
            end
        end
    end
})

AddFunction("Utility", {
    Name = "ShowSpeed",
    DisplayName = "显示速度",
    Description = "在屏幕上显示当前速度",
    Type = "Toggle",
    DefaultState = false,
    Order = 3,
    Callback = function(state)
        if state then
            local speedGui = Instance.new("ScreenGui")
            speedGui.Name = "SpeedDisplay"
            speedGui.Parent = CoreGui
            
            local speedLabel = Instance.new("TextLabel")
            speedLabel.Size = UDim2.new(0, 120, 0, 30)
            speedLabel.Position = UDim2.new(0.5, -60, 0.05, 0)
            speedLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            speedLabel.BackgroundTransparency = 0.5
            speedLabel.Text = "速度: 0"
            speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            speedLabel.TextSize = 16
            speedLabel.Font = Enum.Font.GothamBold
            speedLabel.BorderSizePixel = 0
            speedLabel.Parent = speedGui
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = speedLabel
            
            local speedConnection
            speedConnection = RunService.Heartbeat:Connect(function()
                if not ToggleStates["ShowSpeed"] then
                    speedConnection:Disconnect()
                    speedGui:Destroy()
                    return
                end
                local c = LocalPlayer.Character
                if c then
                    local hrp = c:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local velocity = hrp.Velocity
                        local speed = math.floor(velocity.Magnitude * 10) / 10
                        speedLabel.Text = "速度: " .. speed .. " studs/s"
                    end
                end
            end)
            
            ActiveConnections["ShowSpeed"] = speedConnection
        else
            if ActiveConnections["ShowSpeed"] then
                ActiveConnections["ShowSpeed"]:Disconnect()
                ActiveConnections["ShowSpeed"] = nil
            end
            local speedGui = CoreGui:FindFirstChild("SpeedDisplay")
            if speedGui then
                speedGui:Destroy()
            end
        end
    end
})

-- 新增：圣奥里所有车辆无限燃油（工具标签）
AddFunction("Utility", {
    Name = "AllVehiclesFuel",
    DisplayName = "所有车辆无限燃油",
    Description = "全地图车辆燃油锁定（增强）",
    Type = "Toggle",
    DefaultState = false,
    Order = 4,
    Callback = function(state)
        if state then
            local allFuelConnection
            allFuelConnection = RunService.Heartbeat:Connect(function()
                if not ToggleStates["AllVehiclesFuel"] then
                    allFuelConnection:Disconnect()
                    return
                end
                -- 遍历工作区所有模型
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("Model") then
                        -- 判断是否为车辆（有 VehicleSeat 或 Seat）
                        local isVehicle = false
                        for _, seat in ipairs(obj:GetChildren()) do
                            if seat:IsA("VehicleSeat") or seat:IsA("Seat") then
                                isVehicle = true
                                break
                            end
                        end
                        if isVehicle then
                            -- 扫描车辆内所有数值对象
                            for _, v in ipairs(obj:GetDescendants()) do
                                if v:IsA("NumberValue") or v:IsA("IntValue") then
                                    -- 用关键词匹配，不区分大小写
                                    local name = v.Name:lower()
                                    if name:find("fuel") or name:find("gas") or name:find("petrol") or name:find("oil") then
                                        v.Value = 999999 -- 或设定为游戏最大燃油值
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            ActiveConnections["AllVehiclesFuel"] = allFuelConnection
        else
            if ActiveConnections["AllVehiclesFuel"] then
                ActiveConnections["AllVehiclesFuel"]:Disconnect()
                ActiveConnections["AllVehiclesFuel"] = nil
            end
        end
    end
})

-- 新增：全自动破解ATM机
AddFunction("Utility", {
    Name = "AutoATM",
    DisplayName = "全自动破解ATM",
    Description = "自动点击破解按钮",
    Type = "Toggle",
    DefaultState = false,
    Order = 5,
    Callback = function(state)
        if state then
            local atmConnection
            atmConnection = RunService.Heartbeat:Connect(function()
                if not ToggleStates["AutoATM"] then
                    atmConnection:Disconnect()
                    return
                end
                local function findAndClick(parent)
                    for _, child in ipairs(parent:GetDescendants()) do
                        if child:IsA("TextButton") or child:IsA("ImageButton") then
                            local name = child.Name:lower()
                            local text = ""
                            if child:IsA("TextButton") then
                                text = child.Text:lower()
                            end
                            if name:find("atm") or name:find("hack") or name:find("crack") or
                               text:find("atm") or text:find("破解") or text:find("hack") then
                                firesignal(child.MouseButton1Click)
                            end
                        end
                    end
                end
                findAndClick(LocalPlayer.PlayerGui)
                findAndClick(CoreGui)
            end)
            ActiveConnections["AutoATM"] = atmConnection
        else
            if ActiveConnections["AutoATM"] then
                ActiveConnections["AutoATM"]:Disconnect()
                ActiveConnections["AutoATM"] = nil
            end
        end
    end
})

-- ============================================
-- 启动
-- ============================================
if CurrentTab == nil then
    local firstTab = nil
    for name, _ in pairs(Tabs) do
        firstTab = name
        break
    end
    if firstTab then
        SwitchTab(firstTab)
    end
end

if CurrentTab then
    RefreshContent(CurrentTab)
end

FloatingButton.Size = UDim2.new(0, 0, 0, 0)
FloatingButton.BackgroundTransparency = 1
TweenObject(FloatingButton, {
    Size = UDim2.new(0, 100, 0, 36),
    BackgroundTransparency = 0,
}, 0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, 0.2)

print("╔════════════════════════════════════╗")
print("║     弑ℳ笙 UI v1.0 已加载      ║")
print("║     忍者注入器 | 手机端专用       ║")
print("║     功能数: " .. #AllFunctions .. "                       ║")
print("║     标签数: " .. #Tabs .. "                       ║")
print("║  修改功能配置区后重新执行即可更新  ║")
print("╚════════════════════════════════════╝")

return {
    Tabs = Tabs,
    AddFunction = AddFunction,
    CreateTab = CreateTab,
    SwitchTab = SwitchTab,
    OpenPanel = OpenPanel,
    ClosePanel = ClosePanel,
    ToggleStates = ToggleStates,
    SliderValues = SliderValues,
    Theme = Theme,
}