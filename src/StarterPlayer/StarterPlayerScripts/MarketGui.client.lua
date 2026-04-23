--!strict
-- Market UI: shows near the market plaza. Tabs for Buy / Sell. Press E when
-- close to the market marker to open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))
local MonsterData = require(Modules:WaitForChild("MonsterData"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local catalog
task.spawn(function()
	local ok, data = pcall(function() return Remotes.Functions.GetMarketCatalog:InvokeServer() end)
	if ok then catalog = data end
end)

local screen = Instance.new("ScreenGui")
screen.Name = "MarketGui"
screen.ResetOnSpawn = false
screen.Enabled = false
screen.Parent = playerGui

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(720, 480)
frame.BackgroundColor3 = Color3.fromRGB(22, 20, 30)
frame.BorderSizePixel = 0
frame.Parent = screen
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "Market"
title.Font = Enum.Font.FredokaOne
title.TextSize = 26
title.TextColor3 = Color3.fromRGB(240, 220, 160)
title.Parent = frame

local coinsLabel = Instance.new("TextLabel")
coinsLabel.Position = UDim2.new(1, -180, 0, 10)
coinsLabel.Size = UDim2.fromOffset(160, 28)
coinsLabel.BackgroundTransparency = 1
coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
coinsLabel.Font = Enum.Font.Gotham
coinsLabel.TextSize = 16
coinsLabel.TextColor3 = Color3.fromRGB(240, 210, 120)
coinsLabel.Text = "0 coins"
coinsLabel.Parent = frame

-- Tabs.
local currentTab = "Buy"
local buyTab = Instance.new("TextButton")
buyTab.Position = UDim2.new(0, 16, 0, 48)
buyTab.Size = UDim2.fromOffset(100, 30)
buyTab.Text = "Buy"
buyTab.BackgroundColor3 = Color3.fromRGB(70, 60, 110)
buyTab.TextColor3 = Color3.fromRGB(240, 240, 240)
buyTab.Font = Enum.Font.GothamBold
buyTab.TextSize = 14
buyTab.BorderSizePixel = 0
buyTab.Parent = frame
Instance.new("UICorner", buyTab).CornerRadius = UDim.new(0, 6)

local sellTab = Instance.new("TextButton")
sellTab.Position = UDim2.new(0, 124, 0, 48)
sellTab.Size = UDim2.fromOffset(100, 30)
sellTab.Text = "Sell"
sellTab.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
sellTab.TextColor3 = Color3.fromRGB(240, 240, 240)
sellTab.Font = Enum.Font.GothamBold
sellTab.TextSize = 14
sellTab.BorderSizePixel = 0
sellTab.Parent = frame
Instance.new("UICorner", sellTab).CornerRadius = UDim.new(0, 6)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.new(0, 16, 0, 88)
list.Size = UDim2.new(1, -32, 1, -104)
list.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
list.BorderSizePixel = 0
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 4
list.Parent = frame
Instance.new("UICorner", list).CornerRadius = UDim.new(0, 8)

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = list
Instance.new("UIPadding", list).PaddingTop = UDim.new(0, 8)

local function clearList()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
end

local function rowForBuy(entry)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -16, 0, 52)
	row.Position = UDim2.new(0, 8, 0, 0)
	row.BackgroundColor3 = Color3.fromRGB(32, 30, 44)
	row.BorderSizePixel = 0
	row.Parent = list
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromOffset(10, 6)
	name.Size = UDim2.new(0.5, 0, 0, 20)
	name.BackgroundTransparency = 1
	name.Text = entry.DisplayName .. "  (" .. entry.Kind .. ")"
	name.TextColor3 = Color3.fromRGB(240, 240, 240)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.Parent = row

	local desc = Instance.new("TextLabel")
	desc.Position = UDim2.fromOffset(10, 26)
	desc.Size = UDim2.new(0.6, 0, 0, 18)
	desc.BackgroundTransparency = 1
	desc.Text = entry.Description
	desc.TextColor3 = Color3.fromRGB(170, 170, 190)
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 12
	desc.Parent = row

	local price = Instance.new("TextLabel")
	price.Position = UDim2.new(1, -200, 0, 16)
	price.Size = UDim2.fromOffset(100, 20)
	price.BackgroundTransparency = 1
	price.Text = tostring(entry.BuyPrice) .. " c"
	price.TextColor3 = Color3.fromRGB(240, 210, 120)
	price.Font = Enum.Font.GothamBold
	price.TextSize = 14
	price.Parent = row

	local btn = Instance.new("TextButton")
	btn.Position = UDim2.new(1, -90, 0, 10)
	btn.Size = UDim2.fromOffset(80, 32)
	btn.Text = "Buy"
	btn.BackgroundColor3 = Color3.fromRGB(70, 130, 80)
	btn.TextColor3 = Color3.fromRGB(240, 240, 240)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.BorderSizePixel = 0
	btn.Parent = row
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	btn.MouseButton1Click:Connect(function()
		Remotes.Events.MarketBuy:FireServer(entry.Id, 1)
	end)
end

local function rowForSellItem(stack)
	local def = ItemData.Get(stack.Id)
	if not def then return end
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -16, 0, 44)
	row.BackgroundColor3 = Color3.fromRGB(32, 30, 44)
	row.BorderSizePixel = 0
	row.Parent = list
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromOffset(10, 4)
	name.Size = UDim2.new(0.5, 0, 1, 0)
	name.BackgroundTransparency = 1
	name.Text = ("%s × %d"):format(def.DisplayName, stack.Count)
	name.TextColor3 = Color3.fromRGB(240, 240, 240)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.Gotham
	name.TextSize = 14
	name.Parent = row

	local price = Instance.new("TextLabel")
	price.Position = UDim2.new(1, -200, 0, 0)
	price.Size = UDim2.fromOffset(100, 44)
	price.BackgroundTransparency = 1
	price.Text = tostring(def.SellPrice) .. " c ea"
	price.TextColor3 = Color3.fromRGB(240, 210, 120)
	price.Font = Enum.Font.Gotham
	price.TextSize = 14
	price.Parent = row

	local btn = Instance.new("TextButton")
	btn.Position = UDim2.new(1, -90, 0, 6)
	btn.Size = UDim2.fromOffset(80, 32)
	btn.Text = "Sell 1"
	btn.BackgroundColor3 = Color3.fromRGB(130, 90, 70)
	btn.TextColor3 = Color3.fromRGB(240, 240, 240)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.BorderSizePixel = 0
	btn.Parent = row
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	btn.MouseButton1Click:Connect(function()
		Remotes.Events.MarketSell:FireServer("item", stack.Id, 1)
	end)
