--!strict
-- Populates the world with wild monsters in biome-appropriate locations.
-- Mobs are represented as simple models with Humanoid + primary colored parts
-- so combat and capture work uniformly. WorldBuilder must run first.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local MonsterData = require(Modules:WaitForChild("MonsterData"))

-- Wait for WorldBuilder to finish.
while not _G.WorldState do task.wait(0.1) end
local WorldState = _G.WorldState

local monstersFolder = Workspace:FindFirstChild("World"):FindFirstChild("MonsterSpawns")
if not monstersFolder then
	monstersFolder = Instance.new("Folder")
	monstersFolder.Name = "MonsterSpawns"
	monstersFolder.Parent = Workspace:FindFirstChild("World")
end

-- ── Spawn selection ──────────────────────────────────────────────────────
local rng = Random.new()

local RARITY_WEIGHT: { [string]: number } = {
	Common    = 55,
	Uncommon  = 25,
	Rare      = 12,
	Epic      = 6,
	Legendary = 2,
}

local function pickSpeciesForBiome(biome: string)
	local pool = MonsterData.ForBiome(biome)
	if #pool == 0 then return nil end
	local total = 0
	for _, def in ipairs(pool) do total += (RARITY_WEIGHT[def.Rarity] or 1) end
	local roll = rng:NextNumber(0, total)
	local running = 0
	for _, def in ipairs(pool) do
		running += (RARITY_WEIGHT[def.Rarity] or 1)
		if roll <= running then return def end
	end
	return pool[#pool]
end

-- ── Model factory ────────────────────────────────────────────────────────
local function buildMonsterModel(def: MonsterData.MonsterDef, pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = def.DisplayName

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = def.Size
	body.Color = def.PrimaryColor
	body.Material = Enum.Material.SmoothPlastic
	body.Position = pos + Vector3.new(0, def.Size.Y / 2, 0)
	body.Anchored = false
	body.CanCollide = true
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(def.Size.X * 0.7, def.Size.Y * 0.7, def.Size.X * 0.7)
	head.Color = def.SecondaryColor
	head.Material = Enum.Material.SmoothPlastic
	head.Position = body.Position + Vector3.new(0, def.Size.Y * 0.7, -def.Size.Z * 0.4)
	head.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = head
	weld.Parent = body

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = def.BaseHP
	humanoid.Health = def.BaseHP
	humanoid.WalkSpeed = def.BaseSpeed
	humanoid.DisplayName = def.DisplayName
	humanoid.Parent = model

	model.PrimaryPart = body

	-- Data the rest of the server reads off of the instance.
	local idTag = Instance.new("StringValue")
	idTag.Name = "SpeciesId"
	idTag.Value = def.Id
	idTag.Parent = model

	local rarityTag = Instance.new("StringValue")
	rarityTag.Name = "Rarity"
	rarityTag.Value = def.Rarity
	rarityTag.Parent = model

	CollectionService:AddTag(model, "WildMonster")
	return model
end

-- ── Simple wander AI ─────────────────────────────────────────────────────
local function startWandering(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	task.spawn(function()
		while model.Parent and humanoid.Health > 0 do
			local here = model.PrimaryPart and model.PrimaryPart.Position or Vector3.zero
			local dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
			humanoid:MoveTo(here + dir * rng:NextNumber(12, 40))
			task.wait(rng:NextNumber(3, 7))
		end
	end)
end

-- ── Spawn loop ───────────────────────────────────────────────────────────
local alive = 0

local function spawnOne()
	if alive >= GameConfig.MaxWildMonsters then return end
	local anchor = WorldState.SpawnAnchors[rng:NextInteger(1, #WorldState.SpawnAnchors)]
	if not anchor then return end
	local def = pickSpeciesForBiome(anchor.Biome)
	if not def then return end

	local jitter = Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10))
	local model = buildMonsterModel(def, anchor.Position + jitter)
	model.Parent = monstersFolder

	alive += 1
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		alive -= 1
		task.wait(3)
		if model.Parent then model:Destroy() end
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then alive = math.max(0, alive - 1) end
	end)

	startWandering(model)
end

-- Initial population.
for _ = 1, math.floor(GameConfig.MaxWildMonsters * 0.6) do
	spawnOne()
end

-- Drip feed respawns.
task.spawn(function()
	while true do
		task.wait(GameConfig.RespawnSeconds)
		spawnOne()
	end
end)

-- Public: used by ModMenuHandler to force-spawn a specific species.
local MonsterSpawner = {}
_G.MonsterSpawner = MonsterSpawner

function MonsterSpawner.SpawnSpecies(speciesId: string, position: Vector3): Model?
	local def = MonsterData.Get(speciesId)
	if not def then return nil end
	local model = buildMonsterModel(def, position)
	model.Parent = monstersFolder
	alive += 1
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.Died:Connect(function() alive -= 1 end)
	startWandering(model)
	return model
end
