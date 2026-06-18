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

export type QuestProgress = {
	Status: "Active" | "Completed",
	Progress: { [string]: number }, -- keyed by Objective.Id
}

export type PlayerSave = {
	Coins: number,
	Items: { ItemStack },
	Monsters: { CaughtMonster },
	ActiveMonsterUuid: string?,
	EquippedWeaponId: string?,
	DiscoveredMonsters: { [string]: boolean },
	-- Story / quest state.
	Quests: { [string]: QuestProgress },
	LifetimeCoins: number,          -- total ever earned (for Dominion)
	LifetimeSpent: number,          -- total ever spent at market (for side quest)
	VisitedLocations: { [string]: boolean }, -- e.g. "Lake1", "Lake2"
	DefeatedByType: { [string]: number },    -- "Dark" -> count
	DefeatedTotal: number,
	TalkedNpcs: { [string]: boolean },
	IntroSeen: boolean,
	EndingAchieved: string?,
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
		Quests = {},
		LifetimeCoins = 0,
		LifetimeSpent = 0,
		VisitedLocations = {},
		DefeatedByType = {},
		DefeatedTotal = 0,
		TalkedNpcs = {},
		IntroSeen = false,
		EndingAchieved = nil,
	}
end

-- Old saves from before the quest system. Used when loading from DataStore
-- so existing players get the new fields without resetting their progress.
function Inventory.MigrateSave(save: any): PlayerSave
	save.Quests = save.Quests or {}
	save.LifetimeCoins = save.LifetimeCoins or save.Coins or 0
	save.LifetimeSpent = save.LifetimeSpent or 0
	save.VisitedLocations = save.VisitedLocations or {}
	save.DefeatedByType = save.DefeatedByType or {}
	save.DefeatedTotal = save.DefeatedTotal or 0
	save.TalkedNpcs = save.TalkedNpcs or {}
	save.IntroSeen = save.IntroSeen or false
	return save
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
