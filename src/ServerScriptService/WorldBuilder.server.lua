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
local WaterFolder = folder("Water", WorldRoot)
local BoatsFolder = folder("Boats", WorldRoot)

-- Shared state that other systems read.
local WorldState = {
	Seed = SEED,
	BiomeAt = biomeAt,
	SpawnAnchors = {} :: { { Position: Vector3, Biome: string } },
	CavePortals = {} :: { Vector3 },
	CabinPositions = {} :: { Vector3 },
	CampPositions = {} :: { Vector3 },
	LakeCenters = {} :: { { Position: Vector3, Radius: number } },
	RiverPath = {} :: { Vector3 },
	BoatDocks = {} :: { Vector3 },
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

-- ── Lakes ────────────────────────────────────────────────────────────────
local function buildLake(center: Vector3, radius: number)
	-- Circular water surface disc + shore-height adjustment is implicit (the
	-- biome map already paints sand at low elevations, but a real lake just
	-- sits on top of the terrain). Add a single water disc + a few smaller
	-- overlapping discs so the outline is organic.
	local main = Instance.new("Part")
	main.Shape = Enum.PartType.Cylinder
	main.Anchored = true
	main.Size = Vector3.new(2, radius * 2, radius * 2)
	main.CFrame = CFrame.new(center + Vector3.new(0, -0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	main.Color = Color3.fromRGB(50, 100, 170)
	main.Material = Enum.Material.Water
	main.Transparency = 0.25
	main.Name = "LakeSurface"
	main.Parent = WaterFolder

	for i = 1, 5 do
		local lobe = Instance.new("Part")
		lobe.Shape = Enum.PartType.Cylinder
		lobe.Anchored = true
		local r = radius * rng:NextNumber(0.5, 0.9)
		local angle = rng:NextNumber(0, math.pi * 2)
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * 0.5
		lobe.Size = Vector3.new(2, r * 2, r * 2)
		lobe.CFrame = CFrame.new(center + offset + Vector3.new(0, -0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		lobe.Color = Color3.fromRGB(50, 100, 170)
		lobe.Material = Enum.Material.Water
		lobe.Transparency = 0.25
		lobe.Name = "LakeSurface"
		lobe.Parent = WaterFolder
	end

	-- Sandy beach ring.
	local beach = Instance.new("Part")
	beach.Shape = Enum.PartType.Cylinder
	beach.Anchored = true
	beach.Size = Vector3.new(1, (radius + 12) * 2, (radius + 12) * 2)
	beach.CFrame = CFrame.new(center + Vector3.new(0, -1.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beach.Color = Color3.fromRGB(230, 210, 160)
	beach.Material = Enum.Material.Sand
	beach.Parent = WaterFolder

	table.insert(WorldState.LakeCenters, { Position = center, Radius = radius })
end

-- ── Rivers ───────────────────────────────────────────────────────────────
-- Meandering strip from a source point to the nearest lake (or ocean edge).
local function buildRiver(fromPos: Vector3, toPos: Vector3)
	local dir = (toPos - fromPos)
	local length = dir.Magnitude
	local steps = math.floor(length / 18)
	if steps < 2 then return end

	local last = fromPos
	for i = 1, steps do
		local t = i / steps
		-- Meander: sine-wave perpendicular offset.
		local straight = fromPos:Lerp(toPos, t)
		local perp = Vector3.new(-dir.Unit.Z, 0, dir.Unit.X)
		local wobble = math.sin(t * math.pi * 3 + rng:NextNumber()) * 22 * (1 - math.abs(t - 0.5) * 0.8)
		local point = straight + perp * wobble
		point = Vector3.new(point.X, -0.4, point.Z)
		table.insert(WorldState.RiverPath, point)

		-- Rectangular segment from last to point.
		local mid = (last + point) / 2
		local segLen = (point - last).Magnitude + 4
		local segment = Instance.new("Part")
		segment.Anchored = true
		segment.Size = Vector3.new(segLen, 1.5, 14)
		local lookDir = (point - last)
		segment.CFrame = CFrame.new(mid, mid + Vector3.new(lookDir.X, 0, lookDir.Z))
			* CFrame.Angles(0, math.rad(90), 0)
		segment.Color = Color3.fromRGB(60, 110, 180)
		segment.Material = Enum.Material.Water
		segment.Transparency = 0.25
		segment.Name = "RiverSegment"
		segment.Parent = WaterFolder

		last = point
	end
end

local function buildWaterways()
	-- Pick 4 lakes distributed around the map (random but non-overlapping).
	local lakeSpecs = {}
	local attempts = 0
	while #lakeSpecs < 4 and attempts < 200 do
		attempts += 1
		local r = rng:NextInteger(55, 95)
		local pos = Vector3.new(
			rng:NextNumber(-HALF + r + 80, HALF - r - 80),
			-0.4,
			rng:NextNumber(-HALF + r + 80, HALF - r - 80)
		)
		-- Keep away from market plaza + other lakes.
		if pos.Magnitude < 120 then continue end
		local ok = true
		for _, other in ipairs(lakeSpecs) do
			if (pos - other.Position).Magnitude < other.Radius + r + 80 then
				ok = false; break
			end
		end
		if ok then
			table.insert(lakeSpecs, { Position = pos, Radius = r })
		end
	end
	for _, lake in ipairs(lakeSpecs) do
		buildLake(lake.Position, lake.Radius)
	end

	-- River from each lake toward the nearest ocean edge.
	for _, lake in ipairs(lakeSpecs) do
		local p = lake.Position
		-- Closest cardinal edge.
		local toEdge
		local dx = HALF - math.abs(p.X); local dz = HALF - math.abs(p.Z)
		if dx < dz then
			toEdge = Vector3.new(math.sign(p.X) * HALF, -0.4, p.Z + rng:NextNumber(-60, 60))
		else
			toEdge = Vector3.new(p.X + rng:NextNumber(-60, 60), -0.4, math.sign(p.Z) * HALF)
		end
		buildRiver(p, toEdge)
	end
end

-- ── Boats ────────────────────────────────────────────────────────────────
-- A "boat" is a VehicleSeat on a floating hull. Anchored by default; the
-- BoatHandler script unanchors it and drives it when a player sits.
local function buildBoat(pos: Vector3)
	local boat = Instance.new("Model")
	boat.Name = "Boat"

	local hull = Instance.new("Part")
	hull.Anchored = true
	hull.Size = Vector3.new(8, 2, 14)
	hull.CFrame = CFrame.new(pos + Vector3.new(0, 1, 0))
	hull.Color = Color3.fromRGB(110, 70, 40)
	hull.Material = Enum.Material.Wood
	hull.TopSurface = Enum.SurfaceType.Smooth
	hull.BottomSurface = Enum.SurfaceType.Smooth
	hull.Name = "Hull"
	hull.Parent = boat

	-- Bow wedge.
	local bow = Instance.new("WedgePart")
	bow.Anchored = true
	bow.Size = Vector3.new(8, 2, 4)
	bow.CFrame = CFrame.new(pos + Vector3.new(0, 1, -9)) * CFrame.Angles(0, math.rad(180), 0)
	bow.Color = Color3.fromRGB(110, 70, 40)
	bow.Material = Enum.Material.Wood
	bow.Parent = boat

	local bowWeld = Instance.new("WeldConstraint")
	bowWeld.Part0 = hull; bowWeld.Part1 = bow; bowWeld.Parent = hull

	-- Seat.
	local seat = Instance.new("VehicleSeat")
	seat.Anchored = true
	seat.Size = Vector3.new(3, 1, 3)
	seat.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
	seat.Color = Color3.fromRGB(80, 50, 30)
	seat.Material = Enum.Material.Wood
	seat.HeadsUpDisplay = false
	seat.Parent = boat

	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = hull; seatWeld.Part1 = seat; seatWeld.Parent = hull

	-- Flag pole.
	local mast = Instance.new("Part")
	mast.Anchored = true
	mast.Size = Vector3.new(0.4, 8, 0.4)
	mast.CFrame = CFrame.new(pos + Vector3.new(0, 6, 3))
	mast.Color = Color3.fromRGB(90, 60, 30)
	mast.Material = Enum.Material.Wood
	mast.Parent = boat

	local mastWeld = Instance.new("WeldConstraint")
	mastWeld.Part0 = hull; mastWeld.Part1 = mast; mastWeld.Parent = hull

	-- Tag so BoatHandler / client can find it.
	boat:AddTag("Boat")
	boat.PrimaryPart = hull
	boat.Parent = BoatsFolder

	return boat
end

local function placeDocksAndBoats()
	-- One small wooden dock + a boat at each lake, plus 2 boats on the shore.
	for _, lake in ipairs(WorldState.LakeCenters) do
		-- Dock on the +X side of the lake.
		local dockPos = lake.Position + Vector3.new(lake.Radius - 4, 1, 0)
		local dock = Instance.new("Part")
		dock.Anchored = true
		dock.Size = Vector3.new(14, 1, 6)
		dock.CFrame = CFrame.new(dockPos)
		dock.Color = Color3.fromRGB(120, 80, 50)
		dock.Material = Enum.Material.Wood
		dock.Name = "Dock"
		dock.Parent = StructuresFolder
		table.insert(WorldState.BoatDocks, dockPos)

		buildBoat(lake.Position + Vector3.new(lake.Radius - 16, 0, 2))
	end

	-- A couple of boats along the ocean ring (south shore + east shore).
	buildBoat(Vector3.new(0, 0, HALF - 40))
	buildBoat(Vector3.new(HALF - 40, 0, 0))
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

-- ── Lucky Block: zone ring markers ───────────────────────────────────────
-- Visual boundary rings at each zone's outer radius so players know when
-- they're approaching a new zone. Uses many thin arc segments.

local LuckyBlockData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("LuckyBlockData"))

local ZoneRingsFolder = folder("ZoneRings", WorldRoot)

local function buildZoneRing(zone: any)
	local radius = zone.MaxRadius
	local segments = 80
	for i = 0, segments - 1 do
		local a1 = (i / segments) * math.pi * 2
		local a2 = ((i + 1) / segments) * math.pi * 2
		local mid = (a1 + a2) / 2
		local px = math.cos(mid) * radius
		local pz = math.sin(mid) * radius
		local h = math.noise(px * 0.01, pz * 0.01) * 6 + 5

		local arc = Instance.new("Part")
		arc.Anchored = true
		arc.CanCollide = false
		arc.Size = Vector3.new(radius * math.pi * 2 / segments * 1.05, 12, 0.5)
		arc.CFrame = CFrame.new(Vector3.new(px, h, pz))
			* CFrame.Angles(0, -mid - math.pi / 2, 0)
		arc.Color = zone.BlockColor
		arc.Material = Enum.Material.Neon
		arc.Transparency = 0.72
		arc.CastShadow = false
		arc.Name = ("ZoneRing_%d"):format(zone.Id)
		arc.Parent = ZoneRingsFolder

		-- Zone label on first segment.
		if i == 0 then
			local bb = Instance.new("BillboardGui")
			bb.Adornee = arc
			bb.Size = UDim2.fromOffset(220, 36)
			bb.StudsOffset = Vector3.new(0, 8, 0)
			bb.AlwaysOnTop = false
			local txt = Instance.new("TextLabel")
			txt.Size = UDim2.fromScale(1, 1)
			txt.BackgroundTransparency = 1
			txt.Text = ("Zone %d: %s"):format(zone.Id, zone.Name)
			txt.Font = Enum.Font.GothamBold
			txt.TextSize = 15
			txt.TextColor3 = zone.BlockGlow
			txt.TextStrokeTransparency = 0
			txt.Parent = bb
			bb.Parent = arc
		end
	end
end

for _, zone in ipairs(LuckyBlockData.Zones) do
	if zone.Id < #LuckyBlockData.Zones then  -- don't draw ring at the void boundary
		buildZoneRing(zone)
	end
end

-- ── Speed Upgrade Station (beside the market) ─────────────────────────────

local function buildUpgradeStation(parent: Instance)
	local pos = Vector3.new(50, 4, 10)

	local base = Instance.new("Part")
	base.Anchored = true
	base.Size = Vector3.new(10, 1, 10)
	base.CFrame = CFrame.new(pos)
	base.Color = Color3.fromRGB(40, 40, 60)
	base.Material = Enum.Material.SmoothPlastic
	base.TopSurface = Enum.SurfaceType.Smooth
	base.Parent = parent

	-- Central pillar.
	local pillar = Instance.new("Part")
	pillar.Anchored = true
	pillar.Size = Vector3.new(2.5, 8, 2.5)
	pillar.CFrame = CFrame.new(pos + Vector3.new(0, 4.5, 0))
	pillar.Color = Color3.fromRGB(60, 60, 90)
	pillar.Material = Enum.Material.Metal
	pillar.Parent = parent

	-- Glowing top orb.
	local orb = Instance.new("Part")
	orb.Anchored = true
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(3, 3, 3)
	orb.CFrame = CFrame.new(pos + Vector3.new(0, 9.5, 0))
	orb.Color = Color3.fromRGB(80, 160, 255)
	orb.Material = Enum.Material.Neon
	orb.Transparency = 0.1
	orb.CastShadow = false
	orb.Parent = parent

	local orbLight = Instance.new("PointLight")
	orbLight.Brightness = 4
	orbLight.Range = 30
	orbLight.Color = Color3.fromRGB(80, 160, 255)
	orbLight.Parent = orb

	-- Arrow ring around the pillar.
	for i = 0, 5 do
		local a = (i / 6) * math.pi * 2
		local arrow = Instance.new("Part")
		arrow.Anchored = true
		arrow.Size = Vector3.new(0.4, 1.2, 0.4)
		arrow.CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 1.8, 5 + i * 0.4, math.sin(a) * 1.8))
		arrow.Color = Color3.fromRGB(120, 200, 255)
		arrow.Material = Enum.Material.Neon
		arrow.Transparency = 0.3
		arrow.CastShadow = false
		arrow.Parent = parent
	end

	-- Billboard label.
	local bb = Instance.new("BillboardGui")
	bb.Adornee = orb
	bb.Size = UDim2.fromOffset(200, 50)
	bb.StudsOffset = Vector3.new(0, 3.5, 0)
	bb.AlwaysOnTop = false
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = "⚡ Speed Upgrades\n[U] to open"
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 14
	lbl.TextColor3 = Color3.fromRGB(140, 210, 255)
	lbl.TextStrokeTransparency = 0
	lbl.Parent = bb
	bb.Parent = orb

	-- ProximityPrompt on the pillar so the client can detect "near upgrade station".
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradeStationPrompt"
	prompt.ActionText = "Upgrade"
	prompt.ObjectText = "Speed Station"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.U
	prompt.Parent = pillar

	WorldState.UpgradeStationPos = pos
end

-- ── Go ───────────────────────────────────────────────────────────────────
buildOcean()
buildTerrain()
buildWaterways()
buildMarket(MarketFolder)
buildUpgradeStation(MarketFolder)
scatter()
placeDocksAndBoats()
ensureSpawnLocation()

print(("[WorldBuilder] anchors=%d cabins=%d camps=%d caves=%d lakes=%d boats=%d zones=%d"):format(
	#WorldState.SpawnAnchors,
	#WorldState.CabinPositions,
	#WorldState.CampPositions,
	#WorldState.CavePortals,
	#WorldState.LakeCenters,
	#BoatsFolder:GetChildren(),
	#LuckyBlockData.Zones
))
