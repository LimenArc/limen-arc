--!strict
-- Central game config. Tweak values here instead of chasing magic numbers.

local GameConfig = {}

-- Map dimensions (studs). The world is roughly square, centered on origin.
GameConfig.MapSize = 2048
GameConfig.CellSize = 32

-- Biome weighting. Must sum to 1. Keys match MonsterData biome tags.
GameConfig.BiomeWeights = {
	Grassland = 0.28,
	Forest    = 0.22,
	Desert    = 0.12,
	Tundra    = 0.10,
	Volcanic  = 0.08,
	Swamp     = 0.08,
	Shore     = 0.12,
}

-- Structures scattered across the map.
GameConfig.Cabins = 12
GameConfig.Camps = 18
GameConfig.Caves = 8

-- Spawner.
GameConfig.MaxWildMonsters   = 120
GameConfig.RespawnSeconds    = 8
GameConfig.SpawnRadiusStuds  = 150

-- Combat / capture.
GameConfig.BaseAttackCooldown   = 0.8
GameConfig.CaptureAttemptTicks  = 60      -- frames of "wiggle" before escape
GameConfig.TrapBreakoutBase     = 0.18    -- probability per tick for a basic trap

-- Starting wallet.
GameConfig.StartingCoins = 150

-- DataStore name. Change if forking.
GameConfig.DataStoreName = "MonsterRealm_v1"

-- Mod-menu allow list. Empty table = available to everyone (only do this in
-- development). Put your UserId in here before shipping.
GameConfig.ModMenuAllowedUserIds = {} :: { [number]: boolean }

-- Mod-menu defaults. Flags the client can toggle; server enforces.
GameConfig.ModMenuDefaults = {
	GodMode             = false,
	InfiniteStamina     = false,
	SpeedMultiplier     = 1,    -- 1..8
	JumpMultiplier      = 1,    -- 1..4
	NoClip              = false,
	InfiniteMoney       = false,
	InstantCapture      = false,
	AutoCatch           = false,
	DamageMultiplier    = 1,    -- 0.1..20
	EspMonsters         = false,
	EspLoot             = false,
	XrayCaves           = false,
	InstantLevelUp      = false,
	Weather             = "Clear", -- Clear | Rain | Storm | Snow
	ClockTime           = 14,      -- 0..24
	TimeScale           = 1,       -- 0.1..10
	-- Lucky Block cheats
	FreeUpgrades        = false, -- speed & slot purchases cost 0
	UnlockAllZones      = false, -- disables zone speed gate
	InstantBlock        = false, -- block opens immediately (no hold)
	AutoFarm            = false, -- server auto-opens nearest block every 3s
	MaxBaseIncome       = false, -- base income × 10
	SpawnMythicBlock    = false, -- trigger: spawn a mythic block at player
}

-- ── Lucky Block settings ──────────────────────────────────────────────────
GameConfig.BaseIncomeTickRate  = 5      -- seconds between income ticks
GameConfig.BlockInteractDist   = 14     -- studs; ProximityPrompt MaxDistance
GameConfig.MaxBaseSlots        = 24     -- hard cap on base creature slots
GameConfig.BlockBobAmplitude   = 0.4   -- block hover bob height (studs)
GameConfig.BlockBobSpeed       = 1.2   -- block bob cycles per second
GameConfig.ZonePushbackStuds   = 30    -- how far back player is pushed on gate deny

-- Base plot layout.
GameConfig.BasePlotSize        = 72     -- each player's plot is 72×72 studs
GameConfig.BasePlotsPerRow     = 6      -- 6 plots in a row before wrapping
GameConfig.BasePlotOrigin      = Vector3.new(160, 0, -80) -- world position of first plot

return GameConfig
