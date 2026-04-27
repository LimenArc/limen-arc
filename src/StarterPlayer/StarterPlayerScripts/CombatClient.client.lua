--!strict
-- Combat input for Valiant Sky.
-- Click = basic attack, 1-5 = skills, B/G = block, double-tap WASD = dash.

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player  = Players.LocalPlayer

-- ── Local cooldown tracking (client-predicted, UI only) ───────────────────────

local localCooldowns: { [string]: number } = {
	basic = 0,
	["1"] = 0, ["2"] = 0, ["3"] = 0, ["4"] = 0, ["5"] = 0,
}

_G.CombatCooldowns = localCooldowns  -- read by HUD

-- ── Basic attack (left click) ─────────────────────────────────────────────────

local mouse = player:GetMouse()
mouse.Button1Down:Connect(function()
	-- Don't attack if blocking key is held
	if UserInputService:IsKeyDown(Enum.KeyCode.B)
		or UserInputService:IsKeyDown(Enum.KeyCode.G) then
		return
	end
	Remotes.Events.CombatBasicAttack:FireServer()
	localCooldowns.basic = os.clock()
end)

-- ── Skills (keys 1-5) ─────────────────────────────────────────────────────────

local skillKeys: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.One]   = "1",
	[Enum.KeyCode.Two]   = "2",
	[Enum.KeyCode.Three] = "3",
	[Enum.KeyCode.Four]  = "4",
	[Enum.KeyCode.Five]  = "5",
}

-- ── Block (B or G hold) ───────────────────────────────────────────────────────

local function sendBlockState()
	local blocking = UserInputService:IsKeyDown(Enum.KeyCode.B)
		or UserInputService:IsKeyDown(Enum.KeyCode.G)
	Remotes.Events.CombatBlock:FireServer(blocking)
end

-- ── Dash (double-tap WASD) ────────────────────────────────────────────────────

local DOUBLE_TAP_WINDOW = 0.28
local lastTap: { [Enum.KeyCode]: number } = {}
local dashKeys: { Enum.KeyCode } = {
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
}

-- ── Unified InputBegan ────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then return end

	-- Skills
	local slot = skillKeys[input.KeyCode]
	if slot then
		Remotes.Events.CombatSkill:FireServer(slot)
		localCooldowns[slot] = os.clock()
		return
	end

	-- Block
	if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.G then
		sendBlockState()
		return
	end

	-- Dash detection
	for _, k in ipairs(dashKeys) do
		if input.KeyCode == k then
			local now = tick()
			local prev = lastTap[k]
			if prev and (now - prev) < DOUBLE_TAP_WINDOW then
				Remotes.Events.CombatDash:FireServer()
				lastTap[k] = 0
			else
				lastTap[k] = now
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.G then
		sendBlockState()
	end
end)
