--!strict
-- The mod menu. Press M to toggle.
-- Every control fires ModMenuSetFlag; the server validates and applies.
-- The spawn-monster dropdown + teleport destinations are separate remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local MonsterData = require(Modules:WaitForChild("MonsterData"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local state
task.spawn(function()
	local ok, data = pcall(function() return Remotes.Functions.GetModMenuState:InvokeServer() end)
	if ok then state = data end
end)

local screen = Instance.new("ScreenGui")
screen.Name = "ModMenuGui"
screen.ResetOnSpawn = false
screen.Enabled = false
screen.Parent = playerGui

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(520, 580)
frame.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
frame.BorderSizePixel = 0
frame.Parent = screen
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(210, 180, 90)
stroke.Thickness = 1.5
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "· MOD MENU ·"
title.Font = Enum.Font.FredokaOne
title.TextSize = 24
title.TextColor3 = Color3.fromRGB(240, 220, 160)
title.Parent = frame

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.new(0, 14, 0, 48)
scroll.Size = UDim2.new(1, -28, 1, -62)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = scroll

-- Local mirror of server flags so toggles update instantly.
local flags = {}
for k, v in pairs(GameConfig.ModMenuDefaults) do flags[k] = v end

local function row(): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 40)
	f.BackgroundColor3 = Color3.fromRGB(24, 28, 42)
	f.BorderSizePixel = 0
	f.Parent = scroll
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
	return f
end

local function addLabel(parent: Instance, text: string, width: UDim2)
	local l = Instance.new("TextLabel")
	l.Size = width
	l.Position = UDim2.fromOffset(12, 0)
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Font = Enum.Font.Gotham
	l.TextSize = 14
	l.TextColor3 = Color3.fromRGB(230, 230, 240)
	l.Parent = parent
	return l
end

local function setFlag(flag: string, value: any)
	flags[flag] = value
	Remotes.Events.ModMenuSetFlag:FireServer(flag, value)
end

local function addToggleRow(flag: string, label: string)
	local f = row()
	addLabel(f, label, UDim2.new(1, -90, 1, 0))
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(70, 26)
	btn.Position = UDim2.new(1, -82, 0.5, -13)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.Parent = f
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	local function redraw()
		local on = flags[flag]
		btn.BackgroundColor3 = if on then Color3.fromRGB(80, 140, 90) else Color3.fromRGB(80, 60, 70)
		btn.TextColor3 = Color3.fromRGB(240, 240, 240)
		btn.Text = if on then "ON" else "OFF"
	end
	redraw()
	btn.MouseButton1Click:Connect(function()
		setFlag(flag, not flags[flag]); redraw()
	end)
end

local function addSliderRow(flag: string, label: string, minV: number, maxV: number, step: number)
	local f = row()
	f.Size = UDim2.new(1, 0, 0, 48)
	local title = addLabel(f, ("%s: %s"):format(label, tostring(flags[flag] or minV)), UDim2.new(1, -20, 0, 20))
	title.Position = UDim2.fromOffset(12, 4)

	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 12, 0, 30)
	bar.Size = UDim2.new(1, -24, 0, 8)
	bar.BackgroundColor3 = Color3.fromRGB(50, 55, 75)
	bar.BorderSizePixel = 0
	bar.Parent = f
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(210, 180, 90)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

	local function setFromMouse(x: number)
		local absPos = bar.AbsolutePosition.X
		local absSize = bar.AbsoluteSize.X
		local frac = math.clamp((x - absPos) / math.max(1, absSize), 0, 1)
		local raw = minV + (maxV - minV) * frac
		local snapped = math.floor(raw / step + 0.5) * step
		snapped = math.clamp(snapped, minV, maxV)
		flags[flag] = snapped
		title.Text = ("%s: %s"):format(label, tostring(snapped))
		fill.Size = UDim2.new(frac, 0, 1, 0)
		setFlag(flag, snapped)
	end

	local button = Instance.new("TextButton")
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Size = UDim2.new(1, 0, 1, 0)
	button.Parent = bar
	button.MouseButton1Down:Connect(function()
		local dragging = true
		setFromMouse(UserInputService:GetMouseLocation().X)
		local move; local up
		move = UserInputService.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				setFromMouse(input.Position.X)
			end
		end)
		up = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false; move:Disconnect(); up:Disconnect()
			end
		end)
	end)

	-- initial fill
	local init = flags[flag] or minV
	local frac = (init - minV) / math.max(1, maxV - minV)
	fill.Size = UDim2.new(frac, 0, 1, 0)
end

