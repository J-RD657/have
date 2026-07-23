--秋雨UI

--[[
    秋雨 Vision Spatial UI
    Injector / Executor Client Script

    功能：
    1. 双面 SurfaceGui
    2. 只跟随玩家 XYZ，不跟随玩家转向
    3. 顶部滑条控制 -180° ~ 180°
    4. 松手保持旋转角度
    5. Vision 风格弧形连体黑屏
    6. 白色粒子伪预加载
    7. 自由缩放
    8. 息屏、最小化、关闭
    9. 最小化漂浮 3D 小球
    10. 玩家选择和绕圈

    ====== 新增功能（圣奥里服务器） ======
    11. 无限子弹
    12. 无限血量
    13. 自瞄（可切换头部/身体）
    14. 飞天（WASD + 空格/Shift）
    =====================================
]]

--==================================================
-- 防止重复执行
--==================================================

local ENV = getgenv and getgenv() or _G
local SCRIPT_KEY = "__AKI_RAIN_VISION_SPATIAL_UI__"

if ENV[SCRIPT_KEY] and ENV[SCRIPT_KEY].Destroy then
    pcall(function()
        ENV[SCRIPT_KEY]:Destroy()
    end)
end

--==================================================
-- 服务
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

--==================================================
-- 清理管理器
--==================================================

local Controller = {
    Connections = {},
    Instances = {},
    Destroyed = false,
}

ENV[SCRIPT_KEY] = Controller

function Controller:AddConnection(connection)
    table.insert(self.Connections, connection)
    return connection
end

function Controller:AddInstance(instance)
    table.insert(self.Instances, instance)
    return instance
end

function Controller:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(self.Connections)

    for index = #self.Instances, 1, -1 do
        local instance = self.Instances[index]

        pcall(function()
            if instance and instance.Parent then
                instance:Destroy()
            end
        end)
    end

    table.clear(self.Instances)

    if ENV[SCRIPT_KEY] == self then
        ENV[SCRIPT_KEY] = nil
    end
end

--==================================================
-- 角色
--==================================================

local Character
local Root
local Humanoid

local function SetupCharacter(character)
    Character = character or LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    Root = Character:WaitForChild("HumanoidRootPart")
    Humanoid = Character:WaitForChild("Humanoid")
end

SetupCharacter()

Controller:AddConnection(
    LocalPlayer.CharacterAdded:Connect(function(character)
        SetupCharacter(character)
    end)
)

--==================================================
-- 配置
--==================================================

local CONFIG = {
    PanelWidth = 5.7,
    PanelHeight = 6.5,

    Distance = 5.4,
    HeightOffset = -0.75,

    CurveAngle = 31,
    CenterGap = -0.10,

    MinimumScale = 0.5,
    MaximumScale = 1.65,
    ScaleStep = 0.1,

    FollowSpeed = 18,

    OrbitRadius = 8,
    OrbitHeight = 3,
    OrbitSmoothness = 12,

    OrbDistance = 4.1,
    OrbHeight = 1,
    OrbSize = 0.72,

    Background = Color3.fromRGB(2, 3, 6),
    Secondary = Color3.fromRGB(18, 22, 32),
    Elevated = Color3.fromRGB(29, 35, 50),

    Text = Color3.fromRGB(235, 242, 255),
    SubText = Color3.fromRGB(145, 170, 210),

    Accent = Color3.fromRGB(80, 145, 255),
    Active = Color3.fromRGB(55, 225, 130),
    Danger = Color3.fromRGB(255, 80, 105),
    White = Color3.fromRGB(255, 255, 255),
}

--==================================================
-- 状态
--==================================================

local SelectedTarget

local Circling = false
local CircleTarget
local CircleAngle = 0
local CircleSpeed = 2
local CircleConnection

local RotationAngle = 0
local DisplayScale = 1

local DisplayPowered = true
local Minimized = false
local InterfaceReady = false

local CurrentDisplayPosition = Root.Position
local CurrentOrbPosition = Root.Position

-- ====== 新增功能状态 ======
local InfiniteAmmo = false
local InfiniteHealth = false
local AimAssist = false
local AimPart = "Head"  -- "Head" 或 "Torso"
local FlyEnabled = false
local FlyBodyVelocity = nil
local FlyConnection = nil

-- 用于存储功能连接的清理
local FeatureConnections = {}

--==================================================
-- 固定方向
--==================================================

-- 只在脚本执行时读取一次玩家方向。
-- 后续角色怎么转身，都不会修改这个方向。

local InitialLook = Root.CFrame.LookVector

local FixedForward = Vector3.new(
    InitialLook.X,
    0,
    InitialLook.Z
)

if FixedForward.Magnitude < 0.01 then
    FixedForward = Vector3.new(0, 0, -1)
else
    FixedForward = FixedForward.Unit
end

-- 面板放置在玩家初始朝向的前面。
-- 面板自身朝向玩家，因此不会反过来。
local FixedFacingRotation =
    CFrame.lookAt(
        Vector3.zero,
        -FixedForward,
        Vector3.yAxis
    )
    - Vector3.zero

--==================================================
-- 工具函数
--==================================================

local function Connect(signal, callback)
    return Controller:AddConnection(signal:Connect(callback))
end

local function Tween(object, duration, properties, style, direction)
    if not object or not object.Parent then
        return
    end

    local tween = TweenService:Create(
        object,
        TweenInfo.new(
            duration or 0.2,
            style or Enum.EasingStyle.Quint,
            direction or Enum.EasingDirection.Out
        ),
        properties
    )

    tween:Play()
    return tween
end

local function AddCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 12)
    corner.Parent = parent
    return corner
end

local function AddStroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or CONFIG.Accent
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.6
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local function MakeLabel(parent, text, size, color)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Text = text or ""
    label.TextColor3 = color or CONFIG.Text
    label.TextSize = size or 12
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Active = false
    label.Parent = parent
    return label
end

local function MakeGlassFrame(parent)
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = CONFIG.Secondary
    frame.BackgroundTransparency = 0.12
    frame.BorderSizePixel = 0
    frame.Active = false
    frame.Selectable = false
    frame.ClipsDescendants = true
    frame.Parent = parent

    AddCorner(frame, 14)
    AddStroke(frame, Color3.fromRGB(105, 150, 255), 1, 0.67)

    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 105
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 52, 72)),
        ColorSequenceKeypoint.new(0.38, Color3.fromRGB(20, 24, 36)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 6, 11)),
    })
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.15),
        NumberSequenceKeypoint.new(1, 0.34),
    })
    gradient.Parent = frame

    return frame
end

--==================================================
-- 世界文件夹
--==================================================

local WorldFolder = Instance.new("Folder")
WorldFolder.Name = "AkiRainVisionSpatialUI"
WorldFolder.Parent = Workspace
Controller:AddInstance(WorldFolder)

--==================================================
-- 绕圈
--==================================================

local StopCircling

local function StartCircling(target)
    if Circling then
        StopCircling()
    end

    if not target or target == LocalPlayer then
        return
    end

    if not Root or not Root.Parent then
        return
    end

    local targetCharacter = target.Character
    local targetRoot = targetCharacter
        and targetCharacter:FindFirstChild("HumanoidRootPart")

    if not targetRoot then
        return
    end

    Circling = true
    CircleTarget = target
    CircleAngle = math.random() * math.pi * 2

    CircleConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not Circling or not CircleTarget then
            StopCircling()
            return
        end

        if not Root or not Root.Parent then
            StopCircling()
            return
        end

        local currentCharacter = CircleTarget.Character
        local targetRootNow = currentCharacter
            and currentCharacter:FindFirstChild("HumanoidRootPart")

        local targetHumanoid = currentCharacter
            and currentCharacter:FindFirstChildOfClass("Humanoid")

        if not targetRootNow then
            StopCircling()
            return
        end

        if targetHumanoid and targetHumanoid.Health <= 0 then
            StopCircling()
            return
        end

        CircleAngle += CircleSpeed * deltaTime

        local targetPosition = targetRootNow.Position

        local desiredPosition = Vector3.new(
            targetPosition.X
                + CONFIG.OrbitRadius * math.cos(CircleAngle),

            targetPosition.Y
                + CONFIG.OrbitHeight,

            targetPosition.Z
                + CONFIG.OrbitRadius * math.sin(CircleAngle)
        )

        local alpha =
            1 - math.exp(-CONFIG.OrbitSmoothness * deltaTime)

        local desiredCFrame = CFrame.lookAt(
            desiredPosition,
            Vector3.new(
                targetPosition.X,
                desiredPosition.Y,
                targetPosition.Z
            )
        )

        Root.CFrame = Root.CFrame:Lerp(
            desiredCFrame,
            alpha
        )
    end)

    table.insert(Controller.Connections, CircleConnection)
