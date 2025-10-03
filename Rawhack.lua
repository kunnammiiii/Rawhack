-- RawHack Part1: Functions and Improvements
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- Переменные
local bhopEnabled = false
local bhopMultiplierGround = 1.5
local bhopMultiplierAir = 2.5
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
local lagQueue = {}
local bhopToggleButton = nil

-- Функция поиска цели
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

-- Silent Aim
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
            end
        end
    end
    return oldRaycast(self, unpack(args))
end)

-- AutoFire
RunService.Heartbeat:Connect(function()
    if autoFireEnabled and silentAimEnabled then
        local target = findClosestPlayerInFOV(RootPart.Position, RootPart.CFrame.LookVector * 100, autoPeekFOV)
        if target and LocalPlayer.Character:FindFirstChildOfClass("Tool") then
            LocalPlayer.Character:FindFirstChildOfClass("Tool").Activated:FireServer(target.Head.Position)
        end
    end
end)

-- B-Hop (автопрыжки с ускорением)
RunService.Stepped:Connect(function()
    if bhopEnabled and Humanoid.MoveDirection.Magnitude > 0 then
        if Humanoid:GetState() == Enum.HumanoidStateType.Running or Humanoid:GetState() == Enum.HumanoidStateType.RunningNoPhysics then
            Humanoid.Jump = true
            RootPart.Velocity = Vector3.new(RootPart.Velocity.X * bhopMultiplierGround, RootPart.Velocity.Y, RootPart.Velocity.Z * bhopMultiplierGround)
        elseif Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
            RootPart.Velocity = Vector3.new(RootPart.Velocity.X * bhopMultiplierAir, RootPart.Velocity.Y, RootPart.Velocity.Z * bhopMultiplierAir)
        end
    end
end)

-- FakeLag
RunService.Heartbeat:Connect(function()
    if fakeLagEnabled then
        table.insert(lagQueue, RootPart.Position)
        if #lagQueue > fakeLagAmount * 60 then
            RootPart.CFrame = CFrame.new(table.remove(lagQueue, 1))
        end
    end
end)

-- Speed
RunService.Heartbeat:Connect(function()
    if speedEnabled then
        if speedMode == "WalkSpeed" then
            Humanoid.WalkSpeed = 16 * speedMultiplier
        elseif speedMode == "CFrame" then
            RootPart.CFrame = RootPart.CFrame + RootPart.CFrame.LookVector * speedMultiplier * 16 * RunService.Heartbeat:Wait()
        end
    end
end)

-- AutoPeek
local function autoPeekAction()
    if autoPeekEnabled then
        local target = findClosestPlayerInFOV(RootPart.Position, RootPart.CFrame.LookVector, autoPeekFOV)
        if target then
            local peekDir = workspace:Raycast(RootPart.Position, RootPart.CFrame.RightVector * 10) and -RootPart.CFrame.RightVector or RootPart.CFrame.RightVector
            RootPart.CFrame = CFrame.new(RootPart.Position + peekDir * 5, target.Head.Position)
            if silentAimEnabled and autoFireEnabled then
                wait(0.1)
                if LocalPlayer.Character:FindFirstChildOfClass("Tool") then
                    LocalPlayer.Character:FindFirstChildOfClass("Tool").Activated:FireServer(target.Head.Position)
                end
            end
        end
    end
end
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and autoPeekEnabled then
        autoPeekAction()
    end
end)
-- RawHack Part2: Compact GUI with Scrolling
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RawHackGui"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local OpenButton = Instance.new("ImageButton")
OpenButton.Size = UDim2.new(0, 50, 0, 50)
OpenButton.Position = UDim2.new(0.9, -25, 0.9, -25)
OpenButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
OpenButton.BorderSizePixel = 0
OpenButton.Image = "rbxassetid://6031075938"
OpenButton.Parent = ScreenGui

local dragging, dragInput, dragStart, startPos
OpenButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = OpenButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
OpenButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
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
MainFrame.Size = UDim2.new(0, 300, 0, 250)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -125)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
local MainFrameCorner = Instance.new("UICorner")
MainFrameCorner.CornerRadius = UDim.new(0, 10)
MainFrameCorner.Parent = MainFrame
MainFrame.Parent = ScreenGui

