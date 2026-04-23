--!strict
-- Click / tap to attack + F / throw-trap-button to capture. Works on
-- keyboard+mouse, gamepad, and Android touch.
--
-- Target detection: raycast from the camera through the last input's
-- screen position. On PC this is the mouse position; on mobile this is the
-- tap position. Using GetMouseLocation() works on both because Roblox
-- emulates the mouse for touch taps.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local selectedTrapId = "trap_basic"

local function findWildMonsterFromInstance(inst: Instance?): Model?
	while inst do
		if inst:IsA("Model") and CollectionService:HasTag(inst, "WildMonster") then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

-- Raycast to whatever the user tapped / clicked.
local function monsterUnderScreenPoint(x: number, y: number): Model?
	local ray = camera:ViewportPointToRay(x, y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if player.Character then
		params.FilterDescendantsInstances = { player.Character }
	end
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if hit then return findWildMonsterFromInstance(hit.Instance) end
	return nil
end

-- Closest wild monster within N studs (for on-screen Attack / Catch buttons
-- that don't have a precise tap target).
local function nearestMonster(radius: number): Model?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local world = Workspace:FindFirstChild("World")
	local spawns = world and world:FindFirstChild("MonsterSpawns")
	if not spawns then return nil end
	local best, bestDist = nil :: Model?, radius
	for _, mob in ipairs(spawns:GetChildren()) do
		if mob:IsA("Model") and mob.PrimaryPart and CollectionService:HasTag(mob, "WildMonster") then
			local d = (mob.PrimaryPart.Position - root.Position).Magnitude
			if d < bestDist then
				best = mob
				bestDist = d
			end
		end
	end
	return best
end

-- Unified "attempt attack" / "attempt throw" helpers used by inputs + buttons.
local function attemptAttack(target: Model?)
	local t = target or nearestMonster(20)
	if t then Remotes.Events.CombatAttack:FireServer(t) end
end

local function attemptThrow(target: Model?)
	local t = target or nearestMonster(40)
	if t then Remotes.Events.ThrowTrap:FireServer(selectedTrapId, t) end
end

-- ── Input: handles mouse click AND touch tap ─────────────────────────────
-- We ignore taps that landed on GUI (processed = true).
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local isClickOrTap =
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	if isClickOrTap then
		local pos = input.Position  -- Vector3 on touch, Vector2-ish on mouse
		local target = monsterUnderScreenPoint(pos.X, pos.Y)
		if target then
			attemptAttack(target)
		end
	elseif input.KeyCode == Enum.KeyCode.F then
		local loc = UserInputService:GetMouseLocation()
		attemptThrow(monsterUnderScreenPoint(loc.X, loc.Y))
	elseif input.KeyCode == Enum.KeyCode.One then selectedTrapId = "trap_basic"
	elseif input.KeyCode == Enum.KeyCode.Two then selectedTrapId = "trap_strong"
	elseif input.KeyCode == Enum.KeyCode.Three then selectedTrapId = "trap_shock"
	elseif input.KeyCode == Enum.KeyCode.Four then selectedTrapId = "trap_lure"
	elseif input.KeyCode == Enum.KeyCode.Five then selectedTrapId = "trap_master"
	end
end)

-- ── Exposed for HUD + action bar ─────────────────────────────────────────
_G.Combat = {
	SelectedTrap = function() return selectedTrapId end,
	SetTrap = function(id: string) selectedTrapId = id end,
	Attack = attemptAttack,
	Throw = attemptThrow,
}
_G.SelectedTrap = function() return selectedTrapId end
