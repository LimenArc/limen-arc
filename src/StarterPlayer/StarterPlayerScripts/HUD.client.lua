--!strict
-- Valiant Sky HUD: HP bar, skill cooldown pips, kill feed, respawn countdown, round info.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player  = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Screen GUI ────────────────────────────────────────────────────────────────

local screen = Instance.new("ScreenGui")
screen.Name          = "HUDGui"
screen.ResetOnSpawn  = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent        = playerGui

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function makeFrame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	for k, v in pairs(props) do (f :: any)[k] = v end
	f.Parent = parent
	return f
end

local function makeLabel(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	for k, v in pairs(props) do (l :: any)[k] = v end
	l.Parent = parent
	return l
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- ── HP Bar (bottom-left) ──────────────────────────────────────────────────────

local hpContainer = makeFrame(screen, {
	AnchorPoint = Vector2.new(0, 1),
	Position    = UDim2.new(0, 16, 1, -16),
	Size        = UDim2.fromOffset(260, 48),
	BackgroundColor3 = Color3.fromRGB(14, 18, 28),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
})
corner(hpContainer, 8)

local nameLabel = makeLabel(hpContainer, {
	Position  = UDim2.fromOffset(10, 4),
	Size      = UDim2.new(1, -20, 0, 18),
	Text      = player.Name,
	Font      = Enum.Font.GothamBold,
	TextSize  = 13,
	TextColor3 = Color3.fromRGB(220, 220, 240),
	TextXAlignment = Enum.TextXAlignment.Left,
})

local hpBarBg = makeFrame(hpContainer, {
	Position = UDim2.fromOffset(10, 26),
	Size     = UDim2.new(1, -20, 0, 14),
	BackgroundColor3 = Color3.fromRGB(50, 30, 30),
	BorderSizePixel  = 0,
})
corner(hpBarBg, 4)

local hpBarFill = makeFrame(hpBarBg, {
	Position = UDim2.fromOffset(0, 0),
	Size     = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(80, 200, 100),
	BorderSizePixel  = 0,
})
corner(hpBarFill, 4)

local hpTextLabel = makeLabel(hpBarBg, {
	Size      = UDim2.fromScale(1, 1),
	Text      = "",
	Font      = Enum.Font.GothamBold,
	TextSize  = 11,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	ZIndex    = 3,
})

-- ── Skill Cooldown Bar (bottom-center) ───────────────────────────────────────

local SLOT_LABELS = { "M", "1", "2", "3", "4", "5" }
local SLOT_KEYS   = { "basic", "1", "2", "3", "4", "5" }
local SLOT_W, SLOT_H, SLOT_GAP = 58, 66, 4
local totalW = #SLOT_LABELS * SLOT_W + (#SLOT_LABELS - 1) * SLOT_GAP

local skillBar = makeFrame(screen, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position    = UDim2.new(0.5, 0, 1, -16),
	Size        = UDim2.fromOffset(totalW + 16, SLOT_H + 16),
	BackgroundColor3 = Color3.fromRGB(14, 18, 28),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
})
corner(skillBar, 8)

type SlotUI = { frame: Frame, keyLabel: TextLabel, nameLabel: TextLabel, cdLabel: TextLabel }
local slots: { SlotUI } = {}

