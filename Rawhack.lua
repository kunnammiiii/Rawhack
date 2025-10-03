-- RawHack Part1: Variables and Functions
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- Переменные для функций
local bhopEnabled = false
local bhopMultiplier = 2
local silentAimEnabled = false
local silentAimMode = "Head Only"
local autoFireEnabled = false
local autoFireMode = "Instant"
local autoFireDelay = 0.1
local fakeLagEnabled = false
local fakeLagAmount = 0.5
local speedEnabled = false
local speedMode = "WalkSpeed"
local speedMultiplier = 2
local autoPeekEnabled = false
local autoPeekFOV = 100
local targetPlayer = nil
local lagQueue = {}

-- Функция поиска ближайшего игрока в FOV
function findClosestPlayerInFOV(origin, direction, fov)
    local closest, dist = nil, math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(player.Character.Head.Position)
            local delta = Vector2.new(screenPos.X - workspace.CurrentCamera.ViewportSize.X/2, screenPos.Y - workspace.CurrentCamera.ViewportSize.Y/2)
            if onScreen and delta.Magnitude < fov/2 then
                local playerDist = (player.Character.Head.Position - origin).Magnitude
                if playerDist < dist then
                    closest, dist = player, playerDist
                end
            end
        end
    end
    return closest and closest.Character
end

