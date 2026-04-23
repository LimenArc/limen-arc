--!strict
-- Stateless helpers that operate on a player's persisted data table.
-- Kept in ReplicatedStorage so the client can preview (read-only) the same shape.

local ItemData = require(script.Parent.ItemData)

export type ItemStack = { Id: string, Count: number }
export type CaughtMonster = {
	Uuid: string,
	SpeciesId: string,
	Nickname: string?,
	Level: number,
	XP: number,
	CurrentHP: number,
	MaxHP: number,
}

export type PlayerSave = {
	Coins: number,
	Items: { ItemStack },
	Monsters: { CaughtMonster },
	ActiveMonsterUuid: string?,
	EquippedWeaponId: string?,
	DiscoveredMonsters: { [string]: boolean },
}

local Inventory = {}

function Inventory.NewSave(startingCoins: number): PlayerSave
	return {
		Coins = startingCoins,
		Items = {},
		Monsters = {},
		ActiveMonsterUuid = nil,
		EquippedWeaponId = nil,
		DiscoveredMonsters = {},
	}
end

function Inventory.AddItem(save: PlayerSave, itemId: string, count: number): boolean
	local def = ItemData.Get(itemId)
	if not def then return false end
	local remaining = count
	for _, stack in ipairs(save.Items) do
		if stack.Id == itemId and stack.Count < def.MaxStack then
			local room = def.MaxStack - stack.Count
			local add = math.min(room, remaining)
			stack.Count += add
			remaining -= add
			if remaining <= 0 then return true end
		end
	end
	while remaining > 0 do
		local add = math.min(def.MaxStack, remaining)
		table.insert(save.Items, { Id = itemId, Count = add })
		remaining -= add
	end
	return true
end

function Inventory.RemoveItem(save: PlayerSave, itemId: string, count: number): boolean
	local have = 0
	for _, stack in ipairs(save.Items) do
		if stack.Id == itemId then have += stack.Count end
	end
	if have < count then return false end

	local remaining = count
	for i = #save.Items, 1, -1 do
		if remaining <= 0 then break end
		local stack = save.Items[i]
		if stack.Id == itemId then
			if stack.Count <= remaining then
				remaining -= stack.Count
				table.remove(save.Items, i)
			else
				stack.Count -= remaining
				remaining = 0
			end
		end
	end
	return true
end

function Inventory.ItemCount(save: PlayerSave, itemId: string): number
	local have = 0
	for _, stack in ipairs(save.Items) do
		if stack.Id == itemId then have += stack.Count end
	end
	return have
end

function Inventory.AddMonster(save: PlayerSave, mon: CaughtMonster)
	table.insert(save.Monsters, mon)
	save.DiscoveredMonsters[mon.SpeciesId] = true
	if not save.ActiveMonsterUuid then
		save.ActiveMonsterUuid = mon.Uuid
	end
end

function Inventory.RemoveMonster(save: PlayerSave, uuid: string): boolean
	for i, mon in ipairs(save.Monsters) do
		if mon.Uuid == uuid then
			table.remove(save.Monsters, i)
			if save.ActiveMonsterUuid == uuid then
				save.ActiveMonsterUuid = if save.Monsters[1] then save.Monsters[1].Uuid else nil
			end
			return true
		end
	end
	return false
end

function Inventory.FindMonster(save: PlayerSave, uuid: string): CaughtMonster?
	for _, mon in ipairs(save.Monsters) do
		if mon.Uuid == uuid then return mon end
	end
	return nil
end

return Inventory
