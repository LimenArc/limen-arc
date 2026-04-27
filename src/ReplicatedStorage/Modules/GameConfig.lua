--!strict

export type MechanicsConfig = {
	Gravity: number,
	MaxHP: number,
	DamageMultiplier: number,
	BasicDamage: number,
	BasicCooldown: number,
	BasicRange: number,
	MoveSpeed: number,
	RespawnTime: number,
	BlockDamageReduction: number,
	DashIframeDuration: number,
	DashDistance: number,
	RoundMode: string,
	RoundDuration: number,
}

local GameConfig = {}

-- Empty = everyone can use mod menu (dev mode). Add UserIds before shipping.
GameConfig.ModMenuAllowedUserIds: { [number]: boolean } = {}

GameConfig.DefaultMechanics: MechanicsConfig = {
	Gravity              = 196.2,
	MaxHP                = 500,
	DamageMultiplier     = 1.0,
	BasicDamage          = 22,
	BasicCooldown        = 0.5,
	BasicRange           = 8,
	MoveSpeed            = 16,
	RespawnTime          = 5,
	BlockDamageReduction = 0.65,
	DashIframeDuration   = 0.3,
	DashDistance         = 18,
	RoundMode            = "FFA",
	RoundDuration        = 300,
}

GameConfig.DefaultMovesetName = "Flame Strike"
GameConfig.DefaultMapName     = "Flat Arena"

-- Numeric min/max per mechanic key (used by ModMenuHandler for validation).
type NumRange = { min: number, max: number }
type StrOpts  = { options: { string } }
GameConfig.MechanicsRanges: { [string]: NumRange | StrOpts } = {
	Gravity              = { min = 10,   max = 1000  },
	MaxHP                = { min = 50,   max = 10000 },
	DamageMultiplier     = { min = 0.1,  max = 50    },
	BasicDamage          = { min = 1,    max = 9999  },
	BasicCooldown        = { min = 0.05, max = 10    },
	BasicRange           = { min = 1,    max = 100   },
	MoveSpeed            = { min = 2,    max = 100   },
	RespawnTime          = { min = 1,    max = 60    },
	BlockDamageReduction = { min = 0,    max = 1     },
	DashIframeDuration   = { min = 0,    max = 2     },
	DashDistance         = { min = 0,    max = 100   },
	RoundMode            = { options = { "FFA", "TimedFFA", "1v1" } },
	RoundDuration        = { min = 30,   max = 3600  },
}

return GameConfig
