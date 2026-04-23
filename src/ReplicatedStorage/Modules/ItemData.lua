--!strict
-- Item catalog: weapons, traps, consumables.
-- Ids are stable; display data is for UI.

export type ItemKind = "Weapon" | "Trap" | "Consumable" | "KeyItem"

export type ItemDef = {
	Id: string,
	DisplayName: string,
	Kind: ItemKind,
	Price: number,     -- 0 = not normally sold
	SellPrice: number, -- what the market will buy it back for
	Description: string,
	Stats: { [string]: number },
	MaxStack: number,
}

local Items: { ItemDef } = {
	-- ── Weapons ──
	{
		Id = "stick", DisplayName = "Walking Stick", Kind = "Weapon",
		Price = 25, SellPrice = 8,
		Description = "A sturdy stick. Better than fists.",
		Stats = { Damage = 6, Range = 6, SwingSpeed = 0.7 }, MaxStack = 1,
	},
	{
		Id = "sling", DisplayName = "Leather Sling", Kind = "Weapon",
		Price = 90, SellPrice = 30,
		Description = "Ranged pebbles at medium distance.",
		Stats = { Damage = 10, Range = 60, SwingSpeed = 0.9 }, MaxStack = 1,
	},
	{
		Id = "bow", DisplayName = "Hunter's Bow", Kind = "Weapon",
		Price = 280, SellPrice = 110,
		Description = "Serious ranged damage for patient trainers.",
		Stats = { Damage = 22, Range = 120, SwingSpeed = 1.1 }, MaxStack = 1,
	},
	{
		Id = "shockrod", DisplayName = "Shock Rod", Kind = "Weapon",
		Price = 520, SellPrice = 210,
		Description = "Melee weapon that stuns on hit.",
		Stats = { Damage = 18, Range = 7, SwingSpeed = 0.8, StunSeconds = 1.2 }, MaxStack = 1,
	},
	{
		Id = "enchantedblade", DisplayName = "Enchanted Blade", Kind = "Weapon",
		Price = 1400, SellPrice = 520,
		Description = "Bypasses 25% of a monster's defense.",
		Stats = { Damage = 34, Range = 6, SwingSpeed = 0.9, ArmorPierce = 0.25 }, MaxStack = 1,
	},

	-- ── Traps ──
	{
		Id = "trap_basic", DisplayName = "Basic Trap", Kind = "Trap",
		Price = 30, SellPrice = 8,
		Description = "Starter trap. Works on weak or low-HP monsters.",
		Stats = { CatchBonus = 0.1 }, MaxStack = 99,
	},
	{
		Id = "trap_strong", DisplayName = "Reinforced Trap", Kind = "Trap",
		Price = 120, SellPrice = 40,
		Description = "Tougher cage. Better odds on rare catches.",
		Stats = { CatchBonus = 0.25 }, MaxStack = 99,
	},
	{
		Id = "trap_shock", DisplayName = "Shock Trap", Kind = "Trap",
		Price = 240, SellPrice = 80,
		Description = "Stuns first, then captures. Good for fast monsters.",
		Stats = { CatchBonus = 0.2, StunSeconds = 2 }, MaxStack = 99,
	},
	{
		Id = "trap_lure", DisplayName = "Lure Trap", Kind = "Trap",
		Price = 180, SellPrice = 60,
		Description = "Pulls nearby monsters in before triggering.",
		Stats = { CatchBonus = 0.18, LureRadius = 40 }, MaxStack = 99,
	},
	{
		Id = "trap_master", DisplayName = "Master Trap", Kind = "Trap",
		Price = 1200, SellPrice = 320,
		Description = "Guaranteed capture except on Legendaries.",
		Stats = { CatchBonus = 0.9 }, MaxStack = 20,
	},

	-- ── Consumables ──
	{
		Id = "potion_hp", DisplayName = "Health Potion", Kind = "Consumable",
		Price = 40, SellPrice = 12,
		Description = "Restores 40 HP to self or active monster.",
		Stats = { HealAmount = 40 }, MaxStack = 99,
	},
	{
		Id = "potion_hp_super", DisplayName = "Super Potion", Kind = "Consumable",
		Price = 140, SellPrice = 40,
		Description = "Restores 120 HP.",
		Stats = { HealAmount = 120 }, MaxStack = 99,
	},
	{
		Id = "potion_stamina", DisplayName = "Stamina Draft", Kind = "Consumable",
		Price = 60, SellPrice = 18,
		Description = "Refills stamina fully.",
		Stats = { StaminaAmount = 100 }, MaxStack = 99,
	},
	{
		Id = "candy_xp", DisplayName = "Training Candy", Kind = "Consumable",
		Price = 220, SellPrice = 70,
		Description = "Gives a caught monster one level.",
		Stats = { XPLevels = 1 }, MaxStack = 99,
	},
	{
		Id = "revival", DisplayName = "Revival Elixir", Kind = "Consumable",
		Price = 300, SellPrice = 90,
		Description = "Revives a fainted monster at half HP.",
		Stats = { ReviveFraction = 0.5 }, MaxStack = 20,
	},

	-- ── Key items (not in market) ──
	{
		Id = "map_fragment", DisplayName = "Map Fragment", Kind = "KeyItem",
		Price = 0, SellPrice = 0,
		Description = "Collect all four to reveal the Legendary's lair.",
		Stats = {}, MaxStack = 4,
	},
}

local byId: { [string]: ItemDef } = {}
for _, def in ipairs(Items) do
	byId[def.Id] = def
end

local M = {}
M.All = Items

function M.Get(id: string): ItemDef?
	return byId[id]
end

function M.OfKind(kind: ItemKind): { ItemDef }
	local out = {}
	for _, def in ipairs(Items) do
		if def.Kind == kind then
			table.insert(out, def)
		end
	end
	return out
end

return M