end

StopCircling = function()
    Circling = false
    CircleTarget = nil

    if CircleConnection then
        pcall(function()
            CircleConnection:Disconnect()
        end)

        CircleConnection = nil
    end
end

--==================================================
-- 3D 部件
--==================================================

local function MakeInteractivePart(name, size)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false

    -- SurfaceGui 点击必须为 true。
    part.CanQuery = true

    part.CastShadow = false
    part.Transparency = 1
    part.Parent = WorldFolder

    return part
end

local LeftPanel = MakeInteractivePart(
    "LeftPanel",
    Vector3.new(
        CONFIG.PanelWidth,
        CONFIG.PanelHeight,
        0.08
    )
)

local RightPanel = MakeInteractivePart(
    "RightPanel",
    Vector3.new(
        CONFIG.PanelWidth,
        CONFIG.PanelHeight,
        0.08
    )
)

local TopControlPart = MakeInteractivePart(
    "TopControl",
    Vector3.new(7.3, 0.88, 0.08)
)

local CenterBridge = Instance.new("Part")
CenterBridge.Name = "CenterBridge"
CenterBridge.Anchored = true
CenterBridge.CanCollide = false
CenterBridge.CanTouch = false
CenterBridge.CanQuery = false
CenterBridge.CastShadow = false
CenterBridge.Material = Enum.Material.SmoothPlastic
CenterBridge.Color = Color3.fromRGB(0, 0, 0)
CenterBridge.Transparency = 1
CenterBridge.Size = Vector3.new(
    0.22,
    CONFIG.PanelHeight,
    0.11
)
CenterBridge.Parent = WorldFolder

--==================================================
-- 漂浮恢复球
--==================================================

local OrbPart = MakeInteractivePart(
    "VisionOrb",
    Vector3.one * CONFIG.OrbSize
)

OrbPart.Shape = Enum.PartType.Ball
OrbPart.Material = Enum.Material.Glass
OrbPart.Color = CONFIG.Accent
OrbPart.Transparency = 1

local OrbLight = Instance.new("PointLight")
OrbLight.Color = Color3.fromRGB(150, 195, 255)
OrbLight.Brightness = 1.7
OrbLight.Range = 8
OrbLight.Enabled = false
OrbLight.Parent = OrbPart

local OrbHighlight = Instance.new("Highlight")
OrbHighlight.Adornee = OrbPart
OrbHighlight.FillColor = CONFIG.Accent
OrbHighlight.FillTransparency = 0.45
OrbHighlight.OutlineColor = CONFIG.White
OrbHighlight.OutlineTransparency = 0.2
OrbHighlight.Enabled = false
OrbHighlight.Parent = OrbPart

local OrbGui = Instance.new("BillboardGui")
OrbGui.Name = "OrbGui"
OrbGui.Adornee = OrbPart
OrbGui.Size = UDim2.fromOffset(125, 125)
OrbGui.AlwaysOnTop = true
OrbGui.Enabled = false
OrbGui.Parent = OrbPart

local OrbButton = Instance.new("TextButton")
OrbButton.Size = UDim2.fromScale(1, 1)
OrbButton.BackgroundTransparency = 1
OrbButton.BorderSizePixel = 0
OrbButton.Text = "◉"
OrbButton.TextColor3 = CONFIG.White
OrbButton.TextSize = 58
OrbButton.Font = Enum.Font.GothamBold
OrbButton.TextStrokeTransparency = 0.7
OrbButton.Active = true
OrbButton.Selectable = true
OrbButton.AutoButtonColor = false
OrbButton.Parent = OrbGui

local OrbHint = Instance.new("TextLabel")
OrbHint.Size = UDim2.new(1, 85, 0, 24)
OrbHint.Position = UDim2.new(0.5, 0, 1, 3)
OrbHint.AnchorPoint = Vector2.new(0.5, 0)
OrbHint.BackgroundColor3 = Color3.fromRGB(5, 7, 12)
OrbHint.BackgroundTransparency = 0.15
OrbHint.BorderSizePixel = 0
OrbHint.Text = "打开空间面板"
OrbHint.TextColor3 = CONFIG.Text
OrbHint.TextSize = 11
OrbHint.Font = Enum.Font.GothamMedium
OrbHint.Parent = OrbGui
AddCorner(OrbHint, 10)
AddStroke(OrbHint, CONFIG.Accent, 1, 0.55)

--==================================================
-- UI 控件
--==================================================

local function MakeButton(parent, text, callback, options)
    options = options or {}

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(
        1,
        -10,
        0,
        options.Height or 39
    )

    button.BackgroundColor3 =
        options.Color
        or Color3.fromRGB(25, 30, 43)

    button.BackgroundTransparency =
        options.Transparency or 0.08

    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = options.TextColor or CONFIG.Text
    button.TextSize = options.TextSize or 12
    button.Font = options.Font or Enum.Font.GothamMedium

    button.Active = true
    button.Selectable = true
    button.AutoButtonColor = false

    pcall(function()
        button.Interactable = true
    end)

    button.Parent = parent

    AddCorner(button, options.Radius or 12)

    AddStroke(
        button,
        options.StrokeColor or CONFIG.Accent,
        1,
        options.StrokeTransparency or 0.67
    )

    local originalColor = button.BackgroundColor3
    local originalTransparency = button.BackgroundTransparency

    Connect(button.MouseEnter, function()
        Tween(button, 0.14, {
            BackgroundColor3 =
                options.HoverColor
                or Color3.fromRGB(38, 47, 68),

            BackgroundTransparency = 0,
        })
    end)

    Connect(button.MouseLeave, function()
        Tween(button, 0.14, {
            BackgroundColor3 = originalColor,
            BackgroundTransparency = originalTransparency,
        })
    end)

    Connect(button.Activated, function()
        Tween(button, 0.07, {
            BackgroundColor3 =
                options.ClickColor
                or CONFIG.Accent,

            BackgroundTransparency = 0,
        })

        task.delay(0.11, function()
            if button and button.Parent then
                Tween(button, 0.18, {
                    BackgroundColor3 = originalColor,
                    BackgroundTransparency = originalTransparency,
                })
            end
        end)

        callback(button)
    end)

    return button
end

