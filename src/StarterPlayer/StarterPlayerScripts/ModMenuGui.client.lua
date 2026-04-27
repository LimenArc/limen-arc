--!strict
-- Valiant Sky Mod Menu — 3 tabs: Mechanics, Moveset Manager, Map Manager.
-- Toggle with M key. Server validates all changes.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local HttpService        = game:GetService("HttpService")

local GameConfig    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local JSONValidator = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JSONValidator"))
local Remotes       = require(ReplicatedStorage:WaitForChild("Remotes"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Server state ──────────────────────────────────────────────────────────────

type ServerState = {
	Allowed:       boolean,
	Mechanics:     any,
	MovesetList:   { { name: string, isBuiltin: boolean } },
	MapList:       { { name: string, isBuiltin: boolean } },
	PlayerMoveset: string,
	CurrentMap:    string,
}

local serverState: ServerState? = nil

local function refreshState()
	local ok, data = pcall(function()
		return Remotes.Functions.GetModMenuState:InvokeServer()
	end)
	if ok and data then
		serverState = data :: ServerState
	end
end

task.spawn(refreshState)

-- ── UI helpers ────────────────────────────────────────────────────────────────

local COL_BG     = Color3.fromRGB(14, 18, 28)
local COL_PANEL  = Color3.fromRGB(22, 26, 40)
local COL_ROW    = Color3.fromRGB(30, 35, 52)
local COL_ACCENT = Color3.fromRGB(100, 120, 220)
local COL_GREEN  = Color3.fromRGB(80, 200, 100)
local COL_RED    = Color3.fromRGB(220, 80, 80)
local COL_TEXT   = Color3.fromRGB(220, 220, 240)
local COL_DIM    = Color3.fromRGB(140, 140, 165)

local function corner(inst: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function makeFrame(parent: Instance, size: UDim2, pos: UDim2, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function makeLabel(parent: Instance, text: string, size: UDim2, pos: UDim2,
	fontSize: number, color: Color3?, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.Text = text
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = fontSize
	l.TextColor3 = color or COL_TEXT
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function makeButton(parent: Instance, text: string, size: UDim2, pos: UDim2,
	color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Text = text
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = COL_TEXT
	b.AutoButtonColor = true
	corner(b, 6)
	b.Parent = parent
	return b
end

-- ── Main window ───────────────────────────────────────────────────────────────

local screen = Instance.new("ScreenGui")
screen.Name          = "ModMenuGui"
screen.ResetOnSpawn  = false
screen.Enabled       = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent        = playerGui

local window = makeFrame(screen, UDim2.fromOffset(600, 640),
	UDim2.new(0.5, -300, 0.5, -320), COL_BG)
corner(window, 12)

makeLabel(window, "⚔  VALIANT SKY — MOD MENU  ⚔",
	UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 0),
	16, COL_TEXT, Enum.TextXAlignment.Center)

-- ── Tab bar ───────────────────────────────────────────────────────────────────

local TAB_NAMES = { "Mechanics", "Movesets", "Maps" }
local tabBar    = makeFrame(window, UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 36), COL_PANEL)
local tabButtons: { TextButton } = {}

local contentArea = makeFrame(window,
	UDim2.new(1, -16, 1, -88),
	UDim2.fromOffset(8, 80), COL_PANEL)
corner(contentArea, 8)

local activeTab = ""

-- ── Tab content frames ────────────────────────────────────────────────────────

local function makeTabContent(): Frame
	local f = makeFrame(contentArea, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), COL_PANEL)
	f.Visible = false
	f.ClipsDescendants = true
	corner(f, 8)
	return f
end

local mechContent    = makeTabContent()
local movesetContent = makeTabContent()
local mapContent     = makeTabContent()

local tabContents: { [string]: Frame } = {
	Mechanics = mechContent,
	Movesets  = movesetContent,
	Maps      = mapContent,
}

local function selectTab(name: string)
	activeTab = name
	for _, n in ipairs(TAB_NAMES) do
		tabContents[n].Visible = (n == name)
	end
	for i, btn in ipairs(tabButtons) do
		btn.BackgroundColor3 = (TAB_NAMES[i] == name) and COL_ACCENT or COL_ROW
	end
end

for i, name in ipairs(TAB_NAMES) do
	local w = 1 / #TAB_NAMES
	local btn = makeButton(tabBar, name,
		UDim2.new(w, -4, 1, -8),
		UDim2.new((i - 1) * w, 2, 0, 4),
		COL_ROW)
	btn.TextSize = 14
	btn.MouseButton1Click:Connect(function() selectTab(name) end)
	table.insert(tabButtons, btn)
end

-- ── Toggle (M key) ────────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.M then
		screen.Enabled = not screen.Enabled
		if screen.Enabled then
			task.spawn(refreshState)
			if activeTab == "" then selectTab("Mechanics") end
		end
	end
end)

-- ── Mechanics tab ─────────────────────────────────────────────────────────────

local mechScroll = Instance.new("ScrollingFrame")
mechScroll.Size                = UDim2.fromScale(1, 1)
mechScroll.Position            = UDim2.fromOffset(0, 0)
mechScroll.BackgroundTransparency = 1
mechScroll.BorderSizePixel     = 0
mechScroll.ScrollBarThickness  = 6
mechScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mechScroll.CanvasSize          = UDim2.fromOffset(0, 0)
mechScroll.Parent              = mechContent

local mechLayout = Instance.new("UIListLayout")
mechLayout.FillDirection  = Enum.FillDirection.Vertical
mechLayout.SortOrder      = Enum.SortOrder.LayoutOrder
mechLayout.Padding        = UDim.new(0, 4)
mechLayout.Parent         = mechScroll

local mechPad = Instance.new("UIPadding")
mechPad.PaddingLeft   = UDim.new(0, 8)
mechPad.PaddingRight  = UDim.new(0, 8)
mechPad.PaddingTop    = UDim.new(0, 8)
mechPad.Parent        = mechScroll

local mechOrder = 0

local function setMechanic(key: string, value: any)
	Remotes.Events.ModMenuSetMechanic:FireServer(key, value)
end

local function addSliderRow(key: string, label: string, min: number, max: number, step: number)
	mechOrder += 1
	local row = makeFrame(mechScroll, UDim2.new(1, -8, 0, 44),
		UDim2.fromOffset(0, 0), COL_ROW)
	row.LayoutOrder = mechOrder
	corner(row, 6)

	local current = (serverState and (serverState.Mechanics :: any)[key]) or min
	makeLabel(row, label, UDim2.new(0.45, 0, 0, 20), UDim2.fromOffset(8, 4), 12)

	local valLabel = makeLabel(row, tostring(current),
		UDim2.new(0.15, 0, 0, 20),
		UDim2.new(0.45, 0, 0, 4), 12, COL_GREEN, Enum.TextXAlignment.Center)

	local sliderBg = makeFrame(row, UDim2.new(0.38, -12, 0, 8),
		UDim2.new(0.62, 0, 0, 18), Color3.fromRGB(50, 55, 75))
	corner(sliderBg, 4)

	local sliderFill = makeFrame(sliderBg, UDim2.new(0, 0, 1, 0),
		UDim2.fromOffset(0, 0), COL_ACCENT)
	corner(sliderFill, 4)

	local minBtn = makeButton(row, "−", UDim2.fromOffset(22, 22),
		UDim2.new(0.62, -34, 0, 11), Color3.fromRGB(60, 40, 40))
	local maxBtn = makeButton(row, "+", UDim2.fromOffset(22, 22),
		UDim2.new(1, -28, 0, 11), Color3.fromRGB(40, 60, 40))

	local function snap(v: number): number
		return math.clamp(math.round(v / step) * step, min, max)
	end
	local function updateFill(v: number)
		sliderFill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
		local fmt = step < 1 and "%.2f" or "%g"
		valLabel.Text = string.format(fmt, v)
	end

	local val = snap(current)
	updateFill(val)

	minBtn.MouseButton1Click:Connect(function()
		val = snap(val - step)
		updateFill(val)
		setMechanic(key, val)
	end)
	maxBtn.MouseButton1Click:Connect(function()
		val = snap(val + step)
		updateFill(val)
		setMechanic(key, val)
	end)

	-- Drag on slider
	local dragging = false
	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
		end
	end)
	sliderBg.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	game:GetService("UserInputService").InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local rel = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
			val = snap(min + rel * (max - min))
			updateFill(val)
			setMechanic(key, val)
		end
	end)