local function tweenFrame(visible)
    MainFrame.Visible = true
    local goal = visible and {Position = UDim2.new(0.5, -150, 0.5, -125)} or {Position = UDim2.new(0.5, -150, 1, 0)}
    local tween = TweenService:Create(MainFrame, TweenInfo.new(0.3), goal)
    tween:Play()
    if not visible then tween.Completed:Connect(function() MainFrame.Visible = false end) end
end

OpenButton.MouseButton1Click:Connect(function() tweenFrame(not MainFrame.Visible) end)
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch and MainFrame.Visible then
        local pos = UserInputService:GetMouseLocation()
        local framePos = MainFrame.AbsolutePosition
        local frameSize = MainFrame.AbsoluteSize
        if pos.X < framePos.X or pos.X > framePos.X + frameSize.X or pos.Y < framePos.Y or pos.Y > framePos.Y + frameSize.Y then
            tweenFrame(false)
        end
    end
end)

local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(0, 80, 0, 250)
TabContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TabContainer.BorderSizePixel = 0
TabContainer.Parent = MainFrame
local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Vertical
TabLayout.Padding = UDim.new(0, 5)
TabLayout.Parent = TabContainer

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(0, 210, 0, 250)
ContentFrame.Position = UDim2.new(0, 80, 0, 0)
ContentFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame
local ContentScroll = Instance.new("ScrollingFrame")
ContentScroll.Size = UDim2.new(1, 0, 1, 0)
ContentScroll.BackgroundTransparency = 1
ContentScroll.BorderSizePixel = 0
ContentScroll.ScrollBarThickness = 6
ContentScroll.Parent = ContentFrame
local ContentLayout = Instance.new("UIListLayout")
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 5)
ContentLayout.Parent = ContentScroll

local currentTab = nil

local function createTab(name)
    local TabButton = Instance.new("TextButton")
    TabButton.Size = UDim2.new(1, -10, 0, 40)
    TabButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    TabButton.BorderSizePixel = 0
    TabButton.Text = name
    TabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabButton.TextSize = 14
    TabButton.Parent = TabContainer
    local TabCorner = Instance.new("UICorner")
    TabCorner.CornerRadius = UDim.new(0, 5)
    TabCorner.Parent = TabButton

    local TabContent = Instance.new("Frame")
    TabContent.Size = UDim2.new(1, -10, 0, 0)
    TabContent.BackgroundTransparency = 1
    TabContent.Visible = false
    TabContent.Parent = ContentScroll

    TabButton.MouseButton1Click:Connect(function()
        if currentTab then
            currentTab.Button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            currentTab.Content.Visible = false
        end
        currentTab = {Button = TabButton, Content = TabContent}
        TabButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        TabContent.Visible = true
        ContentScroll.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y)
    end)

    return TabButton, TabContent
end

-- Вкладка Rage
local RageTabButton, RageTabContent = createTab("Rage")

local BHopToggle = Instance.new("TextButton")
BHopToggle.Size = UDim2.new(1, 0, 0, 30)
BHopToggle.Text = "B-Hop: Off"
BHopToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
BHopToggle.Parent = RageTabContent
BHopToggle.MouseButton1Click:Connect(function()
    bhopEnabled = not bhopEnabled
    BHopToggle.Text = "B-Hop: " .. (bhopEnabled and "On" or "Off")
    BHopToggle.BackgroundColor3 = bhopEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    if bhopToggleButton then bhopToggleButton.Visible = bhopEnabled end
end)

local BHopAirSlider = Instance.new("TextBox")
BHopAirSlider.Size = UDim2.new(1, 0, 0, 20)
BHopAirSlider.Text = "Air Mult: " .. bhopMultiplierAir
BHopAirSlider.Parent = RageTabContent
BHopAirSlider.FocusLost:Connect(function() bhopMultiplierAir = tonumber(BHopAirSlider.Text:match("%d+%.?%d*")) or 2.5 end)

local SilentAimToggle = Instance.new("TextButton")
SilentAimToggle.Size = UDim2.new(1, 0, 0, 30)
SilentAimToggle.Position = UDim2.new(0, 0, 0, 55)
SilentAimToggle.Text = "Silent Aim: Off"
SilentAimToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
SilentAimToggle.Parent = RageTabContent
SilentAimToggle.MouseButton1Click:Connect(function()
    silentAimEnabled = not silentAimEnabled
    SilentAimToggle.Text = "Silent Aim: " .. (silentAimEnabled and "On" or "Off")
    SilentAimToggle.BackgroundColor3 = silentAimEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end)