local function MakeToggle(parent, text, defaultState, callback)
    local container = MakeGlassFrame(parent)
    container.Size = UDim2.new(1, -10, 0, 43)

    local label = MakeLabel(
        container,
        text,
        12,
        CONFIG.Text
    )

    label.Size = UDim2.new(1, -76, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)

    local track = Instance.new("Frame")
    track.Size = UDim2.fromOffset(49, 27)
    track.Position = UDim2.new(1, -59, 0.5, 0)
    track.AnchorPoint = Vector2.new(0, 0.5)

    track.BackgroundColor3 =
        defaultState
        and CONFIG.Active
        or Color3.fromRGB(72, 77, 92)

    track.BorderSizePixel = 0
    track.Active = false
    track.Parent = container
    AddCorner(track, 20)

    local shine = Instance.new("Frame")
    shine.Size = UDim2.new(1, -5, 0.42, 0)
    shine.Position = UDim2.new(0, 2.5, 0, 2)
    shine.BackgroundColor3 = CONFIG.White
    shine.BackgroundTransparency = 0.76
    shine.BorderSizePixel = 0
    shine.Active = false
    shine.Parent = track
    AddCorner(shine, 20)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(21, 21)
    knob.AnchorPoint = Vector2.new(0, 0.5)

    knob.Position =
        defaultState
        and UDim2.new(1, -24, 0.5, 0)
        or UDim2.new(0, 3, 0.5, 0)

    knob.BackgroundColor3 = CONFIG.White
    knob.BorderSizePixel = 0
    knob.Active = false
    knob.Parent = track
    AddCorner(knob, 20)

    local click = Instance.new("TextButton")
    click.Size = UDim2.fromScale(1, 1)
    click.BackgroundTransparency = 1
    click.BorderSizePixel = 0
    click.Text = ""
    click.Active = true
    click.Selectable = true
    click.AutoButtonColor = false
    click.ZIndex = 10
    click.Parent = container

    pcall(function()
        click.Interactable = true
    end)

    local state = defaultState

    local object = {}

    function object:Set(value, executeCallback)
        state = value

        Tween(track, 0.2, {
            BackgroundColor3 =
                state
                and CONFIG.Active
                or Color3.fromRGB(72, 77, 92),
        })

        Tween(knob, 0.2, {
            Position =
                state
                and UDim2.new(1, -24, 0.5, 0)
                or UDim2.new(0, 3, 0.5, 0),
        })

        if executeCallback then
            callback(state)
        end
    end

    function object:Get()
        return state
    end

    Connect(click.Activated, function()
        object:Set(not state, true)
    end)

    object.Container = container

    return object
end

--==================================================
-- 双面 SurfaceGui
--==================================================

local PlayerListContainers = {}
local StatusLabels = {}
local TargetLabels = {}
local SpeedLabels = {}
local ScaleLabels = {}
local PowerOverlays = {}
local CircleToggles = {}

local function MakeSurface(part, face)
    local surface = Instance.new("SurfaceGui")
    surface.Name = "Surface_" .. face.Name
    surface.Face = face
    surface.AlwaysOnTop = true
    surface.Active = true
    surface.LightInfluence = 0
    surface.Brightness = 2
    surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surface.PixelsPerStud = 100
    surface.CanvasSize = Vector2.new(570, 650)
    surface.ZOffset = 2
    surface.Parent = part

    return surface
end

local function MakePanelShell(surface, titleText, subtitleText)
    local rootFrame = Instance.new("Frame")
    rootFrame.Name = "PanelRoot"
    rootFrame.Size = UDim2.fromScale(1, 1)
    rootFrame.BackgroundColor3 = CONFIG.Background
    rootFrame.BackgroundTransparency = 0.02
    rootFrame.BorderSizePixel = 0
    rootFrame.ClipsDescendants = true
    rootFrame.Active = false
    rootFrame.Parent = surface

    AddCorner(rootFrame, 25)
    AddStroke(rootFrame, Color3.fromRGB(100, 150, 255), 2, 0.38)

    local backgroundGradient = Instance.new("UIGradient")
    backgroundGradient.Rotation = 120
    backgroundGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 26, 46)),
        ColorSequenceKeypoint.new(0.35, Color3.fromRGB(6, 9, 16)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
    })
    backgroundGradient.Parent = rootFrame

    local ambientGlow = Instance.new("Frame")
    ambientGlow.Size = UDim2.new(0.95, 0, 0.35, 0)
    ambientGlow.Position = UDim2.new(-0.18, 0, -0.15, 0)
    ambientGlow.BackgroundColor3 = CONFIG.Accent
    ambientGlow.BackgroundTransparency = 0.84
    ambientGlow.BorderSizePixel = 0
    ambientGlow.Active = false
    ambientGlow.Parent = rootFrame
    AddCorner(ambientGlow, 100)

    local header = MakeGlassFrame(rootFrame)
    header.Size = UDim2.new(1, -24, 0, 62)
    header.Position = UDim2.new(0, 12, 0, 12)

    local title = MakeLabel(
        header,
        titleText,
        17,
        CONFIG.Text
    )

    title.Size = UDim2.new(1, -76, 0, 29)
    title.Position = UDim2.new(0, 16, 0, 7)
    title.Font = Enum.Font.GothamBold

    local subtitle = MakeLabel(
        header,
        subtitleText,
        9,
        CONFIG.SubText
    )

    subtitle.Size = UDim2.new(1, -76, 0, 19)
    subtitle.Position = UDim2.new(0, 16, 0, 34)

    local liveDot = Instance.new("Frame")
    liveDot.Size = UDim2.fromOffset(10, 10)
    liveDot.Position = UDim2.new(1, -30, 0.5, 0)
    liveDot.AnchorPoint = Vector2.new(0.5, 0.5)
    liveDot.BackgroundColor3 = CONFIG.Active
    liveDot.BorderSizePixel = 0
    liveDot.Active = false
    liveDot.Parent = header
    AddCorner(liveDot, 20)

    local content = Instance.new("ScrollingFrame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -24, 1, -92)
    content.Position = UDim2.new(0, 12, 0, 82)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Active = true
    content.Selectable = true
    content.ScrollBarThickness = 3
    content.ScrollBarImageColor3 = CONFIG.Accent
    content.ScrollBarImageTransparency = 0.25
    content.CanvasSize = UDim2.new()
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.ScrollingDirection = Enum.ScrollingDirection.Y
    content.Parent = rootFrame

    local padding = Instance.new("UIPadding")
    padding.PaddingBottom = UDim.new(0, 12)
    padding.Parent = content

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 7)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content

    local powerOverlay = Instance.new("Frame")
    powerOverlay.Name = "PowerOverlay"
    powerOverlay.Size = UDim2.fromScale(1, 1)
    powerOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    powerOverlay.BackgroundTransparency = 1
    powerOverlay.BorderSizePixel = 0
    powerOverlay.Visible = false
    powerOverlay.Active = false
    powerOverlay.ZIndex = 100
    powerOverlay.Parent = rootFrame
    AddCorner(powerOverlay, 25)

    local poweredOffText = MakeLabel(
        powerOverlay,
        "DISPLAY OFF",
        16,
        Color3.fromRGB(55, 60, 68)
    )

    poweredOffText.Size = UDim2.fromScale(1, 1)
    poweredOffText.TextXAlignment = Enum.TextXAlignment.Center
    poweredOffText.Font = Enum.Font.GothamBold
    poweredOffText.ZIndex = 101

    table.insert(PowerOverlays, powerOverlay)

    return rootFrame, content
end

--==================================================
-- 玩家列表刷新
--==================================================

local function RefreshPlayerLists()
    for _, content in ipairs(PlayerListContainers) do
        for _, child in ipairs(content:GetChildren()) do
            if child:GetAttribute("PlayerItem") then
                child:Destroy()
            end
        end

        local currentPlayers = Players:GetPlayers()

        table.sort(currentPlayers, function(a, b)
            return string.lower(a.DisplayName)
                < string.lower(b.DisplayName)
        end)

        for _, player in ipairs(currentPlayers) do
            if player ~= LocalPlayer then
                local selected = SelectedTarget == player

                local button = MakeButton(
                    content,
                    (
                        selected
                        and "◎  "
                        or "○  "
                    ) .. player.DisplayName,

                    function()
                        SelectedTarget = player
                        RefreshPlayerLists()
                    end,

                    {
                        Color =
                            selected
                            and Color3.fromRGB(25, 100, 72)
                            or Color3.fromRGB(23, 28, 40),

                        StrokeColor =
                            selected
                            and CONFIG.Active
                            or CONFIG.Accent,

                        ClickColor =
                            selected
                            and CONFIG.Active
                            or CONFIG.Accent,
                    }
                )

                button:SetAttribute("PlayerItem", true)

                local username = MakeLabel(
                    button,
                    "@" .. player.Name,
                    9,
                    CONFIG.SubText
                )

                username.Size = UDim2.new(0.45, 0, 1, 0)
                username.Position = UDim2.new(0.52, 0, 0, 0)
                username.TextXAlignment = Enum.TextXAlignment.Right
                username.ZIndex = 2
            end
        end
    end