-- Silent Aim (hook raycast)
local oldRaycast
oldRaycast = hookmetamethod(game, "__namecall", function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    if silentAimEnabled and method == "Raycast" and self == workspace then
        local rayOrigin = args[1]
        local rayDirection = args[2]
        local target = findClosestPlayerInFOV(rayOrigin, rayDirection, autoPeekFOV)
        if target then
            if silentAimMode == "Head Only" then
                args[2] = (target.Head.Position - rayOrigin).Unit * 1000
            elseif silentAimMode == "Body" then
                args[2] = (target.Torso.Position - rayOrigin).Unit * 1000
            elseif silentAimMode == "Random" then
                local parts = {"Head", "Torso", "Left Arm", "Right Arm"}
                local randPart = target[parts[math.random(1, #parts)]]
                args[2] = (randPart.Position - rayOrigin).Unit * 1000
            elseif silentAimMode == "FOV-Based" then
                args[2] = (target.Head.Position - rayOrigin).Unit * 1000
            elseif silentAimMode == "Raycast" then
                args[2] = (target.Head.Position - rayOrigin).Unit * 1000
            end
        end
    end
    return oldRaycast(self, unpack(args))
end)

-- AutoFire
RunService.Heartbeat:Connect(function()
    if autoFireEnabled and silentAimEnabled then
        local target = findClosestPlayerInFOV(RootPart.Position, RootPart.CFrame.LookVector * 100, autoPeekFOV)
        if target then
            if autoFireMode == "Instant" or (autoFireMode == "Auto" and UserInputService.TouchEnabled) then
                if LocalPlayer.Character:FindFirstChildOfClass("Tool") then
                    LocalPlayer.Character:FindFirstChildOfClass("Tool").Activated:FireServer(target.Head.Position)
                end
            elseif autoFireMode == "Delay" then
                wait(autoFireDelay)
            elseif autoFireMode == "Touch-Hold" then
                UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                    end
                end)
            end
        end
    end
end)

-- B-Hop с ускорением в воздухе
RunService.Stepped:Connect(function()
    if bhopEnabled and Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        RootPart.Velocity = Vector3.new(RootPart.Velocity.X * bhopMultiplier, 50, RootPart.Velocity.Z * bhopMultiplier)
    end
end)

-- FakeLag
local lastPos = RootPart.Position
RunService.Heartbeat:Connect(function()
    if fakeLagEnabled then
        table.insert(lagQueue, RootPart.Position)
        if #lagQueue > fakeLagAmount * 60 then
            RootPart.CFrame = CFrame.new(table.remove(lagQueue, 1))
        end
        for _, part in pairs(Character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CFrame = RootPart.CFrame * CFrame.new(0, 0, -5)
            end
        end
    end
end)

-- Speeds
RunService.Heartbeat:Connect(function()
    if speedEnabled then
        if speedMode == "WalkSpeed" then
            Humanoid.WalkSpeed = 16 * speedMultiplier
        elseif speedMode == "CFrame" then
            RootPart.CFrame = RootPart.CFrame + RootPart.CFrame.LookVector * (speedMultiplier - 1) * 16 * RunService.Heartbeat:Wait()
        elseif speedMode == "Fly" then
            local cam = workspace.CurrentCamera.CFrame
            RootPart.CFrame = cam + cam.LookVector * speedMultiplier * 50
        elseif speedMode == "BunnyHop" then
            if Humanoid:GetState() == Enum.HumanoidStateType.Jumping then
                RootPart.Velocity = Vector3.new(RootPart.Velocity.X * speedMultiplier, RootPart.Velocity.Y, RootPart.Velocity.Z * speedMultiplier)
            end
        end
    end
end)

-- AutoPeek кнопка
local PeekButton = Instance.new("TextButton")
PeekButton.Size = UDim2.new(0, 100, 0, 50)
PeekButton.Position = UDim2.new(0.5, -50, 0.8, 0)
PeekButton.Text = "AutoPeek"
PeekButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
PeekButton.TextColor3 = Color3.fromRGB(255, 255, 255)
PeekButton.Visible = false
PeekButton.Parent = game.CoreGui
local peekDragging, peekDragInput, peekDragStart, peekStartPos
PeekButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        peekDragging = true
        peekDragStart = input.Position
        peekStartPos = PeekButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                peekDragging = false
            end
        end)
    end
end)
PeekButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        peekDragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if peekDragging and input == peekDragInput then
        local delta = input.Position - peekDragStart
        PeekButton.Position = UDim2.new(peekStartPos.X.Scale, peekStartPos.X.Offset + delta.X, peekStartPos.Y.Scale, peekStartPos.Y.Offset + delta.Y)
    end
end)
PeekButton.MouseButton1Click:Connect(function()
    if autoPeekEnabled then
        local target = findClosestPlayerInFOV(RootPart.Position, RootPart.CFrame.LookVector, autoPeekFOV)
        if target then
            local rayRight = workspace:Raycast(RootPart.Position, RootPart.CFrame.RightVector * 10)
            local rayLeft = workspace:Raycast(RootPart.Position, -RootPart.CFrame.RightVector * 10)
            local peekDir = rayRight and rayRight.Instance and rayRight.Instance.CanCollide and -RootPart.CFrame.RightVector or RootPart.CFrame.RightVector
            RootPart.CFrame = CFrame.new(RootPart.Position + peekDir * 5, target.Head.Position)
            if silentAimEnabled and autoFireEnabled then
                wait(0.1)
                if LocalPlayer.Character:FindFirstChildOfClass("Tool") then
                    LocalPlayer.Character:FindFirstChildOfClass("Tool").Activated:FireServer(target.Head.Position)
                end
            end
        end
    end
end)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RawHackGui"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local OpenButton = Instance.new("ImageButton")
OpenButton.Size = UDim2.new(0, 60, 0, 60)
OpenButton.Position = UDim2.new(0.9, 0, 0.9, 0)
OpenButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
OpenButton.BorderSizePixel = 0
OpenButton.Image = "rbxassetid://6031075938"
OpenButton.ScaleType = Enum.ScaleType.Fit
local OpenButtonCorner = Instance.new("UICorner")
OpenButtonCorner.CornerRadius = UDim.new(0, 30)
OpenButtonCorner.Parent = OpenButton
local OpenButtonStroke = Instance.new("UIStroke")
OpenButtonStroke.Color = Color3.fromRGB(255, 255, 255)
OpenButtonStroke.Thickness = 2
OpenButtonStroke.Parent = OpenButton
OpenButton.Parent = ScreenGui