local AutoFireToggle = Instance.new("TextButton")
AutoFireToggle.Size = UDim2.new(1, 0, 0, 30)
AutoFireToggle.Position = UDim2.new(0, 0, 0, 90)
AutoFireToggle.Text = "AutoFire: Off"
AutoFireToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
AutoFireToggle.Parent = RageTabContent
AutoFireToggle.MouseButton1Click:Connect(function()
    autoFireEnabled = not autoFireEnabled
    AutoFireToggle.Text = "AutoFire: " .. (autoFireEnabled and "On" or "Off")
    AutoFireToggle.BackgroundColor3 = autoFireEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end)

local FakeLagToggle = Instance.new("TextButton")
FakeLagToggle.Size = UDim2.new(1, 0, 0, 30)
FakeLagToggle.Position = UDim2.new(0, 0, 0, 125)
FakeLagToggle.Text = "FakeLag: Off"
FakeLagToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
FakeLagToggle.Parent = RageTabContent
FakeLagToggle.MouseButton1Click:Connect(function()
    fakeLagEnabled = not fakeLagEnabled
    FakeLagToggle.Text = "FakeLag: " .. (fakeLagEnabled and "On" or "Off")
    FakeLagToggle.BackgroundColor3 = fakeLagEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end)

local SpeedToggle = Instance.new("TextButton")
SpeedToggle.Size = UDim2.new(1, 0, 0, 30)
SpeedToggle.Position = UDim2.new(0, 0, 0, 160)
SpeedToggle.Text = "Speed: Off"
SpeedToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
SpeedToggle.Parent = RageTabContent
SpeedToggle.MouseButton1Click:Connect(function()
    speedEnabled = not speedEnabled
    SpeedToggle.Text = "Speed: " .. (speedEnabled and "On" or "Off")
    SpeedToggle.BackgroundColor3 = speedEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end)

local SpeedSlider = Instance.new("TextBox")
SpeedSlider.Size = UDim2.new(1, 0, 0, 20)
SpeedSlider.Position = UDim2.new(0, 0, 0, 195)
SpeedSlider.Text = "Speed Mult: " .. speedMultiplier
SpeedSlider.Parent = RageTabContent
SpeedSlider.FocusLost:Connect(function() speedMultiplier = tonumber(SpeedSlider.Text:match("%d+%.?%d*")) or 2 end)

-- B-Hop Toggle Button on Screen
bhopToggleButton = Instance.new("TextButton")
bhopToggleButton.Size = UDim2.new(0, 40, 0, 40)
bhopToggleButton.Position = UDim2.new(0.5, -20, 0.9, -20)
bhopToggleButton.Text = "B-Hop"
bhopToggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
bhopToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
bhopToggleButton.Visible = false
bhopToggleButton.Parent = ScreenGui
bhopToggleButton.MouseButton1Click:Connect(function()
    bhopEnabled = not bhopEnabled
    bhopToggleButton.BackgroundColor3 = bhopEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    BHopToggle.Text = "B-Hop: " .. (bhopEnabled and "On" or "Off")
    BHopToggle.BackgroundColor3 = bhopEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end)

-- AutoPeek Toggle
local AutoPeekToggle = Instance.new("TextButton")
AutoPeekToggle.Size = UDim2.new(1, 0, 0, 30)
AutoPeekToggle.Position = UDim2.new(0, 0, 0, 220)
AutoPeekToggle.Text = "AutoPeek: Off"
AutoPeekToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
AutoPeekToggle.Parent = RageTabContent
AutoPeekToggle.MouseButton1Click:Connect(function()
    autoPeekEnabled = not autoPeekEnabled
    AutoPeekToggle.Text = "AutoPeek: " .. (autoPeekEnabled and "On" or "Off")
    AutoPeekToggle.BackgroundColor3 = autoPeekEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end)

RageTabButton.MouseButton1Click:Fire()

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -40, 0, 5)
CloseButton.Text = "X"
CloseButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Parent = MainFrame
CloseButton.MouseButton1Click:Connect(function() tweenFrame(false) end)

ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ContentScroll.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 10)
end)

print("RawHack loaded successfully.")

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    RootPart = char:WaitForChild("HumanoidRootPart")
end)