end

local function rowForSellMonster(mon)
	local def = MonsterData.Get(mon.SpeciesId)
	if not def then return end
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -16, 0, 44)
	row.BackgroundColor3 = Color3.fromRGB(40, 30, 48)
	row.BorderSizePixel = 0
	row.Parent = list
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromOffset(10, 4)
	name.Size = UDim2.new(0.7, 0, 1, 0)
	name.BackgroundTransparency = 1
	name.Text = ("%s  Lv %d  (%s)"):format(def.DisplayName, mon.Level, def.Rarity)
	name.TextColor3 = Color3.fromRGB(240, 240, 240)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.Gotham
	name.TextSize = 14
	name.Parent = row

	local btn = Instance.new("TextButton")
	btn.Position = UDim2.new(1, -90, 0, 6)
	btn.Size = UDim2.fromOffset(80, 32)
	btn.Text = "Sell"
	btn.BackgroundColor3 = Color3.fromRGB(150, 70, 70)
	btn.TextColor3 = Color3.fromRGB(240, 240, 240)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.BorderSizePixel = 0
	btn.Parent = row
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	btn.MouseButton1Click:Connect(function()
		Remotes.Events.MarketSell:FireServer("monster", mon.Uuid, 1)
	end)
end

local function renderBuy()
	clearList()
	if not catalog then return end
	for _, entry in ipairs(catalog) do
		rowForBuy(entry)
	end
end

local function renderSell()
	clearList()
	local save = _G.SaveCache and _G.SaveCache.Save
	if not save then return end
	for _, stack in ipairs(save.Items) do rowForSellItem(stack) end
	for _, mon in ipairs(save.Monsters) do rowForSellMonster(mon) end
end

local function setTab(name: string)
	currentTab = name
	buyTab.BackgroundColor3 = if name == "Buy" then Color3.fromRGB(70, 60, 110) else Color3.fromRGB(40, 40, 60)
	sellTab.BackgroundColor3 = if name == "Sell" then Color3.fromRGB(70, 60, 110) else Color3.fromRGB(40, 40, 60)
	if name == "Buy" then renderBuy() else renderSell() end
end
buyTab.MouseButton1Click:Connect(function() setTab("Buy") end)
sellTab.MouseButton1Click:Connect(function() setTab("Sell") end)

-- Keep data fresh.
if _G.SaveCache then
	_G.SaveCache.Updated.Event:Connect(function(save)
		coinsLabel.Text = ("%d coins"):format(save.Coins or 0)
		if screen.Enabled then setTab(currentTab) end
	end)
end

-- Proximity detector for market marker.
local function marketMarker(): BasePart?
	local world = Workspace:FindFirstChild("World")
	if not world then return nil end
	local market = world:FindFirstChild("Market")
	if not market then return nil end
	return market:FindFirstChild("MarketMarker") :: BasePart?
end

local inRange = false
local hintGui = Instance.new("ScreenGui")
hintGui.Name = "MarketHint"
hintGui.ResetOnSpawn = false
hintGui.Parent = playerGui
local hintLabel = Instance.new("TextLabel")
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -80)
hintLabel.Size = UDim2.fromOffset(280, 32)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 24, 40)
hintLabel.BackgroundTransparency = 0.2
hintLabel.BorderSizePixel = 0
hintLabel.Text = "[E] Market"
hintLabel.TextColor3 = Color3.fromRGB(240, 220, 160)
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextSize = 14
hintLabel.Visible = false
hintLabel.Parent = hintGui
Instance.new("UICorner", hintLabel).CornerRadius = UDim.new(0, 6)

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local marker = marketMarker()
	if root and marker then
		inRange = (root.Position - marker.Position).Magnitude < 45
		hintLabel.Visible = inRange and not screen.Enabled
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E and inRange then
		screen.Enabled = not screen.Enabled
		if screen.Enabled then setTab(currentTab) end
	end
end)
