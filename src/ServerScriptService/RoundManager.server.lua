--!strict

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes    = require(ReplicatedStorage.Remotes)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

while not _G.PlayerSetup do task.wait() end
local PlayerSetup = _G.PlayerSetup

-- ── State ─────────────────────────────────────────────────────────────────────

type RoundState = {
	mode:          string,
	active:        boolean,
	timeRemaining: number,
	leaderboard:   { [number]: number }, -- userId → kills
	oneVoneIds:    { number }?,
}

local state: RoundState = {
	mode          = GameConfig.DefaultMechanics.RoundMode,
	active        = false,
	timeRemaining = GameConfig.DefaultMechanics.RoundDuration,
	leaderboard   = {},
	oneVoneIds    = nil,
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function broadcast()
	local lb: { [string]: number } = {}
	for uid, kills in pairs(state.leaderboard) do
		lb[tostring(uid)] = kills
	end
	Remotes.Events.RoundStateUpdate:FireAllClients({
		mode          = state.mode,
		timeRemaining = state.timeRemaining,
		leaderboard   = lb,
		active        = state.active,
	})
end

local function countAlive(): (number, Player?)
	local count = 0
	local last: Player? = nil
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			count += 1
			last = player
		end
	end
	return count, last
end

local function announceWinner(winner: Player?)
	local msg = winner and (winner.Name .. " wins the round!") or "Round over!"
	Remotes.Events.Notify:FireAllClients(msg)
end

-- ── Public API ────────────────────────────────────────────────────────────────

local RoundManager = {}
_G.RoundManager = RoundManager

function RoundManager.GetLeaderboard(): { [number]: number }
	return state.leaderboard
end

function RoundManager.SetMode(mode: string)
	state.mode = mode
	RoundManager.EndRound()
	task.delay(3, function()
		RoundManager.StartRound(mode)
	end)
end

function RoundManager.SetDuration(seconds: number)
	state.timeRemaining = seconds
end

function RoundManager.StartRound(mode: string)
	state.mode    = mode
	state.active  = true
	state.leaderboard = {}

	-- Reset kills for all players
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerSetup.ResetKills(player)
		state.leaderboard[player.UserId] = 0
	end

	if mode == "1v1" then
		local all = Players:GetPlayers()
		if #all >= 2 then
			local i1 = math.random(1, #all)
			local i2 = math.random(1, #all - 1)
			if i2 >= i1 then i2 += 1 end
			state.oneVoneIds = { all[i1].UserId, all[i2].UserId }
			Remotes.Events.Notify:FireAllClients(
				"1v1: " .. all[i1].Name .. " vs " .. all[i2].Name
			)
		end
	else
		state.oneVoneIds = nil
	end

	broadcast()
end

function RoundManager.EndRound()
	state.active = false

	if state.mode == "FFA" or state.mode == "1v1" then
		-- winner = player with most kills
		local topKills = -1
		local winner: Player? = nil
		for uid, kills in pairs(state.leaderboard) do
			if kills > topKills then
				topKills = kills
				winner = Players:GetPlayerByUserId(uid)
			end
		end
		announceWinner(winner)
	elseif state.mode == "TimedFFA" then
		local topKills = -1
		local winner: Player? = nil
		for uid, kills in pairs(state.leaderboard) do
			if kills > topKills then
				topKills = kills
				winner = Players:GetPlayerByUserId(uid)
			end
		end
		announceWinner(winner)
	end

	broadcast()
end

function RoundManager.OnKill(killer: Player, victim: Player)
	if not state.active then return end

	state.leaderboard[killer.UserId] = (state.leaderboard[killer.UserId] or 0) + 1
	broadcast()

	if state.mode == "FFA" then
		local alive, lastAlive = countAlive()
		if alive <= 1 then
			RoundManager.EndRound()
			task.delay(8, function()
				RoundManager.StartRound(state.mode)
			end)
		end
	elseif state.mode == "1v1" then
		local ids = state.oneVoneIds
		if ids then
			local victimId = victim.UserId
			if victimId == ids[1] or victimId == ids[2] then
				RoundManager.EndRound()
				task.delay(8, function()
					RoundManager.StartRound(state.mode)
				end)
			end
		end
	end
end

-- ── TimedFFA countdown ────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(1)
		if state.active and state.mode == "TimedFFA" then
			state.timeRemaining = math.max(0, state.timeRemaining - 1)
			broadcast()
			if state.timeRemaining <= 0 then
				state.timeRemaining = PlayerSetup.GetMechanics().RoundDuration
				RoundManager.EndRound()
				task.delay(8, function()
					RoundManager.StartRound(state.mode)
				end)
			end
		end
	end
end)

-- ── Auto-start ────────────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function()
	if not state.active and #Players:GetPlayers() >= 1 then
		task.delay(3, function()
			if not state.active then
				RoundManager.StartRound(GameConfig.DefaultMechanics.RoundMode)
			end
		end)
	end
end)

task.delay(5, function()
	if not state.active then
		RoundManager.StartRound(GameConfig.DefaultMechanics.RoundMode)
	end
end)
