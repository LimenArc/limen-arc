--!strict
-- Player-to-player trade UI.
--  · T on a nearby player → send trade request
--  · Incoming request → accept/decline prompt
--  · Active session → two-pane window; click items/monsters to add/remove
--    from your side; edit a coin amount; Lock ➜ Confirm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))
local MonsterData = require(Modules:WaitForChild("MonsterData"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Local edit buffer for the current session — mirrors my offer until we push.
local myOffer = { Items = {} :: { [string]: number }, Monsters = {} :: { [string]: true }, Coins = 0 }

local screen = Instance.new("ScreenGui")
screen.Name = "TradeGui"
screen.ResetOnSpawn = false
screen.Enabled = false
screen.Parent = playerGui

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(780, 520)
frame.BackgroundColor3 = Color3.fromRGB(20, 22, 36)
frame.BorderSizePixel = 0
frame.Parent = screen
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "Trade"
title.Font = Enum.Font.FredokaOne
title.TextSize = 24
title.TextColor3 = Color3.fromRGB(240, 220, 160)
title.Parent = frame

local function pane(xScale: number, heading: string): (Frame, ScrollingFrame, TextLabel, TextLabel)
	local pane = Instance.new("Frame")
	pane.Position = UDim2.new(xScale, 12, 0, 48)
	pane.Size = UDim2.new(0.5, -18, 1, -120)
	pane.BackgroundColor3 = Color3.fromRGB(28, 30, 48)
	pane.BorderSizePixel = 0
	pane.Parent = frame
	Instance.new("UICorner", pane).CornerRadius = UDim.new(0, 8)

	local h = Instance.new("TextLabel")
	h.Size = UDim2.new(1, 0, 0, 26)
	h.BackgroundTransparency = 1
	h.Text = heading
	h.Font = Enum.Font.GothamBold
	h.TextSize = 15
	h.TextColor3 = Color3.fromRGB(240, 220, 160)
	h.Parent = pane

	local lockDot = Instance.new("TextLabel")
	lockDot.Size = UDim2.fromOffset(60, 20)
	lockDot.Position = UDim2.new(1, -70, 0, 4)
	lockDot.BackgroundTransparency = 1
	lockDot.Text = "unlocked"
	lockDot.Font = Enum.Font.Gotham
	lockDot.TextSize = 12
	lockDot.TextColor3 = Color3.fromRGB(180, 180, 200)
	lockDot.Parent = pane

	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.new(0, 8, 0, 30)
	scroll.Size = UDim2.new(1, -16, 1, -38)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.Parent = pane

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scroll

	return pane, scroll, h, lockDot
end

local _, mineScroll, mineHeading, mineLock = pane(0, "Your offer")
local _, theirScroll, theirHeading, theirLock = pane(0.5, "Their offer")

-- Coin editor.
local coinsRow = Instance.new("Frame")
coinsRow.Position = UDim2.new(0, 14, 1, -68)
coinsRow.Size = UDim2.new(0.5, -20, 0, 30)
coinsRow.BackgroundColor3 = Color3.fromRGB(30, 34, 52)
coinsRow.BorderSizePixel = 0
coinsRow.Parent = frame
Instance.new("UICorner", coinsRow).CornerRadius = UDim.new(0, 6)

local coinsLabel = Instance.new("TextLabel")
coinsLabel.Size = UDim2.fromOffset(80, 30)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text = "  My coins:"
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.Font = Enum.Font.Gotham
coinsLabel.TextSize = 13
coinsLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
coinsLabel.Parent = coinsRow

local coinsBox = Instance.new("TextBox")
coinsBox.Position = UDim2.new(0, 90, 0, 4)
coinsBox.Size = UDim2.fromOffset(100, 22)
coinsBox.Text = "0"
coinsBox.PlaceholderText = "0"
coinsBox.BackgroundColor3 = Color3.fromRGB(14, 16, 26)
coinsBox.BorderSizePixel = 0
coinsBox.TextColor3 = Color3.fromRGB(240, 220, 140)
coinsBox.Font = Enum.Font.Gotham
coinsBox.TextSize = 13
coinsBox.Parent = coinsRow
Instance.new("UICorner", coinsBox).CornerRadius = UDim.new(0, 4)

-- Bottom buttons.
local function button(text: string, color: Color3, xOffset: number): TextButton
	local btn = Instance.new("TextButton")
	btn.Position = UDim2.new(1, xOffset, 1, -48)
	btn.Size = UDim2.fromOffset(140, 36)
	btn.AnchorPoint = Vector2.new(1, 0)
	btn.Text = text
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.fromRGB(30, 30, 30)
	btn.Parent = frame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	return btn
end

local lockBtn = button("Lock",    Color3.fromRGB(210, 180, 90), -170)
local confirmBtn = button("Confirm", Color3.fromRGB(90, 170, 110), -16)
local cancelBtn = button("Cancel",  Color3.fromRGB(180, 80, 80), -322)

-- Local state mirrors of the last server update.
local currentSnapshot

local function rowFactory(parent: Instance, labelText: string, color: Color3): TextButton
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -4, 0, 30)
	row.BackgroundColor3 = color
	row.BorderSizePixel = 0
	row.AutoButtonColor = true
	row.Text = "   " .. labelText
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Font = Enum.Font.Gotham
	row.TextSize = 13
	row.TextColor3 = Color3.fromRGB(240, 240, 240)
	row.Parent = parent
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
	return row
end

local function clear(list: Instance)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") and not c:IsA("UIListLayout") then c:Destroy() end
	end
end

local function pushOffer()
	local items = {}
	for id, count in pairs(myOffer.Items) do
		table.insert(items, { Id = id, Count = count })
	end
	local monsters = {}
	for uuid in pairs(myOffer.Monsters) do table.insert(monsters, uuid) end
	Remotes.Events.TradeOffer:FireServer({
		Items = items, Monsters = monsters, Coins = tonumber(coinsBox.Text) or 0,
	})
end

local function renderMyList()
	clear(mineScroll)
	-- Header: editable controls to add items from your inventory.
	local save = _G.SaveCache and _G.SaveCache.Save
	if not save then return end

	-- Currently-offered items.
	for id, count in pairs(myOffer.Items) do
		local def = ItemData.Get(id)
		if def then
			local row = rowFactory(mineScroll, ("▲ %s × %d  (click to remove)"):format(def.DisplayName, count),
				Color3.fromRGB(60, 80, 60))
			row.MouseButton1Click:Connect(function()
				myOffer.Items[id] = nil
				renderMyList(); pushOffer()
			end)
		end
	end
	for uuid in pairs(myOffer.Monsters) do
		local mon = nil
		for _, m in ipairs(save.Monsters) do
			if m.Uuid == uuid then mon = m; break end
		end
		local def = mon and MonsterData.Get(mon.SpeciesId)
		if def and mon then
			local row = rowFactory(mineScroll, ("▲ %s  Lv %d  (click to remove)"):format(def.DisplayName, mon.Level),
				Color3.fromRGB(60, 60, 90))
			row.MouseButton1Click:Connect(function()
				myOffer.Monsters[uuid] = nil
				renderMyList(); pushOffer()
			end)
		end
	end

	-- Separator.
	local sep = Instance.new("Frame")
	sep.Size = UDim2.new(1, -4, 0, 1)
	sep.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
	sep.BorderSizePixel = 0
	sep.Parent = mineScroll

	-- Remaining inventory (click to add one).
	for _, stack in ipairs(save.Items) do
		local def = ItemData.Get(stack.Id)
		local offered = myOffer.Items[stack.Id] or 0
		local avail = stack.Count - offered
		if def and avail > 0 then
			local row = rowFactory(mineScroll, ("add %s (%d)"):format(def.DisplayName, avail),
				Color3.fromRGB(40, 46, 66))
			row.MouseButton1Click:Connect(function()
				myOffer.Items[stack.Id] = (myOffer.Items[stack.Id] or 0) + 1
				renderMyList(); pushOffer()
			end)
		end
	end
	for _, mon in ipairs(save.Monsters) do
		if not myOffer.Monsters[mon.Uuid] then
			local def = MonsterData.Get(mon.SpeciesId)
			if def then
				local row = rowFactory(mineScroll, ("add %s  Lv %d"):format(def.DisplayName, mon.Level),
					Color3.fromRGB(48, 44, 70))
				row.MouseButton1Click:Connect(function()
					myOffer.Monsters[mon.Uuid] = true
					renderMyList(); pushOffer()
				end)
			end
		end
	end
end

local function renderTheirList(snapshot)
	clear(theirScroll)
	local offer = snapshot.TheirOffer
	for _, stack in ipairs(offer.Items) do
		local def = ItemData.Get(stack.Id)
		if def then
			rowFactory(theirScroll, ("%s × %d"):format(def.DisplayName, stack.Count),
				Color3.fromRGB(40, 46, 66))
		end
	end
	for _, uuid in ipairs(offer.Monsters) do
		-- The server hasn't sent species info; pull what we can by asking back via nil check.
		rowFactory(theirScroll, ("monster  <id ...%s>"):format(uuid:sub(-6)),
			Color3.fromRGB(48, 44, 70))
	end
	if offer.Coins > 0 then
		rowFactory(theirScroll, ("Coins: %d"):format(offer.Coins), Color3.fromRGB(70, 60, 30))
	end
end

local function applySnapshot(snapshot)
	currentSnapshot = snapshot
	mineHeading.Text = "Your offer"
	theirHeading.Text = ("%s's offer"):format(snapshot.Partner.Name)

	mineLock.Text = snapshot.MyLocked and "LOCKED" or "unlocked"
	mineLock.TextColor3 = snapshot.MyLocked and Color3.fromRGB(220, 200, 100) or Color3.fromRGB(180, 180, 200)
	theirLock.Text = snapshot.TheirLocked and "LOCKED" or "unlocked"
	theirLock.TextColor3 = snapshot.TheirLocked and Color3.fromRGB(220, 200, 100) or Color3.fromRGB(180, 180, 200)

	lockBtn.Text = snapshot.MyLocked and "Unlock" or "Lock"
	confirmBtn.BackgroundColor3 = snapshot.BothLocked
		and Color3.fromRGB(90, 170, 110) or Color3.fromRGB(70, 90, 70)
	confirmBtn.Text = snapshot.MyConfirmed and "Waiting…" or (snapshot.BothLocked and "Confirm" or "Lock first")

	renderMyList()
	renderTheirList(snapshot)
	screen.Enabled = true
end

Remotes.Events.TradeUpdate.OnClientEvent:Connect(applySnapshot)

Remotes.Events.TradeEnded.OnClientEvent:Connect(function(info)
	screen.Enabled = false
	myOffer = { Items = {}, Monsters = {}, Coins = 0 }
	coinsBox.Text = "0"
end)

coinsBox.FocusLost:Connect(function()
	local n = tonumber(coinsBox.Text) or 0
	myOffer.Coins = math.max(0, math.floor(n))
	coinsBox.Text = tostring(myOffer.Coins)
	pushOffer()
end)

lockBtn.MouseButton1Click:Connect(function()
	if not currentSnapshot then return end
	Remotes.Events.TradeLock:FireServer(not currentSnapshot.MyLocked)
end)
confirmBtn.MouseButton1Click:Connect(function()
	if not currentSnapshot or not currentSnapshot.BothLocked then return end
	Remotes.Events.TradeConfirm:FireServer()
end)
cancelBtn.MouseButton1Click:Connect(function()
	Remotes.Events.TradeCancel:FireServer()
end)

-- ── Incoming-request prompt ──────────────────────────────────────────────
local promptGui = Instance.new("ScreenGui")
promptGui.Name = "TradePrompt"
promptGui.ResetOnSpawn = false
promptGui.Parent = playerGui

local promptFrame = Instance.new("Frame")
promptFrame.AnchorPoint = Vector2.new(0.5, 0)
promptFrame.Position = UDim2.new(0.5, 0, 0, -120)
promptFrame.Size = UDim2.fromOffset(360, 96)
promptFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 36)
promptFrame.BorderSizePixel = 0
promptFrame.Parent = promptGui
Instance.new("UICorner", promptFrame).CornerRadius = UDim.new(0, 10)

