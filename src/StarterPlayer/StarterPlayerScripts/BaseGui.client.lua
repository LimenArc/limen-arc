--!strict
-- BaseGui: full-screen base management panel (press G to toggle).
-- Shows all base slots, lets players drag creatures from inventory into slots,
-- sell placed creatures, and see live income per tick.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local LuckyBlockData = require(Modules:WaitForChild("LuckyBlockData"))
local Remotes        = require(ReplicatedStorage:WaitForChild("Remotes"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Local state ───────────────────────────────────────────────────────────

local baseState = {
	BaseSlotCount = 4,
	Placements = {} :: { Inventory_BasePlacement },
	LuckyCreatures = {} :: { Inventory_LuckyCreatureEntry },
}

-- Minimal type mirrors (module types aren't importable on client easily).
type Inventory_LuckyCreatureEntry = { Uid: string, CreatureId: string, Rarity: string, CollectedAt: number }
type Inventory_BasePlacement = { SlotIndex: number, Uid: string }

local selectedCreatureUid: string? = nil  -- uid being dragged/selected

-- ── Colour helpers ────────────────────────────────────────────────────────

local function rarityColor(rarity: string): Color3
	local def = LuckyBlockData.Rarities[rarity]
	return def and def.Color or Color3.fromRGB(180, 180, 180)
end

local function rarityGlow(rarity: string): Color3
	local def = LuckyBlockData.Rarities[rarity]
	return def and def.GlowColor or Color3.fromRGB(200, 200, 200)
end

-- ── Screen GUI ────────────────────────────────────────────────────────────

local screen = Instance.new("ScreenGui")
screen.Name = "BaseGui"
screen.ResetOnSpawn = false
screen.DisplayOrder = 12
screen.Enabled = false
screen.Parent = playerGui

-- Background overlay.
local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.55
overlay.BorderSizePixel = 0
overlay.Parent = screen

-- Main panel.
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(860, 580)
panel.BackgroundColor3 = Color3.fromRGB(11, 13, 22)
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Parent = screen
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(240, 200, 80)
panelStroke.Thickness = 1.5
panelStroke.Parent = panel

-- Title bar.
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3 = Color3.fromRGB(20, 22, 38)
titleBar.BorderSizePixel = 0
titleBar.Parent = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 16)

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0.5, 0)
titleFix.Position = UDim2.fromScale(0, 0.5)
titleFix.BackgroundColor3 = Color3.fromRGB(20, 22, 38)
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(0.7, 0, 1, 0)
titleLbl.Position = UDim2.fromOffset(18, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🏠  My Base"
titleLbl.Font = Enum.Font.FredokaOne
titleLbl.TextSize = 22
titleLbl.TextColor3 = Color3.fromRGB(255, 230, 140)
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = titleBar

local closeBtnBase = Instance.new("TextButton")
closeBtnBase.AnchorPoint = Vector2.new(1, 0.5)
closeBtnBase.Position = UDim2.new(1, -12, 0.5, 0)
closeBtnBase.Size = UDim2.fromOffset(36, 36)
closeBtnBase.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtnBase.Text = "✕"
closeBtnBase.Font = Enum.Font.GothamBold
closeBtnBase.TextSize = 18
closeBtnBase.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtnBase.BorderSizePixel = 0
closeBtnBase.Parent = titleBar
Instance.new("UICorner", closeBtnBase).CornerRadius = UDim.new(0, 6)

-- Income summary bar.
local incomeBar = Instance.new("Frame")
incomeBar.Position = UDim2.fromOffset(0, 48)
incomeBar.Size = UDim2.new(1, 0, 0, 32)
incomeBar.BackgroundColor3 = Color3.fromRGB(16, 20, 34)
incomeBar.BorderSizePixel = 0
incomeBar.Parent = panel

local incomeLbl = Instance.new("TextLabel")
incomeLbl.Size = UDim2.fromScale(1, 1)
incomeLbl.BackgroundTransparency = 1
incomeLbl.Font = Enum.Font.GothamBold
incomeLbl.TextSize = 14
incomeLbl.TextColor3 = Color3.fromRGB(140, 220, 140)
incomeLbl.Parent = incomeBar

-- Two-column layout: left = slots, right = inventory.
local leftCol = Instance.new("Frame")
leftCol.Position = UDim2.fromOffset(10, 84)
leftCol.Size = UDim2.new(0.52, -15, 1, -94)
leftCol.BackgroundTransparency = 1
leftCol.Parent = panel

local rightCol = Instance.new("Frame")
rightCol.Position = UDim2.new(0.52, 5, 0, 84)
rightCol.Size = UDim2.new(0.48, -15, 1, -94)
rightCol.BackgroundTransparency = 1
rightCol.Parent = panel

-- Slot grid (left column).
local slotColLabel = Instance.new("TextLabel")
slotColLabel.Size = UDim2.new(1, 0, 0, 22)
slotColLabel.BackgroundTransparency = 1
slotColLabel.Font = Enum.Font.GothamBold
slotColLabel.TextSize = 13
slotColLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
slotColLabel.TextXAlignment = Enum.TextXAlignment.Left
slotColLabel.Text = "Base Slots  (place creatures to earn coins)"
slotColLabel.Parent = leftCol

local slotScrollFrame = Instance.new("ScrollingFrame")
slotScrollFrame.Position = UDim2.fromOffset(0, 26)
slotScrollFrame.Size = UDim2.new(1, 0, 1, -26)
slotScrollFrame.BackgroundTransparency = 1
slotScrollFrame.BorderSizePixel = 0
slotScrollFrame.ScrollBarThickness = 4
slotScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
slotScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
slotScrollFrame.Parent = leftCol

local slotGrid = Instance.new("UIGridLayout")
slotGrid.CellSize = UDim2.fromOffset(102, 115)
slotGrid.CellPadding = UDim2.fromOffset(6, 6)
slotGrid.Parent = slotScrollFrame

-- Inventory (right column).
local invColLabel = Instance.new("TextLabel")
invColLabel.Size = UDim2.new(1, 0, 0, 22)
invColLabel.BackgroundTransparency = 1
invColLabel.Font = Enum.Font.GothamBold
invColLabel.TextSize = 13
invColLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
invColLabel.TextXAlignment = Enum.TextXAlignment.Left
invColLabel.Text = "Creature Inventory  (click to select, then click a slot)"
invColLabel.Parent = rightCol

local invScroll = Instance.new("ScrollingFrame")
invScroll.Position = UDim2.fromOffset(0, 26)
invScroll.Size = UDim2.new(1, 0, 1, -26)
invScroll.BackgroundTransparency = 1
invScroll.BorderSizePixel = 0
invScroll.ScrollBarThickness = 4
invScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
invScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
invScroll.Parent = rightCol

local invGrid = Instance.new("UIGridLayout")
invGrid.CellSize = UDim2.fromOffset(100, 90)
invGrid.CellPadding = UDim2.fromOffset(4, 4)
invGrid.Parent = invScroll

-- ── Card builders ─────────────────────────────────────────────────────────

local slotCards: { Frame } = {}
local invCards: { [string]: Frame } = {}

local function clearCards()
	for _, c in ipairs(slotScrollFrame:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for _, c in ipairs(invScroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	slotCards = {}
	invCards = {}
end

local function placementForSlot(slotIdx: number): Inventory_BasePlacement?
	for _, p in ipairs(baseState.Placements) do
		if p.SlotIndex == slotIdx then return p end
	end
	return nil
end

local function creatureByUid(uid: string): Inventory_LuckyCreatureEntry?
	for _, e in ipairs(baseState.LuckyCreatures) do
		if e.Uid == uid then return e end
	end
	return nil
end

local function computeTotalIncome(): number
	local total = 0
	for _, p in ipairs(baseState.Placements) do
		local entry = creatureByUid(p.Uid)
		if not entry then continue end
		local cd = LuckyBlockData.GetCreature(entry.CreatureId)
		local rd = LuckyBlockData.Rarities[entry.Rarity]
		if cd and rd then
			total += math.floor(rd.BaseIncomePerTick * cd.IncomeBonus)
		end
	end
	return total
end

local function buildSlotCard(slotIdx: number)
	local locked = slotIdx > baseState.BaseSlotCount
	local placement = placementForSlot(slotIdx)
	local entry = placement and creatureByUid(placement.Uid) or nil
	local cd = entry and LuckyBlockData.GetCreature(entry.CreatureId) or nil
	local rd = cd and LuckyBlockData.Rarities[entry.Rarity] or nil

	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(102, 115)
	card.BackgroundColor3 = if locked then Color3.fromRGB(18, 18, 25)
		elseif entry then Color3.fromRGB(22, 24, 38)
		else Color3.fromRGB(20, 22, 35)
	card.BorderSizePixel = 0
	card.Parent = slotScrollFrame
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.2
	stroke.Color = if locked then Color3.fromRGB(40, 40, 55)
		elseif entry and rd then rd.Color
		else Color3.fromRGB(60, 65, 90)
	stroke.Parent = card

	local slotNum = Instance.new("TextLabel")
	slotNum.Size = UDim2.new(1, 0, 0, 18)
	slotNum.BackgroundTransparency = 1
	slotNum.Font = Enum.Font.GothamBold
	slotNum.TextSize = 11
	slotNum.TextColor3 = Color3.fromRGB(80, 80, 100)
	slotNum.Text = ("Slot %d"):format(slotIdx)
	slotNum.Parent = card

	if locked then
		local lockLbl = Instance.new("TextLabel")
		lockLbl.Position = UDim2.fromOffset(0, 28)
		lockLbl.Size = UDim2.new(1, 0, 0, 60)
		lockLbl.BackgroundTransparency = 1
		lockLbl.Font = Enum.Font.GothamBold
		lockLbl.TextSize = 22
		lockLbl.TextColor3 = Color3.fromRGB(55, 55, 75)
		lockLbl.Text = "🔒"
		lockLbl.Parent = card

		local unlockLbl = Instance.new("TextLabel")
		unlockLbl.Position = UDim2.fromOffset(0, 80)
		unlockLbl.Size = UDim2.new(1, 0, 0, 22)
		unlockLbl.BackgroundTransparency = 1
		unlockLbl.Font = Enum.Font.Gotham
		unlockLbl.TextSize = 10
		unlockLbl.TextColor3 = Color3.fromRGB(80, 80, 100)
		unlockLbl.Text = "Expand base [U]"
		unlockLbl.TextWrapped = true
		unlockLbl.Parent = card
	elseif entry and cd and rd then
		-- Filled slot.
		local colorDot = Instance.new("Frame")
		colorDot.AnchorPoint = Vector2.new(0.5, 0)
		colorDot.Position = UDim2.fromOffset(51, 20)
		colorDot.Size = UDim2.fromOffset(36, 36)
		colorDot.BackgroundColor3 = cd.PrimaryColor
		colorDot.BorderSizePixel = 0
		colorDot.Parent = card
		Instance.new("UICorner", colorDot).CornerRadius = UDim.new(1, 0)

		local innerDot = Instance.new("Frame")
		innerDot.AnchorPoint = Vector2.new(0.5, 0.5)
		innerDot.Position = UDim2.fromScale(0.5, 0.5)
		innerDot.Size = UDim2.fromOffset(18, 18)
		innerDot.BackgroundColor3 = cd.SecondaryColor
		innerDot.BorderSizePixel = 0
		innerDot.Parent = colorDot
		Instance.new("UICorner", innerDot).CornerRadius = UDim.new(1, 0)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Position = UDim2.fromOffset(2, 58)
		nameLbl.Size = UDim2.new(1, -4, 0, 28)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextSize = 11
		nameLbl.TextColor3 = rd.GlowColor
		nameLbl.TextWrapped = true
		nameLbl.Text = cd.DisplayName
		nameLbl.Parent = card

		local incLbl = Instance.new("TextLabel")
		incLbl.Position = UDim2.fromOffset(2, 86)
		incLbl.Size = UDim2.new(1, -4, 0, 16)
		incLbl.BackgroundTransparency = 1
		incLbl.Font = Enum.Font.Gotham
		incLbl.TextSize = 11
		incLbl.TextColor3 = Color3.fromRGB(130, 220, 130)
		incLbl.Text = ("⬆%d/tick"):format(math.floor(rd.BaseIncomePerTick * cd.IncomeBonus))
		incLbl.Parent = card

		-- Sell button.
		local sellBtn = Instance.new("TextButton")
		sellBtn.AnchorPoint = Vector2.new(1, 1)
		sellBtn.Position = UDim2.new(1, -2, 1, -2)
		sellBtn.Size = UDim2.fromOffset(28, 16)
		sellBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
		sellBtn.Text = "Sell"
		sellBtn.Font = Enum.Font.Gotham
		sellBtn.TextSize = 10
		sellBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
		sellBtn.BorderSizePixel = 0
		sellBtn.Parent = card
		Instance.new("UICorner", sellBtn).CornerRadius = UDim.new(0, 4)

		sellBtn.MouseButton1Click:Connect(function()
			Remotes.Events.SellBaseCreature:FireServer(slotIdx)
		end)

		-- Click slot = remove creature.
		card.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				Remotes.Events.RemoveBaseCreature:FireServer(slotIdx)
			end
		end)
	else
		-- Empty slot.
		local emptyLbl = Instance.new("TextLabel")
		emptyLbl.Position = UDim2.fromOffset(0, 30)
		emptyLbl.Size = UDim2.new(1, 0, 0, 50)
		emptyLbl.BackgroundTransparency = 1
		emptyLbl.Font = Enum.Font.GothamBold
		emptyLbl.TextSize = 26
		emptyLbl.TextColor3 = Color3.fromRGB(50, 55, 75)
		emptyLbl.Text = "+"
		emptyLbl.Parent = card

		local hintLbl = Instance.new("TextLabel")
		hintLbl.Position = UDim2.fromOffset(0, 78)
		hintLbl.Size = UDim2.new(1, 0, 0, 24)
		hintLbl.BackgroundTransparency = 1
		hintLbl.Font = Enum.Font.Gotham
		hintLbl.TextSize = 10
		hintLbl.TextColor3 = Color3.fromRGB(60, 65, 90)
		hintLbl.Text = "Select creature\nthen click"
		hintLbl.TextWrapped = true
		hintLbl.Parent = card

		-- Click empty slot = place selected creature.
		card.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				if selectedCreatureUid then
					Remotes.Events.PlaceBaseCreature:FireServer(selectedCreatureUid, slotIdx)
					selectedCreatureUid = nil
				end
			end
		end)
	end

	slotCards[slotIdx] = card
end

local function buildInvCard(entry: Inventory_LuckyCreatureEntry)
	local cd = LuckyBlockData.GetCreature(entry.CreatureId)
	local rd = LuckyBlockData.Rarities[entry.Rarity]
	if not cd or not rd then return end

	-- Check if placed.
	local isPlaced = false
	for _, p in ipairs(baseState.Placements) do
		if p.Uid == entry.Uid then isPlaced = true; break end
	end

	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(100, 90)
	card.BackgroundColor3 = if isPlaced then Color3.fromRGB(16, 22, 16) else Color3.fromRGB(22, 24, 38)
	card.BorderSizePixel = 0
	card.Parent = invScroll
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if entry.Uid == selectedCreatureUid then 2.5 else 1.2
	stroke.Color = if entry.Uid == selectedCreatureUid then Color3.fromRGB(255, 230, 100)
		else rd.Color
	stroke.Parent = card

	local colorDot = Instance.new("Frame")
	colorDot.AnchorPoint = Vector2.new(0.5, 0)
	colorDot.Position = UDim2.fromOffset(50, 8)
	colorDot.Size = UDim2.fromOffset(30, 30)
	colorDot.BackgroundColor3 = cd.PrimaryColor
	colorDot.BorderSizePixel = 0
	colorDot.Parent = card
	Instance.new("UICorner", colorDot).CornerRadius = UDim.new(1, 0)

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Position = UDim2.fromOffset(2, 40)
	nameLbl.Size = UDim2.new(1, -4, 0, 26)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 10
	nameLbl.TextColor3 = rd.GlowColor
	nameLbl.TextWrapped = true
	nameLbl.Text = cd.DisplayName
	nameLbl.Parent = card

	local rarLbl = Instance.new("TextLabel")
	rarLbl.Position = UDim2.fromOffset(2, 66)
	rarLbl.Size = UDim2.new(1, -4, 0, 16)
	rarLbl.BackgroundTransparency = 1
	rarLbl.Font = Enum.Font.Gotham
	rarLbl.TextSize = 10
	rarLbl.TextColor3 = rd.Color
	rarLbl.Text = if isPlaced then "★ Placed" else entry.Rarity
	rarLbl.Parent = card

	card.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			selectedCreatureUid = if selectedCreatureUid == entry.Uid then nil else entry.Uid
			refreshUI()
		end
	end)

	invCards[entry.Uid] = card
end

-- ── Full refresh ──────────────────────────────────────────────────────────

function refreshUI()
	clearCards()
	-- Slot cards.
	for i = 1, math.max(baseState.BaseSlotCount, 6) do
		buildSlotCard(i)
	end
	-- Inventory cards.
	for _, entry in ipairs(baseState.LuckyCreatures) do
		buildInvCard(entry)
	end
	-- Income summary.
	local totalIncome = computeTotalIncome()
	incomeLbl.Text = ("Total base income: %d coins / 5 s  •  %d/%d slots filled"):format(
		totalIncome, #baseState.Placements, baseState.BaseSlotCount)
end

-- ── Toggle open/close ─────────────────────────────────────────────────────

local function toggle()
	screen.Enabled = not screen.Enabled
	if screen.Enabled then
		-- Request fresh state.
		task.spawn(function()
			local ok, data = pcall(function() return Remotes.Functions.GetBaseState:InvokeServer() end)
			if ok and data then
				baseState.BaseSlotCount = data.BaseSlotCount or 4
				baseState.Placements = data.Placements or {}
				baseState.LuckyCreatures = data.LuckyCreatures or {}
			end
			-- Also sync from local save cache.
			local save = _G.SaveCache and _G.SaveCache.Save
			if save then
				baseState.BaseSlotCount = save.BaseSlotCount or 4
				baseState.Placements = save.BasePlacements or {}
				baseState.LuckyCreatures = save.LuckyCreatures or {}
			end
			refreshUI()
		end)
	end
end

closeBtnBase.MouseButton1Click:Connect(toggle)

UserInputService.InputBegan:Connect(function(inp, consumed)
	if consumed then return end
	if inp.KeyCode == Enum.KeyCode.G then toggle() end
end)

-- ── Remote updates ────────────────────────────────────────────────────────

Remotes.Events.BaseUpdate.OnClientEvent:Connect(function(data)
	baseState.BaseSlotCount = data.BaseSlotCount or baseState.BaseSlotCount
	baseState.Placements = data.Placements or {}
	baseState.LuckyCreatures = data.LuckyCreatures or {}
	if screen.Enabled then refreshUI() end
end)

-- Also sync from save cache updates.
Remotes.Events.RequestSave.OnClientEvent:Connect(function(save)
	if save then
		baseState.BaseSlotCount = save.BaseSlotCount or 4
		baseState.Placements = save.BasePlacements or {}
		baseState.LuckyCreatures = save.LuckyCreatures or {}
		if screen.Enabled then refreshUI() end
	end
end)

-- Hint label at bottom of screen.
local hintScreen = Instance.new("ScreenGui")
hintScreen.Name = "BaseHintGui"
hintScreen.ResetOnSpawn = false
hintScreen.Parent = playerGui

local hintLbl = Instance.new("TextLabel")
hintLbl.AnchorPoint = Vector2.new(0.5, 1)
hintLbl.Position = UDim2.new(0.5, 0, 1, -6)
hintLbl.Size = UDim2.fromOffset(340, 22)
hintLbl.BackgroundTransparency = 1
hintLbl.Font = Enum.Font.Gotham
hintLbl.TextSize = 12
hintLbl.TextColor3 = Color3.fromRGB(130, 130, 150)
hintLbl.Text = "[G] Base  [U] Upgrades  [M] Mod Menu  [E] Open Block"
hintLbl.Parent = hintScreen

print("[BaseGui] ready")