for i, keyStr in ipairs(SLOT_LABELS) do
	local xOff = 8 + (i - 1) * (SLOT_W + SLOT_GAP)
	local slotFrame = makeFrame(skillBar, {
		Position = UDim2.fromOffset(xOff, 8),
		Size     = UDim2.fromOffset(SLOT_W, SLOT_H),
		BackgroundColor3 = Color3.fromRGB(30, 35, 50),
		BorderSizePixel  = 0,
	})
	corner(slotFrame, 6)

	local kl = makeLabel(slotFrame, {
		Position  = UDim2.fromOffset(0, 2),
		Size      = UDim2.new(1, 0, 0, 18),
		Text      = keyStr,
		Font      = Enum.Font.GothamBold,
		TextSize  = 13,
		TextColor3 = Color3.fromRGB(180, 180, 220),
	})

	local nl = makeLabel(slotFrame, {
		Position  = UDim2.fromOffset(0, 20),
		Size      = UDim2.new(1, 0, 0, 26),
		Text      = "—",
		Font      = Enum.Font.Gotham,
		TextSize  = 10,
		TextColor3 = Color3.fromRGB(210, 210, 230),
		TextWrapped = true,
	})

	local cdl = makeLabel(slotFrame, {
		Position  = UDim2.fromOffset(0, 46),
		Size      = UDim2.new(1, 0, 0, 16),
		Text      = "",
		Font      = Enum.Font.GothamBold,
		TextSize  = 11,
		TextColor3 = Color3.fromRGB(255, 190, 60),
	})

	slots[i] = { frame = slotFrame, keyLabel = kl, nameLabel = nl, cdLabel = cdl }
end

-- Current moveset data (names + cooldowns per slot)
local moveNames:     { [string]: string } = {}
local moveCooldowns: { [string]: number } = {}

-- ── Kill Feed (top-right) ─────────────────────────────────────────────────────

local KILLFEED_MAX = 8
local killFeedFrame = makeFrame(screen, {
	AnchorPoint     = Vector2.new(1, 0),
	Position        = UDim2.new(1, -16, 0, 16),
	Size            = UDim2.fromOffset(280, KILLFEED_MAX * 26),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
})

local killFeedLayout = Instance.new("UIListLayout")
killFeedLayout.FillDirection  = Enum.FillDirection.Vertical
killFeedLayout.VerticalAlignment = Enum.VerticalAlignment.Top
killFeedLayout.SortOrder      = Enum.SortOrder.LayoutOrder
killFeedLayout.Padding        = UDim.new(0, 2)
killFeedLayout.Parent         = killFeedFrame

local killEntryCount = 0

local function addKillFeedEntry(killerName: string, victimName: string)
	killEntryCount += 1

	-- Remove oldest if over limit
	local children = killFeedFrame:GetChildren()
	local labels: { TextLabel } = {}
	for _, c in ipairs(children) do
		if c:IsA("TextLabel") then table.insert(labels, c) end
	end
	if #labels >= KILLFEED_MAX then
		table.sort(labels, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		labels[1]:Destroy()
	end

	local entry = makeLabel(killFeedFrame, {
		Size        = UDim2.fromOffset(280, 24),
		Text        = killerName .. "  ⚔  " .. victimName,
		Font        = Enum.Font.GothamBold,
		TextSize    = 13,
		TextColor3  = Color3.fromRGB(240, 200, 100),
		TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundColor3 = Color3.fromRGB(14, 18, 28),
		BackgroundTransparency = 0.3,
		LayoutOrder = killEntryCount,
	})
	corner(entry, 4)

	task.delay(8, function()
		TweenService:Create(entry, TweenInfo.new(0.6), {
			TextTransparency       = 1,
			BackgroundTransparency = 1,
		}):Play()
		task.wait(0.7)
		entry:Destroy()
	end)
end

-- ── Respawn Countdown (center screen) ────────────────────────────────────────

local respawnLabel = makeLabel(screen, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position    = UDim2.fromScale(0.5, 0.45),
	Size        = UDim2.fromOffset(300, 60),
	Text        = "",
	Font        = Enum.Font.GothamBold,
	TextSize    = 28,
	TextColor3  = Color3.fromRGB(255, 100, 100),
	Visible     = false,
})

-- ── Round Info (top-center) ───────────────────────────────────────────────────

local roundContainer = makeFrame(screen, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position    = UDim2.new(0.5, 0, 0, 12),
	Size        = UDim2.fromOffset(300, 42),
	BackgroundColor3 = Color3.fromRGB(14, 18, 28),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
})
corner(roundContainer, 8)

local roundModeLabel = makeLabel(roundContainer, {
	Position  = UDim2.fromOffset(0, 4),
	Size      = UDim2.new(1, 0, 0, 16),
	Text      = "FFA",
	Font      = Enum.Font.GothamBold,
	TextSize  = 13,
	TextColor3 = Color3.fromRGB(200, 200, 255),
})

