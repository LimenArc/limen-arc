--!strict
-- Procedurally paints the open world on server start: biome terrain,
-- caves, cabins, camps, and a central market plaza. Deterministic per seed
-- so a server session has a consistent layout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))

local MAP_SIZE = GameConfig.MapSize
local HALF = MAP_SIZE / 2
local CELL = GameConfig.CellSize

local SEED = tick() % 100000
local rng = Random.new(SEED)
print(("[WorldBuilder] seed=%d size=%d"):format(SEED, MAP_SIZE))

-- ── Biome map ────────────────────────────────────────────────────────────
-- We use a coarse Perlin to carve biomes. The same function is consulted by
-- MonsterSpawner to figure out which biome a given position belongs to.

local BIOME_SCALE = 0.0025

local function biomeAt(x: number, z: number): string
	-- Two noise channels: temperature (n1) and moisture (n2). Gives 4 quadrants
	-- plus a "rocky/volcanic" pocket where both channels are extreme.
	local n1 = math.noise(x * BIOME_SCALE, z * BIOME_SCALE, 0.13)
	local n2 = math.noise(x * BIOME_SCALE + 1000, z * BIOME_SCALE + 1000, 0.77)

	-- Shore: within ~130 studs of the map's edge water ring.
	local distFromCenter = math.sqrt(x * x + z * z)
	if distFromCenter > HALF - 140 then
		return "Shore"
	end

	if n1 > 0.35 and n2 > 0.35 then return "Volcanic" end
	if n1 < -0.35 and n2 < -0.35 then return "Tundra" end
	if n1 > 0.2 and n2 < -0.1 then return "Desert" end
	if n2 > 0.2 and n1 < 0 then return "Swamp" end
	if n2 > 0.1 then return "Forest" end
	return "Grassland"
end

local BIOME_COLORS: { [string]: Color3 } = {
	Grassland = Color3.fromRGB(110, 170, 80),
	Forest    = Color3.fromRGB(70, 120, 60),
	Desert    = Color3.fromRGB(220, 200, 130),
	Tundra    = Color3.fromRGB(220, 230, 240),
	Volcanic  = Color3.fromRGB(90, 60, 50),
	Swamp     = Color3.fromRGB(80, 100, 70),
	Shore     = Color3.fromRGB(230, 210, 160),
}

local BIOME_MATERIALS: { [string]: Enum.Material } = {
	Grassland = Enum.Material.Grass,
	Forest    = Enum.Material.LeafyGrass,
	Desert    = Enum.Material.Sand,
	Tundra    = Enum.Material.Snow,
	Volcanic  = Enum.Material.Basalt,
	Swamp     = Enum.Material.Mud,
	Shore     = Enum.Material.Sand,
}

-- ── Container folders ────────────────────────────────────────────────────
local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local WorldRoot = folder("World", Workspace)
local TerrainFolder = folder("Terrain", WorldRoot)
local StructuresFolder = folder("Structures", WorldRoot)
local CavesFolder = folder("Caves", WorldRoot)
local MarketFolder = folder("Market", WorldRoot)
local SpawnsFolder = folder("MonsterSpawns", WorldRoot)

-- Shared state that other systems read.
local WorldState = {
	Seed = SEED,
	BiomeAt = biomeAt,
	SpawnAnchors = {} :: { { Position: Vector3, Biome: string } },
	CavePortals = {} :: { Vector3 },
	CabinPositions = {} :: { Vector3 },
	CampPositions = {} :: { Vector3 },
	MarketCenter = Vector3.new(0, 4, 0),
}
_G.WorldState = WorldState

-- ── Coarse terrain tiles ─────────────────────────────────────────────────
-- Instead of painting Terrain voxels (which makes this file enormous), we
-- spawn colored BasePart tiles on a grid. Cheaper to author, still readable
-- as biomes. Games that ship would swap this for Terrain:WriteVoxels.

local function buildTerrain()
	local tilesPerSide = math.floor(MAP_SIZE / CELL)
	for ix = 0, tilesPerSide - 1 do
		for iz = 0, tilesPerSide - 1 do
			local x = -HALF + ix * CELL + CELL / 2
			local z = -HALF + iz * CELL + CELL / 2
			local biome = biomeAt(x, z)

			-- Mild height variation for visual interest.
			local h = math.noise(x * 0.01, z * 0.01) * 6
			local tile = Instance.new("Part")
			tile.Anchored = true
			tile.Size = Vector3.new(CELL, 4, CELL)
			tile.Position = Vector3.new(x, h, z)
			tile.Color = BIOME_COLORS[biome]
			tile.Material = BIOME_MATERIALS[biome]
			tile.TopSurface = Enum.SurfaceType.Smooth
			tile.BottomSurface = Enum.SurfaceType.Smooth
			tile.Parent = TerrainFolder

			-- Tag every ~3rd tile as a spawn anchor.
			if (ix + iz) % 3 == 0 then
				table.insert(WorldState.SpawnAnchors, {
					Position = Vector3.new(x, h + 3, z),
					Biome = biome,
				})
			end
		end
	end
