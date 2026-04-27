--!strict

local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapData   = require(ReplicatedStorage.Modules.MapData)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local Remotes   = require(ReplicatedStorage.Remotes)

type MapDef = MapData.MapDef

-- ── Workspace map folder ─────────────────────────────────────────────────────

local function getOrCreateMapFolder(): Folder
	local existing = workspace:FindFirstChild("Map")
	if existing and existing:IsA("Folder") then return existing end
	if existing then existing:Destroy() end
	local f = Instance.new("Folder")
	f.Name   = "Map"
	f.Parent = workspace
	return f
end

-- ── State ────────────────────────────────────────────────────────────────────

local currentMap: MapDef? = nil

-- ── Public API ───────────────────────────────────────────────────────────────

local MapManager = {}
_G.MapManager    = MapManager

function MapManager.LoadMap(def: MapDef)
	currentMap = def

	local mapFolder = getOrCreateMapFolder()
	mapFolder:ClearAllChildren()

	local platforms = Instance.new("Folder")
	platforms.Name   = "Platforms"
	platforms.Parent = mapFolder

	for _, p in ipairs(def.platforms) do
		local part       = Instance.new("Part")
		part.Anchored    = true
		part.Size        = Vector3.new(p.size[1], p.size[2], p.size[3])
		part.CFrame      = CFrame.new(p.pos[1], p.pos[2], p.pos[3])
		part.Color       = Color3.fromRGB(p.color[1], p.color[2], p.color[3])
		part.Material    = Enum.Material.SmoothPlastic
		part.TopSurface  = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent      = platforms
	end

	-- Approximate sky color via Lighting Ambient
	local r = def.skyboxColor[1] / 255
	local g = def.skyboxColor[2] / 255
	local b = def.skyboxColor[3] / 255
	game:GetService("Lighting").Ambient = Color3.new(r * 0.4, g * 0.4, b * 0.4)
	game:GetService("Lighting").OutdoorAmbient = Color3.new(r * 0.6, g * 0.6, b * 0.6)

	-- Teleport all live players to spawn points
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				local sp = MapManager.GetRandomSpawn()
				hrp.CFrame = CFrame.new(sp)
			end
		end
	end

	Remotes.Events.MapLoaded:FireAllClients(def.name)
	Remotes.Events.Notify:FireAllClients("Map loaded: " .. def.name)
end

function MapManager.GetRandomSpawn(): Vector3
	local def = currentMap
	if not def or #def.spawnPoints == 0 then
		return Vector3.new(0, 5, 0)
	end
	local sp = def.spawnPoints[math.random(1, #def.spawnPoints)]
	return Vector3.new(sp[1], sp[2] + 3, sp[3])
end

function MapManager.GetCurrentMap(): MapDef?
	return currentMap
end

function MapManager.GetBoundary(): number
	if currentMap then return currentMap.boundaries end
	return 100
end

-- ── Kill-floor loop ──────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(0.5)
		local boundary = MapManager.GetBoundary()
		for _, char in ipairs(CollectionService:GetTagged("VSPlayer")) do
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local pos = hrp.Position
				local dist2D = Vector2.new(pos.X, pos.Z).Magnitude
				if dist2D > boundary or pos.Y < -50 then
					hum:TakeDamage(hum.MaxHealth)
				end
			end
		end
	end
end)

-- ── Load default map on start ────────────────────────────────────────────────

local defaultDef = MapData.Get(GameConfig.DefaultMapName)
if defaultDef then
	MapManager.LoadMap(defaultDef)
else
	warn("MapManager: default map '" .. GameConfig.DefaultMapName .. "' not found")
end
