--!strict
-- Handles BuySpeedUpgrade and BuyBaseSlots remote events.
-- Validates coins, applies upgrades, and pushes save snapshots.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local LuckyBlockData = require(Modules:WaitForChild("LuckyBlockData"))
local GameConfig     = require(Modules:WaitForChild("GameConfig"))
local Remotes        = require(ReplicatedStorage:WaitForChild("Remotes"))

-- ── Apply speed to character ──────────────────────────────────────────────

local function applySpeed(player: Player, level: number)
	local tier = LuckyBlockData.GetSpeedTier(level)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if humanoid then
		humanoid.WalkSpeed = tier.WalkSpeed
	end
end

-- ── Buy speed upgrade ─────────────────────────────────────────────────────

Remotes.Events.BuySpeedUpgrade.OnServerEvent:Connect(function(player: Player)
	local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
	if not save then return end

	local currentLevel = save.SpeedLevel or 0
	local nextLevel = currentLevel + 1
	local nextTier = LuckyBlockData.GetSpeedTier(nextLevel)

	if nextLevel > #LuckyBlockData.SpeedTiers - 1 then
		Remotes.Events.Notify:FireClient(player, "Speed is already maxed out!")
		return
	end

	local flags = _G.ModMenu and _G.ModMenu.GetFlags(player) or {}
	local cost = if flags.FreeUpgrades then 0 else nextTier.Cost

	if save.Coins < cost then
		Remotes.Events.Notify:FireClient(player,
			("Not enough coins! Need %d, have %d."):format(cost, save.Coins))
		return
	end

	save.Coins -= cost
	save.SpeedLevel = nextLevel
	applySpeed(player, nextLevel)
	_G.PlayerData.Push(player)

	Remotes.Events.Notify:FireClient(player,
		("⚡ Speed upgraded to %s (WalkSpeed %d)!"):format(nextTier.Label, nextTier.WalkSpeed))
end)

-- ── Buy base slot expansion ───────────────────────────────────────────────

Remotes.Events.BuyBaseSlots.OnServerEvent:Connect(function(player: Player)
	local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
	if not save then return end

	local currentSlots = save.BaseSlotCount or 4
	-- Find the next tier that gives more slots.
	local nextTier: LuckyBlockData.BaseSlotTier? = nil
	for _, tier in ipairs(LuckyBlockData.BaseSlotTiers) do
		if tier.Slots > currentSlots then
			nextTier = tier
			break
		end
	end

	if not nextTier then
		Remotes.Events.Notify:FireClient(player, "Base slots are already at maximum!")
		return
	end

	local flags = _G.ModMenu and _G.ModMenu.GetFlags(player) or {}
	local cost = if flags.FreeUpgrades then 0 else nextTier.Cost

	if save.Coins < cost then
		Remotes.Events.Notify:FireClient(player,
			("Not enough coins! Need %d, have %d."):format(cost, save.Coins))
		return
	end

	save.Coins -= cost
	save.BaseSlotCount = nextTier.Slots
	_G.PlayerData.Push(player)

	-- Refresh figurines to reveal newly unlocked pedestals.
	if _G.BaseManager then
		_G.BaseManager.RefreshPlot(player.UserId)
	end

	Remotes.Events.Notify:FireClient(player,
		("🏠 Base expanded to %d slots!"):format(nextTier.Slots))
end)

-- ── Re-apply speed on character spawn ─────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
		if save then applySpeed(player, save.SpeedLevel or 0) end
	end)
end)

print("[SpeedUpgradeHandler] ready")