end

local function addChoiceRow(key: string, label: string, options: { string })
	mechOrder += 1
	local row = makeFrame(mechScroll, UDim2.new(1, -8, 0, 44),
		UDim2.fromOffset(0, 0), COL_ROW)
	row.LayoutOrder = mechOrder
	corner(row, 6)

	makeLabel(row, label, UDim2.new(0.4, 0, 0, 20), UDim2.fromOffset(8, 4), 12)

	local current = (serverState and (serverState.Mechanics :: any)[key]) or options[1]
	local choiceLabel = makeLabel(row, tostring(current),
		UDim2.new(0.25, 0, 0, 20),
		UDim2.new(0.4, 0, 0, 4), 12, COL_GREEN, Enum.TextXAlignment.Center)

	local idx = 1
	for i, opt in ipairs(options) do
		if opt == current then idx = i end
	end

	local prevBtn = makeButton(row, "◀", UDim2.fromOffset(28, 28),
		UDim2.new(0.65, 0, 0, 8), Color3.fromRGB(50, 50, 80))
	local nextBtn = makeButton(row, "▶", UDim2.fromOffset(28, 28),
		UDim2.new(0.85, 0, 0, 8), Color3.fromRGB(50, 50, 80))

	local function update()
		choiceLabel.Text = options[idx]
		setMechanic(key, options[idx])
	end

	prevBtn.MouseButton1Click:Connect(function()
		idx = ((idx - 2) % #options) + 1
		update()
	end)
	nextBtn.MouseButton1Click:Connect(function()
		idx = (idx % #options) + 1
		update()
	end)
end

-- Build mechanics rows
addSliderRow("Gravity",              "Gravity",            10,   1000, 10  )
addSliderRow("MaxHP",                "Max HP",             50,   5000, 50  )
addSliderRow("DamageMultiplier",     "Damage Multiplier",  0.1,  10,   0.1 )
addSliderRow("BasicDamage",          "Basic Attack Dmg",   1,    500,  1   )
addSliderRow("BasicCooldown",        "Basic Cooldown (s)", 0.1,  5,    0.05)
addSliderRow("BasicRange",           "Basic Range",        1,    50,   1   )
addSliderRow("MoveSpeed",            "Move Speed",         2,    100,  2   )
addSliderRow("RespawnTime",          "Respawn Time (s)",   1,    30,   1   )
addSliderRow("BlockDamageReduction", "Block Reduction",    0,    1,    0.05)
addSliderRow("DashIframeDuration",   "Dash Iframes (s)",   0,    2,    0.05)
addSliderRow("RoundDuration",        "Round Time (s)",     30,   600,  30  )
addChoiceRow("RoundMode",            "Round Mode",         { "FFA", "TimedFFA", "1v1" })

-- ── Moveset tab ───────────────────────────────────────────────────────────────

-- Left: list panel (~55% width)
local moveListPanel = makeFrame(movesetContent,
	UDim2.new(0.55, -4, 1, -8),
	UDim2.fromOffset(4, 4), COL_ROW)
corner(moveListPanel, 6)

makeLabel(moveListPanel, "Registered Movesets",
	UDim2.new(1, -8, 0, 20), UDim2.fromOffset(4, 4),
	12, COL_DIM, Enum.TextXAlignment.Center)

local moveScroll = Instance.new("ScrollingFrame")
moveScroll.Size                = UDim2.new(1, 0, 1, -28)
moveScroll.Position            = UDim2.fromOffset(0, 28)
moveScroll.BackgroundTransparency = 1
moveScroll.BorderSizePixel     = 0
moveScroll.ScrollBarThickness  = 5
moveScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
moveScroll.CanvasSize          = UDim2.fromOffset(0, 0)
moveScroll.Parent              = moveListPanel

local moveListLayout = Instance.new("UIListLayout")
moveListLayout.FillDirection  = Enum.FillDirection.Vertical
moveListLayout.SortOrder      = Enum.SortOrder.LayoutOrder
moveListLayout.Padding        = UDim.new(0, 3)
moveListLayout.Parent         = moveScroll

-- Right: upload panel
local moveUploadPanel = makeFrame(movesetContent,
	UDim2.new(0.45, -8, 1, -8),
	UDim2.new(0.55, 4, 0, 4), COL_ROW)
corner(moveUploadPanel, 6)

makeLabel(moveUploadPanel, "Upload Custom Moveset",
	UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, 4),
	12, COL_DIM, Enum.TextXAlignment.Center)

makeLabel(moveUploadPanel, "Paste JSON below:",
	UDim2.new(1, -8, 0, 14), UDim2.fromOffset(4, 26),
	11, COL_DIM)

local moveJsonBox = Instance.new("TextBox")
moveJsonBox.PlaceholderText = '{"name":"My Move","moves":{"basic":{...},"1":{...},...}}'
moveJsonBox.MultiLine        = true
moveJsonBox.ClearTextOnFocus = false
moveJsonBox.Size             = UDim2.new(1, -8, 0, 180)
moveJsonBox.Position         = UDim2.fromOffset(4, 44)
moveJsonBox.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
moveJsonBox.TextColor3       = COL_TEXT
moveJsonBox.PlaceholderColor3 = COL_DIM
moveJsonBox.Font              = Enum.Font.Code
moveJsonBox.TextSize          = 10
moveJsonBox.TextXAlignment    = Enum.TextXAlignment.Left
moveJsonBox.TextYAlignment    = Enum.TextYAlignment.Top
moveJsonBox.BorderSizePixel   = 0
moveJsonBox.Parent            = moveUploadPanel
corner(moveJsonBox, 4)

local moveStatusLabel = makeLabel(moveUploadPanel, "",
	UDim2.new(1, -8, 0, 30), UDim2.fromOffset(4, 228),
	11, COL_GREEN, Enum.TextXAlignment.Center)
moveStatusLabel.TextWrapped = true

local moveUploadBtn = makeButton(moveUploadPanel, "Upload Moveset",
	UDim2.new(1, -8, 0, 28), UDim2.fromOffset(4, 262),
	COL_ACCENT)

local currentMoveset = ""

local function rebuildMoveList(state: ServerState)
	-- Clear
	for _, c in ipairs(moveScroll:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end

	for i, entry in ipairs(state.MovesetList) do
		local row = makeFrame(moveScroll, UDim2.new(1, -4, 0, 34),
			UDim2.fromOffset(0, 0), Color3.fromRGB(25, 30, 46))
		row.LayoutOrder = i
		corner(row, 4)

		local badge = entry.isBuiltin and " [built-in]" or " [custom]"
		local nameColor = entry.name == state.PlayerMoveset and COL_GREEN or COL_TEXT
		makeLabel(row, entry.name .. badge,
			UDim2.new(0.65, 0, 1, 0), UDim2.fromOffset(6, 0),
			11, nameColor)

		local applyBtn = makeButton(row, "Apply",
			UDim2.fromOffset(56, 24), UDim2.new(1, -62, 0, 5),
			COL_ACCENT)
		local entryName = entry.name
		applyBtn.MouseButton1Click:Connect(function()
			Remotes.Events.ModMenuApplyMoveset:FireServer(entryName)
			currentMoveset = entryName
			if serverState then
				serverState.PlayerMoveset = entryName
				rebuildMoveList(serverState)
			end
		end)
	end
end

moveUploadBtn.MouseButton1Click:Connect(function()
	local raw = moveJsonBox.Text
	if raw == "" then
		moveStatusLabel.Text = "Paste JSON first"
		moveStatusLabel.TextColor3 = COL_RED
		return
	end

	-- Client pre-validation
	local parseOk, parsed = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not parseOk then
		moveStatusLabel.Text = "Invalid JSON: parse failed"
		moveStatusLabel.TextColor3 = COL_RED
		return
	end

	local registeredNames: { [string]: boolean } = {}
	if serverState then
		for _, entry in ipairs(serverState.MovesetList) do
			registeredNames[entry.name] = true
		end
	end

	local result = JSONValidator.ValidateMoveset(parsed, registeredNames)
	if not result.ok then
		moveStatusLabel.Text = "Error: " .. (result.err or "?")
		moveStatusLabel.TextColor3 = COL_RED
		return
	end

	moveStatusLabel.Text = "Uploading..."
	moveStatusLabel.TextColor3 = COL_DIM
	Remotes.Events.ModMenuUploadMoveset:FireServer(raw)

	-- Refresh list after server processes it
	task.delay(1.2, function()
		refreshState()
		task.wait(0.1)
		if serverState then rebuildMoveList(serverState) end
		moveStatusLabel.Text = "Uploaded: " .. tostring((parsed :: any).name)
		moveStatusLabel.TextColor3 = COL_GREEN
	end)
end)

-- ── Map tab ───────────────────────────────────────────────────────────────────

local mapListPanel = makeFrame(mapContent,
	UDim2.new(0.55, -4, 1, -8),
	UDim2.fromOffset(4, 4), COL_ROW)
corner(mapListPanel, 6)

makeLabel(mapListPanel, "Registered Maps",
	UDim2.new(1, -8, 0, 20), UDim2.fromOffset(4, 4),
	12, COL_DIM, Enum.TextXAlignment.Center)

local mapScroll = Instance.new("ScrollingFrame")
mapScroll.Size                = UDim2.new(1, 0, 1, -28)
mapScroll.Position            = UDim2.fromOffset(0, 28)
mapScroll.BackgroundTransparency = 1
mapScroll.BorderSizePixel     = 0
mapScroll.ScrollBarThickness  = 5
mapScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mapScroll.CanvasSize          = UDim2.fromOffset(0, 0)
mapScroll.Parent              = mapListPanel

local mapListLayout = Instance.new("UIListLayout")
mapListLayout.FillDirection  = Enum.FillDirection.Vertical
mapListLayout.SortOrder      = Enum.SortOrder.LayoutOrder
mapListLayout.Padding        = UDim.new(0, 3)
mapListLayout.Parent         = mapScroll

local mapUploadPanel = makeFrame(mapContent,
	UDim2.new(0.45, -8, 1, -8),
	UDim2.new(0.55, 4, 0, 4), COL_ROW)
corner(mapUploadPanel, 6)

makeLabel(mapUploadPanel, "Upload Custom Map",
	UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, 4),
	12, COL_DIM, Enum.TextXAlignment.Center)

makeLabel(mapUploadPanel, "Paste JSON below:",
	UDim2.new(1, -8, 0, 14), UDim2.fromOffset(4, 26),
	11, COL_DIM)

local mapJsonBox = Instance.new("TextBox")
mapJsonBox.PlaceholderText = '{"name":"My Map","theme":"urban","skyboxColor":[50,50,80],"platforms":[...],"spawnPoints":[...],"boundaries":120}'
mapJsonBox.MultiLine        = true
mapJsonBox.ClearTextOnFocus = false
mapJsonBox.Size             = UDim2.new(1, -8, 0, 180)
mapJsonBox.Position         = UDim2.fromOffset(4, 44)
mapJsonBox.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
mapJsonBox.TextColor3       = COL_TEXT
mapJsonBox.PlaceholderColor3 = COL_DIM
mapJsonBox.Font              = Enum.Font.Code
mapJsonBox.TextSize          = 10
mapJsonBox.TextXAlignment    = Enum.TextXAlignment.Left
mapJsonBox.TextYAlignment    = Enum.TextYAlignment.Top
mapJsonBox.BorderSizePixel   = 0
mapJsonBox.Parent            = mapUploadPanel
corner(mapJsonBox, 4)

local mapStatusLabel = makeLabel(mapUploadPanel, "",
	UDim2.new(1, -8, 0, 30), UDim2.fromOffset(4, 228),
	11, COL_GREEN, Enum.TextXAlignment.Center)
mapStatusLabel.TextWrapped = true

local mapUploadBtn = makeButton(mapUploadPanel, "Upload Map",
	UDim2.new(1, -8, 0, 28), UDim2.fromOffset(4, 262),
	COL_ACCENT)

local currentMapName = ""

local function rebuildMapList(state: ServerState)
	for _, c in ipairs(mapScroll:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end

	for i, entry in ipairs(state.MapList) do
		local row = makeFrame(mapScroll, UDim2.new(1, -4, 0, 34),
			UDim2.fromOffset(0, 0), Color3.fromRGB(25, 30, 46))
		row.LayoutOrder = i
		corner(row, 4)

		local badge = entry.isBuiltin and " [built-in]" or " [custom]"
		local nameColor = entry.name == state.CurrentMap and COL_GREEN or COL_TEXT
		makeLabel(row, entry.name .. badge,
			UDim2.new(0.65, 0, 1, 0), UDim2.fromOffset(6, 0),
			11, nameColor)

		local loadBtn = makeButton(row, "Load",
			UDim2.fromOffset(56, 24), UDim2.new(1, -62, 0, 5),
			COL_ACCENT)
		local entryName = entry.name
		loadBtn.MouseButton1Click:Connect(function()
			Remotes.Events.ModMenuSwitchMap:FireServer(entryName)
		end)
	end
end

mapUploadBtn.MouseButton1Click:Connect(function()
	local raw = mapJsonBox.Text
	if raw == "" then
		mapStatusLabel.Text = "Paste JSON first"
		mapStatusLabel.TextColor3 = COL_RED
		return
	end

	local parseOk, parsed = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not parseOk then
		mapStatusLabel.Text = "Invalid JSON: parse failed"
		mapStatusLabel.TextColor3 = COL_RED
		return
	end

	local registeredNames: { [string]: boolean } = {}
	if serverState then
		for _, entry in ipairs(serverState.MapList) do
			registeredNames[entry.name] = true
		end
	end

	local result = JSONValidator.ValidateMap(parsed, registeredNames)
	if not result.ok then
		mapStatusLabel.Text = "Error: " .. (result.err or "?")
		mapStatusLabel.TextColor3 = COL_RED
		return
	end

	mapStatusLabel.Text = "Uploading..."
	mapStatusLabel.TextColor3 = COL_DIM
	Remotes.Events.ModMenuUploadMap:FireServer(raw)

	task.delay(1.2, function()
		refreshState()
		task.wait(0.1)
		if serverState then rebuildMapList(serverState) end
		mapStatusLabel.Text = "Uploaded: " .. tostring((parsed :: any).name)
		mapStatusLabel.TextColor3 = COL_GREEN
	end)
end)

-- Listen for map changes to update the active highlight
Remotes.Events.MapLoaded.OnClientEvent:Connect(function(mapName: unknown)
	currentMapName = tostring(mapName)
	if serverState then
		serverState.CurrentMap = currentMapName
		rebuildMapList(serverState)
	end
end)

-- ── Populate lists when mod menu opens ───────────────────────────────────────

screen:GetPropertyChangedSignal("Enabled"):Connect(function()
	if screen.Enabled and serverState then
		rebuildMoveList(serverState)
		rebuildMapList(serverState)
		selectTab(activeTab == "" and "Mechanics" or activeTab)
	end
end)

-- ── Refresh lists after state loads ──────────────────────────────────────────

task.spawn(function()
	task.wait(2)  -- wait for server state to load
	refreshState()
	if serverState then
		rebuildMoveList(serverState)
		rebuildMapList(serverState)
	end
end)

-- Initial tab
selectTab("Mechanics")
