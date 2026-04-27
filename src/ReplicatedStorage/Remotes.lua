--!strict
-- Lazy RemoteEvent / RemoteFunction factory for Valiant Sky.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name   = "Remotes"
	folder.Parent = ReplicatedStorage
end

-- ── Client → Server ──────────────────────────────────────────────────────────
local Events = {
	-- Combat input
	"CombatBasicAttack",      -- click attack
	"CombatSkill",            -- payload: skillSlot (string "1"-"5")
	"CombatBlock",            -- payload: isBlocking (bool)
	"CombatDash",             -- double-tap WASD dash

	-- Mod menu
	"ModMenuSetMechanic",     -- payload: key (string), value (any)
	"ModMenuApplyMoveset",    -- payload: movesetName (string)
	"ModMenuUploadMoveset",   -- payload: rawJson (string)
	"ModMenuSwitchMap",       -- payload: mapName (string)
	"ModMenuUploadMap",       -- payload: rawJson (string)

	-- Server → Client
	"PlayerStateUpdate",      -- { hp, maxHp, moveset, isBlocking }
	"RoundStateUpdate",       -- { mode, timeRemaining, leaderboard }
	"KillFeedEvent",          -- killerName, victimName
	"Notify",                 -- message (string)
	"RespawnCountdown",       -- seconds (number)
	"MapLoaded",              -- mapName (string)
}

-- ── RemoteFunctions ───────────────────────────────────────────────────────────
local Functions = {
	"GetModMenuState",        -- → { Allowed, Mechanics, MovesetList, MapList, PlayerMoveset, CurrentMap }
}

local function ensure(className: string, name: string): Instance
	local existing = folder:FindFirstChild(name)
	if existing then return existing end
	if not RunService:IsServer() then
		return folder:WaitForChild(name, 15)
	end
	local inst = Instance.new(className)
	inst.Name   = name
	inst.Parent = folder
	return inst
end

local Remotes = { Events = {} :: { [string]: RemoteEvent }, Functions = {} :: { [string]: RemoteFunction } }

for _, name in ipairs(Events) do
	Remotes.Events[name] = ensure("RemoteEvent", name) :: RemoteEvent
end
for _, name in ipairs(Functions) do
	Remotes.Functions[name] = ensure("RemoteFunction", name) :: RemoteFunction
end

return Remotes
