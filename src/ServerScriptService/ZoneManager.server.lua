--!strict
-- ZoneManager: tracks which zone each player occupies, enforces speed gates
-- (pushing violators back toward center), and fires ZoneChanged events.
-- Exposes _G.ZoneManager.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig     = require(Modules:WaitForChild("GameConfig"))
local LuckyBlockData = require(Modules:WaitForChild("LuckyBlockData"))
local Remotes        = require(ReplicatedStorage:WaitForChild("Remotes"))

-- ── State ─────────────────────────────────────────────────────────────────

local playerZone: { [number]: number } = {}   -- userId → current zoneId
local pushbackCooldown: { [number]: number } = {}  -- userId → os.clock() expiry

-- ── Helpers ───────────────────────────────────────────────────────────────

local function getRoot(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function currentZoneId(root: BasePart): number
	local pos = root.Position
	local dist = math.sqrt(pos.X * pos.X + pos.Z * pos.Z)
	return LuckyBlockData.ZoneForRadius(dist).Id
end

local function requiredSpeed(zoneId: number): number
	local zone = LuckyBlockData.GetZone(zoneId)
	return zone and zone.MinSpeed or 0
end

local function playerWalkSpeed(player: Player): number
	local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
	if not save then return 16 end
	return LuckyBlockData.GetSpeedTier(save.SpeedLevel).WalkSpeed
end

-- Push the player toward the map center by PushbackStuds.
local function pushBack(player: Player, root: BasePart, violatedZoneId: number)
	local now = os.clock()
	if (pushbackCooldown[player.UserId] or 0) > now then return end
	pushbackCooldown[player.UserId] = now + 2.5

	local pos = root.Position
	local horizontal = Vector3.new(pos.X, 0, pos.Z)
	local dist = horizontal.Magnitude
	if dist < 1 then return end  -- already at center

	-- Move toward center by PushbackStuds.
	local newDist = math.max(dist - GameConfig.ZonePushbackStuds, 0)
	local newXZ = horizontal.Unit * newDist
	root.CFrame = CFrame.new(Vector3.new(newXZ.X, pos.Y, newXZ.Z))

	local zone = LuckyBlockData.GetZone(violatedZoneId)
	local needed = zone and zone.MinSpeed or 0
	Remotes.Events.Notify:FireClient(player,
		("🚫 Need WalkSpeed %d+ to enter %s. Upgrade your speed at the Market!"):format(
		needed, zone and zone.Name or "this zone"))
end

-- ── Check loop ────────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local root = getRoot(player)
			if not root then continue end

			local zoneId = currentZoneId(root)
			local flags = _G.ModMenu and _G.ModMenu.GetFlags(player) or {}

			-- Zone gate: check if player has enough speed.
			if not flags.UnlockAllZones and zoneId > 1 then
				local speed = playerWalkSpeed(player)
				local needed = requiredSpeed(zoneId)
				if speed < needed then
					pushBack(player, root, zoneId)
					-- After pushback, recalculate zone (might have moved to safe zone).
					root = getRoot(player)
					if not root then continue end
					zoneId = currentZoneId(root)
				end
			end

			-- Fire ZoneChanged if the zone changed.
			local prev = playerZone[player.UserId]
			if prev ~= zoneId then
				playerZone[player.UserId] = zoneId

				-- Update furthest zone reached in save.
				local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
				if save and zoneId > (save.FurthestZone or 1) then
					save.FurthestZone = zoneId
				end

				Remotes.Events.ZoneChanged:FireClient(player, zoneId)

				if prev then
					local zone = LuckyBlockData.GetZone(zoneId)
					if zone then
						Remotes.Events.Notify:FireClient(player,
							("➜ Entered %s (Zone %d)"):format(zone.Name, zone.Id))
					end
				end
			end
		end
	end
end)

-- ── Player events ─────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	playerZone[player.UserId] = 1
	pushbackCooldown[player.UserId] = 0
end)

Players.PlayerRemoving:Connect(function(player)
	playerZone[player.UserId] = nil
	pushbackCooldown[player.UserId] = nil
end)

-- ── Remote: GetZoneInfo ───────────────────────────────────────────────────

Remotes.Functions.GetZoneInfo.OnServerInvoke = function(player: Player)
	local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
	local speedLevel = save and save.SpeedLevel or 0
	local speed = LuckyBlockData.GetSpeedTier(speedLevel).WalkSpeed
	return {
		CurrentZoneId = playerZone[player.UserId] or 1,
		PlayerSpeed   = speed,
		Zones         = LuckyBlockData.Zones,
	}
end

-- ── Public API ────────────────────────────────────────────────────────────

local ZoneManager = {}
_G.ZoneManager = ZoneManager

function ZoneManager.GetZone(player: Player): number
	return playerZone[player.UserId] or 1
end

print("[ZoneManager] ready")
