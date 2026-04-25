--!strict
-- LuckyBlockManager: spawns lucky blocks across all five zone rings,
-- handles ProximityPrompt triggers, awards creatures, and respawns blocks
-- on a per-zone timer.  Exposes _G.LuckyBlockManager for the mod menu.

local Players              = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local RunService           = game:GetService("RunService")
local TweenService         = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig    = require(Modules:WaitForChild("GameConfig"))
local LuckyBlockData = require(Modules:WaitForChild("LuckyBlockData"))
local Inventory     = require(Modules:WaitForChild("Inventory"))
local Remotes       = require(ReplicatedStorage:WaitForChild("Remotes"))

-- Wait for WorldState so we know spawn anchors exist.
local WORLD_TIMEOUT = 20
local WorldState = _G.WorldState
if not WorldState then
	local t = os.clock()
	repeat task.wait(0.2) WorldState = _G.WorldState
	until WorldState or (os.clock() - t) > WORLD_TIMEOUT
end

local rng = Random.new(os.time())

-- ── Block model factory ───────────────────────────────────────────────────

local BLOCK_SIZE = Vector3.new(4, 4, 4)

local function makeLuckyBlock(zone: LuckyBlockData.ZoneDef, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = ("LuckyBlock_Z%d"):format(zone.Id)

	-- Main cube body.
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = true
	body.Size = BLOCK_SIZE
	body.CFrame = CFrame.new(position)
	body.Color = zone.BlockColor
	body.Material = Enum.Material.SmoothPlastic
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.CastShadow = true
	body.Parent = model

	-- Inner neon glow core (slightly smaller, neon material).
	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Anchored = true
	glow.CanCollide = false
	glow.Size = BLOCK_SIZE * 0.72
	glow.CFrame = CFrame.new(position)
	glow.Color = zone.BlockGlow
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.35
	glow.CastShadow = false
	glow.Parent = model

	local bodyWeld = Instance.new("WeldConstraint")
	bodyWeld.Part0 = body; bodyWeld.Part1 = glow; bodyWeld.Parent = body

	-- Surface decoration: question mark via BillboardGui.
	local bb = Instance.new("BillboardGui")
	bb.Adornee = body
	bb.Size = UDim2.fromOffset(80, 80)
	bb.StudsOffset = Vector3.new(0, 0, 2.1)
	bb.AlwaysOnTop = false
	local qm = Instance.new("TextLabel")
	qm.Size = UDim2.fromScale(1, 1)
	qm.BackgroundTransparency = 1
	qm.Text = "?"
	qm.Font = Enum.Font.FredokaOne
	qm.TextSize = 60
	qm.TextColor3 = Color3.fromRGB(255, 255, 255)
	qm.TextStrokeTransparency = 0.2
	qm.TextStrokeColor3 = zone.BlockEmission
	qm.Parent = bb
	bb.Parent = body

	-- Zone label floating above.
	local zoneBb = Instance.new("BillboardGui")
	zoneBb.Adornee = body
	zoneBb.Size = UDim2.fromOffset(160, 28)
	zoneBb.StudsOffset = Vector3.new(0, 3.2, 0)
	zoneBb.AlwaysOnTop = false
	local zoneLabel = Instance.new("TextLabel")
	zoneLabel.Size = UDim2.fromScale(1, 1)
	zoneLabel.BackgroundTransparency = 1
	zoneLabel.Text = zone.Name
	zoneLabel.Font = Enum.Font.GothamBold
	zoneLabel.TextSize = 14
	zoneLabel.TextColor3 = zone.BlockGlow
	zoneLabel.TextStrokeTransparency = 0
	zoneLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	zoneLabel.Parent = zoneBb
	zoneBb.Parent = body

	-- PointLight for ambience.
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 20
	light.Color = zone.BlockGlow
	light.Parent = body

	-- SelectionBox outline.
	local sel = Instance.new("SelectionBox")
	sel.Adornee = body
	sel.Color3 = zone.BlockGlow
	sel.LineThickness = 0.06
	sel.SurfaceTransparency = 1
	sel.Parent = model

	-- ProximityPrompt.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = zone.Name .. " Block"
	prompt.HoldDuration = if zone.Id >= 3 then 0.6 else 0.3
	prompt.MaxActivationDistance = GameConfig.BlockInteractDist
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = body

	-- Metadata attributes.
	model:SetAttribute("ZoneId", zone.Id)
	model:SetAttribute("Active", true)
	model.PrimaryPart = body

	return model
end

-- ── Block registry ────────────────────────────────────────────────────────
-- Each zone maintains a fixed-size pool of active blocks.

type BlockSlot = {
	Zone: LuckyBlockData.ZoneDef,
	Model: Model?,
	RespawnAt: number,     -- os.clock() when next block should spawn
	SpawnPosition: Vector3,
}

local slots: { BlockSlot } = {}
local blockToSlot: { [Model]: BlockSlot } = {}

-- ── Position helpers ──────────────────────────────────────────────────────

local function randomPositionInZone(zone: LuckyBlockData.ZoneDef): Vector3
	for _ = 1, 60 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(zone.MinRadius + 20, zone.MaxRadius - 20)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		-- Height follows the same terrain noise used by WorldBuilder.
		local h = math.noise(x * 0.01, z * 0.01) * 6 + 6
		return Vector3.new(x, h, z)
	end
	-- Fallback: dead-center of ring.
	local r = (zone.MinRadius + zone.MaxRadius) / 2
	return Vector3.new(r, 6, 0)
end

-- ── Block lifecycle ───────────────────────────────────────────────────────

local blockFolder: Folder
task.spawn(function()
	-- Wait for Workspace to be ready.
	task.wait()
	local ws = game:GetService("Workspace")
	blockFolder = ws:FindFirstChild("LuckyBlocks") :: Folder
	if not blockFolder then
		blockFolder = Instance.new("Folder")
		blockFolder.Name = "LuckyBlocks"
		blockFolder.Parent = ws
	end
end)

local function spawnBlock(slot: BlockSlot)
	if slot.Model then
		slot.Model:Destroy()
		slot.Model = nil
		blockToSlot[slot.Model] = nil
	end
	local pos = randomPositionInZone(slot.Zone)
	slot.SpawnPosition = pos
	local model = makeLuckyBlock(slot.Zone, pos)
	model.Parent = blockFolder or game:GetService("Workspace")
	slot.Model = model
	blockToSlot[model] = slot
end

local function destroyBlock(slot: BlockSlot, respawnDelay: number)
	local model = slot.Model
	if not model then return end
	slot.Model = nil
	if model then blockToSlot[model] = nil end
	slot.RespawnAt = os.clock() + respawnDelay

	-- Animate: scale to zero then destroy.
	local body = model:FindFirstChild("Body") :: BasePart?
	if body then
		local prompt = body:FindFirstChild("OpenPrompt")
		if prompt then prompt.Enabled = false end

		local ti = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		local tween = TweenService:Create(body, ti, { Size = Vector3.new(0.1, 0.1, 0.1) })
		tween:Play()
		tween.Completed:Connect(function()
			model:Destroy()
		end)
	else
		model:Destroy()
	end
end

-- ── Initialise slots from zone definitions ────────────────────────────────

local function initSlots()
	local stagger = 0
	for _, zone in ipairs(LuckyBlockData.Zones) do
		for i = 1, zone.BlockCount do
			local slot: BlockSlot = {
				Zone = zone,
				Model = nil,
				RespawnAt = os.clock() + stagger,
				SpawnPosition = Vector3.new(0, 0, 0),
			}
			table.insert(slots, slot)
			stagger += 0.25  -- stagger initial spawns so they don't all appear at once
		end
	end
end

-- ── Cooldown per player ───────────────────────────────────────────────────
-- Prevent holding E on the same block twice rapidly.

local openCooldown: { [number]: number } = {}  -- userId → os.clock() cooldown expiry

local function isOnCooldown(player: Player): boolean
	local t = openCooldown[player.UserId]
	return t ~= nil and os.clock() < t
end

local function setCooldown(player: Player, secs: number)
	openCooldown[player.UserId] = os.clock() + secs
end

-- ── Reward logic ──────────────────────────────────────────────────────────

local function giveReward(player: Player, zone: LuckyBlockData.ZoneDef, blockPosition: Vector3)
	local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
	if not save then return end

	local flags = _G.ModMenu and _G.ModMenu.GetFlags(player) or {}

	-- Roll rarity & creature.
	local weights = zone.Weights
	if flags.MaxBaseIncome then
		-- Bias toward Legendary/Mythic in cheat mode.
		weights = { Common=0, Uncommon=0, Rare=0.05, Epic=0.15, Legendary=0.40, Mythic=0.40 }
	end
	local rarity = LuckyBlockData.RollRarity(weights, rng)
	local creatureDef = LuckyBlockData.RollCreature(rarity, rng)

	-- Add to save.
	local entry = Inventory.AddLuckyCreature(save, creatureDef.Id, rarity)
	save.TotalBlocksOpened = (save.TotalBlocksOpened or 0) + 1
	_G.PlayerData.Push(player)

	-- Notify client with the reward.
	Remotes.Events.LuckyBlockResult:FireClient(player, {
		Uid         = entry.Uid,
		CreatureId  = creatureDef.Id,
		DisplayName = creatureDef.DisplayName,
		Rarity      = rarity,
		Description = creatureDef.Description,
		PrimaryColor   = creatureDef.PrimaryColor,
		SecondaryColor = creatureDef.SecondaryColor,
		IncomeBonus = creatureDef.IncomeBonus,
	}, blockPosition)

	-- Broadcast opened position (for open-animation on all nearby clients).
	Remotes.Events.BlockOpened:FireAllClients(blockPosition, zone.BlockGlow)

	-- Toast notification.
	local rarityDef = LuckyBlockData.Rarities[rarity]
	Remotes.Events.Notify:FireClient(player,
		("✦ %s %s — added to your inventory!"):format(rarity, creatureDef.DisplayName))
end

-- ── ProximityPrompt handler ───────────────────────────────────────────────

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
	if prompt.Name ~= "OpenPrompt" then return end
	local body = prompt.Parent :: BasePart?
	if not body then return end
	local model = body.Parent :: Model?
	if not model or not model:IsA("Model") then return end

	local slot = blockToSlot[model]
	if not slot then return end
	if not model:GetAttribute("Active") then return end

	if isOnCooldown(player) then
		Remotes.Events.Notify:FireClient(player, "Opening too fast — slow down!")
		return
	end

	-- Check zone speed gate unless mod menu bypasses it.
	local flags = _G.ModMenu and _G.ModMenu.GetFlags(player) or {}
	local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
	if save and not flags.UnlockAllZones then
		local speedTier = LuckyBlockData.GetSpeedTier(save.SpeedLevel)
		if speedTier.WalkSpeed < slot.Zone.MinSpeed then
			local needed = slot.Zone.MinSpeed
			Remotes.Events.Notify:FireClient(player,
				("Need Speed %d+ to open %s blocks. Upgrade at the Market!"):format(needed, slot.Zone.Name))
			return
		end
	end

	model:SetAttribute("Active", false)
	setCooldown(player, 1.5)

	local blockPos = model.PrimaryPart and model.PrimaryPart.Position or Vector3.new()
	giveReward(player, slot.Zone, blockPos)
	destroyBlock(slot, slot.Zone.RespawnSeconds)
end)

