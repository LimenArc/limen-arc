--!strict
-- Handles throwing a trap at a target monster. The server consumes an item,
-- runs a capture roll (based on trap type, monster rarity, and current HP%),
-- and — on success — removes the monster from the world and adds it to the
-- player's party as a CaughtMonster.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))
local MonsterData = require(Modules:WaitForChild("MonsterData"))
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local RARITY_RESIST_BONUS: { [string]: number } = {
	Common = 0, Uncommon = 0.1, Rare = 0.2, Epic = 0.35, Legendary = 0.55,
}

local function rollCapture(def: MonsterData.MonsterDef, hpFraction: number, trap: ItemData.ItemDef, flags: { [string]: any }): boolean
	if flags.InstantCapture then return true end
	local base = trap.Stats.CatchBonus or 0
	local resist = def.CaptureResistance + (RARITY_RESIST_BONUS[def.Rarity] or 0)
	-- Low-HP monsters are much easier to catch.
	local hpFactor = 1 - (hpFraction * 0.7)
	local p = math.clamp(base + hpFactor - resist, 0.02, 0.98)
	return math.random() < p
end

Remotes.Events.ThrowTrap.OnServerEvent:Connect(function(player, trapId, target)
	if typeof(trapId) ~= "string" then return end
	if typeof(target) ~= "Instance" or not target:IsA("Model") then return end
	if not CollectionService:HasTag(target, "WildMonster") then return end

	local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
	if not save then return end

	local trap = ItemData.Get(trapId)
	if not trap or trap.Kind ~= "Trap" then return end

	local flags = _G.ModMenu and _G.ModMenu.GetFlags(player) or {}

	-- Cost the trap unless mod menu says otherwise.
	if not flags.InfiniteMoney then
		if not _G.PlayerData.TakeItem(player, trapId, 1) then
			Remotes.Events.Notify:FireClient(player, "You don't have that trap.")
			return
		end
	end

	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local speciesTag = target:FindFirstChild("SpeciesId") :: StringValue?
	local def = speciesTag and MonsterData.Get(speciesTag.Value)
	if not def then return end

	local hpFrac = humanoid.Health / math.max(1, humanoid.MaxHealth)
	local success = rollCapture(def, hpFrac, trap, flags)

	if success then
		local mon = {
			Uuid = HttpService:GenerateGUID(false),
			SpeciesId = def.Id,
			Nickname = nil,
			Level = 1 + math.floor(hpFrac * 4),
			XP = 0,
			CurrentHP = def.BaseHP,
			MaxHP = def.BaseHP,
		}
		_G.PlayerData.AddMonster(player, mon)
		target:Destroy()
		Remotes.Events.CaptureResult:FireClient(player, true, def.Id, mon.Uuid)
		Remotes.Events.Notify:FireClient(player, ("Caught %s!"):format(def.DisplayName))
	else
		-- Failed trap: aggroes the monster.
		local root = target.PrimaryPart
		if root then
			local char = player.Character
			local playerRoot = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if playerRoot then
				humanoid:MoveTo(playerRoot.Position)
			end
		end
		Remotes.Events.CaptureResult:FireClient(player, false, def.Id, nil)
		Remotes.Events.Notify:FireClient(player, ("%s broke free!"):format(def.DisplayName))
	end
end)