local dragging, dragInput, dragStart, startPos
OpenButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = OpenButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
OpenButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        OpenButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 400, 0, 400)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
local MainFrameCorner = Instance.new("UICorner")
MainFrameCorner.CornerRadius = UDim.new(0, 15)
MainFrameCorner.Parent = MainFrame
local MainFrameStroke = Instance.new("UIStroke")
MainFrameStroke.Color = Color3.fromRGB(255, 255, 255)
MainFrameStroke.Thickness = 2
MainFrameStroke.Parent = MainFrame
local MainFrameGradient = Instance.new("UIGradient")
MainFrameGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 30)), ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 60, 60))}
MainFrameGradient.Rotation = 45
MainFrameGradient.Parent = MainFrame
MainFrame.Parent = ScreenGui

local function tweenFrame(visible)
    MainFrame.Visible = true
    local goal = visible and {Position = UDim2.new(0.5, -200, 0.5, -200)} or {Position = UDim2.new(0.5, -200, 0.5, 200)}
    local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    local tween = TweenService:Create(MainFrame, tweenInfo, goal)
    tween:Play()
    if not visible then
        tween.Completed:Connect(function() MainFrame.Visible = false end)
    end
end

OpenButton.MouseButton1Click:Connect(function() tweenFrame(not MainFrame.Visible) end)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and MainFrame.Visible then
        local mousePos = UserInputService:GetMouseLocation()
        local framePos = MainFrame.AbsolutePosition
        local frameSize = MainFrame.AbsoluteSize
        if mousePos.X < framePos.X or mousePos.X > framePos.X + frameSize.X or mousePos.Y < framePos.Y or mousePos.Y > framePos.Y + frameSize.Y then
            tweenFrame(false)
        end
    end
end)

local Logo = Instance.new("ImageLabel")
Logo.Size = UDim2.new(0, 50, 0, 50)
Logo.Position = UDim2.new(0, 10, 0, 10)
Logo.BackgroundTransparency = 1
Logo.Image = "rbxassetid://6031075938"
Logo.ScaleType = Enum.ScaleType.Fit
Logo.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 200, 0, 30)
Title.Position = UDim2.new(0, 70, 0, 20)
Title.BackgroundTransparency = 1
Title.Text = "RawHack"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 26
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(0, 100, 0, 340)
TabContainer.Position = UDim2.new(0, 10, 0, 60)
TabContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TabContainer.BorderSizePixel = 0
local TabContainerCorner = Instance.new("UICorner")
TabContainerCorner.CornerRadius = UDim.new(0, 10)
TabContainerCorner.Parent = TabContainer
local TabContainerStroke = Instance.new("UIStroke")
TabContainerStroke.Color = Color3.fromRGB(255, 255, 255)
TabContainerStroke.Thickness = 1
TabContainerStroke.Parent = TabContainer
TabContainer.Parent = MainFrame

local ContentContainer = Instance.new("ScrollingFrame")
ContentContainer.Size = UDim2.new(0, 280, 0, 340)
ContentContainer.Position = UDim2.new(0, 120, 0, 60)
ContentContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
ContentContainer.BorderSizePixel = 0
ContentContainer.ScrollBarThickness = 10
local ContentContainerCorner = Instance.new("UICorner")
ContentContainerCorner.CornerRadius = UDim.new(0, 10)
ContentContainerCorner.Parent = ContentContainer
ContentContainer.Parent = MainFrame
local ContentLayout = Instance.new("UIListLayout")
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 5)
ContentLayout.Parent = ContentContainer

local currentTab = nil

