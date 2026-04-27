--!strict

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovesetData = require(ReplicatedStorage.Modules.MovesetData)
local GameConfig  = require(ReplicatedStorage.Modules.GameConfig)
local Remotes     = require(ReplicatedStorage.Remotes)

type MovesetDef  = MovesetData.MovesetDef
type MechanicsConfig = GameConfig.MechanicsConfig

-- ── Per-player state ─────────────────────────────────────────────────────────

export type PlayerState = {
	moveset:       MovesetDef,
	isBlocking:    boolean,
	lastBasicTime: number,
	lastSkillTime: { [string]: number },
	iFrameUntil:   number,
	lastDashTime:  number,
	kills:         number,
	deaths:        number,
}

local states: { [number]: PlayerState } = {} -- keyed by UserId

-- Session-global mechanics (shared across all players)
local currentMechanics: MechanicsConfig = table.clone(GameConfig.DefaultMechanics) :: MechanicsConfig

-- ── Public API ───────────────────────────────────────────────────────────────

local PlayerSetup = {}
_G.PlayerSetup = PlayerSetup

function PlayerSetup.GetState(player: Player): PlayerState?
	return states[player.UserId]
end

function PlayerSetup.GetMoveset(player: Player): MovesetDef
	local s = states[player.UserId]
	if s then return s.moveset end
	return MovesetData.Get(GameConfig.DefaultMovesetName) :: MovesetDef
end

function PlayerSetup.SetMoveset(player: Player, def: MovesetDef)
	local s = states[player.UserId]
	if not s then return end
	s.moveset = def
	PlayerSetup.PushState(player)
end

function PlayerSetup.GetMechanics(): MechanicsConfig
	return currentMechanics
end

function PlayerSetup.SetMechanics(mechanics: MechanicsConfig)
	currentMechanics = mechanics
end

function PlayerSetup.PushState(player: Player)
	local s = states[player.UserId]
	if not s then return end
	local char = player.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	Remotes.Events.PlayerStateUpdate:FireClient(player, {
		hp         = hum and hum.Health    or 0,
		maxHp      = hum and hum.MaxHealth or currentMechanics.MaxHP,
		moveset    = s.moveset,
		isBlocking = s.isBlocking,
	})
end

function PlayerSetup.ResetKills(player: Player)
	local s = states[player.UserId]
	if s then
		s.kills  = 0
		s.deaths = 0
	end
end

-- ── Character setup ──────────────────────────────────────────────────────────

local function setupCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then return end

	-- Apply current mechanics
	hum.MaxHealth = currentMechanics.MaxHP
	hum.Health    = currentMechanics.MaxHP
	hum.WalkSpeed = currentMechanics.MoveSpeed

	-- Disable default Roblox health regen
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local regenScript = char:FindFirstChild("Health")
	if regenScript then regenScript:Destroy() end

	CollectionService:AddTag(char, "VSPlayer")

	-- Push initial state to client
	PlayerSetup.PushState(player)

	-- Handle death → respawn
	hum.Died:Connect(function()
		hum.WalkSpeed = 0

		local s = states[player.UserId]
		if s then s.deaths += 1 end

		local respawnTime = currentMechanics.RespawnTime
		for i = respawnTime, 1, -1 do
			Remotes.Events.RespawnCountdown:FireClient(player, i)
			task.wait(1)
		end
		Remotes.Events.RespawnCountdown:FireClient(player, 0)
		player:LoadCharacter()
	end)
end

-- ── Player lifecycle ─────────────────────────────────────────────────────────

local function onPlayerAdded(player: Player)
	local defaultMoveset = MovesetData.Get(GameConfig.DefaultMovesetName)
	if not defaultMoveset then
		defaultMoveset = MovesetData.GetAll()[1]
	end

	states[player.UserId] = {
		moveset       = defaultMoveset :: MovesetDef,
		isBlocking    = false,
		lastBasicTime = 0,
		lastSkillTime = { ["1"] = 0, ["2"] = 0, ["3"] = 0, ["4"] = 0, ["5"] = 0 },
		iFrameUntil   = 0,
		lastDashTime  = 0,
		kills         = 0,
		deaths        = 0,
	}

	player.CharacterAdded:Connect(function(char)
		setupCharacter(player, char)
	end)

	if player.Character then
		setupCharacter(player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	states[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

-- ── Apply mechanics to all live characters ────────────────────────────────────

function PlayerSetup.ApplyMechanicsToAll()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.MaxHealth = currentMechanics.MaxHP
			if hum.Health > currentMechanics.MaxHP then
				hum.Health = currentMechanics.MaxHP
			end
			hum.WalkSpeed = currentMechanics.MoveSpeed
		end
	end
end
