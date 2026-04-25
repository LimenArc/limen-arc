--!strict
-- Lucky Block game data: zones, block rarity tables, lucky creatures, speed
-- upgrade tiers, and base slot tiers. Single source of truth shared by all
-- server and client systems.

local LuckyBlockData = {}

-- ── Helpers ────────────────────────────────────────────────────────────────

local function C(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- ── Zones ──────────────────────────────────────────────────────────────────
-- Zones are concentric rings measured as XZ distance from the map origin.
-- MinSpeed is the WalkSpeed a player must have to enter the zone.
-- Players below MinSpeed are pushed back toward center.

export type ZoneDef = {
	Id: number,
	Name: string,
	MinSpeed: number,
	MinRadius: number,
	MaxRadius: number,
	BlockColor: Color3,
	BlockGlow: Color3,
	BlockEmission: Color3,
	BlockCount: number,
	RespawnSeconds: number,
	AmbientColor: Color3,
	Weights: {
		Common: number,
		Uncommon: number,
		Rare: number,
		Epic: number,
		Legendary: number,
		Mythic: number,
	},
}

LuckyBlockData.Zones: { ZoneDef } = {
	{
		Id = 1, Name = "Starter Valley",
		MinSpeed = 0, MinRadius = 0, MaxRadius = 350,
		BlockColor    = C(255, 215, 0),
		BlockGlow     = C(255, 235, 80),
		BlockEmission = C(255, 200, 50),
		BlockCount = 10, RespawnSeconds = 18,
		AmbientColor = C(255, 240, 200),
		Weights = { Common=0.650, Uncommon=0.280, Rare=0.060, Epic=0.009, Legendary=0.001, Mythic=0.000 },
	},
	{
		Id = 2, Name = "Enchanted Forest",
		MinSpeed = 18, MinRadius = 350, MaxRadius = 500,
		BlockColor    = C(60, 220, 90),
		BlockGlow     = C(100, 255, 130),
		BlockEmission = C(40, 200, 70),
		BlockCount = 7, RespawnSeconds = 28,
		AmbientColor = C(180, 255, 190),
		Weights = { Common=0.380, Uncommon=0.360, Rare=0.190, Epic=0.060, Legendary=0.009, Mythic=0.001 },
	},
	{
		Id = 3, Name = "Crystal Tundra",
		MinSpeed = 25, MinRadius = 500, MaxRadius = 650,
		BlockColor    = C(80, 180, 255),
		BlockGlow     = C(140, 220, 255),
		BlockEmission = C(50, 150, 240),
		BlockCount = 6, RespawnSeconds = 40,
		AmbientColor = C(180, 220, 255),
		Weights = { Common=0.180, Uncommon=0.300, Rare=0.310, Epic=0.150, Legendary=0.050, Mythic=0.010 },
	},
	{
		Id = 4, Name = "Infernal Depths",
		MinSpeed = 34, MinRadius = 650, MaxRadius = 820,
		BlockColor    = C(230, 55, 25),
		BlockGlow     = C(255, 100, 50),
		BlockEmission = C(200, 40, 20),
		BlockCount = 5, RespawnSeconds = 55,
		AmbientColor = C(255, 160, 100),
		Weights = { Common=0.040, Uncommon=0.180, Rare=0.360, Epic=0.290, Legendary=0.110, Mythic=0.020 },
	},
	{
		Id = 5, Name = "Mythic Void",
		MinSpeed = 43, MinRadius = 820, MaxRadius = 1100,
		BlockColor    = C(185, 55, 255),
		BlockGlow     = C(220, 110, 255),
		BlockEmission = C(140, 30, 220),
		BlockCount = 4, RespawnSeconds = 80,
		AmbientColor = C(200, 130, 255),
		Weights = { Common=0.000, Uncommon=0.040, Rare=0.220, Epic=0.370, Legendary=0.260, Mythic=0.110 },
	},
}

-- Zone lookup by id.
local zoneById: { [number]: ZoneDef } = {}
for _, z in ipairs(LuckyBlockData.Zones) do
	zoneById[z.Id] = z
end

function LuckyBlockData.GetZone(id: number): ZoneDef?
	return zoneById[id]
end

-- Return the zone for a given XZ distance from origin.
function LuckyBlockData.ZoneForRadius(dist: number): ZoneDef
	for i = #LuckyBlockData.Zones, 1, -1 do
		if dist >= LuckyBlockData.Zones[i].MinRadius then
			return LuckyBlockData.Zones[i]
		end
	end
	return LuckyBlockData.Zones[1]
end

-- ── Rarities ───────────────────────────────────────────────────────────────

export type RarityDef = {
	Name: string,
	Color: Color3,
	GlowColor: Color3,
	BaseIncomePerTick: number,
	ShardValue: number,
}

LuckyBlockData.Rarities: { [string]: RarityDef } = {
	Common = {
		Name = "Common", Color = C(180,180,180), GlowColor = C(210,210,210),
		BaseIncomePerTick = 2, ShardValue = 30,
	},
	Uncommon = {
		Name = "Uncommon", Color = C(80,210,90), GlowColor = C(120,240,130),
		BaseIncomePerTick = 6, ShardValue = 90,
	},
	Rare = {
		Name = "Rare", Color = C(80,140,255), GlowColor = C(120,180,255),
		BaseIncomePerTick = 18, ShardValue = 280,
	},
	Epic = {
		Name = "Epic", Color = C(165,55,230), GlowColor = C(200,90,255),
		BaseIncomePerTick = 45, ShardValue = 800,
	},
	Legendary = {
		Name = "Legendary", Color = C(255,160,0), GlowColor = C(255,210,60),
		BaseIncomePerTick = 110, ShardValue = 2500,
	},
	Mythic = {
		Name = "Mythic", Color = C(255,60,130), GlowColor = C(255,110,190),
		BaseIncomePerTick = 320, ShardValue = 10000,
	},
}

local rarityOrder = { "Common","Uncommon","Rare","Epic","Legendary","Mythic" }
LuckyBlockData.RarityOrder = rarityOrder

-- ── Lucky Creatures ────────────────────────────────────────────────────────
-- Creatures exclusively obtained from lucky blocks.
-- IncomeBonus multiplies the rarity's BaseIncomePerTick.

export type LuckyCreatureDef = {
	Id: string,
	DisplayName: string,
	Rarity: string,
	PrimaryColor: Color3,
	SecondaryColor: Color3,
	Description: string,
	IncomeBonus: number,
	BodyShape: string,  -- "round" | "tall" | "wide" | "dragon" | "orb"
}

LuckyBlockData.Creatures: { LuckyCreatureDef } = {
	-- ── Common ──────────────────────────────────────────────────────────
	{ Id="goldensprout",  DisplayName="Golden Sprout",   Rarity="Common",
	  PrimaryColor=C(205,185,60),  SecondaryColor=C(245,230,130),
	  Description="A cheerful sapling that sheds gold leaf dust.",
	  IncomeBonus=1.0, BodyShape="round" },
	{ Id="pebblefrog",    DisplayName="Pebble Frog",     Rarity="Common",
	  PrimaryColor=C(115,145,95),  SecondaryColor=C(175,200,145),
	  Description="Hops across terrain collecting loose coins.",
	  IncomeBonus=1.0, BodyShape="wide" },
	{ Id="sparkworm",     DisplayName="Spark Worm",      Rarity="Common",
	  PrimaryColor=C(235,205,55),  SecondaryColor=C(255,245,130),
	  Description="Its wriggling tail trails sparkling gold dust.",
	  IncomeBonus=1.1, BodyShape="tall" },
	{ Id="dustbunny",     DisplayName="Dust Bunny",      Rarity="Common",
	  PrimaryColor=C(200,190,180), SecondaryColor=C(240,235,230),
	  Description="Fluffy, soft, and surprisingly lucrative.",
	  IncomeBonus=1.0, BodyShape="round" },
	{ Id="coalpuff",      DisplayName="Coal Puff",       Rarity="Common",
	  PrimaryColor=C(58,52,65),    SecondaryColor=C(100,88,115),
	  Description="Smoulders slowly, converting heat to income.",
	  IncomeBonus=1.0, BodyShape="orb" },
	{ Id="mirevole",      DisplayName="Mirevole",        Rarity="Common",
	  PrimaryColor=C(75,110,65),   SecondaryColor=C(140,185,115),
	  Description="Swamp lizard that sniffs out buried treasure.",
	  IncomeBonus=1.1, BodyShape="wide" },
	{ Id="snowpuff",      DisplayName="Snow Puff",       Rarity="Common",
	  PrimaryColor=C(220,235,245), SecondaryColor=C(245,250,255),
	  Description="Melts and reforms, leaving frost coins behind.",
	  IncomeBonus=1.0, BodyShape="round" },
	{ Id="claybat",       DisplayName="Clay Bat",        Rarity="Common",
	  PrimaryColor=C(175,140,110), SecondaryColor=C(210,180,155),
	  Description="Hangs upside-down and methodically earns.",
	  IncomeBonus=1.0, BodyShape="wide" },

	-- ── Uncommon ────────────────────────────────────────────────────────
	{ Id="silverfox",    DisplayName="Silver Fox",      Rarity="Uncommon",
	  PrimaryColor=C(178,183,195), SecondaryColor=C(228,230,240),
	  Description="Quick and silver-tongued, earns well beyond its size.",
	  IncomeBonus=1.2, BodyShape="tall" },
	{ Id="neonfish",     DisplayName="Neon Fish",       Rarity="Uncommon",
	  PrimaryColor=C(55,225,200),  SecondaryColor=C(115,255,235),
	  Description="Glows in the dark, attracting coins like moths to light.",
	  IncomeBonus=1.2, BodyShape="wide" },
	{ Id="thundercub",   DisplayName="Thunder Cub",     Rarity="Uncommon",
	  PrimaryColor=C(245,215,50),  SecondaryColor=C(75,75,120),
	  Description="Emits miniature thunderbolts worth considerable coin.",
	  IncomeBonus=1.3, BodyShape="round" },
	{ Id="icebloom",     DisplayName="Ice Bloom",       Rarity="Uncommon",
	  PrimaryColor=C(158,222,240), SecondaryColor=C(200,245,255),
	  Description="A flower frozen in time, crystallising income.",
	  IncomeBonus=1.2, BodyShape="orb" },
	{ Id="brambleback",  DisplayName="Bramble Back",    Rarity="Uncommon",
	  PrimaryColor=C(78,100,48),   SecondaryColor=C(150,182,88),
	  Description="Thorny spine doubles as coin accumulator.",
	  IncomeBonus=1.2, BodyShape="wide" },
	{ Id="sandcat",      DisplayName="Sand Cat",        Rarity="Uncommon",
	  PrimaryColor=C(222,192,130), SecondaryColor=C(250,232,180),
	  Description="Desert hunter that buries—and retrieves—treasure.",
	  IncomeBonus=1.3, BodyShape="tall" },

	-- ── Rare ────────────────────────────────────────────────────────────
	{ Id="cobaltdrake",  DisplayName="Cobalt Drake",    Rarity="Rare",
	  PrimaryColor=C(38,78,210),   SecondaryColor=C(78,162,255),
	  Description="Young dragon humming with high-voltage wealth.",
	  IncomeBonus=1.5, BodyShape="dragon" },
	{ Id="magmaslug",    DisplayName="Magma Slug",      Rarity="Rare",
	  PrimaryColor=C(200,58,18),   SecondaryColor=C(255,140,38),
	  Description="Trails a river of molten gold wherever it crawls.",
	  IncomeBonus=1.6, BodyShape="wide" },
	{ Id="vortexhound",  DisplayName="Vortex Hound",    Rarity="Rare",
	  PrimaryColor=C(58,38,100),   SecondaryColor=C(138,98,200),
	  Description="Vacuum-fur coat hoovers up nearby loose coins.",
	  IncomeBonus=1.5, BodyShape="tall" },
	{ Id="crystalstag",  DisplayName="Crystal Stag",    Rarity="Rare",
	  PrimaryColor=C(158,222,240), SecondaryColor=C(200,252,255),
	  Description="Antlers refract ambient light into solid gold coins.",
	  IncomeBonus=1.7, BodyShape="tall" },
	{ Id="prismjay",     DisplayName="Prism Jay",       Rarity="Rare",
	  PrimaryColor=C(255,118,58),  SecondaryColor=C(58,118,255),
	  Description="Rainbow-feathered with an extraordinary eye for wealth.",
	  IncomeBonus=1.5, BodyShape="wide" },

	-- ── Epic ────────────────────────────────────────────────────────────
	{ Id="shadowleopard", DisplayName="Shadow Leopard", Rarity="Epic",
	  PrimaryColor=C(28,18,40),    SecondaryColor=C(118,58,182),
	  Description="Hunts coins across dimensions you can't see.",
	  IncomeBonus=2.0, BodyShape="tall" },
	{ Id="stormwyvern",   DisplayName="Storm Wyvern",   Rarity="Epic",
	  PrimaryColor=C(58,60,100),   SecondaryColor=C(198,200,255),
	  Description="Each wingbeat rains down golden lightning.",
	  IncomeBonus=2.2, BodyShape="dragon" },
	{ Id="rubygorilla",   DisplayName="Ruby Gorilla",   Rarity="Epic",
	  PrimaryColor=C(202,38,38),   SecondaryColor=C(255,82,82),
	  Description="Pounds the earth, unearthing buried coin veins.",
	  IncomeBonus=2.0, BodyShape="round" },
	{ Id="aurorawolf",    DisplayName="Aurora Wolf",    Rarity="Epic",
	  PrimaryColor=C(78,202,180),  SecondaryColor=C(148,100,242),
	  Description="Its howl paints the sky and fills treasuries.",
	  IncomeBonus=2.3, BodyShape="tall" },

	-- ── Legendary ───────────────────────────────────────────────────────
	{ Id="solarprowler",  DisplayName="Solar Prowler",  Rarity="Legendary",
	  PrimaryColor=C(255,182,0),   SecondaryColor=C(255,242,100),
	  Description="Born of a solar flare. Generates immense cosmic wealth.",
	  IncomeBonus=3.0, BodyShape="dragon" },
	{ Id="abyssalwraith", DisplayName="Abyssal Wraith", Rarity="Legendary",
	  PrimaryColor=C(18,8,30),     SecondaryColor=C(78,38,122),
	  Description="A phantom of the deep. Its presence multiplies all income.",
	  IncomeBonus=3.2, BodyShape="orb" },
	{ Id="titanshell",    DisplayName="Titan Shell",    Rarity="Legendary",
	  PrimaryColor=C(98,78,162),   SecondaryColor=C(180,162,242),
	  Description="Ancient and slow but worth a vast fortune per tick.",
	  IncomeBonus=3.0, BodyShape="wide" },

	-- ── Mythic ──────────────────────────────────────────────────────────
	{ Id="cosmicwyrm",      DisplayName="Cosmic Wyrm",       Rarity="Mythic",
	  PrimaryColor=C(18,8,40),     SecondaryColor=C(158,58,255),
	  Description="A serpent woven from starlight and pure gold — rarest of all.",
	  IncomeBonus=5.0, BodyShape="dragon" },
	{ Id="voidlord",        DisplayName="Void Lord",          Rarity="Mythic",
	  PrimaryColor=C(4,4,14),      SecondaryColor=C(78,18,142),
	  Description="Commands the space between stars. Transcends all wealth limits.",
	  IncomeBonus=5.5, BodyShape="orb" },
	{ Id="celestiaphoenix", DisplayName="Celestia Phoenix",  Rarity="Mythic",
	  PrimaryColor=C(255,100,28),  SecondaryColor=C(255,222,58),
	  Description="Reborn endlessly from cosmic fire. Its feathers are solid gold.",
	  IncomeBonus=6.0, BodyShape="dragon" },

	-- ── 🍓 Brainrot Creatures ────────────────────────────────────────────
	-- Rare-to-Mythic special creatures from internet brainrot lore.
	-- Each has an absurdly high IncomeBonus reflecting their meme power.

	-- Uncommon brainrots
	{ Id="tralalelo_tralala",     DisplayName="Tralalelo Tralala",      Rarity="Uncommon",
	  PrimaryColor=C(80,180,80),   SecondaryColor=C(160,230,100),
	  Description="A singing crocodile that hums itself to sleep — and earns in its dreams.",
	  IncomeBonus=1.4, BodyShape="wide" },
	{ Id="brrbrr_patapim",        DisplayName="Brr Brr Patapim",        Rarity="Uncommon",
	  PrimaryColor=C(100,160,220), SecondaryColor=C(200,230,255),
	  Description="An icy creature whose chattering teeth produce gold coins.",
	  IncomeBonus=1.3, BodyShape="round" },
	{ Id="lirili_larila",         DisplayName="Lirili Larila",           Rarity="Uncommon",
	  PrimaryColor=C(220,150,200), SecondaryColor=C(255,210,240),
	  Description="A bouncy pink beast that generates coins with every leap.",
	  IncomeBonus=1.4, BodyShape="round" },

	-- Rare brainrots
	{ Id="bombardiro_crocodilo",  DisplayName="Bombardiro Crocodilo",    Rarity="Rare",
	  PrimaryColor=C(60,100,60),   SecondaryColor=C(120,180,80),
	  Description="Half-crocodile, half-military bomber. Drops coins from altitude.",
	  IncomeBonus=1.8, BodyShape="wide" },
	{ Id="cappuccino_assassino",  DisplayName="Cappuccino Assassino",    Rarity="Rare",
	  PrimaryColor=C(140,80,40),   SecondaryColor=C(230,200,160),
	  Description="A stealthy espresso-powered assassin who leaves gold in its wake.",
	  IncomeBonus=1.9, BodyShape="tall" },
	{ Id="tung_tung_sahur",       DisplayName="Tung Tung Tung Sahur",    Rarity="Rare",
	  PrimaryColor=C(200,160,80),  SecondaryColor=C(240,220,140),
	  Description="A mysterious drumming entity. Each beat echoes coins into your vault.",
	  IncomeBonus=1.7, BodyShape="orb" },
	{ Id="ballerina_capuchina",   DisplayName="Ballerina Capuchina",     Rarity="Rare",
	  PrimaryColor=C(240,180,200), SecondaryColor=C(255,220,240),
	  Description="Spins so fast that coins fly off centrifugally in all directions.",
	  IncomeBonus=1.8, BodyShape="tall" },

	-- Epic brainrots
	{ Id="strawberry_elephant",   DisplayName="Strawberry Elephant",     Rarity="Epic",
	  PrimaryColor=C(230,60,90),   SecondaryColor=C(255,150,170),
	  Description="The legendary strawberry-scented elephant. Its trunk vacuums up coins at epic speed.",
	  IncomeBonus=2.5, BodyShape="wide" },
	{ Id="banana_crocodile",      DisplayName="Banana Crocodile",        Rarity="Epic",
	  PrimaryColor=C(240,210,40),  SecondaryColor=C(80,160,60),
	  Description="Slips on its own peels but somehow generates absurd income.",
	  IncomeBonus=2.4, BodyShape="wide" },
	{ Id="chimpanzini_bananini",  DisplayName="Chimpanzini Bananini",    Rarity="Epic",
	  PrimaryColor=C(200,140,60),  SecondaryColor=C(240,210,60),
	  Description="A tiny monkey-banana hybrid that pelts you with gold bananas.",
	  IncomeBonus=2.6, BodyShape="round" },
	{ Id="glorbo_magnifico",      DisplayName="Glorbo Magnifico",        Rarity="Epic",
	  PrimaryColor=C(180,60,220),  SecondaryColor=C(255,160,255),
	  Description="No one knows what Glorbo is, but it pays magnificently.",
	  IncomeBonus=2.8, BodyShape="orb" },

	-- Legendary brainrots
	{ Id="frigo_camelo",          DisplayName="Frigo Camelo",            Rarity="Legendary",
	  PrimaryColor=C(160,210,240), SecondaryColor=C(220,240,255),
	  Description="A freezing camel made of solid ice. Each hump stores frozen gold coins.",
	  IncomeBonus=3.5, BodyShape="wide" },
	{ Id="bombombini_gusini",     DisplayName="Bombombini Gusini",       Rarity="Legendary",
	  PrimaryColor=C(60,80,160),   SecondaryColor=C(140,160,255),
	  Description="A goose that detonates golden eggs on a loop. Impossibly lucrative.",
	  IncomeBonus=3.8, BodyShape="orb" },
	{ Id="trippi_troppi",         DisplayName="Trippi Troppi",           Rarity="Legendary",
	  PrimaryColor=C(255,120,60),  SecondaryColor=C(255,220,100),
	  Description="A psychedelic tropical bird whose plumage shimmers solid gold.",
	  IncomeBonus=3.6, BodyShape="dragon" },

	-- Mythic brainrots
	{ Id="giogio_magnifico",      DisplayName="Giogio Magnifico",        Rarity="Mythic",
	  PrimaryColor=C(255,215,0),   SecondaryColor=C(255,255,180),
	  Description="The mythic golden being of pure Italian brainrot. Transcends all known creatures.",
	  IncomeBonus=7.0, BodyShape="orb" },
	{ Id="grand_strawberry_lord", DisplayName="Grand Strawberry Lord",   Rarity="Mythic",
	  PrimaryColor=C(220,30,60),   SecondaryColor=C(255,100,130),
	  Description="The ultimate evolution of the Strawberry Elephant. Sovereign of all brainrots.",
	  IncomeBonus=8.0, BodyShape="wide" },
	{ Id="omni_brainrot",         DisplayName="Omni-Brainrot",           Rarity="Mythic",
	  PrimaryColor=C(100,0,200),   SecondaryColor=C(255,60,255),
	  Description="Contains ALL brainrots simultaneously. Its income is literally incomprehensible.",
	  IncomeBonus=10.0, BodyShape="dragon" },
}

-- Index creatures by id and rarity.
local creatureById: { [string]: LuckyCreatureDef } = {}
local creaturesByRarity: { [string]: { LuckyCreatureDef } } = {}
for _, c in ipairs(LuckyBlockData.Creatures) do
	creatureById[c.Id] = c
	if not creaturesByRarity[c.Rarity] then creaturesByRarity[c.Rarity] = {} end
	table.insert(creaturesByRarity[c.Rarity], c)
end

function LuckyBlockData.GetCreature(id: string): LuckyCreatureDef?
	return creatureById[id]
end

function LuckyBlockData.GetCreaturesByRarity(rarity: string): { LuckyCreatureDef }
	return creaturesByRarity[rarity] or {}
end

-- Roll a random rarity given zone weights.
function LuckyBlockData.RollRarity(weights: { [string]: number }, rng: Random): string
	local roll = rng:NextNumber()
	local cumulative = 0
	for _, rarity in ipairs(rarityOrder) do
		cumulative += weights[rarity] or 0
		if roll <= cumulative then return rarity end
	end
	return "Common"
end

-- Roll a random creature of the given rarity.
function LuckyBlockData.RollCreature(rarity: string, rng: Random): LuckyCreatureDef
	local pool = creaturesByRarity[rarity]
	if not pool or #pool == 0 then
		pool = creaturesByRarity["Common"]
	end
	return pool[rng:NextInteger(1, #pool)]
end

-- ── Speed Upgrade Tiers ────────────────────────────────────────────────────

export type SpeedTier = {
	Level: number,
	WalkSpeed: number,
	Cost: number,
	Label: string,
	Color: Color3,
}

LuckyBlockData.SpeedTiers: { SpeedTier } = {
	{ Level=0, WalkSpeed=16, Cost=0,      Label="Default",      Color=C(160,160,160) },
	{ Level=1, WalkSpeed=18, Cost=500,    Label="Swift",        Color=C(120,220,120) },
	{ Level=2, WalkSpeed=21, Cost=1200,   Label="Speedy",       Color=C(80,200,200)  },
	{ Level=3, WalkSpeed=25, Cost=3000,   Label="Sprinter",     Color=C(80,140,255)  },
	{ Level=4, WalkSpeed=30, Cost=7000,   Label="Dasher",       Color=C(160,60,230)  },
	{ Level=5, WalkSpeed=34, Cost=15000,  Label="Racer",        Color=C(255,160,0)   },
	{ Level=6, WalkSpeed=38, Cost=32000,  Label="Blazer",       Color=C(255,100,40)  },
	{ Level=7, WalkSpeed=43, Cost=70000,  Label="Sonic",        Color=C(255,40,40)   },
	{ Level=8, WalkSpeed=50, Cost=150000, Label="Transcendent", Color=C(255,60,130)  },
}

function LuckyBlockData.GetSpeedTier(level: number): SpeedTier
	return LuckyBlockData.SpeedTiers[math.clamp(level, 0, 8) + 1]
end

-- ── Base Slot Tiers ────────────────────────────────────────────────────────

export type BaseSlotTier = { Slots: number, Cost: number }

LuckyBlockData.BaseSlotTiers: { BaseSlotTier } = {
	{ Slots=4,  Cost=0     },
	{ Slots=6,  Cost=250   },
	{ Slots=8,  Cost=900   },
	{ Slots=12, Cost=3000  },
	{ Slots=16, Cost=9000  },
	{ Slots=24, Cost=28000 },
}

return LuckyBlockData