local function addChoiceRow(flag: string, label: string, choices: { string })
	local f = row()
	f.Size = UDim2.new(1, 0, 0, 50)
	addLabel(f, label, UDim2.new(1, -20, 0, 20))

	local holder = Instance.new("Frame")
	holder.Position = UDim2.new(0, 12, 0, 24)
	holder.Size = UDim2.new(1, -24, 0, 22)
	holder.BackgroundTransparency = 1
	holder.Parent = f

	local h = Instance.new("UIListLayout")
	h.FillDirection = Enum.FillDirection.Horizontal
	h.Padding = UDim.new(0, 4)
	h.Parent = holder

	local buttons: { TextButton } = {}
	local function redraw()
		for i, btn in ipairs(buttons) do
			btn.BackgroundColor3 = if flags[flag] == choices[i]
				then Color3.fromRGB(210, 180, 90) else Color3.fromRGB(50, 55, 75)
		end
	end
	for i, choice in ipairs(choices) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(86, 22)
		btn.Text = choice
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 12
		btn.TextColor3 = Color3.fromRGB(240, 240, 240)
		btn.Parent = holder
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
		btn.MouseButton1Click:Connect(function()
			flags[flag] = choice; setFlag(flag, choice); redraw()
		end)
		buttons[i] = btn
	end
	redraw()
end

-- ── Section header helper ────────────────────────────────────────────────

local function sectionHeader(text: string)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 26)
	f.BackgroundColor3 = Color3.fromRGB(20, 22, 35)
	f.BorderSizePixel = 0
	f.Parent = scroll
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 5)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Position = UDim2.fromOffset(12, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextSize = 15
	lbl.TextColor3 = Color3.fromRGB(240, 200, 80)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = text
	lbl.Parent = f
end

-- ── Build all rows ────────────────────────────────────────────────────────

sectionHeader("▸ Player Cheats")
addToggleRow("GodMode",         "God mode")
addToggleRow("InfiniteStamina", "Infinite stamina")
addSliderRow("SpeedMultiplier", "Speed multiplier",  1, 8, 1)
addSliderRow("JumpMultiplier",  "Jump multiplier",   1, 4, 1)
addToggleRow("NoClip",          "No-clip")
addToggleRow("InfiniteMoney",   "Infinite money (top-up)")

sectionHeader("▸ Combat")
addToggleRow("InstantCapture",  "Instant capture")
addToggleRow("AutoCatch",       "Auto-catch nearby monster")
addSliderRow("DamageMultiplier","Damage multiplier", 1, 20, 1)
addToggleRow("InstantLevelUp",  "Instant level up catches")

sectionHeader("▸ Visuals / World")
addToggleRow("EspMonsters",     "ESP — monsters")
addToggleRow("EspLoot",         "ESP — loot crates")
addToggleRow("XrayCaves",       "X-ray caves")
addChoiceRow("Weather",         "Weather",     { "Clear", "Rain", "Storm", "Snow" })
addSliderRow("ClockTime",       "Time of day", 0, 24, 1)
addSliderRow("TimeScale",       "Gravity scale (world speed)", 1, 10, 1)

sectionHeader("▸ Lucky Block Cheats  (Everything FREE)")
addToggleRow("FreeUpgrades",    "Free upgrades (speed & base slots)")
addToggleRow("UnlockAllZones",  "Unlock all zones (ignore speed gate)")
addToggleRow("InstantBlock",    "Instant block open (no hold)")
addToggleRow("AutoFarm",        "Auto-farm nearest block every 3 s")
addToggleRow("MaxBaseIncome",   "Max base income (×10 multiplier)")
addToggleRow("InfiniteMoney",   "Infinite money — 1M coin top-up")

-- One-shot button to spawn a Mythic block at your feet.
do
	local f = row()
	addLabel(f, "Spawn Mythic Block at player", UDim2.new(1, -120, 1, 0))
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(100, 26)
	btn.Position = UDim2.new(1, -112, 0.5, -13)
	btn.BackgroundColor3 = Color3.fromRGB(140, 40, 200)
	btn.TextColor3 = Color3.fromRGB(255, 220, 255)
	btn.Text = "✦ SPAWN"
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.BorderSizePixel = 0
	btn.Parent = f
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	btn.MouseButton1Click:Connect(function()
		Remotes.Events.ModMenuSpawnBlock:FireServer()
	end)
end

-- Spawn-monster dropdown + teleport buttons at the bottom.
local spawnRow = row()
spawnRow.Size = UDim2.new(1, 0, 0, 56)
addLabel(spawnRow, "Spawn monster", UDim2.new(0, 140, 1, 0))

local speciesBtn = Instance.new("TextButton")
speciesBtn.Position = UDim2.new(0, 150, 0, 14)
speciesBtn.Size = UDim2.fromOffset(210, 28)
speciesBtn.Text = "Emberpup ▾"
speciesBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 75)
speciesBtn.BorderSizePixel = 0
speciesBtn.Font = Enum.Font.Gotham
speciesBtn.TextSize = 13
speciesBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
speciesBtn.Parent = spawnRow
Instance.new("UICorner", speciesBtn).CornerRadius = UDim.new(0, 4)