end

-- ── Water ring around the edge ───────────────────────────────────────────
local function buildOcean()
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.Size = Vector3.new(MAP_SIZE + 600, 2, MAP_SIZE + 600)
	ring.Position = Vector3.new(0, -1, 0)
	ring.Color = Color3.fromRGB(40, 90, 160)
	ring.Material = Enum.Material.Water
	ring.Transparency = 0.2
	ring.TopSurface = Enum.SurfaceType.Smooth
	ring.Parent = WorldRoot
end

-- ── Structures: cabins ───────────────────────────────────────────────────
-- A cabin is a simple box hut with a door cutout and a roof peak.

local function buildCabin(pos: Vector3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Cabin"
	model.Parent = parent

	local base = Instance.new("Part")
	base.Anchored = true
	base.Size = Vector3.new(16, 10, 14)
	base.Position = pos + Vector3.new(0, 5, 0)
	base.Color = Color3.fromRGB(120, 80, 50)
	base.Material = Enum.Material.Wood
	base.Parent = model

	local roof = Instance.new("WedgePart")
	roof.Anchored = true
	roof.Size = Vector3.new(18, 5, 16)
	roof.CFrame = CFrame.new(pos + Vector3.new(0, 12.5, 0))
	roof.Color = Color3.fromRGB(80, 40, 20)
	roof.Material = Enum.Material.Slate
	roof.Parent = model

	local door = Instance.new("Part")
	door.Anchored = true
	door.Size = Vector3.new(3.5, 6, 0.4)
	door.CFrame = CFrame.new(pos + Vector3.new(0, 3, -7))
	door.Color = Color3.fromRGB(60, 40, 20)
	door.Material = Enum.Material.Wood
	door.Parent = model

	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 1.4
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Parent = base

	model.PrimaryPart = base
end

-- ── Structures: camps ────────────────────────────────────────────────────
local function buildCamp(pos: Vector3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Camp"
	model.Parent = parent

	-- Fire pit
	local pit = Instance.new("Part")
	pit.Shape = Enum.PartType.Cylinder
	pit.Anchored = true
	pit.Size = Vector3.new(1, 5, 5)
	pit.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pit.Color = Color3.fromRGB(40, 30, 25)
	pit.Material = Enum.Material.Slate
	pit.Parent = model

	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Heat = 12
	fire.Parent = pit

	-- Two tents flanking the pit.
	for i = 1, 2 do
		local tent = Instance.new("WedgePart")
		tent.Anchored = true
		tent.Size = Vector3.new(8, 5, 6)
		local offset = Vector3.new(if i == 1 then -7 else 7, 2.5, 4)
		tent.CFrame = CFrame.new(pos + offset) * CFrame.Angles(0, math.rad(if i == 1 then 90 else -90), 0)
		tent.Color = Color3.fromRGB(150, 120, 80)
		tent.Material = Enum.Material.Fabric
		tent.Parent = model
	end

	-- Small crate (lootable hook; CombatHandler's pickup system looks for this name).
	local crate = Instance.new("Part")
	crate.Name = "LootCrate"
	crate.Anchored = true
	crate.Size = Vector3.new(3, 3, 3)
	crate.CFrame = CFrame.new(pos + Vector3.new(6, 1.5, -4))
	crate.Color = Color3.fromRGB(100, 70, 40)
	crate.Material = Enum.Material.WoodPlanks
	crate.Parent = model
end

-- ── Caves ────────────────────────────────────────────────────────────────
local function buildCave(pos: Vector3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Cave"
	model.Parent = parent

	-- Hollow dome using an inverted negative-ish approach: big dark rock pile
	-- with a tunnel portal. Not a true voxel cave, but marks the location
	-- clearly so players can navigate to it.
	for i = 1, 12 do
		local chunk = Instance.new("Part")
		chunk.Anchored = true
		local s = rng:NextInteger(10, 20)
		chunk.Size = Vector3.new(s, s, s)
		local angle = (i / 12) * math.pi * 2
		chunk.Position = pos + Vector3.new(math.cos(angle) * 14, s / 2 - 2, math.sin(angle) * 14)
		chunk.Color = Color3.fromRGB(60, 55, 60)
		chunk.Material = Enum.Material.Rock
		chunk.Parent = model
	end

	local portal = Instance.new("Part")
	portal.Name = "CavePortal"
	portal.Anchored = true
	portal.CanCollide = false
	portal.Size = Vector3.new(12, 10, 2)
	portal.Position = pos + Vector3.new(0, 5, -14)
	portal.Color = Color3.fromRGB(10, 5, 15)
	portal.Material = Enum.Material.SmoothPlastic
	portal.Transparency = 0.1
	portal.Parent = model

	table.insert(WorldState.CavePortals, portal.Position)
end

-- ── Market plaza ─────────────────────────────────────────────────────────
local function buildMarket(parent: Instance)
	local pos = Vector3.new(0, 4, 0)
	WorldState.MarketCenter = pos

	local plaza = Instance.new("Part")
	plaza.Anchored = true
	plaza.Size = Vector3.new(80, 1, 80)
	plaza.Position = pos + Vector3.new(0, -1.5, 0)
	plaza.Color = Color3.fromRGB(200, 180, 140)
	plaza.Material = Enum.Material.Cobblestone
	plaza.Parent = parent

	-- Four stalls, one per quadrant.
	local names = { "Weapons", "Traps", "Potions", "Exotic" }
	for i = 1, 4 do
		local angle = (i - 1) * math.pi / 2
		local stallPos = pos + Vector3.new(math.cos(angle) * 20, 1, math.sin(angle) * 20)

		local stall = Instance.new("Part")
		stall.Anchored = true
		stall.Size = Vector3.new(10, 6, 10)
		stall.Position = stallPos + Vector3.new(0, 3, 0)
		stall.Color = Color3.fromRGB(200, 160, 110)
		stall.Material = Enum.Material.Wood
		stall.Parent = parent

		local roof = Instance.new("Part")
		roof.Anchored = true
		roof.Size = Vector3.new(12, 0.5, 12)
		roof.Position = stallPos + Vector3.new(0, 6.5, 0)
		roof.Color = Color3.fromRGB(160, 60, 60)
		roof.Material = Enum.Material.Fabric
		roof.Parent = parent

		local label = Instance.new("BillboardGui")
		label.Adornee = stall
		label.Size = UDim2.fromOffset(200, 40)
		label.AlwaysOnTop = true
		label.StudsOffset = Vector3.new(0, 5, 0)
		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.fromScale(1, 1)
		txt.BackgroundTransparency = 1
		txt.Text = names[i]
		txt.TextColor3 = Color3.fromRGB(255, 240, 180)
		txt.TextStrokeTransparency = 0
		txt.TextScaled = true
		txt.Font = Enum.Font.Fantasy
		txt.Parent = label
		label.Parent = stall
	end

	-- Central "merchant" marker — proximity trigger handled client-side.
	local marker = Instance.new("Part")
	marker.Name = "MarketMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.Size = Vector3.new(4, 8, 4)
	marker.Position = pos + Vector3.new(0, 4, 0)
	marker.Color = Color3.fromRGB(240, 200, 80)
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.35
	marker.Parent = parent
end

-- ── Scatter structures ───────────────────────────────────────────────────
local function randomFlatPoint(minDist: number): Vector3
	for _ = 1, 60 do
		local x = rng:NextNumber(-HALF + 60, HALF - 60)
		local z = rng:NextNumber(-HALF + 60, HALF - 60)
		if x * x + z * z > minDist * minDist then
			local biome = biomeAt(x, z)
			if biome ~= "Shore" then
				local y = math.noise(x * 0.01, z * 0.01) * 6 + 2
				return Vector3.new(x, y, z)
			end
		end
	end
	return Vector3.new(rng:NextNumber(-HALF, HALF), 2, rng:NextNumber(-HALF, HALF))
end

local function scatter()
	for _ = 1, GameConfig.Cabins do
		local p = randomFlatPoint(90)
		buildCabin(p, StructuresFolder)
		table.insert(WorldState.CabinPositions, p)
	end
	for _ = 1, GameConfig.Camps do
		local p = randomFlatPoint(70)
		buildCamp(p, StructuresFolder)
		table.insert(WorldState.CampPositions, p)
	end
	for _ = 1, GameConfig.Caves do
		local p = randomFlatPoint(130)
		buildCave(p, CavesFolder)
	end
end

-- ── Spawn location for players ───────────────────────────────────────────
local function ensureSpawnLocation()
	local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Position = Vector3.new(0, 6, 30)
		spawn.Color = Color3.fromRGB(240, 200, 80)
		spawn.Material = Enum.Material.Neon
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Parent = Workspace
	end
end

-- ── Go ───────────────────────────────────────────────────────────────────
buildOcean()
buildTerrain()
buildMarket(MarketFolder)
scatter()
ensureSpawnLocation()

print(("[WorldBuilder] anchors=%d cabins=%d camps=%d caves=%d"):format(
	#WorldState.SpawnAnchors,
	#WorldState.CabinPositions,
	#WorldState.CampPositions,
	#WorldState.CavePortals
))