end

--==================================================
-- 左侧面板
--==================================================

local function BuildPlayerPanel(content)
    local heading = MakeLabel(
        content,
        "可用玩家",
        11,
        CONFIG.SubText
    )

    heading.Size = UDim2.new(1, -10, 0, 24)
    heading.Font = Enum.Font.GothamBold

    table.insert(PlayerListContainers, content)
end

--==================================================
-- 右侧面板（新增功能集成在这里）
--==================================================

local function SynchronizeCircleToggles(value)
    for _, toggle in ipairs(CircleToggles) do
        if toggle:Get() ~= value then
            toggle:Set(value, false)
        end
    end
end

-- ====== 新增功能实现 ======

-- 无限子弹
local function ToggleInfiniteAmmo(state)
    InfiniteAmmo = state
    if state then
        local conn = RunService.Heartbeat:Connect(function()
            if not InfiniteAmmo then return end
            local player = LocalPlayer
            if not player then return end
            local char = player.Character
            if not char then return end
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                -- 尝试常见弹药属性
                local ammo = tool:FindFirstChild("Ammo") or tool:FindFirstChild("Bullets") or tool:FindFirstChild("AmmoCount")
                if ammo and ammo:IsA("NumberValue") then
                    ammo.Value = ammo.Value + 999 -- 补充
                end
                -- 某些武器使用 IntValue
                if ammo and ammo:IsA("IntValue") then
                    ammo.Value = ammo.Value + 999
                end
            end
        end)
        table.insert(FeatureConnections, conn)
    else
        -- 移除连接（将在更新循环中清理）
        for i = #FeatureConnections, 1, -1 do
            if FeatureConnections[i] and FeatureConnections[i].Connected then
                FeatureConnections[i]:Disconnect()
            end
        end
        FeatureConnections = {}
    end
end

-- 无限血量
local function ToggleInfiniteHealth(state)
    InfiniteHealth = state
    if state then
        local conn = RunService.Heartbeat:Connect(function()
            if not InfiniteHealth then return end
            local player = LocalPlayer
            if not player then return end
            local char = player.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.Health = hum.MaxHealth
            end
        end)
        table.insert(FeatureConnections, conn)
    else
        for i = #FeatureConnections, 1, -1 do
            if FeatureConnections[i] and FeatureConnections[i].Connected then
                FeatureConnections[i]:Disconnect()
            end
        end
        FeatureConnections = {}
    end
end