local goBtn = Instance.new("TextButton")
goBtn.Position = UDim2.new(1, -86, 0, 14)
goBtn.Size = UDim2.fromOffset(72, 28)
goBtn.Text = "Spawn"
goBtn.BackgroundColor3 = Color3.fromRGB(210, 180, 90)
goBtn.TextColor3 = Color3.fromRGB(30, 30, 30)
goBtn.Font = Enum.Font.GothamBold
goBtn.TextSize = 13
goBtn.BorderSizePixel = 0
goBtn.Parent = spawnRow
Instance.new("UICorner", goBtn).CornerRadius = UDim.new(0, 4)

local selectedSpecies = "emberpup"
local dropdown: Frame?
speciesBtn.MouseButton1Click:Connect(function()
	if dropdown then dropdown:Destroy(); dropdown = nil; return end
	local d = Instance.new("ScrollingFrame")
	d.Position = UDim2.new(0, 150, 0, 44)
	d.Size = UDim2.fromOffset(210, 180)
	d.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
	d.BorderSizePixel = 0
	d.CanvasSize = UDim2.new(0, 0, 0, 0)
	d.AutomaticCanvasSize = Enum.AutomaticSize.Y
	d.ScrollBarThickness = 3
	d.Parent = spawnRow
	Instance.new("UICorner", d).CornerRadius = UDim.new(0, 4)
	local l = Instance.new("UIListLayout"); l.Parent = d
	for _, def in ipairs(MonsterData.All) do
		local opt = Instance.new("TextButton")
		opt.Size = UDim2.new(1, 0, 0, 22)
		opt.Text = ("%s  [%s]"):format(def.DisplayName, def.Rarity)
		opt.TextXAlignment = Enum.TextXAlignment.Left
		opt.Font = Enum.Font.Gotham
		opt.TextSize = 12
		opt.BackgroundColor3 = Color3.fromRGB(26, 30, 44)
		opt.TextColor3 = Color3.fromRGB(220, 220, 230)
		opt.BorderSizePixel = 0
		opt.Parent = d
		opt.MouseButton1Click:Connect(function()
			selectedSpecies = def.Id
			speciesBtn.Text = def.DisplayName .. " ▾"
			d:Destroy(); dropdown = nil
		end)
	end
	dropdown = d
end)

goBtn.MouseButton1Click:Connect(function()
	Remotes.Events.ModMenuSpawnMonster:FireServer(selectedSpecies)
end)

-- Teleport waypoints.
local teleRow = row()
teleRow.Size = UDim2.new(1, 0, 0, 50)
addLabel(teleRow, "Teleport", UDim2.new(0, 80, 1, 0))

local teleHolder = Instance.new("Frame")
teleHolder.Position = UDim2.new(0, 90, 0, 14)
teleHolder.Size = UDim2.new(1, -100, 0, 22)
teleHolder.BackgroundTransparency = 1
teleHolder.Parent = teleRow
local teleLayout = Instance.new("UIListLayout")
teleLayout.FillDirection = Enum.FillDirection.Horizontal
teleLayout.Padding = UDim.new(0, 4)
teleLayout.Parent = teleHolder

local function teleButton(name: string, getPos: () -> Vector3?)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(100, 22)
	btn.Text = name
	btn.BackgroundColor3 = Color3.fromRGB(50, 55, 75)
	btn.TextColor3 = Color3.fromRGB(240, 240, 240)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 12
	btn.BorderSizePixel = 0
	btn.Parent = teleHolder
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
	btn.MouseButton1Click:Connect(function()
		local pos = getPos()
		if pos then Remotes.Events.ModMenuTeleport:FireServer(pos) end
	end)
end