local promptLabel = Instance.new("TextLabel")
promptLabel.Size = UDim2.new(1, 0, 0, 40)
promptLabel.BackgroundTransparency = 1
promptLabel.Font = Enum.Font.GothamBold
promptLabel.TextSize = 15
promptLabel.TextColor3 = Color3.fromRGB(240, 230, 200)
promptLabel.Text = ""
promptLabel.Parent = promptFrame

local acceptBtn = Instance.new("TextButton")
acceptBtn.Position = UDim2.new(0, 20, 0, 48)
acceptBtn.Size = UDim2.fromOffset(150, 36)
acceptBtn.Text = "Accept"
acceptBtn.BackgroundColor3 = Color3.fromRGB(90, 170, 110)
acceptBtn.BorderSizePixel = 0
acceptBtn.TextColor3 = Color3.fromRGB(30, 30, 30)
acceptBtn.Font = Enum.Font.GothamBold
acceptBtn.TextSize = 14
acceptBtn.Parent = promptFrame
Instance.new("UICorner", acceptBtn).CornerRadius = UDim.new(0, 6)

local declineBtn = Instance.new("TextButton")
declineBtn.Position = UDim2.new(1, -170, 0, 48)
declineBtn.Size = UDim2.fromOffset(150, 36)
declineBtn.Text = "Decline"
declineBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 80)
declineBtn.BorderSizePixel = 0
declineBtn.TextColor3 = Color3.fromRGB(30, 30, 30)
declineBtn.Font = Enum.Font.GothamBold
declineBtn.TextSize = 14
declineBtn.Parent = promptFrame
Instance.new("UICorner", declineBtn).CornerRadius = UDim.new(0, 6)

