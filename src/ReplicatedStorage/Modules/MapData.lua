--!strict

export type PlatformDef = {
	pos:   { number }, -- [x, y, z]
	size:  { number }, -- [x, y, z]
	color: { number }, -- [r, g, b] 0-255
}

export type MapDef = {
	name:        string,
	theme:       string,
	skyboxColor: { number },      -- [r, g, b]
	platforms:   { PlatformDef },
	spawnPoints: { { number } },  -- array of [x, y, z]
	boundaries:  number,          -- kill-floor radius from origin
}

local MapData = {}

local Registry: { [string]: MapDef } = {}
local BuiltinNames: { string } = {}

local function reg(def: MapDef)
	Registry[def.name] = def
	table.insert(BuiltinNames, def.name)
end

-- ── Built-in maps ────────────────────────────────────────────────────────────

reg({
	name        = "Flat Arena",
	theme       = "plain",
	skyboxColor = { 100, 120, 160 },
	platforms   = {
		{ pos = {  0,  0,  0 }, size = { 150, 4, 150 }, color = { 140, 140, 150 } },
	},
	spawnPoints = {
		{ -40, 5,   0 },
		{  40, 5,   0 },
		{   0, 5, -40 },
		{   0, 5,  40 },
	},
	boundaries  = 100,
})

reg({
	name        = "Rooftop",
	theme       = "urban",
	skyboxColor = { 50, 50, 80 },
	platforms   = {
		{ pos = {  0,  0,   0 }, size = { 120, 4, 120 }, color = {  80,  80,  90 } },
		{ pos = { 60, 14,   0 }, size = {  40, 4,  40 }, color = {  60,  60,  70 } },
		{ pos = {-60, 14,   0 }, size = {  40, 4,  40 }, color = {  60,  60,  70 } },
		{ pos = {  0, 14,  60 }, size = {  40, 4,  40 }, color = {  60,  60,  70 } },
		{ pos = {  0, 14, -60 }, size = {  40, 4,  40 }, color = {  60,  60,  70 } },
		{ pos = {  0, 28,   0 }, size = {  30, 4,  30 }, color = {  50,  50,  60 } },
	},
	spawnPoints = {
		{ -35, 5,   0 },
		{  35, 5,   0 },
		{   0, 5, -35 },
		{   0, 5,  35 },
	},
	boundaries  = 120,
})

reg({
	name        = "Forest Clearing",
	theme       = "nature",
	skyboxColor = { 120, 160, 100 },
	platforms   = {
		{ pos = {  0,  0,   0 }, size = { 160, 4, 160 }, color = {  80, 110,  60 } },
		{ pos = {  0, 10,  65 }, size = {  30, 4,  20 }, color = {  90,  60,  30 } },
		{ pos = {  0, 10, -65 }, size = {  30, 4,  20 }, color = {  90,  60,  30 } },
		{ pos = { 65, 10,   0 }, size = {  20, 4,  30 }, color = {  90,  60,  30 } },
		{ pos = {-65, 10,   0 }, size = {  20, 4,  30 }, color = {  90,  60,  30 } },
		{ pos = { 50, 16,  50 }, size = {  20, 4,  20 }, color = { 100,  70,  35 } },
		{ pos = {-50, 16,  50 }, size = {  20, 4,  20 }, color = { 100,  70,  35 } },
		{ pos = { 50, 16, -50 }, size = {  20, 4,  20 }, color = { 100,  70,  35 } },
		{ pos = {-50, 16, -50 }, size = {  20, 4,  20 }, color = { 100,  70,  35 } },
	},
	spawnPoints = {
		{ -40, 5,   0 },
		{  40, 5,   0 },
		{   0, 5, -40 },
		{   0, 5,  40 },
	},
	boundaries  = 130,
})

reg({
	name        = "Volcano Peak",
	theme       = "volcanic",
	skyboxColor = { 180, 80, 40 },
	platforms   = {
		{ pos = {  0,  0,   0 }, size = { 140, 4, 140 }, color = {  60,  40,  30 } },
		{ pos = { 30, 12,   0 }, size = {  50, 4,  50 }, color = {  70,  35,  25 } },
		{ pos = {-30, 12,   0 }, size = {  50, 4,  50 }, color = {  70,  35,  25 } },
		{ pos = {  0, 24,   0 }, size = {  40, 4,  40 }, color = {  80,  30,  20 } },
		{ pos = {  0, 38,   0 }, size = {  20, 4,  20 }, color = {  90,  25,  15 } },
	},
	spawnPoints = {
		{ -45, 5,   0 },
		{  45, 5,   0 },
		{   0, 5, -45 },
		{   0, 5,  45 },
	},
	boundaries  = 110,
})

-- ── API ──────────────────────────────────────────────────────────────────────

function MapData.GetAll(): { MapDef }
	local out: { MapDef } = {}
	for _, def in pairs(Registry) do
		table.insert(out, def)
	end
	return out
end

function MapData.Get(name: string): MapDef?
	return Registry[name]
end

function MapData.Register(def: MapDef): boolean
	if Registry[def.name] then return false end
	Registry[def.name] = def
	return true
end

function MapData.IsBuiltin(name: string): boolean
	for _, n in ipairs(BuiltinNames) do
		if n == name then return true end
	end
	return false
end

function MapData.GetBuiltinNames(): { string }
	return BuiltinNames
end

function MapData.GetRegisteredNames(): { string }
	local names: { string } = {}
	for name in pairs(Registry) do
		table.insert(names, name)
	end
	return names
end

return MapData