local function createTab(name, positionY)
    local TabButton = Instance.new("TextButton")
    TabButton.Size = UDim2.new(1, -10, 0, 40)
    TabButton.Position = UDim2.new(0, 5, 0, positionY)
    TabButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    TabButton.BorderSizePixel = 0
    TabButton.Text = name
    TabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabButton.TextSize = 16
    TabButton.Font = Enum.Font.Gotham
    local TabButtonCorner = Instance.new("UICorner")
    TabButtonCorner.CornerRadius = UDim.new(0, 8)
    TabButtonCorner.Parent = TabButton
    local TabButtonStroke = Instance.new("UIStroke")
    TabButtonStroke.Color = Color3.fromRGB(255, 255, 255)
    TabButtonStroke.Thickness = 1
    TabButtonStroke.Parent = TabButton
    TabButton.Parent = TabContainer
    
    local TabContent = Instance.new("Frame")
    TabContent.Name = "Content"
    TabContent.Size = UDim2.new(1, 0, 1, 0)
    TabContent.BackgroundTransparency = 1
    TabContent.Visible = false
    TabContent.Parent = ContentContainer
    TabContent.Size = UDim2.new(1, 0, 0, 0)
    
    local highlightTween = TweenService:Create(TabButton, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {BackgroundColor3 = Color3.fromRGB(80, 80, 80)})
    
    TabButton.MouseButton1Click:Connect(function()
        if currentTab then
            TweenService:Create(currentTab.Button, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {BackgroundColor3 = Color3.fromRGB(50, 50, 50)}):Play()
            currentTab.Content.Visible = false
        end
        currentTab = {Button = TabButton, Content = TabContent}
        highlightTween:Play()
        currentTab.Content.Visible = true
        ContentContainer.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y)
    end)
    
    return TabButton, TabContent
end

-- Вкладка Rage
local RageTabButton, RageTabContent = createTab("Rage", 5)

local BHopToggle = Instance.new("TextButton")
BHopToggle.Size = UDim2.new(1, 0, 0, 30)
BHopToggle.Text = "B-Hop: Off"
BHopToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
BHopToggle.Parent = RageTabContent
BHopToggle.MouseButton1Click:Connect(function()
    bhopEnabled = not bhopEnabled
    BHopToggle.Text = "B-Hop: " .. (bhopEnabled and "On" or "Off")
    BHopToggle.BackgroundColor3 = bhopEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end)

local BHopSlider = Instance.new("TextBox")
BHopSlider.Size = UDim2.new(1, 0, 0, 20)
BHopSlider.Position = UDim2.new(0, 0, 0, 35)
BHopSlider.Text = "Multiplier: " .. bhopMultiplier
BHopSlider.Parent = RageTabContent
BHopSlider.FocusLost:Connect(function()
    bhopMultiplier = tonumber(BHopSlider.Text:match("%d+")) or 2
    BHopSlider.Text = "Multiplier: " .. bhopMultiplier
end)

local SilentAimToggle = Instance.new("TextButton")
SilentAimToggle.Size = UDim2.new(1, 0, 0, 30)
SilentAimToggle.Position = UDim2.new(0, 0, 0, 60)
SilentAimToggle.Text = "Silent Aim: Off"
SilentAimToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
SilentAimToggle.Parent = RageTabContent
SilentAimToggle.MouseButton1Click:Connect(function()
    silentAimEnabled = not silentAimEnabled
    SilentAimToggle.Text = "Silent Aim: " .. (silentAimEnabled and "On" or "Off")
    SilentAimToggle.BackgroundColor3 = silentAimEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end)

