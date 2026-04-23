--!strict
-- 30 monster species. Mix of types and biomes so the world feels varied.
-- Each entry is consumed by MonsterSpawner and CombatHandler.

export type MonsterMove = {
	Name: string,
	Power: number,
	Type: string,
	Cooldown: number,
}

export type MonsterDef = {
	Id: string,
	DisplayName: string,
	Types: { string },
	Biomes: { string },
	Rarity: string,          -- Common | Uncommon | Rare | Epic | Legendary
	BaseHP: number,
	BaseAttack: number,
	BaseDefense: number,
	BaseSpeed: number,
	Size: Vector3,
	PrimaryColor: Color3,
	SecondaryColor: Color3,
	Moves: { MonsterMove },
	CaptureResistance: number, -- 0..1; higher = harder to trap
	CoinValue: number,         -- sell-to-market value
}

local function C(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local MonsterData: { MonsterDef } = {
	{
		Id = "emberpup", DisplayName = "Emberpup",
		Types = {"Fire"}, Biomes = {"Volcanic", "Grassland"}, Rarity = "Common",
		BaseHP = 45, BaseAttack = 14, BaseDefense = 9, BaseSpeed = 16,
		Size = Vector3.new(2, 2, 3), PrimaryColor = C(210, 80, 30), SecondaryColor = C(255, 170, 60),
		Moves = {
			{ Name = "Ember", Power = 12, Type = "Fire", Cooldown = 1.0 },
			{ Name = "Tackle", Power = 8, Type = "Normal", Cooldown = 0.8 },
		},
		CaptureResistance = 0.15, CoinValue = 40,
	},
	{
		Id = "flameox", DisplayName = "Flameox",
		Types = {"Fire"}, Biomes = {"Volcanic"}, Rarity = "Uncommon",
		BaseHP = 80, BaseAttack = 22, BaseDefense = 14, BaseSpeed = 12,
		Size = Vector3.new(3.5, 3.5, 5), PrimaryColor = C(150, 40, 20), SecondaryColor = C(250, 120, 40),
		Moves = {
			{ Name = "Flamecharge", Power = 22, Type = "Fire", Cooldown = 1.4 },
			{ Name = "Gore", Power = 18, Type = "Normal", Cooldown = 1.2 },
		},
		CaptureResistance = 0.35, CoinValue = 120,
	},
	{
		Id = "cindermaw", DisplayName = "Cindermaw",
		Types = {"Fire", "Dark"}, Biomes = {"Volcanic"}, Rarity = "Rare",
		BaseHP = 110, BaseAttack = 30, BaseDefense = 18, BaseSpeed = 14,
		Size = Vector3.new(4, 4, 6), PrimaryColor = C(60, 20, 20), SecondaryColor = C(230, 70, 30),
		Moves = {
			{ Name = "Infernal Bite", Power = 32, Type = "Fire", Cooldown = 1.6 },
			{ Name = "Shadow Lunge", Power = 24, Type = "Dark", Cooldown = 1.3 },
		},
		CaptureResistance = 0.55, CoinValue = 340,
	},
	{
		Id = "aquafin", DisplayName = "Aquafin",
		Types = {"Water"}, Biomes = {"Shore"}, Rarity = "Common",
		BaseHP = 48, BaseAttack = 12, BaseDefense = 11, BaseSpeed = 18,
		Size = Vector3.new(2, 2, 3), PrimaryColor = C(60, 130, 210), SecondaryColor = C(180, 220, 240),
		Moves = {
			{ Name = "Water Jet", Power = 12, Type = "Water", Cooldown = 0.9 },
			{ Name = "Tail Slap", Power = 9, Type = "Normal", Cooldown = 0.8 },
		},
		CaptureResistance = 0.15, CoinValue = 45,
	},
	{
		Id = "tidewyrm", DisplayName = "Tidewyrm",
		Types = {"Water", "Dragon"}, Biomes = {"Shore", "Swamp"}, Rarity = "Epic",
		BaseHP = 140, BaseAttack = 28, BaseDefense = 20, BaseSpeed = 19,
		Size = Vector3.new(3, 3, 8), PrimaryColor = C(20, 60, 120), SecondaryColor = C(100, 220, 230),
		Moves = {
			{ Name = "Hydro Pulse", Power = 30, Type = "Water", Cooldown = 1.4 },
			{ Name = "Dragon Coil", Power = 26, Type = "Dragon", Cooldown = 1.6 },
		},
		CaptureResistance = 0.7, CoinValue = 620,
	},
	{
		Id = "coralix", DisplayName = "Coralix",
		Types = {"Water", "Rock"}, Biomes = {"Shore"}, Rarity = "Uncommon",
		BaseHP = 72, BaseAttack = 15, BaseDefense = 28, BaseSpeed = 9,
		Size = Vector3.new(3, 3, 3), PrimaryColor = C(230, 120, 150), SecondaryColor = C(240, 200, 210),
		Moves = {
			{ Name = "Shell Bash", Power = 18, Type = "Rock", Cooldown = 1.1 },
			{ Name = "Bubble", Power = 14, Type = "Water", Cooldown = 0.9 },
		},
		CaptureResistance = 0.35, CoinValue = 130,
	},
	{
		Id = "sproutcub", DisplayName = "Sprout Cub",
		Types = {"Grass"}, Biomes = {"Forest", "Grassland"}, Rarity = "Common",
		BaseHP = 46, BaseAttack = 11, BaseDefense = 12, BaseSpeed = 14,
		Size = Vector3.new(2, 2.5, 2), PrimaryColor = C(80, 140, 60), SecondaryColor = C(200, 220, 120),
		Moves = {
			{ Name = "Vine Whip", Power = 11, Type = "Grass", Cooldown = 0.9 },
			{ Name = "Bite", Power = 8, Type = "Normal", Cooldown = 0.8 },
		},
		CaptureResistance = 0.12, CoinValue = 35,
	},
	{
		Id = "verdantusk", DisplayName = "Verdantusk",
		Types = {"Grass", "Ground"}, Biomes = {"Forest"}, Rarity = "Uncommon",
		BaseHP = 90, BaseAttack = 20, BaseDefense = 22, BaseSpeed = 10,
		Size = Vector3.new(3.5, 4, 5), PrimaryColor = C(90, 110, 50), SecondaryColor = C(210, 180, 90),
		Moves = {
			{ Name = "Tusk Charge", Power = 22, Type = "Ground", Cooldown = 1.3 },
			{ Name = "Leaf Blade", Power = 19, Type = "Grass", Cooldown = 1.1 },
		},
		CaptureResistance = 0.4, CoinValue = 150,
	},
	{
		Id = "thornvine", DisplayName = "Thornvine",
		Types = {"Grass", "Dark"}, Biomes = {"Forest", "Swamp"}, Rarity = "Rare",
		BaseHP = 85, BaseAttack = 26, BaseDefense = 14, BaseSpeed = 16,
		Size = Vector3.new(2.5, 5, 2.5), PrimaryColor = C(50, 80, 40), SecondaryColor = C(120, 40, 80),
		Moves = {
			{ Name = "Thorn Lash", Power = 25, Type = "Grass", Cooldown = 1.1 },
			{ Name = "Night Creep", Power = 22, Type = "Dark", Cooldown = 1.3 },
		},
		CaptureResistance = 0.55, CoinValue = 320,
	},
	{
		Id = "sparkmouse", DisplayName = "Sparkmouse",
		Types = {"Electric"}, Biomes = {"Grassland", "Forest"}, Rarity = "Common",
		BaseHP = 40, BaseAttack = 15, BaseDefense = 8, BaseSpeed = 22,
		Size = Vector3.new(1.5, 1.5, 2), PrimaryColor = C(240, 220, 60), SecondaryColor = C(255, 255, 200),
		Moves = {
			{ Name = "Spark", Power = 12, Type = "Electric", Cooldown = 0.8 },
			{ Name = "Quick Bite", Power = 9, Type = "Normal", Cooldown = 0.7 },
		},
		CaptureResistance = 0.18, CoinValue = 50,
	},
	{
		Id = "voltcrest", DisplayName = "Voltcrest",
		Types = {"Electric", "Flying"}, Biomes = {"Grassland"}, Rarity = "Rare",
		BaseHP = 95, BaseAttack = 28, BaseDefense = 12, BaseSpeed = 24,
		Size = Vector3.new(3, 2, 4), PrimaryColor = C(220, 180, 40), SecondaryColor = C(60, 80, 120),
		Moves = {
			{ Name = "Thunderstrike", Power = 30, Type = "Electric", Cooldown = 1.4 },
			{ Name = "Sky Dive", Power = 24, Type = "Flying", Cooldown = 1.3 },
		},
		CaptureResistance = 0.55, CoinValue = 330,
	},
	{
		Id = "boltfang", DisplayName = "Boltfang",
		Types = {"Electric", "Dark"}, Biomes = {"Forest"}, Rarity = "Epic",
		BaseHP = 120, BaseAttack = 34, BaseDefense = 18, BaseSpeed = 22,
		Size = Vector3.new(3, 3, 5), PrimaryColor = C(30, 30, 50), SecondaryColor = C(240, 230, 80),
		Moves = {
			{ Name = "Volt Tackle", Power = 36, Type = "Electric", Cooldown = 1.6 },
			{ Name = "Shadow Bite", Power = 28, Type = "Dark", Cooldown = 1.3 },
		},
		CaptureResistance = 0.7, CoinValue = 600,
	},
	{
		Id = "stonelet", DisplayName = "Stonelet",
		Types = {"Rock"}, Biomes = {"Desert", "Volcanic"}, Rarity = "Common",
		BaseHP = 60, BaseAttack = 10, BaseDefense = 22, BaseSpeed = 6,
		Size = Vector3.new(2, 2, 2), PrimaryColor = C(140, 130, 110), SecondaryColor = C(80, 70, 60),
		Moves = {
			{ Name = "Rock Throw", Power = 14, Type = "Rock", Cooldown = 1.0 },
			{ Name = "Tackle", Power = 8, Type = "Normal", Cooldown = 0.8 },
		},
		CaptureResistance = 0.18, CoinValue = 55,
	},
	{
		Id = "cragback", DisplayName = "Cragback",
		Types = {"Rock", "Ground"}, Biomes = {"Desert"}, Rarity = "Uncommon",
		BaseHP = 100, BaseAttack = 22, BaseDefense = 30, BaseSpeed = 8,
		Size = Vector3.new(4, 3, 5), PrimaryColor = C(120, 100, 80), SecondaryColor = C(60, 45, 35),
		Moves = {
			{ Name = "Rockslide", Power = 24, Type = "Rock", Cooldown = 1.4 },
			{ Name = "Quake Stomp", Power = 22, Type = "Ground", Cooldown = 1.5 },
		},
		CaptureResistance = 0.4, CoinValue = 160,
	},
	{
		Id = "boulderion", DisplayName = "Boulderion",
		Types = {"Rock"}, Biomes = {"Volcanic"}, Rarity = "Legendary",
		BaseHP = 220, BaseAttack = 38, BaseDefense = 48, BaseSpeed = 6,
		Size = Vector3.new(6, 6, 6), PrimaryColor = C(70, 60, 50), SecondaryColor = C(220, 80, 40),
		Moves = {
			{ Name = "Mountain Slam", Power = 44, Type = "Rock", Cooldown = 1.9 },
			{ Name = "Eruption", Power = 40, Type = "Fire", Cooldown = 2.1 },
		},
		CaptureResistance = 0.9, CoinValue = 1800,
	},
	{
		Id = "sandpaw", DisplayName = "Sandpaw",
		Types = {"Ground"}, Biomes = {"Desert"}, Rarity = "Common",
		BaseHP = 52, BaseAttack = 14, BaseDefense = 12, BaseSpeed = 15,
		Size = Vector3.new(2, 2, 3), PrimaryColor = C(210, 180, 120), SecondaryColor = C(150, 120, 80),
		Moves = {
			{ Name = "Sand Attack", Power = 10, Type = "Ground", Cooldown = 0.8 },
			{ Name = "Claw", Power = 11, Type = "Normal", Cooldown = 0.9 },
		},
		CaptureResistance = 0.18, CoinValue = 45,
	},
	{
		Id = "dusthorn", DisplayName = "Dusthorn",
		Types = {"Ground", "Rock"}, Biomes = {"Desert"}, Rarity = "Rare",
		BaseHP = 110, BaseAttack = 26, BaseDefense = 24, BaseSpeed = 12,
		Size = Vector3.new(4, 3.5, 5), PrimaryColor = C(180, 140, 90), SecondaryColor = C(90, 70, 50),
		Moves = {
			{ Name = "Sand Vortex", Power = 26, Type = "Ground", Cooldown = 1.4 },
			{ Name = "Horn Drill", Power = 30, Type = "Rock", Cooldown = 1.6 },
		},
		CaptureResistance = 0.55, CoinValue = 340,
	},
	{
		Id = "mindling", DisplayName = "Mindling",
		Types = {"Psychic"}, Biomes = {"Grassland", "Forest"}, Rarity = "Uncommon",
		BaseHP = 55, BaseAttack = 22, BaseDefense = 10, BaseSpeed = 14,
		Size = Vector3.new(1.8, 2.2, 1.8), PrimaryColor = C(200, 160, 230), SecondaryColor = C(240, 220, 255),
		Moves = {
			{ Name = "Mind Beam", Power = 20, Type = "Psychic", Cooldown = 1.1 },
			{ Name = "Confuse", Power = 14, Type = "Psychic", Cooldown = 1.3 },
		},
		CaptureResistance = 0.4, CoinValue = 140,
	},
	{
		Id = "psybeam", DisplayName = "Psybeam",
		Types = {"Psychic", "Flying"}, Biomes = {"Tundra", "Grassland"}, Rarity = "Epic",
		BaseHP = 115, BaseAttack = 32, BaseDefense = 16, BaseSpeed = 21,
		Size = Vector3.new(3, 3, 4), PrimaryColor = C(120, 80, 180), SecondaryColor = C(230, 210, 250),
		Moves = {
			{ Name = "Psystorm", Power = 34, Type = "Psychic", Cooldown = 1.6 },
			{ Name = "Air Cutter", Power = 24, Type = "Flying", Cooldown = 1.2 },
		},
		CaptureResistance = 0.7, CoinValue = 640,
	},
	{
		Id = "shadeling", DisplayName = "Shadeling",
		Types = {"Dark"}, Biomes = {"Swamp", "Forest"}, Rarity = "Common",
		BaseHP = 44, BaseAttack = 16, BaseDefense = 9, BaseSpeed = 17,
		Size = Vector3.new(1.8, 2.2, 1.8), PrimaryColor = C(40, 30, 50), SecondaryColor = C(120, 80, 160),
		Moves = {
			{ Name = "Shadow Nip", Power = 13, Type = "Dark", Cooldown = 0.9 },
			{ Name = "Sneak", Power = 9, Type = "Normal", Cooldown = 0.7 },
		},
		CaptureResistance = 0.2, CoinValue = 55,
	},
	{
		Id = "nightmaul", DisplayName = "Nightmaul",
		Types = {"Dark", "Rock"}, Biomes = {"Swamp"}, Rarity = "Rare",
		BaseHP = 120, BaseAttack = 30, BaseDefense = 22, BaseSpeed = 13,
		Size = Vector3.new(4, 4, 5), PrimaryColor = C(30, 25, 35), SecondaryColor = C(110, 90, 60),
		Moves = {
			{ Name = "Crushing Dark", Power = 30, Type = "Dark", Cooldown = 1.4 },
			{ Name = "Rock Maul", Power = 26, Type = "Rock", Cooldown = 1.5 },
		},
		CaptureResistance = 0.55, CoinValue = 350,
	},
	{
		Id = "frostkit", DisplayName = "Frostkit",
		Types = {"Ice"}, Biomes = {"Tundra"}, Rarity = "Common",
		BaseHP = 50, BaseAttack = 12, BaseDefense = 11, BaseSpeed = 15,
		Size = Vector3.new(2, 2, 3), PrimaryColor = C(180, 220, 240), SecondaryColor = C(230, 240, 255),
		Moves = {
			{ Name = "Icy Breath", Power = 12, Type = "Ice", Cooldown = 0.9 },
			{ Name = "Pounce", Power = 10, Type = "Normal", Cooldown = 0.8 },
		},
		CaptureResistance = 0.18, CoinValue = 50,
	},
	{
		Id = "glacierion", DisplayName = "Glacierion",
		Types = {"Ice", "Rock"}, Biomes = {"Tundra"}, Rarity = "Legendary",
		BaseHP = 200, BaseAttack = 36, BaseDefense = 42, BaseSpeed = 10,
		Size = Vector3.new(5.5, 6, 5.5), PrimaryColor = C(120, 180, 210), SecondaryColor = C(60, 80, 120),
		Moves = {
			{ Name = "Avalanche", Power = 42, Type = "Ice", Cooldown = 1.9 },
			{ Name = "Glacier Slam", Power = 38, Type = "Rock", Cooldown = 1.8 },
		},
		CaptureResistance = 0.9, CoinValue = 1700,
	},
	{
		Id = "phantlet", DisplayName = "Phantlet",
		Types = {"Ghost"}, Biomes = {"Swamp", "Forest"}, Rarity = "Uncommon",
		BaseHP = 55, BaseAttack = 18, BaseDefense = 10, BaseSpeed = 16,
		Size = Vector3.new(2, 2.5, 2), PrimaryColor = C(180, 190, 220), SecondaryColor = C(110, 90, 160),
		Moves = {
			{ Name = "Spirit Touch", Power = 18, Type = "Ghost", Cooldown = 1.0 },
			{ Name = "Haunt", Power = 14, Type = "Ghost", Cooldown = 1.2 },
		},
		CaptureResistance = 0.45, CoinValue = 150,
	},
	{
		Id = "wispmaw", DisplayName = "Wispmaw",
		Types = {"Ghost", "Fire"}, Biomes = {"Swamp", "Volcanic"}, Rarity = "Rare",
		BaseHP = 95, BaseAttack = 28, BaseDefense = 14, BaseSpeed = 18,
		Size = Vector3.new(3, 3, 3), PrimaryColor = C(60, 50, 80), SecondaryColor = C(240, 140, 60),
		Moves = {
			{ Name = "Hexflame", Power = 28, Type = "Ghost", Cooldown = 1.3 },
			{ Name = "Cinder Curse", Power = 24, Type = "Fire", Cooldown = 1.4 },
		},
		CaptureResistance = 0.6, CoinValue = 380,
	},
	{
		Id = "pebbletoad", DisplayName = "Pebbletoad",
		Types = {"Rock", "Water"}, Biomes = {"Shore", "Swamp"}, Rarity = "Common",
		BaseHP = 58, BaseAttack = 13, BaseDefense = 18, BaseSpeed = 10,
		Size = Vector3.new(2.5, 2, 2.5), PrimaryColor = C(100, 120, 110), SecondaryColor = C(180, 200, 160),
		Moves = {
			{ Name = "Pebble Toss", Power = 14, Type = "Rock", Cooldown = 0.9 },
			{ Name = "Water Splash", Power = 10, Type = "Water", Cooldown = 0.8 },
		},
		CaptureResistance = 0.2, CoinValue = 55,
	},
	{
		Id = "wingnip", DisplayName = "Wingnip",
		Types = {"Flying"}, Biomes = {"Grassland", "Forest"}, Rarity = "Common",
		BaseHP = 42, BaseAttack = 13, BaseDefense = 9, BaseSpeed = 22,
		Size = Vector3.new(2, 1.5, 2), PrimaryColor = C(160, 130, 100), SecondaryColor = C(240, 210, 150),
		Moves = {
			{ Name = "Wing Jab", Power = 12, Type = "Flying", Cooldown = 0.8 },
			{ Name = "Peck", Power = 10, Type = "Normal", Cooldown = 0.7 },
		},
		CaptureResistance = 0.18, CoinValue = 45,
	},
	{
		Id = "skytalon", DisplayName = "Skytalon",
		Types = {"Flying", "Fire"}, Biomes = {"Volcanic", "Grassland"}, Rarity = "Epic",
		BaseHP = 130, BaseAttack = 32, BaseDefense = 16, BaseSpeed = 26,
		Size = Vector3.new(5, 2.5, 5), PrimaryColor = C(200, 60, 40), SecondaryColor = C(250, 200, 80),
		Moves = {
			{ Name = "Firestorm Dive", Power = 36, Type = "Fire", Cooldown = 1.7 },
			{ Name = "Talon Rake", Power = 28, Type = "Flying", Cooldown = 1.3 },
		},
		CaptureResistance = 0.72, CoinValue = 680,
	},
	{
		Id = "rootling", DisplayName = "Rootling",
		Types = {"Grass", "Ground"}, Biomes = {"Forest", "Swamp"}, Rarity = "Uncommon",
		BaseHP = 75, BaseAttack = 17, BaseDefense = 22, BaseSpeed = 8,
		Size = Vector3.new(3, 2.5, 3), PrimaryColor = C(110, 90, 60), SecondaryColor = C(90, 140, 60),
		Moves = {
			{ Name = "Root Snare", Power = 18, Type = "Grass", Cooldown = 1.2 },
			{ Name = "Mud Slap", Power = 14, Type = "Ground", Cooldown = 1.0 },
		},
		CaptureResistance = 0.35, CoinValue = 120,
	},
	{
		Id = "dragonspawn", DisplayName = "Dragonspawn",
		Types = {"Dragon"}, Biomes = {"Volcanic", "Tundra"}, Rarity = "Legendary",
		BaseHP = 240, BaseAttack = 42, BaseDefense = 34, BaseSpeed = 20,
		Size = Vector3.new(6, 5, 8), PrimaryColor = C(80, 50, 120), SecondaryColor = C(220, 80, 60),
		Moves = {
			{ Name = "Dragonfire", Power = 46, Type = "Dragon", Cooldown = 1.9 },
			{ Name = "Wyrm Roar", Power = 38, Type = "Dragon", Cooldown = 2.0 },
		},
		CaptureResistance = 0.92, CoinValue = 2200,
	},
}

-- Index for fast lookups by id.
local byId: { [string]: MonsterDef } = {}
for _, def in ipairs(MonsterData) do
	byId[def.Id] = def
end

local M = {}
M.All = MonsterData

function M.Get(id: string): MonsterDef?
	return byId[id]
end

function M.ForBiome(biome: string): { MonsterDef }
	local out = {}
	for _, def in ipairs(MonsterData) do
		for _, b in ipairs(def.Biomes) do
			if b == biome then
				table.insert(out, def)
				break
			end
		end
	end
	return out
end

return M
