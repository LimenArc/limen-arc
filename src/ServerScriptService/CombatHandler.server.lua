--!strict
-- Server-authoritative combat. The client asks to attack a target; the server
-- validates weapon/range/cooldown and applies damage. Dropping a wild monster
-- to zero HP yields coins. Trapping is handled in TrapHandler.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))
local MonsterData = require(Modules:WaitForChild("MonsterData"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local lastAttack: { [Player]: number } = {}

local function getModFlags(player: Player)
	return _G.ModMenu and _G.ModMenu.GetFlags(player) or {}
end

Remotes.Events.CombatAttack.OnServerEvent:Connect(function(player, target)
	if typeof(target) ~= "Instance" or not target:IsA("Model") then return end
	if not CollectionService:HasTag(target, "WildMonster") then return end

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	local targetRoot = target.PrimaryPart
	if not targetRoot then return end

	local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
	if not save then return end

	local weaponId = save.EquippedWeaponId or "stick"
	local weapon = ItemData.Get(weaponId)
	if not weapon or weapon.Kind ~= "Weapon" then return end

	-- Cooldown.
	local now = os.clock()
	local nextOk = (lastAttack[player] or 0) + (weapon.Stats.SwingSpeed or 1)
	if now < nextOk then return end
	lastAttack[player] = now

	-- Range.
	local dist = (root.Position - targetRoot.Position).Magnitude
	if dist > (weapon.Stats.Range or 6) + 2 then return end

	-- Damage.
	local flags = getModFlags(player)
	local multiplier = flags.DamageMultiplier or 1
	local dmg = (weapon.Stats.Damage or 1) * multiplier

	-- Armor pierce.
	local speciesId = target:FindFirstChild("SpeciesId")
	local def = speciesId and MonsterData.Get((speciesId :: StringValue).Value)
	if def then
		local pierce = weapon.Stats.ArmorPierce or 0
		local effectiveDef = def.BaseDefense * (1 - pierce)
		dmg = math.max(1, dmg - effectiveDef * 0.1)
	end

	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	humanoid:TakeDamage(dmg)

	if humanoid.Health <= 0 and def then
		_G.PlayerData.AddCoins(player, math.floor(def.CoinValue * 0.4))
		Remotes.Events.Notify:FireClient(player, ("Defeated %s. +%d coins"):format(def.DisplayName, math.floor(def.CoinValue * 0.4)))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttack[player] = nil
end)