local SilentAimModeLabel = Instance.new("TextLabel")
SilentAimModeLabel.Size = UDim2.new(1, 0, 0, 20)
SilentAimModeLabel.Position = UDim2.new(0, 0, 0, 95)
SilentAimModeLabel.Text = "Mode: " .. silentAimMode
SilentAimModeLabel.Parent = RageTabContent
local SilentAimDropdown = Instance.new("TextButton")
SilentAimDropdown.Size = UDim2.new(1, 0, 0, 20)
SilentAimDropdown.Position = UDim2.new(0, 0, 0, 115)
SilentAimDropdown.Text = "Change Mode"
SilentAimDropdown.Parent = RageTabContent
SilentAimDropdown.MouseButton1Click:Connect(function()
    local modes = {"Head Only", "Body", "Random", "FOV-Based", "Raycast"}
    silentAimMode = modes[math.random(1, #modes)]
    SilentAimModeLabel.Text = "Mode: " .. silentAimMode
end)

local AutoFireToggle = Instance.new("TextButton")
AutoFireToggle.Size = UDim2.new(1, 0, 0, 30)
AutoFireToggle.Position = UDim2.new(0, 0, 0, 140)
AutoFireToggle.Text = "AutoFire: Off"
AutoFireToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
AutoFireToggle.Parent = RageTabContent
AutoFireToggle.MouseButton1Click:Connect(function()
    autoFireEnabled = not autoFireEnabled
    AutoFireToggle.Text = "AutoFire: " .. (autoFireEnabled and "On" or "Off")
    AutoFireToggle.BackgroundColor3 = autoFireEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end)

local AutoFireModeLabel = Instance.new("TextLabel")
AutoFireModeLabel.Size = UDim2.new(1, 0, 0, 20)
AutoFireModeLabel.Position = UDim2.new(0, 0, 0, 175)
AutoFireModeLabel.Text = "Mode: " .. autoFireMode
AutoFireModeLabel.Parent = RageTabContent
local AutoFireDropdown = Instance.new("TextButton")
AutoFireDropdown.Size = UDim2.new(1, 0, 0, 20)
AutoFireDropdown.Position = UDim2.new(0, 0, 0, 195)
AutoFireDropdown.Text = "Change Mode"
AutoFireDropdown.Parent = RageTabContent
AutoFireDropdown.MouseButton1Click:Connect(function()
    local modes = UserInputService.TouchEnabled and {"Touch-Hold", "Auto"} or {"Instant", "Delay"}
    autoFireMode = modes[math.random(1, #modes)]
    AutoFireModeLabel.Text = "Mode: " .. autoFireMode
end)

local AutoFireSlider = Instance.new("TextBox")
AutoFireSlider.Size = UDim2.new(1, 0, 0, 20)
AutoFireSlider.Position = UDim2.new(0, 0, 0, 220)
AutoFireSlider.Text = "Delay: " .. autoFireDelay
AutoFireSlider.Parent = RageTabContent
AutoFireSlider.FocusLost:Connect(function()
    autoFireDelay = tonumber(AutoFireSlider.Text:match("%d+")) or 0.1
    AutoFireSlider.Text = "Delay: " .. autoFireDelay
end)

local FakeLagToggle = Instance.new("TextButton")
FakeLagToggle.Size = UDim2.new(1, 0, 0, 30)
FakeLagToggle.Position = UDim2.new(0, 0, 0, 245)
FakeLagToggle.Text = "FakeLag: Off"
FakeLagToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
FakeLagToggle.Parent = RageTabContent
FakeLagToggle.MouseButton1Click:Connect(function()
    fakeLagEnabled = not fakeLagEnabled
    FakeLagToggle.Text = "FakeLag: " .. (fakeLagEnabled and "On" or "Off")
    FakeLagToggle.BackgroundColor3 = fakeLagEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end)

local FakeLagSlider = Instance.new("TextBox")
FakeLagSlider.Size = UDim2.new(1, 0, 0, 20)
FakeLagSlider.Position = UDim2.new(0, 0, 0, 280)
FakeLagSlider.Text = "Amount: " .. fakeLagAmount
FakeLagSlider.Parent = RageTabContent
FakeLagSlider.FocusLost:Connect(function()
    fakeLagAmount = math.clamp(tonumber(FakeLagSlider.Text:match("%d+")) or 0.5, 0, 1)
    FakeLagSlider.Text = "Amount: " .. fakeLagAmount
end)

local AutoPeekToggle = Instance.new("TextButton")
AutoPeekToggle.Size = UDim2.new(1, 0, 0, 30)
AutoPeekToggle.Position = UDim2.new(0, 0, 0, 305)
AutoPeekToggle.Text = "AutoPeek: Off"
AutoPeekToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
AutoPeekToggle.Parent = RageTabContent
AutoPeekToggle.MouseButton1Click:Connect(function()
    autoPeekEnabled = not autoPeekEnabled
    AutoPeekToggle.Text = "AutoPeek: " .. (autoPeekEnabled and "On" or "Off")
    AutoPeekToggle.BackgroundColor3 = autoPeekEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    PeekButton.Visible = autoPeekEnabled
end)

local AutoPeekSlider = Instance.new("TextBox")
AutoPeekSlider.Size = UDim2.new(1, 0, 0, 20)
AutoPeekSlider.Position = UDim2.new(0, 0, 0, 340)
AutoPeekSlider.Text = "FOV: " .. autoPeekFOV
AutoPeekSlider.Parent = RageTabContent
AutoPeekSlider.FocusLost:Connect(function()
    autoPeekFOV = tonumber(AutoPeekSlider.Text:match("%d+")) or 100
    AutoPeekSlider.Text = "FOV: " .. autoPeekFOV
end)

-- Вкладка Visual
local VisualTabButton, VisualTabContent = createTab("Visual", 50)

local SpeedToggle = Instance.new("TextButton")
SpeedToggle.Size = UDim2.new(1, 0, 0, 30)
SpeedToggle.Text = "Speed: Off"
SpeedToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
SpeedToggle.Parent = VisualTabContent
SpeedToggle.MouseButton1Click:Connect(function()
    speedEnabled = not speedEnabled
    SpeedToggle.Text = "Speed: " .. (speedEnabled and "On" or "Off")
    SpeedToggle.BackgroundColor3 = speedEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end)

local SpeedModeLabel = Instance.new("TextLabel")
SpeedModeLabel.Size = UDim2.new(1, 0, 0, 20)
SpeedModeLabel.Position = UDim2.new(0, 0, 0, 35)
SpeedModeLabel.Text = "Mode: " .. speedMode
SpeedModeLabel.Parent = VisualTabContent
local SpeedDropdown = Instance.new("TextButton")
SpeedDropdown.Size = UDim2.new(1, 0, 0, 20)
SpeedDropdown.Position = UDim2.new(0, 0, 0, 55)
SpeedDropdown.Text = "Change Mode"
SpeedDropdown.Parent = VisualTabContent
SpeedDropdown.MouseButton1Click:Connect(function()
    local modes = {"WalkSpeed", "CFrame", "Fly", "BunnyHop"}
    speedMode = modes[math.random(1, #modes)]
    SpeedModeLabel.Text = "Mode: " .. speedMode
end)

local SpeedSlider = Instance.new("TextBox")
SpeedSlider.Size = UDim2.new(1, 0, 0, 20)
SpeedSlider.Position = UDim2.new(0, 0, 0, 80)
SpeedSlider.Text = "Multiplier: " .. speedMultiplier
SpeedSlider.Parent = VisualTabContent
SpeedSlider.FocusLost:Connect(function()
    speedMultiplier = tonumber(SpeedSlider.Text:match("%d+")) or 2
    SpeedSlider.Text = "Multiplier: " .. speedMultiplier
end)

RageTabButton.MouseButton1Click:Fire()

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -40, 0, 10)
CloseButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 20
CloseButton.Font = Enum.Font.GothamBold
CloseButton.BorderSizePixel = 0
local CloseButtonCorner = Instance.new("UICorner")
CloseButtonCorner.CornerRadius = UDim.new(0, 8)
CloseButtonCorner.Parent = CloseButton
CloseButton.Parent = MainFrame
CloseButton.MouseButton1Click:Connect(function() tweenFrame(false) end)

ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ContentContainer.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y)
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    RootPart = char:WaitForChild("HumanoidRootPart")
end)

print("RawHack loaded successfully.")