-- 获取自瞄目标（优先选择选中的玩家，否则最近敌人）
local function GetAimTarget()
    local target = SelectedTarget
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        return target
    end
    -- 否则找最近的敌人
    local player = LocalPlayer
    if not player then return nil end
    local char = player.Character
    if not char then return nil end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end
    local closest = nil
    local closestDist = math.huge
    for _, other in pairs(Players:GetPlayers()) do
        if other ~= player then
            local oChar = other.Character
            if oChar and oChar:FindFirstChild("HumanoidRootPart") then
                local oRoot = oChar.HumanoidRootPart
                local dist = (oRoot.Position - rootPart.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = other
                end
            end
        end
    end
    return closest
end

-- 自瞄
local function ToggleAimAssist(state)
    AimAssist = state
    if state then
        local conn = RunService.Heartbeat:Connect(function()
            if not AimAssist then return end
            local target = GetAimTarget()
            if not target then return end
            local targetChar = target.Character
            if not targetChar then return end
            local partName = AimPart == "Head" and "Head" or "HumanoidRootPart"
            local targetPart = targetChar:FindFirstChild(partName)
            if not targetPart then return end
            local camera = Workspace.CurrentCamera
            if not camera then return end
            -- 平滑旋转到目标
            local targetPos = targetPart.Position
            local lookAt = CFrame.lookAt(camera.CFrame.Position, targetPos)
            camera.CFrame = lookAt
        end)
        table.insert(FeatureConnections, conn)
    else
        for i = #FeatureConnections, 1, -1 do
            if FeatureConnections[i] and FeatureConnections[i].Connected then
                FeatureConnections[i]:Disconnect()
            end
        end
        FeatureConnections = {}
    end
end

-- 飞天
local function ToggleFly(state)
    FlyEnabled = state
    local player = LocalPlayer
    if not player then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    if state then
        -- 创建 BodyVelocity
        FlyBodyVelocity = Instance.new("BodyVelocity")
        FlyBodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        FlyBodyVelocity.Parent = rootPart

        hum.PlatformStand = true

        -- 如果正在绕圈，停止
        if Circling then
            StopCircling()
        end

        FlyConnection = RunService.Heartbeat:Connect(function()
            if not FlyEnabled or not FlyBodyVelocity or not FlyBodyVelocity.Parent then
                return
            end
            local moveDirection = Vector3.new()
            local forward = rootPart.CFrame.LookVector
            local right = rootPart.CFrame.RightVector

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDirection = moveDirection + forward
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDirection = moveDirection - forward
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDirection = moveDirection - right
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDirection = moveDirection + right
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDirection = moveDirection + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveDirection = moveDirection - Vector3.new(0, 1, 0)
            end

            local speed = 50
            if moveDirection.Magnitude > 0 then
                moveDirection = moveDirection.Unit * speed
            end
            FlyBodyVelocity.Velocity = moveDirection
        end)
        table.insert(FeatureConnections, FlyConnection)
    else
        if FlyConnection then
            FlyConnection:Disconnect()
            FlyConnection = nil
        end
        if FlyBodyVelocity then
            FlyBodyVelocity:Destroy()
            FlyBodyVelocity = nil
        end
        hum.PlatformStand = false
        -- 清理连接列表中的FlyConnection
        for i = #FeatureConnections, 1, -1 do
            if FeatureConnections[i] == FlyConnection then
                table.remove(FeatureConnections, i)
            end
        end
    end
end

-- 创建自瞄部位选择下拉（简化：两个按钮切换）
local function BuildAimPartSelector(content)
    local container = MakeGlassFrame(content)
    container.Size = UDim2.new(1, -10, 0, 43)

    local label = MakeLabel(
        container,
        "自瞄部位",
        12,
        CONFIG.Text
    )
    label.Size = UDim2.new(0.45, 0, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)

    local headBtn = Instance.new("TextButton")
    headBtn.Size = UDim2.new(0.22, 0, 0.7, 0)
    headBtn.Position = UDim2.new(0.55, 0, 0.15, 0)
    headBtn.BackgroundColor3 = AimPart == "Head" and CONFIG.Active or Color3.fromRGB(40, 45, 60)
    headBtn.BackgroundTransparency = 0.15
    headBtn.BorderSizePixel = 0
    headBtn.Text = "头部"
    headBtn.TextColor3 = CONFIG.Text
    headBtn.TextSize = 12
    headBtn.Font = Enum.Font.GothamMedium
    headBtn.Active = true
    headBtn.Selectable = true
    headBtn.AutoButtonColor = false
    headBtn.Parent = container
    AddCorner(headBtn, 10)
    AddStroke(headBtn, AimPart == "Head" and CONFIG.Active or CONFIG.Accent, 1, 0.5)

    local torsoBtn = headBtn:Clone()
    torsoBtn.Position = UDim2.new(0.78, 0, 0.15, 0)
    torsoBtn.Text = "身体"
    torsoBtn.BackgroundColor3 = AimPart == "Torso" and CONFIG.Active or Color3.fromRGB(40, 45, 60)
    torsoBtn.StrokeColor = AimPart == "Torso" and CONFIG.Active or CONFIG.Accent
    torsoBtn.Parent = container

    Connect(headBtn.Activated, function()
        AimPart = "Head"
        headBtn.BackgroundColor3 = CONFIG.Active
        torsoBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
        -- 更新描边颜色
        headBtn:FindFirstChildOfClass("UIStroke").Color = CONFIG.Active
        torsoBtn:FindFirstChildOfClass("UIStroke").Color = CONFIG.Accent
    end)

    Connect(torsoBtn.Activated, function()
        AimPart = "Torso"
        torsoBtn.BackgroundColor3 = CONFIG.Active
        headBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
        torsoBtn:FindFirstChildOfClass("UIStroke").Color = CONFIG.Active
        headBtn:FindFirstChildOfClass("UIStroke").Color = CONFIG.Accent
    end)
end

-- ====== 修改 BuildControlPanel 添加新功能 ======
local function BuildControlPanel(content)
    -- 原有状态卡片
    local statusCard = MakeGlassFrame(content)
    statusCard.Size = UDim2.new(1, -10, 0, 78)

    local status = MakeLabel(
        statusCard,
        "状态：空闲",
        13,
        CONFIG.Text
    )

    status.Size = UDim2.new(1, -22, 0, 29)
    status.Position = UDim2.new(0, 11, 0, 8)
    status.Font = Enum.Font.GothamBold

    local target = MakeLabel(
        statusCard,
        "目标：未选择",
        11,
        CONFIG.SubText
    )

    target.Size = UDim2.new(1, -22, 0, 24)
    target.Position = UDim2.new(0, 11, 0, 42)

    table.insert(StatusLabels, status)
    table.insert(TargetLabels, target)

    local circleToggle = MakeToggle(
        content,
        "绕圈模式",
        false,

        function(enabled)
            if enabled then
                if SelectedTarget then
                    StartCircling(SelectedTarget)
                    SynchronizeCircleToggles(true)
                else
                    SynchronizeCircleToggles(false)
                end
            else
                StopCircling()
                SynchronizeCircleToggles(false)
            end
        end
    )

    table.insert(CircleToggles, circleToggle)

    local speedCard = MakeGlassFrame(content)
    speedCard.Size = UDim2.new(1, -10, 0, 86)

    local speedTitle = MakeLabel(
        speedCard,
        "轨道速度",
        11,
        CONFIG.SubText
    )

    speedTitle.Size = UDim2.new(0.55, 0, 0, 24)
    speedTitle.Position = UDim2.new(0, 12, 0, 7)

    local speedValue = MakeLabel(
        speedCard,
        tostring(CircleSpeed) .. "×",
        21,
        CONFIG.Text
    )

    speedValue.Size = UDim2.new(0.35, 0, 0, 30)
    speedValue.Position = UDim2.new(0.61, 0, 0, 5)
    speedValue.TextXAlignment = Enum.TextXAlignment.Right
    speedValue.Font = Enum.Font.GothamBold

    table.insert(SpeedLabels, speedValue)

    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0.45, 0, 0, 31)
    minus.Position = UDim2.new(0.03, 0, 0, 47)
    minus.BackgroundColor3 = Color3.fromRGB(35, 41, 58)
    minus.BackgroundTransparency = 0.05
    minus.BorderSizePixel = 0
    minus.Text = "－"
    minus.TextColor3 = CONFIG.Text
    minus.TextSize = 20
    minus.Font = Enum.Font.GothamBold
    minus.Active = true
    minus.Selectable = true
    minus.AutoButtonColor = false
    minus.ZIndex = 10
    minus.Parent = speedCard
    AddCorner(minus, 10)

    local plus = minus:Clone()
    plus.Position = UDim2.new(0.52, 0, 0, 47)
    plus.Text = "＋"
    plus.Parent = speedCard

    Connect(minus.Activated, function()
        CircleSpeed = math.max(1, CircleSpeed - 1)
    end)

    Connect(plus.Activated, function()
        CircleSpeed = math.min(10, CircleSpeed + 1)
    end)

    local scaleCard = MakeGlassFrame(content)
    scaleCard.Size = UDim2.new(1, -10, 0, 86)

    local scaleTitle = MakeLabel(
        scaleCard,
        "空间显示缩放",
        11,
        CONFIG.SubText
    )

    scaleTitle.Size = UDim2.new(0.58, 0, 0, 24)
    scaleTitle.Position = UDim2.new(0, 12, 0, 7)

    local scaleValue = MakeLabel(
        scaleCard,
        "100%",
        19,
        CONFIG.Text
    )

    scaleValue.Size = UDim2.new(0.34, 0, 0, 28)
    scaleValue.Position = UDim2.new(0.62, 0, 0, 6)
    scaleValue.TextXAlignment = Enum.TextXAlignment.Right
    scaleValue.Font = Enum.Font.GothamBold

    table.insert(ScaleLabels, scaleValue)

    local scaleDown = Instance.new("TextButton")
    scaleDown.Size = UDim2.new(0.45, 0, 0, 31)
    scaleDown.Position = UDim2.new(0.03, 0, 0, 47)
    scaleDown.BackgroundColor3 = Color3.fromRGB(35, 41, 58)
    scaleDown.BackgroundTransparency = 0.05
    scaleDown.BorderSizePixel = 0
    scaleDown.Text = "缩小"
    scaleDown.TextColor3 = CONFIG.Text
    scaleDown.TextSize = 11
    scaleDown.Font = Enum.Font.GothamBold
    scaleDown.Active = true
    scaleDown.Selectable = true
    scaleDown.AutoButtonColor = false
    scaleDown.ZIndex = 10
    scaleDown.Parent = scaleCard
    AddCorner(scaleDown, 10)

    local scaleUp = scaleDown:Clone()
    scaleUp.Position = UDim2.new(0.52, 0, 0, 47)
    scaleUp.Text = "放大"
    scaleUp.Parent = scaleCard

    Connect(scaleDown.Activated, function()
        DisplayScale = math.clamp(
            DisplayScale - CONFIG.ScaleStep,
            CONFIG.MinimumScale,
            CONFIG.MaximumScale
        )
    end)

    Connect(scaleUp.Activated, function()
        DisplayScale = math.clamp(
            DisplayScale + CONFIG.ScaleStep,
            CONFIG.MinimumScale,
            CONFIG.MaximumScale
        )
    end)

    MakeButton(content, "清除当前目标", function()
        SelectedTarget = nil
        StopCircling()
        SynchronizeCircleToggles(false)
        RefreshPlayerLists()
    end)

    -- ====== 新增功能区域 ======
    local sectionLabel = MakeLabel(
        content,
        "—— 作弊功能 ——",
        12,
        CONFIG.SubText
    )
    sectionLabel.Size = UDim2.new(1, -10, 0, 26)
    sectionLabel.TextXAlignment = Enum.TextXAlignment.Center
    sectionLabel.Font = Enum.Font.GothamBold

    -- 无限子弹
    local ammoToggle = MakeToggle(content, "无限子弹", false, function(state)
        ToggleInfiniteAmmo(state)
    end)

    -- 无限血量
    local healthToggle = MakeToggle(content, "无限血量", false, function(state)
        ToggleInfiniteHealth(state)
    end)

    -- 自瞄
    local aimToggle = MakeToggle(content, "自瞄", false, function(state)
        ToggleAimAssist(state)
    end)

    -- 自瞄部位选择
    BuildAimPartSelector(content)

    -- 飞天
    local flyToggle = MakeToggle(content, "飞天 (WASD+空格/Shift)", false, function(state)
        ToggleFly(state)
        if state and Circling then
            StopCircling()
            SynchronizeCircleToggles(false)
        end
    end)
end

--==================================================
-- 创建双面面板
--==================================================

local function PopulatePart(part, panelType)
    for _, face in ipairs({
        Enum.NormalId.Front,
        Enum.NormalId.Back,
    }) do
        local surface = MakeSurface(part, face)

        local _, content = MakePanelShell(
            surface,

            panelType == "Players"
                and "玩家空间"
                or "轨道控制",

            face == Enum.NormalId.Front
                and "AKI RAIN • FRONT INTERFACE"
                or "AKI RAIN • REAR INTERFACE"
        )

        if panelType == "Players" then
            BuildPlayerPanel(content)
        else
            BuildControlPanel(content)
        end
    end