local function showPrompt(text: string)
	promptLabel.Text = text
	promptFrame:TweenPosition(UDim2.new(0.5, 0, 0, 24), "Out", "Quad", 0.25, true)
end
local function hidePrompt()
	promptFrame:TweenPosition(UDim2.new(0.5, 0, 0, -120), "In", "Quad", 0.2, true)
end
hidePrompt()

Remotes.Events.TradeIncoming.OnClientEvent:Connect(function(info)
	showPrompt(("%s wants to trade"):format(info.FromName))
	acceptBtn.MouseButton1Click:Once(function()
		Remotes.Events.TradeRespond:FireServer(true)
		hidePrompt()
	end)
	declineBtn.MouseButton1Click:Once(function()
		Remotes.Events.TradeRespond:FireServer(false)
		hidePrompt()
	end)
	task.delay(30, hidePrompt)
end)

-- ── Trigger: T near a player → request trade with closest ────────────────
local function findClosestPlayerNearMe(): Player?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local closest, bestDist = nil, 32
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Character then
			local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if oRoot then
				local d = (oRoot.Position - root.Position).Magnitude
				if d < bestDist then closest, bestDist = other, d end
			end
		end
	end
	return closest
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.T then
		local other = findClosestPlayerNearMe()
		if other then
			Remotes.Events.TradeRequest:FireServer(other.UserId)
		else
			-- no one nearby
		end
	end
