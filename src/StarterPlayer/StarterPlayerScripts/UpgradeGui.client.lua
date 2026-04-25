--!strict
-- UpgradeGui: speed upgrade + base slot expansion panel.
-- Press U (or interact with the Speed Station ProximityPrompt) to toggle.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService      = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local LuckyBlockData = require(Modules:WaitForChild("LuckyBlockData"))
local Remotes        = require(ReplicatedStorage:WaitForChild("Remotes"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Screen GUI ────────────────────────────────────────────────────────────

local screen = Instance.new("ScreenGui")
screen.Name = "UpgradeGui"
screen.ResetOnSpawn = false
screen.DisplayOrder = 14
screen.Enabled = false
screen.Parent = playerGui

-- Overlay.
local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.6
overlay.BorderSizePixel = 0
overlay.Parent = screen

-- Panel.
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(680, 580)
panel.BackgroundColor3 = Color3.fromRGB(11, 13, 22)
panel.BorderSizePixel = 0
panel.Parent = screen
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(80, 160, 255)
panelStroke.Thickness = 1.5
panelStroke.Parent = panel

-- Title.
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(16, 20, 36)
titleBar.BorderSizePixel = 0
titleBar.Parent = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 16)

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0.5, 0)
titleFix.Position = UDim2.fromScale(0, 0.5)
titleFix.BackgroundColor3 = Color3.fromRGB(16, 20, 36)
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(0.75, 0, 1, 0)
titleLbl.Position = UDim2.fromOffset(18, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "⚡  Upgrades"
titleLbl.Font = Enum.Font.FredokaOne
titleLbl.TextSize = 22
titleLbl.TextColor3 = Color3.fromRGB(130, 200, 255)
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.Position = UDim2.new(1, -12, 0.5, 0)
closeBtn.Size = UDim2.fromOffset(36, 36)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Coins display.
local coinsBar = Instance.new("Frame")
coinsBar.Position = UDim2.fromOffset(0, 52)
coinsBar.Size = UDim2.new(1, 0, 0, 30)
coinsBar.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
coinsBar.BorderSizePixel = 0
coinsBar.Parent = panel

local coinsLbl = Instance.new("TextLabel")
coinsLbl.Size = UDim2.fromScale(1, 1)
coinsLbl.BackgroundTransparency = 1
coinsLbl.Font = Enum.Font.GothamBold
coinsLbl.TextSize = 14
coinsLbl.TextColor3 = Color3.fromRGB(240, 210, 120)
coinsLbl.Parent = coinsBar

-- ── Two-column layout ─────────────────────────────────────────────────────

local leftHalf = Instance.new("Frame")
leftHalf.Position = UDim2.fromOffset(10, 86)
leftHalf.Size = UDim2.new(0.5, -15, 1, -96)
leftHalf.BackgroundTransparency = 1
leftHalf.Parent = panel

local rightHalf = Instance.new("Frame")
rightHalf.Position = UDim2.new(0.5, 5, 0, 86)
rightHalf.Size = UDim2.new(0.5, -15, 1, -96)
rightHalf.BackgroundTransparency = 1
rightHalf.Parent = panel

-- Section label helper.
local function sectionLabel(parent: Instance, text: string, yOff: number)
	local lbl = Instance.new("TextLabel")
	lbl.Position = UDim2.fromOffset(0, yOff)
	lbl.Size = UDim2.new(1, 0, 0, 22)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 14
	lbl.TextColor3 = Color3.fromRGB(200, 200, 220)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = text
	lbl.Parent = parent
end

-- ── Speed upgrades (left half) ────────────────────────────────────────────

sectionLabel(leftHalf, "⚡ Speed Tiers", 0)

local speedScroll = Instance.new("ScrollingFrame")
speedScroll.Position = UDim2.fromOffset(0, 26)
speedScroll.Size = UDim2.new(1, 0, 1, -26)
speedScroll.BackgroundTransparency = 1
speedScroll.BorderSizePixel = 0
speedScroll.ScrollBarThickness = 4
speedScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
speedScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
speedScroll.Parent = leftHalf

local speedLayout = Instance.new("UIListLayout")
speedLayout.Padding = UDim.new(0, 5)
speedLayout.Parent = speedScroll

local speedBuyBtn: TextButton? = nil

local function buildSpeedTiers(currentLevel: number, coins: number)
	for _, child in ipairs(speedScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	speedBuyBtn = nil

	for _, tier in ipairs(LuckyBlockData.SpeedTiers) do
		local isCurrent = tier.Level == currentLevel
		local isNext    = tier.Level == currentLevel + 1
		local isPast    = tier.Level <= currentLevel
		local canAfford = coins >= tier.Cost

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -4, 0, 54)
		row.BackgroundColor3 = if isCurrent then Color3.fromRGB(24, 36, 50)
			elseif isPast then Color3.fromRGB(16, 22, 16)
			else Color3.fromRGB(18, 20, 32)
		row.BorderSizePixel = 0
		row.Parent = speedScroll
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

		local rowStroke = Instance.new("UIStroke")
		rowStroke.Thickness = if isCurrent then 2 else 1
		rowStroke.Color = if isCurrent then tier.Color
			elseif isPast then Color3.fromRGB(50, 100, 50)
			else Color3.fromRGB(45, 48, 68)
		rowStroke.Parent = row

		-- Level number.
		local lvlLbl = Instance.new("TextLabel")
		lvlLbl.Position = UDim2.fromOffset(10, 0)
		lvlLbl.Size = UDim2.fromOffset(28, 54)
		lvlLbl.BackgroundTransparency = 1
		lvlLbl.Font = Enum.Font.FredokaOne
		lvlLbl.TextSize = 22
		lvlLbl.TextColor3 = if isPast then Color3.fromRGB(80, 180, 80) else tier.Color
		lvlLbl.Text = tostring(tier.Level)
		lvlLbl.Parent = row

		-- Name + speed.
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Position = UDim2.fromOffset(42, 6)
		nameLbl.Size = UDim2.fromOffset(160, 22)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextSize = 14
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextColor3 = if isPast then Color3.fromRGB(100, 200, 100)
			elseif isCurrent then Color3.fromRGB(255, 255, 255)
			else Color3.fromRGB(180, 180, 200)
		nameLbl.Text = ("%s  (WS %d)"):format(tier.Label, tier.WalkSpeed)
		nameLbl.Parent = row

		-- Zone unlock annotation.
		local unlocksZone = ""
		for _, zone in ipairs(LuckyBlockData.Zones) do
			if zone.MinSpeed == tier.WalkSpeed then
				unlocksZone = "→ Unlocks " .. zone.Name
				break
			end
		end
		local subLbl = Instance.new("TextLabel")
		subLbl.Position = UDim2.fromOffset(42, 28)
		subLbl.Size = UDim2.fromOffset(180, 18)
		subLbl.BackgroundTransparency = 1
		subLbl.Font = Enum.Font.Gotham
		subLbl.TextSize = 11
		subLbl.TextXAlignment = Enum.TextXAlignment.Left
		subLbl.TextColor3 = Color3.fromRGB(120, 140, 200)
		subLbl.Text = if unlocksZone ~= "" then unlocksZone else ""
		subLbl.Parent = row

		-- Cost / status badge.
		if isPast then
			local badge = Instance.new("TextLabel")
			badge.AnchorPoint = Vector2.new(1, 0.5)
			badge.Position = UDim2.new(1, -8, 0.5, 0)
			badge.Size = UDim2.fromOffset(60, 28)
			badge.BackgroundColor3 = Color3.fromRGB(30, 70, 30)
			badge.BorderSizePixel = 0
			badge.Font = Enum.Font.GothamBold
			badge.TextSize = 12
			badge.TextColor3 = Color3.fromRGB(100, 220, 100)
			badge.Text = "✓ Done"
			badge.Parent = row
			Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 6)
		elseif isNext then
			local btn = Instance.new("TextButton")
			btn.AnchorPoint = Vector2.new(1, 0.5)
			btn.Position = UDim2.new(1, -8, 0.5, 0)
			btn.Size = UDim2.fromOffset(90, 32)
			btn.BackgroundColor3 = if canAfford then Color3.fromRGB(30, 80, 180)
				else Color3.fromRGB(60, 40, 40)
			btn.Text = if tier.Cost == 0 then "Free!" else ("%d 🪙"):format(tier.Cost)
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 13
			btn.TextColor3 = if canAfford then Color3.fromRGB(200, 230, 255)
				else Color3.fromRGB(180, 100, 100)
			btn.BorderSizePixel = 0
			btn.Parent = row
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
			speedBuyBtn = btn

			btn.MouseButton1Click:Connect(function()
				Remotes.Events.BuySpeedUpgrade:FireServer()
			end)
		else
			local costLbl = Instance.new("TextLabel")
			costLbl.AnchorPoint = Vector2.new(1, 0.5)
			costLbl.Position = UDim2.new(1, -8, 0.5, 0)
			costLbl.Size = UDim2.fromOffset(80, 28)
			costLbl.BackgroundTransparency = 1
			costLbl.Font = Enum.Font.Gotham
			costLbl.TextSize = 12
			costLbl.TextColor3 = Color3.fromRGB(100, 100, 130)
			costLbl.Text = ("%d 🪙"):format(tier.Cost)
			costLbl.Parent = row
		end
	end