end

PopulatePart(LeftPanel, "Players")
PopulatePart(RightPanel, "Controls")

RefreshPlayerLists()

Connect(Players.PlayerAdded, function()
    RefreshPlayerLists()
end)

Connect(Players.PlayerRemoving, function(player)
    if SelectedTarget == player then
        SelectedTarget = nil
        StopCircling()
        SynchronizeCircleToggles(false)
    end

    RefreshPlayerLists()
end)

--==================================================
-- 顶部旋转滑条
--==================================================

local TopSurface = MakeSurface(
    TopControlPart,
    Enum.NormalId.Front
)

TopSurface.CanvasSize = Vector2.new(1000, 120)

local TopRoot = MakeGlassFrame(TopSurface)
TopRoot.Size = UDim2.fromScale(1, 1)

local SliderArea = Instance.new("Frame")
SliderArea.Size = UDim2.new(1, -360, 1, -18)
SliderArea.Position = UDim2.new(0, 12, 0, 9)
SliderArea.BackgroundTransparency = 1
SliderArea.BorderSizePixel = 0
SliderArea.Active = false
SliderArea.Parent = TopRoot

local AngleText = MakeLabel(
    SliderArea,
    "旋转  0°",
    14,
    CONFIG.Text
)

AngleText.Size = UDim2.new(1, 0, 0, 28)
AngleText.TextXAlignment = Enum.TextXAlignment.Center
AngleText.Font = Enum.Font.GothamBold

local SliderTrack = Instance.new("Frame")
SliderTrack.Size = UDim2.new(1, -30, 0, 18)
SliderTrack.Position = UDim2.new(0, 15, 0, 57)
SliderTrack.BackgroundColor3 = Color3.fromRGB(45, 52, 68)
SliderTrack.BackgroundTransparency = 0.08
SliderTrack.BorderSizePixel = 0
SliderTrack.Active = false
SliderTrack.Parent = SliderArea
AddCorner(SliderTrack, 20)
AddStroke(SliderTrack, CONFIG.Accent, 1, 0.55)

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new(0.5, 0, 1, 0)
SliderFill.BackgroundColor3 = CONFIG.Accent
SliderFill.BackgroundTransparency = 0.18
SliderFill.BorderSizePixel = 0
SliderFill.Active = false
SliderFill.Parent = SliderTrack
AddCorner(SliderFill, 20)

local SliderKnob = Instance.new("TextButton")
SliderKnob.Size = UDim2.fromOffset(58, 58)
SliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
SliderKnob.Position = UDim2.new(0.5, 0, 0.5, 0)
SliderKnob.BackgroundColor3 = Color3.fromRGB(225, 238, 255)
SliderKnob.BackgroundTransparency = 0.02
SliderKnob.BorderSizePixel = 0
SliderKnob.Text = "↔"
SliderKnob.TextColor3 = Color3.fromRGB(20, 35, 60)
SliderKnob.TextSize = 25
SliderKnob.Font = Enum.Font.GothamBold
SliderKnob.Active = true
SliderKnob.Selectable = true
SliderKnob.AutoButtonColor = false
SliderKnob.ZIndex = 10
SliderKnob.Parent = SliderTrack
AddCorner(SliderKnob, 40)
AddStroke(SliderKnob, CONFIG.White, 2, 0.2)

pcall(function()
    SliderKnob.Interactable = true
end)

local draggingSlider = false
local dragStartX = 0
local dragStartAngle = 0
local activeTouchInput

local function SetRotationAngle(angle)
    RotationAngle = math.clamp(angle, -180, 180)

    local normalized =
        (RotationAngle + 180) / 360

    SliderKnob.Position =
        UDim2.new(normalized, 0, 0.5, 0)

    SliderFill.Size =
        UDim2.new(normalized, 0, 1, 0)

    AngleText.Text = string.format(
        "旋转  %d°",
        math.floor(RotationAngle + 0.5)
    )
end

local function BeginSliderDrag(screenX, inputObject)
    draggingSlider = true
    dragStartX = screenX
    dragStartAngle = RotationAngle
    activeTouchInput = inputObject

    Tween(SliderKnob, 0.12, {
        Size = UDim2.fromOffset(65, 65),
        BackgroundColor3 = CONFIG.White,
    })
end

local function EndSliderDrag()
    if not draggingSlider then
        return
    end

    draggingSlider = false
    activeTouchInput = nil

    -- 不复位。
    -- 松开以后继续保持 RotationAngle。
    Tween(SliderKnob, 0.16, {
        Size = UDim2.fromOffset(58, 58),
        BackgroundColor3 = Color3.fromRGB(225, 238, 255),
    })
end

Connect(SliderKnob.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        BeginSliderDrag(
            UserInputService:GetMouseLocation().X,
            input
        )

    elseif input.UserInputType == Enum.UserInputType.Touch then
        BeginSliderDrag(
            input.Position.X,
            input
        )
    end
end)

Connect(UserInputService.InputChanged, function(input)
    if not draggingSlider then
        return
    end

    local currentX

    if input.UserInputType == Enum.UserInputType.MouseMovement then
        currentX = UserInputService:GetMouseLocation().X

    elseif input.UserInputType == Enum.UserInputType.Touch then
        if activeTouchInput and input ~= activeTouchInput then
            return
        end

        currentX = input.Position.X
    end

    if not currentX then
        return
    end

    local deltaX = currentX - dragStartX

    -- 鼠标移动大约 520 像素对应完整 360°。
    local newAngle =
        dragStartAngle
        + (deltaX / 520) * 360

    SetRotationAngle(newAngle)
end)

Connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        EndSliderDrag()

    elseif input.UserInputType == Enum.UserInputType.Touch then
        if not activeTouchInput or input == activeTouchInput then
            EndSliderDrag()
        end
    end
end)

-- 点击轨道位置，也可以直接调整角度。
Connect(SliderTrack.InputBegan, function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local absolutePosition = SliderTrack.AbsolutePosition
    local absoluteSize = SliderTrack.AbsoluteSize

    if absoluteSize.X <= 0 then
        return
    end

    local inputX =
        input.UserInputType == Enum.UserInputType.Touch
        and input.Position.X
        or UserInputService:GetMouseLocation().X

    local normalized = math.clamp(
        (inputX - absolutePosition.X) / absoluteSize.X,
        0,
        1
    )

    SetRotationAngle(
        -180 + normalized * 360
    )
end)

--==================================================
-- 顶部操作按钮
--==================================================

local TopButtons = Instance.new("Frame")
TopButtons.Size = UDim2.new(0, 340, 1, -18)
TopButtons.Position = UDim2.new(1, -350, 0, 9)
TopButtons.BackgroundTransparency = 1
TopButtons.BorderSizePixel = 0
TopButtons.Active = false
TopButtons.Parent = TopRoot

local TopLayout = Instance.new("UIListLayout")
TopLayout.FillDirection = Enum.FillDirection.Horizontal
TopLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TopLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TopLayout.Padding = UDim.new(0, 8)
TopLayout.Parent = TopButtons

