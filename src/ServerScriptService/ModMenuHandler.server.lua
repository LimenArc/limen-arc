--!strict

local Players           = game:GetService("Players")
local HttpService        = game:GetService("HttpService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local GameConfig     = require(ReplicatedStorage.Modules.GameConfig)
local MovesetData    = require(ReplicatedStorage.Modules.MovesetData)
local MapData        = require(ReplicatedStorage.Modules.MapData)
local JSONValidator  = require(ReplicatedStorage.Modules.JSONValidator)
local Remotes        = require(ReplicatedStorage.Remotes)

while not _G.PlayerSetup  do task.wait() end
while not _G.MapManager   do task.wait() end
while not _G.RoundManager do task.wait() end

local PlayerSetup  = _G.PlayerSetup
local MapManager   = _G.MapManager
local RoundManager = _G.RoundManager

-- ── Allow-list check ─────────────────────────────────────────────────────────

local function isAllowed(player: Player): boolean
	local list = GameConfig.ModMenuAllowedUserIds
	if next(list) == nil then return true end -- empty = dev mode (everyone)
	return list[player.UserId] == true
end

local function deny(player: Player, reason: string)
	Remotes.Events.Notify:FireClient(player, "Mod menu: " .. reason)
end

-- ── Registered name sets ──────────────────────────────────────────────────────

local function movesetNameSet(): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, def in ipairs(MovesetData.GetAll()) do
		set[def.name] = true
	end
	return set
end

local function mapNameSet(): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, def in ipairs(MapData.GetAll()) do
		set[def.name] = true
	end
	return set
end

-- ── Mechanic range check ──────────────────────────────────────────────────────

local function mechanicInRange(key: string, value: any): (boolean, string?)
	local rangeDef = (GameConfig.MechanicsRanges :: any)[key]
	if not rangeDef then return false, "unknown mechanic key: " .. key end

	if rangeDef.options then
		for _, opt in ipairs(rangeDef.options) do
			if value == opt then return true, nil end
		end
		return false, key .. ": invalid option '" .. tostring(value) .. "'"
	end

	if type(value) ~= "number" then
		return false, key .. ": expected a number"
	end
	if value < rangeDef.min or value > rangeDef.max then
		return false,
			key .. ": must be " .. rangeDef.min .. "–" .. rangeDef.max
	end
	return true, nil
end

-- ── GetModMenuState ───────────────────────────────────────────────────────────

Remotes.Functions.GetModMenuState.OnServerInvoke = function(player: Player)
	local movesetList: { { name: string, isBuiltin: boolean } } = {}
	for _, def in ipairs(MovesetData.GetAll()) do
		table.insert(movesetList, {
			name      = def.name,
			isBuiltin = MovesetData.IsBuiltin(def.name),
		})
	end

	local mapList: { { name: string, isBuiltin: boolean } } = {}
	for _, def in ipairs(MapData.GetAll()) do
		table.insert(mapList, {
			name      = def.name,
			isBuiltin = MapData.IsBuiltin(def.name),
		})
	end

	local currentMap = MapManager.GetCurrentMap()

	return {
		Allowed       = isAllowed(player),
		Mechanics     = PlayerSetup.GetMechanics(),
		MovesetList   = movesetList,
		MapList       = mapList,
		PlayerMoveset = PlayerSetup.GetMoveset(player).name,
		CurrentMap    = currentMap and currentMap.name or "",
	}
end

-- ── ModMenuSetMechanic ────────────────────────────────────────────────────────

Remotes.Events.ModMenuSetMechanic.OnServerEvent:Connect(function(player: Player, key: unknown, value: unknown)
	if not isAllowed(player) then deny(player, "not authorized") return end
	if type(key) ~= "string" then return end

	local valid, errMsg = mechanicInRange(key, value)
	if not valid then
		deny(player, errMsg or "invalid value")
		return
	end

	local mechanics = PlayerSetup.GetMechanics()
	;(mechanics :: any)[key] = value

	-- Side effects for keys that affect live state immediately
	if key == "Gravity" then
		workspace.Gravity = value :: number
	end
	if key == "MaxHP" or key == "MoveSpeed" then
		PlayerSetup.ApplyMechanicsToAll()
	end
	if key == "RoundMode" then
		RoundManager.SetMode(value :: string)
	end
	if key == "RoundDuration" then
		RoundManager.SetDuration(value :: number)
	end
end)

-- ── ModMenuApplyMoveset ───────────────────────────────────────────────────────

Remotes.Events.ModMenuApplyMoveset.OnServerEvent:Connect(function(player: Player, movesetName: unknown)
	if not isAllowed(player) then deny(player, "not authorized") return end
	if type(movesetName) ~= "string" then return end

	local def = MovesetData.Get(movesetName)
	if not def then
		deny(player, "unknown moveset: " .. movesetName)
		return
	end
	PlayerSetup.SetMoveset(player, def)
	Remotes.Events.Notify:FireClient(player, "Moveset applied: " .. movesetName)
end)

-- ── ModMenuUploadMoveset ──────────────────────────────────────────────────────

Remotes.Events.ModMenuUploadMoveset.OnServerEvent:Connect(function(player: Player, rawJson: unknown)
	if not isAllowed(player) then deny(player, "not authorized") return end
	if type(rawJson) ~= "string" then return end
	if #rawJson > 4096 then
		deny(player, "moveset JSON too large (max 4096 bytes)")
		return
	end

	local parseOk, parsed = pcall(function()
		return HttpService:JSONDecode(rawJson)
	end)
	if not parseOk then
		deny(player, "invalid JSON: parse failed")
		return
	end

	local result = JSONValidator.ValidateMoveset(parsed, movesetNameSet())
	if not result.ok then
		deny(player, "invalid moveset: " .. (result.err or "unknown error"))
		return
	end

	MovesetData.Register(parsed :: any)
	PlayerSetup.SetMoveset(player, parsed :: any)
	Remotes.Events.Notify:FireClient(player, "Moveset registered: " .. tostring((parsed :: any).name))
end)

-- ── ModMenuSwitchMap ──────────────────────────────────────────────────────────

Remotes.Events.ModMenuSwitchMap.OnServerEvent:Connect(function(player: Player, mapName: unknown)
	if not isAllowed(player) then deny(player, "not authorized") return end
	if type(mapName) ~= "string" then return end

	local def = MapData.Get(mapName)
	if not def then
		deny(player, "unknown map: " .. mapName)
		return
	end
	MapManager.LoadMap(def)
end)

-- ── ModMenuUploadMap ──────────────────────────────────────────────────────────

Remotes.Events.ModMenuUploadMap.OnServerEvent:Connect(function(player: Player, rawJson: unknown)
	if not isAllowed(player) then deny(player, "not authorized") return end
	if type(rawJson) ~= "string" then return end
	if #rawJson > 8192 then
		deny(player, "map JSON too large (max 8192 bytes)")
		return
	end

	local parseOk, parsed = pcall(function()
		return HttpService:JSONDecode(rawJson)
	end)
	if not parseOk then
		deny(player, "invalid JSON: parse failed")
		return
	end

	local result = JSONValidator.ValidateMap(parsed, mapNameSet())
	if not result.ok then
		deny(player, "invalid map: " .. (result.err or "unknown error"))
		return
	end

	MapData.Register(parsed :: any)
	MapManager.LoadMap(parsed :: any)
	Remotes.Events.Notify:FireAllClients("New map loaded: " .. tostring((parsed :: any).name))
end)
