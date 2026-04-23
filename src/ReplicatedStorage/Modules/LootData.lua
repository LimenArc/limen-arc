--!strict
-- Loot tables for chests and lucky blocks. Kept in ReplicatedStorage so
-- future balance tweaks don't require touching server logic.

export type LootEntry = {
	Kind: "Coins" | "Item" | "Monster" | "Penalty",
	Id: string?,      -- item id or species id
	MinCount: number?,
	MaxCount: number?,
	Weight: number,
	Message: string?, -- optional override for notifications
}

local Loot = {}

-- Normal chests: reliable loot, no penalties.
Loot.Chest = {
	{ Kind = "Coins", MinCount = 40, MaxCount = 150, Weight = 40 },
	{ Kind = "Item",  Id = "potion_hp",      MinCount = 1, MaxCount = 3, Weight = 18 },
	{ Kind = "Item",  Id = "potion_stamina", MinCount = 1, MaxCount = 2, Weight = 12 },
	{ Kind = "Item",  Id = "trap_basic",     MinCount = 1, MaxCount = 4, Weight = 15 },
	{ Kind = "Item",  Id = "trap_strong",    MinCount = 1, MaxCount = 2, Weight = 8 },
	{ Kind = "Item",  Id = "candy_xp",       MinCount = 1, MaxCount = 1, Weight = 4 },
	{ Kind = "Item",  Id = "revival",        MinCount = 1, MaxCount = 1, Weight = 2 },
	{ Kind = "Item",  Id = "sling",          MinCount = 1, MaxCount = 1, Weight = 1 },
}

-- Lucky blocks: bigger swings. Some penalties (minor), some jackpots.
Loot.LuckyBlock = {
	-- Jackpots
	{ Kind = "Coins", MinCount = 500,  MaxCount = 1500, Weight = 6,
	  Message = "Jackpot! +%d coins" },
	{ Kind = "Item",  Id = "trap_master", MinCount = 1, MaxCount = 1, Weight = 3,
	  Message = "Legendary find: Master Trap!" },
	{ Kind = "Item",  Id = "enchantedblade", MinCount = 1, MaxCount = 1, Weight = 1,
	  Message = "Legendary find: Enchanted Blade!" },
	{ Kind = "Monster", Id = "skytalon", Weight = 1,
	  Message = "A Skytalon joins your party!" },
	{ Kind = "Monster", Id = "boulderion", Weight = 1,
	  Message = "A Boulderion joins your party!" },
	{ Kind = "Monster", Id = "dragonspawn", Weight = 0.3,
	  Message = "A DRAGONSPAWN joins your party!" },

	-- Story: map fragments.
	{ Kind = "Item", Id = "map_fragment", MinCount = 1, MaxCount = 1, Weight = 6,
	  Message = "A weathered map fragment!" },

	-- Mid-tier rewards
	{ Kind = "Coins", MinCount = 80, MaxCount = 300, Weight = 22 },
	{ Kind = "Item",  Id = "potion_hp_super", MinCount = 1, MaxCount = 2, Weight = 14 },
	{ Kind = "Item",  Id = "candy_xp",        MinCount = 1, MaxCount = 3, Weight = 10 },
	{ Kind = "Item",  Id = "trap_shock",      MinCount = 1, MaxCount = 3, Weight = 10 },
	{ Kind = "Item",  Id = "trap_lure",       MinCount = 1, MaxCount = 2, Weight = 8 },
	{ Kind = "Item",  Id = "revival",         MinCount = 1, MaxCount = 2, Weight = 8 },
	{ Kind = "Item",  Id = "bow",             MinCount = 1, MaxCount = 1, Weight = 4 },

	-- Duds / penalties (never lethal)
	{ Kind = "Penalty", Id = "coins", MinCount = 20, MaxCount = 80, Weight = 10,
	  Message = "Trapped! -%d coins" },
	{ Kind = "Penalty", Id = "teleport", Weight = 4,
	  Message = "Yoinked to spawn by a prank spirit." },
}

local function pickWeighted(table_: { LootEntry }, rng: Random): LootEntry
	local total = 0
	for _, e in ipairs(table_) do total += e.Weight end
	local roll = rng:NextNumber(0, total)
	local running = 0
	for _, e in ipairs(table_) do
		running += e.Weight
		if roll <= running then return e end
	end
	return table_[#table_]
end

function Loot.RollChest(rng: Random): LootEntry
	return pickWeighted(Loot.Chest, rng)
end

function Loot.RollLuckyBlock(rng: Random): LootEntry
	return pickWeighted(Loot.LuckyBlock, rng)
end

return Loot