local function MakeTopButton(text, width, color, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(width, 78)
    button.BackgroundColor3 =
        color or Color3.fromRGB(32, 39, 56)

    button.BackgroundTransparency = 0.05
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = CONFIG.Text
    button.TextSize = 16
    button.Font = Enum.Font.GothamBold
    button.Active = true
    button.Selectable = true
    button.AutoButtonColor = false
    button.ZIndex = 10
    button.Parent = TopButtons
    AddCorner(button, 22)
    AddStroke(button, CONFIG.Accent, 1, 0.58)

    pcall(function()
        button.Interactable = true
    end)

    Connect(button.Activated, function()
        Tween(button, 0.07, {
            BackgroundColor3 = CONFIG.Accent,
        })

        task.delay(0.11, function()
            if button.Parent then
                Tween(button, 0.18, {
                    BackgroundColor3 =
                        color
                        or Color3.fromRGB(32, 39, 56),
                })
            end
        end)

        callback()
    end)

    return button
end

local function SetPowered(value)
    DisplayPowered = value

    for _, overlay in ipairs(PowerOverlays) do
        overlay.Visible = not value

        if not value then
            overlay.BackgroundTransparency = 1

            Tween(overlay, 0.25, {
                BackgroundTransparency = 0,
            })
        end
    end
end

local function SetPanelSurfacesEnabled(enabled)
    for _, part in ipairs({
        LeftPanel,
        RightPanel,
        TopControlPart,
    }) do
        for _, object in ipairs(part:GetDescendants()) do
            if object:IsA("SurfaceGui") then
                object.Enabled = enabled
            end
        end
    end
end

local function SetMinimized(value)
    Minimized = value

    if value then
        SetPanelSurfacesEnabled(false)

        CenterBridge.Transparency = 1

        OrbGui.Enabled = true
        OrbLight.Enabled = true
        OrbHighlight.Enabled = true

        OrbPart.Size = Vector3.one * 0.08
        OrbPart.Transparency = 1

        Tween(OrbPart, 0.34, {
            Size = Vector3.one * CONFIG.OrbSize,
            Transparency = 0.13,
        }, Enum.EasingStyle.Back)

    else
        OrbGui.Enabled = false
        OrbLight.Enabled = false
        OrbHighlight.Enabled = false

        Tween(OrbPart, 0.2, {
            Size = Vector3.one * 0.08,
            Transparency = 1,
        })

        SetPanelSurfacesEnabled(true)

        CenterBridge.Transparency =
            InterfaceReady and 0.015 or 1
    end
end

MakeTopButton("电源", 92, nil, function()
    SetPowered(not DisplayPowered)
end)

MakeTopButton("最小化", 112, nil, function()
    SetMinimized(true)
end)

MakeTopButton(
    "关闭",
    92,
    Color3.fromRGB(90, 26, 40),

    function()
        StopCircling()
        Controller:Destroy()
    end
)

Connect(OrbButton.Activated, function()
    SetMinimized(false)
end)

--==================================================
-- 白色粒子伪预加载
--==================================================

local function MakePreloadText(centerCFrame)
    local part = Instance.new("Part")
    part.Name = "PreloadText"
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Transparency = 1
    part.Size = Vector3.new(5.6, 1.2, 0.05)
    part.CFrame = centerCFrame
    part.Parent = WorldFolder

    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.Brightness = 3
    gui.CanvasSize = Vector2.new(700, 150)
    gui.Parent = part

    local title = MakeLabel(
        gui,
        "AKI RAIN",
        34,
        CONFIG.White
    )

    title.Size = UDim2.new(1, 0, 0, 68)
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Font = Enum.Font.GothamBold
    title.TextTransparency = 1

    local subtitle = MakeLabel(
        gui,
        "SPATIAL INTERFACE INITIALIZING",
        11,
        Color3.fromRGB(180, 205, 240)
    )

    subtitle.Size = UDim2.new(1, 0, 0, 28)
    subtitle.Position = UDim2.new(0, 0, 0, 64)
    subtitle.TextXAlignment = Enum.TextXAlignment.Center
    subtitle.TextTransparency = 1

    local progressBack = Instance.new("Frame")
    progressBack.Size = UDim2.new(0.6, 0, 0, 4)
    progressBack.Position = UDim2.new(0.2, 0, 1, -22)
    progressBack.BackgroundColor3 = Color3.fromRGB(60, 68, 82)
    progressBack.BackgroundTransparency = 0.3
    progressBack.BorderSizePixel = 0
    progressBack.Parent = gui
    AddCorner(progressBack, 5)

    local progress = Instance.new("Frame")
    progress.Size = UDim2.new(0, 0, 1, 0)
    progress.BackgroundColor3 = CONFIG.White
    progress.BorderSizePixel = 0
    progress.Parent = progressBack
    AddCorner(progress, 5)

    return part, title, subtitle, progress
end

local function MakeParticle(position)
    local particle = Instance.new("Part")
    particle.Name = "VisionParticle"
    particle.Shape = Enum.PartType.Ball
    particle.Size = Vector3.one * 0.035
    particle.Position = position
    particle.Anchored = true
    particle.CanCollide = false
    particle.CanTouch = false
    particle.CanQuery = false
    particle.CastShadow = false
    particle.Material = Enum.Material.Neon
    particle.Color = CONFIG.White
    particle.Transparency = 0.06
    particle.Parent = WorldFolder

    return particle
end

local function PlayPreload()
    if not Root or not Root.Parent then
        return
    end

    SetPanelSurfacesEnabled(false)
    CenterBridge.Transparency = 1

    local centerPosition =
        Root.Position
        + FixedForward * CONFIG.Distance
        + Vector3.new(0, 0.1, 0)

    local centerCFrame =
        CFrame.new(centerPosition)
        * FixedFacingRotation

    local textPart, title, subtitle, progress =
        MakePreloadText(
            centerCFrame * CFrame.new(0, 0, -0.15)
        )

    Tween(title, 0.4, {
        TextTransparency = 0,
    })

    task.delay(0.13, function()
        if subtitle.Parent then
            Tween(subtitle, 0.42, {
                TextTransparency = 0.06,
            })
        end
    end)

    Tween(progress, 1.75, {
        Size = UDim2.new(1, 0, 1, 0),
    }, Enum.EasingStyle.Sine)

    local particles = {}
    local particleCount = 125

    for index = 1, particleCount do
        local particle = MakeParticle(centerPosition)
        table.insert(particles, particle)

        local side = index % 2 == 0 and -1 or 1

        local horizontal =
            side * (
                0.25
                + math.random() * 5.6
            )

        local vertical =
            (math.random() - 0.5) * 5.5

        local depth =
            (math.random() - 0.5) * 0.75

        -- 一部分粒子形成显示器轮廓。
        if index <= 78 then
            local edge = index % 4

            if edge == 0 then
                vertical = CONFIG.PanelHeight * 0.46
                horizontal = (math.random() - 0.5) * 11

            elseif edge == 1 then
                vertical = -CONFIG.PanelHeight * 0.46
                horizontal = (math.random() - 0.5) * 11

            elseif edge == 2 then
                horizontal = -5.45
                vertical = (math.random() - 0.5) * 5.8

            else
                horizontal = 5.45
                vertical = (math.random() - 0.5) * 5.8
            end
        end

        local target =
            centerCFrame
            * CFrame.new(
                horizontal,
                vertical,
                depth
            )

        particle.CFrame =
            centerCFrame
            * CFrame.new(
                (math.random() - 0.5) * 0.3,
                (math.random() - 0.5) * 0.3,
                (math.random() - 0.5) * 0.3
            )

        task.delay(index * 0.0025, function()
            if not particle.Parent then
                return
            end

            Tween(
                particle,
                0.65 + math.random() * 0.45,
                {
                    CFrame = target,
                    Size =
                        Vector3.one
                        * (
                            0.04
                            + math.random() * 0.07
                        ),
                },
                Enum.EasingStyle.Quint
            )
        end)
    end

    -- 中央扩散扫描球。
    local pulse = Instance.new("Part")
    pulse.Name = "PreloadPulse"
    pulse.Shape = Enum.PartType.Ball
    pulse.Size = Vector3.one * 0.1
    pulse.CFrame = centerCFrame
    pulse.Anchored = true
    pulse.CanCollide = false
    pulse.CanTouch = false
    pulse.CanQuery = false
    pulse.CastShadow = false
    pulse.Material = Enum.Material.Neon
    pulse.Color = CONFIG.White
    pulse.Transparency = 0.2
    pulse.Parent = WorldFolder

    Tween(
        pulse,
        1.35,
        {
            Size = Vector3.one * 12,
            Transparency = 1,
        },
        Enum.EasingStyle.Quint
    )

    task.wait(1.55)

    title.Text = "VISION READY"
    subtitle.Text = "SPATIAL SYSTEM ONLINE"

    task.wait(0.28)

    for index, particle in ipairs(particles) do
        task.delay(index * 0.001, function()
            if not particle.Parent then
                return
            end

            Tween(
                particle,
                0.3,
                {
                    CFrame =
                        centerCFrame
                        * CFrame.new(
                            (math.random() - 0.5) * 0.2,
                            (math.random() - 0.5) * 0.2,
                            0
                        ),

                    Size = Vector3.one * 0.01,
                    Transparency = 1,
                },
                Enum.EasingStyle.Quint,
                Enum.EasingDirection.In
            )
        end)
    end

    task.wait(0.28)

    Tween(title, 0.22, {
        TextTransparency = 1,
    })

    Tween(subtitle, 0.22, {
        TextTransparency = 1,
    })

    task.wait(0.27)

    for _, particle in ipairs(particles) do
        pcall(function()
            particle:Destroy()
        end)
    end

    pcall(function()
        pulse:Destroy()
    end)

    pcall(function()
        textPart:Destroy()
    end)
end

--==================================================
-- 每帧更新
--==================================================

local RevealScale = 0.02
local OrbTime = 0

Connect(RunService.RenderStepped, function(deltaTime)
    if Controller.Destroyed then
        return
    end

    if not Root or not Root.Parent then
        return
    end

    local followAlpha =
        1 - math.exp(-CONFIG.FollowSpeed * deltaTime)

    -- 这里只读取 Root.Position。
    -- 不读取当前 LookVector，不跟随角色转向。
    local desiredCenter =
        Root.Position
        + FixedForward * CONFIG.Distance
        + Vector3.new(0, CONFIG.HeightOffset, 0)

    CurrentDisplayPosition =
        CurrentDisplayPosition:Lerp(
            desiredCenter,
            followAlpha
        )

    -- 固定初始方向 + 顶部滑条旋转角度。
    local displayRig =
        CFrame.new(CurrentDisplayPosition)
        * CFrame.Angles(
            0,
            math.rad(RotationAngle),
            0
        )
        * FixedFacingRotation

    local finalScale =
        DisplayScale
        * math.max(RevealScale, 0.01)

    local panelWidth =
        CONFIG.PanelWidth
        * finalScale

    local panelHeight =
        CONFIG.PanelHeight
        * finalScale

    local gap =
        CONFIG.CenterGap
        * finalScale

    LeftPanel.Size = Vector3.new(
        panelWidth,
        panelHeight,
        0.08
    )

    RightPanel.Size = Vector3.new(
        panelWidth,
        panelHeight,
        0.08
    )

    local halfDistance =
        panelWidth * 0.5
        + gap

    local curve =
        math.rad(CONFIG.CurveAngle)

    -- 左右两块向玩家方向内弯。
    local leftLocal =
        CFrame.new(-halfDistance, 0, 0)
        * CFrame.Angles(0, -curve, 0)

    local rightLocal =
        CFrame.new(halfDistance, 0, 0)
        * CFrame.Angles(0, curve, 0)

    LeftPanel.CFrame =
        displayRig
        * leftLocal

    RightPanel.CFrame =
        displayRig
        * rightLocal

    CenterBridge.Size = Vector3.new(
        math.max(
            0.18,
            math.abs(gap) * 2 + 0.26
        ),
        panelHeight * 0.96,
        0.12
    )

    CenterBridge.CFrame =
        displayRig
        * CFrame.new(0, 0, 0.02)

    TopControlPart.Size = Vector3.new(
        7.3 * finalScale,
        0.88 * finalScale,
        0.08
    )

    TopControlPart.CFrame =
        displayRig
        * CFrame.new(
            0,
            panelHeight * 0.5
                + 0.68 * finalScale,
            0
        )

    for _, label in ipairs(StatusLabels) do
        label.Text =
            Circling
            and "状态：绕圈中"
            or "状态：空闲"

        label.TextColor3 =
            Circling
            and CONFIG.Active
            or CONFIG.Text
    end

    for _, label in ipairs(TargetLabels) do
        label.Text =
            "目标："
            .. (
                SelectedTarget
                and SelectedTarget.DisplayName
                or "未选择"
            )
    end

    for _, label in ipairs(SpeedLabels) do
        label.Text =
            tostring(CircleSpeed)
            .. "×"
    end

    for _, label in ipairs(ScaleLabels) do
        label.Text = string.format(
            "%d%%",
            math.floor(DisplayScale * 100 + 0.5)
        )
    end

    -- 漂浮小球位置同样只跟随 XYZ。
    OrbTime += deltaTime

    local desiredOrbPosition =
        Root.Position
        + FixedForward * CONFIG.OrbDistance
        + Vector3.new(
            0,
            CONFIG.OrbHeight
                + math.sin(OrbTime * 2.1) * 0.15,
            0
        )

    CurrentOrbPosition =
        CurrentOrbPosition:Lerp(
            desiredOrbPosition,
            followAlpha
        )

    OrbPart.CFrame =
        CFrame.new(CurrentOrbPosition)
        * CFrame.Angles(
            OrbTime * 0.3,
            OrbTime * 0.75,
            OrbTime * 0.2
        )
end)

--==================================================
-- 鼠标滚轮缩放
--==================================================

Connect(UserInputService.InputChanged, function(input)
    if Minimized or not InterfaceReady then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseWheel then
        DisplayScale = math.clamp(
            DisplayScale + input.Position.Z * 0.06,
            CONFIG.MinimumScale,
            CONFIG.MaximumScale
        )
    end
end)

--==================================================
-- 快捷键
--==================================================

Connect(UserInputService.InputBegan, function(input, processed)
    if processed then
        return
    end

    if input.KeyCode == Enum.KeyCode.M then
        SetMinimized(not Minimized)

    elseif input.KeyCode == Enum.KeyCode.P then
        SetPowered(not DisplayPowered)

    elseif input.KeyCode == Enum.KeyCode.R then
        SetRotationAngle(0)

    elseif input.KeyCode == Enum.KeyCode.LeftBracket then
        DisplayScale = math.clamp(
            DisplayScale - CONFIG.ScaleStep,
            CONFIG.MinimumScale,
            CONFIG.MaximumScale
        )

    elseif input.KeyCode == Enum.KeyCode.RightBracket then
        DisplayScale = math.clamp(
            DisplayScale + CONFIG.ScaleStep,
            CONFIG.MinimumScale,
            CONFIG.MaximumScale
        )
    end
end)

--==================================================
-- 启动
--==================================================

SetRotationAngle(0)
SetPowered(true)

task.spawn(function()
    PlayPreload()

    if Controller.Destroyed then
        return
    end

    InterfaceReady = true
    SetPanelSurfacesEnabled(true)
    CenterBridge.Transparency = 0.015

    local revealValue = Instance.new("NumberValue")
    revealValue.Value = 0.02
    revealValue.Parent = WorldFolder

    Connect(
        revealValue:GetPropertyChangedSignal("Value"),
        function()
            RevealScale = revealValue.Value
        end
    )

    Tween(
        revealValue,
        0.72,
        {
            Value = 1,
        },
        Enum.EasingStyle.Back
    )

    task.delay(0.9, function()
        if revealValue.Parent then
            RevealScale = 1
            revealValue:Destroy()
        end
    end)
end)

print("==========================================")
print("✅ 秋雨 Vision Spatial UI 已加载")
print("✅ 双面 GUI 已启用")
print("✅ 仅跟随 XYZ，不跟随角色转向")
print("✅ 顶部滑条范围：-180° ~ 180°")
print("✅ 松手后保持当前旋转角度")
print("✅ M 最小化 / P 息屏 / R 角度复位")
print("✅ 新增：无限子弹 / 无限血量 / 自瞄(头/身) / 飞天")
print("==========================================")