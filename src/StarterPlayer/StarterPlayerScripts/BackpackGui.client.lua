--!strict
-- Backpack / party UI. Press B to toggle. Shows items and caught monsters;
-- clicking a monster sets it active, clicking an item equips it (weapons)
-- or uses it (consumables).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))
local MonsterData = require(Modules:WaitForChild("MonsterData"))
local UiKit = require(Modules:WaitForChild("UiKit"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "BackpackGui"
screen.ResetOnSpawn = false
screen.Enabled = false
screen.Parent = playerGui

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(640, 480)
frame.BackgroundColor3 = Color3.fromRGB(18, 22, 36)
frame.BorderSizePixel = 0
frame.Parent = screen

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

UiKit.AddCloseButton(frame)

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundTransparency = 1
header.Text = "Backpack"
header.Font = Enum.Font.GothamBold
header.TextSize = 22
header.TextColor3 = Color3.fromRGB(240, 230, 200)
header.Parent = frame

local coins = Instance.new("TextLabel")
coins.Position = UDim2.new(1, -160, 0, 8)
coins.Size = UDim2.fromOffset(140, 28)
coins.BackgroundTransparency = 1
coins.TextXAlignment = Enum.TextXAlignment.Right
coins.Font = Enum.Font.Gotham
coins.TextSize = 16
coins.TextColor3 = Color3.fromRGB(240, 210, 120)
coins.Text = "0 coins"
coins.Parent = frame

local function makeColumn(title: string, xScale: number)
	local col = Instance.new("Frame")
	col.Position = UDim2.new(xScale, 12, 0, 48)
	col.Size = UDim2.new(0.5, -18, 1, -60)
	col.BackgroundColor3 = Color3.fromRGB(28, 32, 48)
	col.BorderSizePixel = 0
	col.Parent = frame
	Instance.new("UICorner", col).CornerRadius = UDim.new(0, 8)

	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.new(1, 0, 0, 28)
	heading.BackgroundTransparency = 1
	heading.Text = title
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = 16
	heading.TextColor3 = Color3.fromRGB(230, 210, 170)
	heading.Parent = col

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -12, 1, -36)
	scroll.Position = UDim2.new(0, 6, 0, 30)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.Parent = col

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scroll

	return scroll
end

local itemsList = makeColumn("Items", 0)
local monstersList = makeColumn("Monsters", 0.5)

local function clearList(list: Instance)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
	end
end

local function rowButton(parent: Instance, label: string, sub: string?, color: Color3?)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.BackgroundColor3 = color or Color3.fromRGB(40, 46, 66)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 14
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.TextColor3 = Color3.fromRGB(240, 240, 240)
	btn.Text = "   " .. label .. (if sub then "   |   " .. sub else "")
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	return btn
end

local function render(save)
	if not save then return end
	coins.Text = ("%d coins"):format(save.Coins or 0)
	clearList(itemsList)
	clearList(monstersList)

	for _, stack in ipairs(save.Items or {}) do
		local def = ItemData.Get(stack.Id)
		if def then
			local isEquipped = save.EquippedWeaponId == stack.Id
			local btn = rowButton(itemsList,
				("%s × %d"):format(def.DisplayName, stack.Count),
				if isEquipped then "equipped" else def.Kind)
			btn.MouseButton1Click:Connect(function()
				Remotes.Events.UseItem:FireServer(stack.Id, save.ActiveMonsterUuid)
			end)
		end
	end

	for _, mon in ipairs(save.Monsters or {}) do
		local def = MonsterData.Get(mon.SpeciesId)
		if def then
			local isActive = save.ActiveMonsterUuid == mon.Uuid
			local color = if isActive then Color3.fromRGB(80, 70, 30) else Color3.fromRGB(40, 46, 66)
			local btn = rowButton(monstersList,
				("%s (Lv %d)"):format(mon.Nickname or def.DisplayName, mon.Level),
				("%d/%d HP"):format(mon.CurrentHP, mon.MaxHP),
				color)
			btn.MouseButton1Click:Connect(function()
				Remotes.Events.SetActiveMonster:FireServer(mon.Uuid)
			end)
		end
	end
end

if _G.SaveCache then
	render(_G.SaveCache.Save)
	_G.SaveCache.Updated.Event:Connect(render)
else
	task.spawn(function()
		while not _G.SaveCache do task.wait(0.1) end
		render(_G.SaveCache.Save)
		_G.SaveCache.Updated.Event:Connect(render)
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.B then
		screen.Enabled = not screen.Enabled
	end
end)