-- ── Respawn loop ──────────────────────────────────────────────────────────

task.spawn(function()
	-- Brief startup wait so WorldBuilder and blockFolder are ready.
	task.wait(3)
	initSlots()
	-- Initial spawn.
	for _, slot in ipairs(slots) do
		if os.clock() >= slot.RespawnAt then
			spawnBlock(slot)
		end
	end
	while true do
		task.wait(1)
		for _, slot in ipairs(slots) do
			if not slot.Model and os.clock() >= slot.RespawnAt then
				spawnBlock(slot)
			end
		end
	end
end)

-- ── Bob animation ─────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		local dt = task.wait()
		local t = os.clock()
		for _, slot in ipairs(slots) do
			local model = slot.Model
			if model then
				local body = model:FindFirstChild("Body") :: BasePart?
				if body and body.Anchored then
					local base = slot.SpawnPosition
					local bob = math.sin(t * GameConfig.BlockBobSpeed * math.pi * 2) * GameConfig.BlockBobAmplitude
					body.CFrame = CFrame.new(base + Vector3.new(0, bob, 0))
						* CFrame.Angles(0, t * 0.6, 0)
					-- Keep glow in sync.
					local glow = model:FindFirstChild("Glow") :: BasePart?
					if glow then
						glow.CFrame = body.CFrame
					end
				end
			end
		end
	end
