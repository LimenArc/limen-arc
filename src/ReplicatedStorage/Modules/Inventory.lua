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

-- A creature obtained from a lucky block, stored in the lucky creature inventory.
export type LuckyCreatureEntry = {
	Uid: string,       -- unique per-instance id
	CreatureId: string,
	Rarity: string,
	CollectedAt: number,
}

-- One creature placed in the base at a given grid slot (1-indexed).
export type BasePlacement = {
	SlotIndex: number,
	Uid: string,       -- references a LuckyCreatureEntry.Uid
}

export type PlayerSave = {
	Coins: number,
	Items: { ItemStack },
	Monsters: { CaughtMonster },
	ActiveMonsterUuid: string?,
	EquippedWeaponId: string?,
	DiscoveredMonsters: { [string]: boolean },
	-- Lucky Block additions
	SpeedLevel: number,
	BaseSlotCount: number,
	LuckyCreatures: { LuckyCreatureEntry },
	BasePlacements: { BasePlacement },
	FurthestZone: number,
	TotalBlocksOpened: number,
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
		SpeedLevel = 0,
		BaseSlotCount = 4,
		LuckyCreatures = {},
		BasePlacements = {},
		FurthestZone = 1,
		TotalBlocksOpened = 0,
	}
end

-- Ensure legacy saves loaded from DataStore have the new fields.
function Inventory.Migrate(save: PlayerSave)
	if save.SpeedLevel == nil then save.SpeedLevel = 0 end
	if save.BaseSlotCount == nil then save.BaseSlotCount = 4 end
	if save.LuckyCreatures == nil then save.LuckyCreatures = {} end
	if save.BasePlacements == nil then save.BasePlacements = {} end
	if save.FurthestZone == nil then save.FurthestZone = 1 end
	if save.TotalBlocksOpened == nil then save.TotalBlocksOpened = 0 end
end

-- Add a lucky creature to the inventory; returns its new entry.
function Inventory.AddLuckyCreature(save: PlayerSave, creatureId: string, rarity: string): LuckyCreatureEntry
	local entry: LuckyCreatureEntry = {
		Uid = ("%s_%d_%d"):format(creatureId, os.time(), math.random(1000, 9999)),
		CreatureId = creatureId,
		Rarity = rarity,
		CollectedAt = os.time(),
	}
	table.insert(save.LuckyCreatures, entry)
	return entry
end

-- Find a lucky creature entry by uid.
function Inventory.FindLuckyCreature(save: PlayerSave, uid: string): LuckyCreatureEntry?
	for _, e in ipairs(save.LuckyCreatures) do
		if e.Uid == uid then return e end
	end
	return nil
end

-- Remove a lucky creature by uid (e.g. on sell).
function Inventory.RemoveLuckyCreature(save: PlayerSave, uid: string): boolean
	for i, e in ipairs(save.LuckyCreatures) do
		if e.Uid == uid then
			table.remove(save.LuckyCreatures, i)
			-- Also remove from base if placed.
			for j = #save.BasePlacements, 1, -1 do
				if save.BasePlacements[j].Uid == uid then
					table.remove(save.BasePlacements, j)
				end
			end
			return true
		end
	end
	return false
end

-- Place a creature in a base slot (replaces any existing occupant).
function Inventory.PlaceInBase(save: PlayerSave, uid: string, slotIndex: number): boolean
	if not Inventory.FindLuckyCreature(save, uid) then return false end
	-- Remove any existing creature in that slot.
	for i = #save.BasePlacements, 1, -1 do
		if save.BasePlacements[i].SlotIndex == slotIndex then
			table.remove(save.BasePlacements, i)
		end
	end
	-- Remove uid from any other slot.
	for i = #save.BasePlacements, 1, -1 do
		if save.BasePlacements[i].Uid == uid then
			table.remove(save.BasePlacements, i)
		end
	end
	table.insert(save.BasePlacements, { SlotIndex = slotIndex, Uid = uid })
	return true
end

-- Remove a creature from a base slot.
function Inventory.RemoveFromBase(save: PlayerSave, slotIndex: number): boolean
	for i, p in ipairs(save.BasePlacements) do
		if p.SlotIndex == slotIndex then
			table.remove(save.BasePlacements, i)
			return true
		end
	end
	return false
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
