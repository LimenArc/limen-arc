--!strict

local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes    = require(ReplicatedStorage.Remotes)
local MovesetData = require(ReplicatedStorage.Modules.MovesetData)

type MoveData = MovesetData.MoveData

-- Wait for PlayerSetup to expose its API
while not _G.PlayerSetup do task.wait() end
local PlayerSetup = _G.PlayerSetup

-- Wait for RoundManager
while not _G.RoundManager do task.wait() end
local RoundManager = _G.RoundManager

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function getCharacterAndHRP(player: Player): (Model?, BasePart?)
	local char = player.Character
	if not char then return nil, nil end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return char, hrp
end

local function isAlive(char: Model?): boolean
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function isIframe(userId: number): boolean
	local state = PlayerSetup.GetState(Players:GetPlayerByUserId(userId))
	if not state then return false end
	return os.clock() < state.iFrameUntil
end

local function getLiveTargets(attackerChar: Model, range: number): { Player }
	local hrp = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return {} end
	local origin = hrp.Position
	local targets: { Player } = {}
	for _, taggedChar in ipairs(CollectionService:GetTagged("VSPlayer")) do
		if taggedChar == attackerChar then continue end
		if not isAlive(taggedChar) then continue end
		local targetHRP = taggedChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not targetHRP then continue end
		if (targetHRP.Position - origin).Magnitude <= range then
			local targetPlayer = Players:GetPlayerFromCharacter(taggedChar)
			if targetPlayer then
				table.insert(targets, targetPlayer)
			end
		end
	end
	return targets
end

local function getProjectileTarget(attackerChar: Model, range: number): Player?
	local hrp = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return nil end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { attackerChar }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * range, params)
	if not result then return nil end
	local hit = result.Instance
	local hitChar = hit:FindFirstAncestorOfClass("Model")
	if not hitChar or not isAlive(hitChar) then return nil end
	if not CollectionService:HasTag(hitChar, "VSPlayer") then return nil end
	return Players:GetPlayerFromCharacter(hitChar)
end

-- ── Kill handling ─────────────────────────────────────────────────────────────

local function handleKill(killer: Player, victim: Player)
	local ks = PlayerSetup.GetState(killer)
	if ks then ks.kills += 1 end

	Remotes.Events.KillFeedEvent:FireAllClients(killer.Name, victim.Name)
	RoundManager.OnKill(killer, victim)

	-- Humanoid.Died in PlayerSetup triggers the respawn countdown
end

-- ── Damage application ────────────────────────────────────────────────────────

local function applyDamage(attacker: Player, target: Player, rawDamage: number)
	if isIframe(target.UserId) then return end

	local mechanics = PlayerSetup.GetMechanics()
	local targetState = PlayerSetup.GetState(target)
	local reduction = targetState and targetState.isBlocking
		and mechanics.BlockDamageReduction or 0

	local damage = rawDamage * mechanics.DamageMultiplier * (1 - reduction)

	local char = target.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	hum:TakeDamage(damage)

	if hum.Health <= 0 then
		handleKill(attacker, target)
	end
end

-- ── Basic attack ──────────────────────────────────────────────────────────────

Remotes.Events.CombatBasicAttack.OnServerEvent:Connect(function(player: Player)
	local state = PlayerSetup.GetState(player)
	if not state then return end

	local now = os.clock()
	local mechanics = PlayerSetup.GetMechanics()

	if (now - state.lastBasicTime) < mechanics.BasicCooldown then return end
	state.lastBasicTime = now

	local char, _ = getCharacterAndHRP(player)
	if not isAlive(char) then return end

	for _, target in ipairs(getLiveTargets(char :: Model, mechanics.BasicRange)) do
		applyDamage(player, target, mechanics.BasicDamage)
	end
end)

-- ── Skill attacks ─────────────────────────────────────────────────────────────

Remotes.Events.CombatSkill.OnServerEvent:Connect(function(player: Player, skillSlot: unknown)
	if type(skillSlot) ~= "string" then return end
	if skillSlot ~= "1" and skillSlot ~= "2" and skillSlot ~= "3"
		and skillSlot ~= "4" and skillSlot ~= "5" then return end

	local state = PlayerSetup.GetState(player)
	if not state then return end

	local move = state.moveset.moves[skillSlot]
	if not move then return end

	local now = os.clock()
	if (now - state.lastSkillTime[skillSlot]) < move.cooldown then return end
	state.lastSkillTime[skillSlot] = now

	local char, _ = getCharacterAndHRP(player)
	if not isAlive(char) then return end
	local charModel = char :: Model

	if move.type == "projectile" then
		local target = getProjectileTarget(charModel, move.range)
		if target then
			applyDamage(player, target, move.damage)
		end
	elseif move.type == "dash" then
		-- Dash: grant iframes; movement handled client-side
		state.iFrameUntil   = now + PlayerSetup.GetMechanics().DashIframeDuration
		state.lastDashTime  = now
		-- Still deal damage to targets in melee range at start of dash
		for _, target in ipairs(getLiveTargets(charModel, move.range * 0.5)) do
			applyDamage(player, target, move.damage)
		end
	else
		-- melee / grab / aoe — magnitude check
		local targets = getLiveTargets(charModel, move.range)
		for _, target in ipairs(targets) do
			applyDamage(player, target, move.damage)
		end
	end
end)

-- ── Block ─────────────────────────────────────────────────────────────────────

Remotes.Events.CombatBlock.OnServerEvent:Connect(function(player: Player, isBlocking: unknown)
	if type(isBlocking) ~= "boolean" then return end
	local state = PlayerSetup.GetState(player)
	if not state then return end
	state.isBlocking = isBlocking
end)

-- ── Dash (standalone dodge, not a skill) ─────────────────────────────────────

local DASH_COOLDOWN = 1.0

Remotes.Events.CombatDash.OnServerEvent:Connect(function(player: Player)
	local state = PlayerSetup.GetState(player)
	if not state then return end

	local now = os.clock()
	if (now - state.lastDashTime) < DASH_COOLDOWN then return end

	state.iFrameUntil  = now + PlayerSetup.GetMechanics().DashIframeDuration
	state.lastDashTime = now
end)

_G.CombatCore = {}
