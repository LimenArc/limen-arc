--!strict
-- Toast-style notifications driven by server `Notify` events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "NotificationsGui"
screen.ResetOnSpawn = false
screen.Parent = playerGui

local stack = Instance.new("Frame")
stack.AnchorPoint = Vector2.new(1, 0)
stack.Position = UDim2.new(1, -24, 0, 24)
stack.Size = UDim2.fromOffset(320, 400)
stack.BackgroundTransparency = 1
stack.Parent = screen

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
layout.Parent = stack

Remotes.Events.Notify.OnClientEvent:Connect(function(text)
	local item = Instance.new("Frame")
	item.Size = UDim2.new(1, 0, 0, 42)
	item.BackgroundColor3 = Color3.fromRGB(20, 24, 40)
	item.BackgroundTransparency = 0.15
	item.BorderSizePixel = 0
	item.Parent = stack

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = item

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "  " .. tostring(text)
	label.TextColor3 = Color3.fromRGB(240, 230, 200)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.Gotham
	label.TextSize = 15
	label.Parent = item

	task.delay(3.5, function()
		local tween = TweenService:Create(item, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		local labelTween = TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 })
		tween:Play(); labelTween:Play()
		tween.Completed:Wait()
		item:Destroy()
	end)
end)
