--!strict

export type MoveData = {
	name: string,
	damage: number,
	cooldown: number,
	range: number,
	type: string, -- "melee" | "grab" | "dash" | "aoe" | "projectile"
}

export type MovesetDef = {
	name: string,
	moves: {
		basic: MoveData,
		["1"]: MoveData,
		["2"]: MoveData,
		["3"]: MoveData,
		["4"]: MoveData,
		["5"]: MoveData,
	},
}

local MovesetData = {}

local Registry: { [string]: MovesetDef } = {}
local BuiltinNames: { string } = {}

local function reg(def: MovesetDef)
	Registry[def.name] = def
	table.insert(BuiltinNames, def.name)
end

-- ── Built-in movesets ────────────────────────────────────────────────────────

reg({
	name = "Flame Strike",
	moves = {
		basic = { name = "Flame Jab",     damage = 22,  cooldown = 0.5,  range = 8,  type = "melee"     },
		["1"] = { name = "Ember Dash",    damage = 45,  cooldown = 5,    range = 12, type = "dash"      },
		["2"] = { name = "Fire Wheel",    damage = 60,  cooldown = 8,    range = 15, type = "aoe"       },
		["3"] = { name = "Inferno Slam",  damage = 80,  cooldown = 12,   range = 10, type = "melee"     },
		["4"] = { name = "Phoenix Dive",  damage = 50,  cooldown = 18,   range = 20, type = "dash"      },
		["5"] = { name = "Solar Domain",  damage = 200, cooldown = 60,   range = 25, type = "aoe"       },
	},
})

reg({
	name = "Shadow Form",
	moves = {
		basic = { name = "Dark Slash",    damage = 20,  cooldown = 0.5,  range = 8,  type = "melee"     },
		["1"] = { name = "Void Grab",     damage = 45,  cooldown = 5,    range = 10, type = "grab"      },
		["2"] = { name = "Shadow Rush",   damage = 60,  cooldown = 8,    range = 15, type = "dash"      },
		["3"] = { name = "Dark Surge",    damage = 80,  cooldown = 12,   range = 20, type = "aoe"       },
		["4"] = { name = "Shadow Clone",  damage = 40,  cooldown = 18,   range = 8,  type = "melee"     },
		["5"] = { name = "Domain: Abyss", damage = 200, cooldown = 60,   range = 25, type = "aoe"       },
	},
})

reg({
	name = "Titan Slam",
	moves = {
		basic = { name = "Iron Fist",     damage = 25,  cooldown = 0.6,  range = 7,  type = "melee"     },
		["1"] = { name = "Shockwave",     damage = 50,  cooldown = 6,    range = 12, type = "aoe"       },
		["2"] = { name = "Boulder Throw", damage = 55,  cooldown = 9,    range = 18, type = "projectile"},
		["3"] = { name = "Ground Pound",  damage = 90,  cooldown = 14,   range = 10, type = "aoe"       },
		["4"] = { name = "Titan Grab",    damage = 60,  cooldown = 20,   range = 8,  type = "grab"      },
		["5"] = { name = "Earthbreaker",  damage = 220, cooldown = 65,   range = 20, type = "aoe"       },
	},
})

reg({
	name = "Swift Blade",
	moves = {
		basic = { name = "Quick Slash",   damage = 18,  cooldown = 0.4,  range = 9,  type = "melee"     },
		["1"] = { name = "Blade Fan",     damage = 40,  cooldown = 4,    range = 14, type = "aoe"       },
		["2"] = { name = "Flash Step",    damage = 55,  cooldown = 7,    range = 16, type = "dash"      },
		["3"] = { name = "Sword Rain",    damage = 75,  cooldown = 11,   range = 22, type = "projectile"},
		["4"] = { name = "Phantom Cuts",  damage = 45,  cooldown = 16,   range = 10, type = "melee"     },
		["5"] = { name = "Thousand Blades",damage = 190,cooldown = 58,   range = 28, type = "aoe"       },
	},
})

reg({
	name = "Storm Caller",
	moves = {
		basic = { name = "Thunder Jab",   damage = 20,  cooldown = 0.5,  range = 8,  type = "melee"     },
		["1"] = { name = "Lightning Bolt",damage = 50,  cooldown = 5,    range = 20, type = "projectile"},
		["2"] = { name = "Static Field",  damage = 60,  cooldown = 8,    range = 14, type = "aoe"       },
		["3"] = { name = "Thunder Clap",  damage = 85,  cooldown = 13,   range = 12, type = "aoe"       },
		["4"] = { name = "Storm Dash",    damage = 45,  cooldown = 17,   range = 18, type = "dash"      },
		["5"] = { name = "Eye of Storm",  damage = 210, cooldown = 62,   range = 30, type = "aoe"       },
	},
})

-- ── API ──────────────────────────────────────────────────────────────────────

function MovesetData.GetAll(): { MovesetDef }
	local out: { MovesetDef } = {}
	for _, def in pairs(Registry) do
		table.insert(out, def)
	end
	return out
end

function MovesetData.Get(name: string): MovesetDef?
	return Registry[name]
end

function MovesetData.Register(def: MovesetDef): boolean
	if Registry[def.name] then return false end
	Registry[def.name] = def
	return true
end

function MovesetData.IsBuiltin(name: string): boolean
	for _, n in ipairs(BuiltinNames) do
		if n == name then return true end
	end
	return false
end

function MovesetData.GetBuiltinNames(): { string }
	return BuiltinNames
end

function MovesetData.GetRegisteredNames(): { string }
	local names: { string } = {}
	for name in pairs(Registry) do
		table.insert(names, name)
	end
	return names
end

return MovesetData