end)

-- ── Mod menu: force-spawn block at player ─────────────────────────────────

Remotes.Events.ModMenuSpawnBlock.OnServerEvent:Connect(function(player)
	local flags = _G.ModMenu and _G.ModMenu.GetFlags(player) or {}
	-- ModMenuHandler already verifies permission; trust it here.
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	-- Spawn a zone-5 block right in front of the player.
	local zone = LuckyBlockData.Zones[5]
	local pos = root.Position + root.CFrame.LookVector * 8 + Vector3.new(0, 3, 0)
	local model = makeLuckyBlock(zone, pos)
	model.Parent = blockFolder or game:GetService("Workspace")
	-- Add a temporary slot so the respawn loop doesn't touch it.
	local tempSlot: BlockSlot = {
		Zone = zone, Model = model,
		RespawnAt = os.clock() + 999,
		SpawnPosition = pos,
	}
	blockToSlot[model] = tempSlot
	table.insert(slots, tempSlot)
end)

-- ── Cleanup on player leave ───────────────────────────────────────────────

Players.PlayerRemoving:Connect(function(player)
	openCooldown[player.UserId] = nil
end)

-- ── Public API ────────────────────────────────────────────────────────────

local LuckyBlockManager = {}
_G.LuckyBlockManager = LuckyBlockManager

function LuckyBlockManager.TotalActive(): number
	local n = 0
	for _, s in ipairs(slots) do if s.Model then n += 1 end end
	return n
end

print(("[LuckyBlockManager] ready — %d zones, %d total block slots"):format(
	#LuckyBlockData.Zones,
	#slots
))