end

-- ── Base slot tiers (right half) ──────────────────────────────────────────

sectionLabel(rightHalf, "🏠 Base Slot Tiers", 0)

local slotScroll = Instance.new("ScrollingFrame")
slotScroll.Position = UDim2.fromOffset(0, 26)
slotScroll.Size = UDim2.new(1, 0, 1, -26)
slotScroll.BackgroundTransparency = 1
slotScroll.BorderSizePixel = 0
slotScroll.ScrollBarThickness = 4
slotScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
slotScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
slotScroll.Parent = rightHalf

local slotLayout2 = Instance.new("UIListLayout")
slotLayout2.Padding = UDim.new(0, 5)
slotLayout2.Parent = slotScroll

local function buildSlotTiers(currentSlots: number, coins: number)
	for _, child in ipairs(slotScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	for i, tier in ipairs(LuckyBlockData.BaseSlotTiers) do
		local isPast = tier.Slots <= currentSlots
		local isNext = (not isPast) and (i == 1 or LuckyBlockData.BaseSlotTiers[i-1].Slots <= currentSlots)
		local canAfford = coins >= tier.Cost

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -4, 0, 54)
		row.BackgroundColor3 = if isPast then Color3.fromRGB(16, 22, 16)
			elseif isNext then Color3.fromRGB(22, 24, 36)
			else Color3.fromRGB(16, 18, 28)
		row.BorderSizePixel = 0
		row.Parent = slotScroll
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

		local rowStroke = Instance.new("UIStroke")
		rowStroke.Thickness = 1
		rowStroke.Color = if isPast then Color3.fromRGB(50, 90, 50)
			elseif isNext then Color3.fromRGB(240, 200, 80)
			else Color3.fromRGB(40, 44, 64)
		rowStroke.Parent = row

		local slotsLbl = Instance.new("TextLabel")
		slotsLbl.Position = UDim2.fromOffset(10, 0)
		slotsLbl.Size = UDim2.fromOffset(100, 54)
		slotsLbl.BackgroundTransparency = 1
		slotsLbl.Font = Enum.Font.GothamBold
		slotsLbl.TextSize = 16
		slotsLbl.TextXAlignment = Enum.TextXAlignment.Left
		slotsLbl.TextColor3 = if isPast then Color3.fromRGB(100, 220, 100)
			elseif isNext then Color3.fromRGB(255, 230, 140)
			else Color3.fromRGB(140, 140, 160)
		slotsLbl.Text = ("%d Slots"):format(tier.Slots)
		slotsLbl.Parent = row

		if isPast then
			local badge = Instance.new("TextLabel")
			badge.AnchorPoint = Vector2.new(1, 0.5)
			badge.Position = UDim2.new(1, -8, 0.5, 0)
			badge.Size = UDim2.fromOffset(60, 28)
			badge.BackgroundColor3 = Color3.fromRGB(30, 70, 30)
			badge.BorderSizePixel = 0
			badge.Font = Enum.Font.GothamBold
			badge.TextSize = 12
			badge.TextColor3 = Color3.fromRGB(100, 220, 100)
			badge.Text = "✓ Done"
			badge.Parent = row
			Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 6)
		elseif isNext then
			local btn = Instance.new("TextButton")
			btn.AnchorPoint = Vector2.new(1, 0.5)
			btn.Position = UDim2.new(1, -8, 0.5, 0)
			btn.Size = UDim2.fromOffset(90, 32)
			btn.BackgroundColor3 = if canAfford then Color3.fromRGB(80, 60, 20)
				else Color3.fromRGB(50, 40, 30)
			btn.Text = if tier.Cost == 0 then "Free!" else ("%d 🪙"):format(tier.Cost)
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 13
			btn.TextColor3 = if canAfford then Color3.fromRGB(255, 225, 140)
				else Color3.fromRGB(150, 120, 80)
			btn.BorderSizePixel = 0
			btn.Parent = row
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

			btn.MouseButton1Click:Connect(function()
				Remotes.Events.BuyBaseSlots:FireServer()
			end)
		else
			local costLbl = Instance.new("TextLabel")
			costLbl.AnchorPoint = Vector2.new(1, 0.5)
			costLbl.Position = UDim2.new(1, -8, 0.5, 0)
			costLbl.Size = UDim2.fromOffset(80, 28)
			costLbl.BackgroundTransparency = 1
			costLbl.Font = Enum.Font.Gotham
			costLbl.TextSize = 12
			costLbl.TextColor3 = Color3.fromRGB(90, 90, 120)
			costLbl.Text = ("%d 🪙"):format(tier.Cost)
			costLbl.Parent = row
		end
	end
