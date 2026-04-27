--!strict
-- Shared moveset/map validation. Used by both server (authoritative) and
-- client (UI feedback only). Server always re-validates independently.

local JSONValidator = {}

export type ValidationResult = {
	ok:  boolean,
	err: string?,
}

local VALID_MOVE_TYPES = { melee = true, grab = true, dash = true, aoe = true, projectile = true }
local MOVE_SLOTS = { "basic", "1", "2", "3", "4", "5" }

local function ok(): ValidationResult
	return { ok = true, err = nil }
end

local function fail(msg: string): ValidationResult
	return { ok = false, err = msg }
end

local function isRGB(t: any): boolean
	if type(t) ~= "table" then return false end
	local count = 0
	for _ in pairs(t) do count += 1 end
	if count ~= 3 then return false end
	for i = 1, 3 do
		if type(t[i]) ~= "number" or t[i] < 0 or t[i] > 255 then return false end
	end
	return true
end

local function isXYZ(t: any): boolean
	if type(t) ~= "table" then return false end
	local count = 0
	for _ in pairs(t) do count += 1 end
	if count ~= 3 then return false end
	for i = 1, 3 do
		if type(t[i]) ~= "number" then return false end
	end
	return true
end

local function isAlphanumericSpaces(s: string): boolean
	return s:match("^[%w%s]+$") ~= nil
end

-- ── Moveset validation ───────────────────────────────────────────────────────

function JSONValidator.ValidateMoveset(
	parsed: any,
	registeredNames: { [string]: boolean }
): ValidationResult
	if type(parsed) ~= "table" then
		return fail("must be a JSON object")
	end

	-- name
	if parsed.name == nil then return fail("missing field: name") end
	if type(parsed.name) ~= "string" then return fail("name must be a string") end
	local nameLen = #parsed.name
	if nameLen < 1 or nameLen > 48 then return fail("name must be 1–48 characters") end
	if not isAlphanumericSpaces(parsed.name) then
		return fail("name: only alphanumeric characters and spaces allowed")
	end
	if registeredNames[parsed.name] then
		return fail("name already registered: " .. parsed.name)
	end

	-- moves table
	if parsed.moves == nil then return fail("missing field: moves") end
	if type(parsed.moves) ~= "table" then return fail("moves must be a JSON object") end

	for _, slot in ipairs(MOVE_SLOTS) do
		local move = parsed.moves[slot]
		if move == nil then
			return fail("missing move slot: " .. slot)
		end
		if type(move) ~= "table" then
			return fail("move " .. slot .. " must be an object")
		end

		-- name
		if type(move.name) ~= "string" or #move.name < 1 or #move.name > 48 then
			return fail("move " .. slot .. ".name must be a string (1–48 chars)")
		end
		-- damage
		if type(move.damage) ~= "number" or move.damage < 1 or move.damage > 9999 then
			return fail("move " .. slot .. ".damage must be a number 1–9999")
		end
		-- cooldown
		if type(move.cooldown) ~= "number" or move.cooldown < 0.1 or move.cooldown > 300 then
			return fail("move " .. slot .. ".cooldown must be a number 0.1–300")
		end
		-- range
		if type(move.range) ~= "number" or move.range < 1 or move.range > 100 then
			return fail("move " .. slot .. ".range must be a number 1–100")
		end
		-- type
		if type(move.type) ~= "string" or not VALID_MOVE_TYPES[move.type] then
			return fail("move " .. slot .. ".type must be: melee, grab, dash, aoe, or projectile")
		end
	end

	return ok()
end

-- ── Map validation ───────────────────────────────────────────────────────────

function JSONValidator.ValidateMap(
	parsed: any,
	registeredNames: { [string]: boolean }
): ValidationResult
	if type(parsed) ~= "table" then
		return fail("must be a JSON object")
	end

	-- name
	if parsed.name == nil then return fail("missing field: name") end
	if type(parsed.name) ~= "string" then return fail("name must be a string") end
	local nameLen = #parsed.name
	if nameLen < 1 or nameLen > 48 then return fail("name must be 1–48 characters") end
	if not isAlphanumericSpaces(parsed.name) then
		return fail("name: only alphanumeric characters and spaces allowed")
	end
	if registeredNames[parsed.name] then
		return fail("name already registered: " .. parsed.name)
	end

	-- theme
	if type(parsed.theme) ~= "string" or #parsed.theme < 1 or #parsed.theme > 32 then
		return fail("theme must be a string (1–32 chars)")
	end

	-- skyboxColor
	if not isRGB(parsed.skyboxColor) then
		return fail("skyboxColor must be [r, g, b] with values 0–255")
	end

	-- platforms
	if type(parsed.platforms) ~= "table" then
		return fail("platforms must be a list")
	end
	local platformCount = 0
	for _ in pairs(parsed.platforms) do platformCount += 1 end
	if platformCount < 1 or platformCount > 64 then
		return fail("platforms must have 1–64 entries")
	end
	for i, p in ipairs(parsed.platforms) do
		if type(p) ~= "table" then
			return fail("platform[" .. i .. "] must be an object")
		end
		if not isXYZ(p.pos) then
			return fail("platform[" .. i .. "].pos must be [x, y, z]")
		end
		if not isXYZ(p.size) then
			return fail("platform[" .. i .. "].size must be [x, y, z]")
		end
		for j = 1, 3 do
			if (p.size[j] :: number) < 1 or (p.size[j] :: number) > 512 then
				return fail("platform[" .. i .. "].size each dimension must be 1–512")
			end
		end
		if not isRGB(p.color) then
			return fail("platform[" .. i .. "].color must be [r, g, b] 0–255")
		end
	end

	-- spawnPoints
	if type(parsed.spawnPoints) ~= "table" then
		return fail("spawnPoints must be a list")
	end
	local spawnCount = 0
	for _ in pairs(parsed.spawnPoints) do spawnCount += 1 end
	if spawnCount < 1 or spawnCount > 32 then
		return fail("spawnPoints must have 1–32 entries")
	end
	for i, sp in ipairs(parsed.spawnPoints) do
		if not isXYZ(sp) then
			return fail("spawnPoints[" .. i .. "] must be [x, y, z]")
		end
	end

	-- boundaries
	if type(parsed.boundaries) ~= "number"
		or parsed.boundaries < 20
		or parsed.boundaries > 2000
	then
		return fail("boundaries must be a number 20–2000")
	end

	return ok()
end

return JSONValidator