end)

-- ── On-screen trade button (for mobile / non-keyboard) ───────────────────
local tradeToggle = Instance.new("ScreenGui")
tradeToggle.Name = "TradeToggleGui"
tradeToggle.ResetOnSpawn = false
tradeToggle.Parent = playerGui

local tbtn = Instance.new("TextButton")
tbtn.AnchorPoint = Vector2.new(1, 0)
tbtn.Position = UDim2.new(1, -16, 0, 88)
tbtn.Size = UDim2.fromOffset(60, 60)
tbtn.Text = "TRADE"
tbtn.Font = Enum.Font.FredokaOne
tbtn.TextSize = 14
tbtn.TextColor3 = Color3.fromRGB(30, 30, 30)
tbtn.BackgroundColor3 = Color3.fromRGB(120, 200, 160)
tbtn.BorderSizePixel = 0
tbtn.Parent = tradeToggle
Instance.new("UICorner", tbtn).CornerRadius = UDim.new(1, 0)
local tstroke = Instance.new("UIStroke"); tstroke.Color = Color3.fromRGB(40, 80, 60)
tstroke.Thickness = 2; tstroke.Parent = tbtn
local tkey = Instance.new("TextLabel")
tkey.AnchorPoint = Vector2.new(0.5, 0); tkey.Position = UDim2.new(0.5, 0, 1, 2)
tkey.Size = UDim2.fromOffset(60, 16); tkey.BackgroundTransparency = 1
tkey.Text = "[T]"; tkey.Font = Enum.Font.Gotham; tkey.TextSize = 11
tkey.TextColor3 = Color3.fromRGB(220, 220, 220); tkey.Parent = tbtn

tbtn.MouseButton1Click:Connect(function()
	local other = findClosestPlayerNearMe()
	if other then
		Remotes.Events.TradeRequest:FireServer(other.UserId)
	end
end)
