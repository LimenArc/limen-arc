--!strict
-- Consumable use path. Potions, candies, revives. Keeps inventory authoritative.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))
local Inventory = require(Modules:WaitForChild("Inventory"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

Remotes.Events.UseItem.OnServerEvent:Connect(function(player, itemId, targetUuid)
	if typeof(itemId) ~= "string" then return end
	local save = _G.PlayerData and _G.PlayerData.Get(player.UserId); if not save then return end
	if Inventory.ItemCount(save, itemId) <= 0 then return end

	local def = ItemData.Get(itemId)
	if not def then return end

	if def.Kind == "Weapon" then
		save.EquippedWeaponId = itemId
		_G.PlayerData.Push(player)
		Remotes.Events.Notify:FireClient(player, ("Equipped %s."):format(def.DisplayName))
		return
	elseif def.Kind ~= "Consumable" then
		return
	end

	-- Heal player self (if no target monster specified).
	if def.Stats.HealAmount and not targetUuid then
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + def.Stats.HealAmount)
			_G.PlayerData.TakeItem(player, itemId, 1)
			Remotes.Events.Notify:FireClient(player, ("+%d HP."):format(def.Stats.HealAmount))
			return
		end
	end

	-- Targeted monster effects.
	if typeof(targetUuid) == "string" then
		local mon = Inventory.FindMonster(save, targetUuid); if not mon then return end
		if def.Stats.HealAmount then
			mon.CurrentHP = math.min(mon.MaxHP, mon.CurrentHP + def.Stats.HealAmount)
		end
		if def.Stats.ReviveFraction and mon.CurrentHP <= 0 then
			mon.CurrentHP = math.floor(mon.MaxHP * def.Stats.ReviveFraction)
		end
		if def.Stats.XPLevels then
			mon.Level += def.Stats.XPLevels
			mon.MaxHP = math.floor(mon.MaxHP * 1.08)
			mon.CurrentHP = mon.MaxHP
		end
		_G.PlayerData.TakeItem(player, itemId, 1)
		_G.PlayerData.Push(player)
	end
end)