local roundTimerLabel = makeLabel(roundContainer, {
	Position  = UDim2.fromOffset(0, 22),
	Size      = UDim2.new(1, 0, 0, 16),
	Text      = "",
	Font      = Enum.Font.Gotham,
	TextSize  = 12,
	TextColor3 = Color3.fromRGB(180, 180, 200),
})

-- ── Remote listeners ──────────────────────────────────────────────────────────

Remotes.Events.KillFeedEvent.OnClientEvent:Connect(function(killerName: unknown, victimName: unknown)
	addKillFeedEntry(tostring(killerName), tostring(victimName))
end)

Remotes.Events.RespawnCountdown.OnClientEvent:Connect(function(seconds: unknown)
	local s = tonumber(seconds) or 0
	if s <= 0 then
		respawnLabel.Visible = false
		respawnLabel.Text = ""
	else
		respawnLabel.Visible = true
		respawnLabel.Text = "Respawning in " .. s .. "..."
	end
end)

Remotes.Events.RoundStateUpdate.OnClientEvent:Connect(function(roundState: unknown)
	if type(roundState) ~= "table" then return end
	local rs = roundState :: any
	roundModeLabel.Text = tostring(rs.mode or "FFA")
	if rs.mode == "TimedFFA" then
		local t = math.max(0, math.floor(tonumber(rs.timeRemaining) or 0))
		local mins = math.floor(t / 60)
		local secs = t % 60
		roundTimerLabel.Text = string.format("%d:%02d", mins, secs)
	else
		roundTimerLabel.Text = ""
	end
end)

Remotes.Events.PlayerStateUpdate.OnClientEvent:Connect(function(stateData: unknown)
	if type(stateData) ~= "table" then return end
	local sd = stateData :: any

	-- Update HP bar
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
			hpBarFill.Size = UDim2.new(pct, 0, 1, 0)
			local r = math.floor((1 - pct) * 200)
			local g = math.floor(pct * 200)
			hpBarFill.BackgroundColor3 = Color3.fromRGB(r, g, 60)
			hpTextLabel.Text = math.ceil(hum.Health) .. " / " .. math.ceil(hum.MaxHealth)
		end
	end

	-- Update moveset names/cooldowns
	if type(sd.moveset) == "table" and type(sd.moveset.moves) == "table" then
		local moves = sd.moveset.moves
		for _, slotKey in ipairs({ "basic", "1", "2", "3", "4", "5" }) do
			local m = moves[slotKey]
			if type(m) == "table" then
				moveNames[slotKey]     = tostring(m.name or slotKey)
				moveCooldowns[slotKey] = tonumber(m.cooldown) or 0
			end
		end
	end
end)

-- ── Heartbeat: HP bar update + cooldown pips ─────────────────────────────────

RunService.Heartbeat:Connect(function()
	-- HP bar from Humanoid directly (smoother than waiting for remote)
	local char = player.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		hpBarFill.Size = UDim2.new(pct, 0, 1, 0)
		local r = math.floor((1 - pct) * 200)
		local g = math.floor(pct * 200)
		hpBarFill.BackgroundColor3 = Color3.fromRGB(r, g, 60)
		hpTextLabel.Text = math.ceil(hum.Health) .. " / " .. math.ceil(hum.MaxHealth)
	end

	-- Cooldown pips
	local cds = _G.CombatCooldowns
	if not cds then return end

	for i, slotKey in ipairs(SLOT_KEYS) do
		local slot = slots[i]
		local lastFire  = cds[slotKey] or 0
		local cooldown  = moveCooldowns[slotKey] or 0
		local elapsed   = os.clock() - lastFire
		local remaining = cooldown - elapsed

		slot.nameLabel.Text = moveNames[slotKey] or "—"

		if remaining > 0 then
			slot.cdLabel.Text  = string.format("%.1fs", remaining)
			slot.frame.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
		else
			slot.cdLabel.Text  = ""
			slot.frame.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
		end
	end
end)