teleButton("Market", function() return Vector3.new(0, 8, 30) end)
teleButton("Nearest Cave", function()
	local world = Workspace:FindFirstChild("World")
	local caves = world and world:FindFirstChild("Caves")
	if not caves then return nil end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local best, bestDist
	for _, cave in ipairs(caves:GetChildren()) do
		local portal = cave:FindFirstChild("CavePortal") :: BasePart?
		if portal then
			local d = (portal.Position - root.Position).Magnitude
			if not bestDist or d < bestDist then best, bestDist = portal.Position, d end
		end
	end
	return best
end)
teleButton("Random Cabin", function()
	local world = Workspace:FindFirstChild("World")
	local structs = world and world:FindFirstChild("Structures")
	if not structs then return nil end
	local cabins = {}
	for _, inst in ipairs(structs:GetChildren()) do
		if inst.Name == "Cabin" and inst:IsA("Model") and inst.PrimaryPart then
			table.insert(cabins, inst.PrimaryPart.Position)
		end
	end
	if #cabins == 0 then return nil end
	return cabins[math.random(1, #cabins)]
end)

-- ── ESP / X-ray / auto-catch heartbeat ───────────────────────────────────
-- Client-only overlays driven by the local flag mirror.
local highlights: { [Instance]: Highlight } = {}
local function ensureHighlight(inst: Instance, color: Color3)
	local h = highlights[inst]
	if h and h.Parent then return h end
	h = Instance.new("Highlight")
	h.Adornee = inst
	h.FillTransparency = 0.6
	h.FillColor = color
	h.OutlineColor = color
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = inst
	highlights[inst] = h
	return h
end
local function clearHighlights()
	for inst, h in pairs(highlights) do
		if h then h:Destroy() end
		highlights[inst] = nil
	end
end

RunService.Heartbeat:Connect(function()
	local world = Workspace:FindFirstChild("World")
	if not world then return end

	if flags.EspMonsters then
		local spawns = world:FindFirstChild("MonsterSpawns")
		if spawns then
			for _, mob in ipairs(spawns:GetChildren()) do
				if mob:IsA("Model") then ensureHighlight(mob, Color3.fromRGB(220, 80, 80)) end
			end
		end
	end
	if flags.EspLoot then
		for _, d in ipairs(world:GetDescendants()) do
			if d.Name == "LootCrate" then ensureHighlight(d, Color3.fromRGB(240, 210, 120)) end
		end
	end
	if flags.XrayCaves then
		local caves = world:FindFirstChild("Caves")
		if caves then
			for _, cave in ipairs(caves:GetChildren()) do
				ensureHighlight(cave, Color3.fromRGB(140, 180, 240))
			end
		end
	end
	if not (flags.EspMonsters or flags.EspLoot or flags.XrayCaves) then
		clearHighlights()
	end

	if flags.AutoCatch then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local spawns = world:FindFirstChild("MonsterSpawns")
			if spawns then
				for _, mob in ipairs(spawns:GetChildren()) do
					if mob:IsA("Model") and mob.PrimaryPart then
						if (mob.PrimaryPart.Position - root.Position).Magnitude < 20 then
							Remotes.Events.ThrowTrap:FireServer("trap_basic", mob)
							break
						end
					end
				end
			end
		end
	end
end)

-- ── On-screen toggle button + keyboard shortcut ──────────────────────────
local toggleGui = Instance.new("ScreenGui")
toggleGui.Name = "ModMenuToggle"
toggleGui.ResetOnSpawn = false
toggleGui.Parent = playerGui

local toggleBtn = Instance.new("TextButton")
toggleBtn.AnchorPoint = Vector2.new(1, 0)
toggleBtn.Position = UDim2.new(1, -16, 0, 16)
toggleBtn.Size = UDim2.fromOffset(60, 60)
toggleBtn.Text = "MOD"
toggleBtn.Font = Enum.Font.FredokaOne
toggleBtn.TextSize = 18
toggleBtn.TextColor3 = Color3.fromRGB(30, 30, 30)
toggleBtn.BackgroundColor3 = Color3.fromRGB(210, 180, 90)
toggleBtn.BorderSizePixel = 0
toggleBtn.AutoButtonColor = true
toggleBtn.Parent = toggleGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(1, 0)
btnCorner.Parent = toggleBtn

local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.fromRGB(60, 40, 10)
btnStroke.Thickness = 2
btnStroke.Parent = toggleBtn

local keyHint = Instance.new("TextLabel")
keyHint.AnchorPoint = Vector2.new(0.5, 0)
keyHint.Position = UDim2.new(0.5, 0, 1, 2)
keyHint.Size = UDim2.fromOffset(60, 16)
keyHint.BackgroundTransparency = 1
keyHint.Text = "[M]"
keyHint.Font = Enum.Font.Gotham
keyHint.TextSize = 11
keyHint.TextColor3 = Color3.fromRGB(230, 210, 170)
keyHint.Parent = toggleBtn

toggleBtn.MouseButton1Click:Connect(function()
	screen.Enabled = not screen.Enabled
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.M then
		screen.Enabled = not screen.Enabled
	end
end)