end

-- ── Refresh from save ─────────────────────────────────────────────────────

local function refreshFromSave()
	local save = _G.SaveCache and _G.SaveCache.Save
	local coins = save and save.Coins or 0
	local speedLevel = save and save.SpeedLevel or 0
	local baseSlots = save and save.BaseSlotCount or 4
	coinsLbl.Text = ("Your coins: %d"):format(coins)
	buildSpeedTiers(speedLevel, coins)
	buildSlotTiers(baseSlots, coins)
end

-- ── Toggle ────────────────────────────────────────────────────────────────

local function toggle()
	screen.Enabled = not screen.Enabled
	if screen.Enabled then refreshFromSave() end
end

closeBtn.MouseButton1Click:Connect(toggle)

UserInputService.InputBegan:Connect(function(inp, consumed)
	if consumed then return end
	if inp.KeyCode == Enum.KeyCode.U then toggle() end
end)

-- Open when speed station ProximityPrompt is triggered.
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, trigPlayer: Player)
	if trigPlayer == player and prompt.Name == "UpgradeStationPrompt" then
		screen.Enabled = true
		refreshFromSave()
	end
end)

-- Live coin refresh while panel is open.
Remotes.Events.RequestSave.OnClientEvent:Connect(function(save)
	if screen.Enabled then refreshFromSave() end
end)

print("[UpgradeGui] ready")
