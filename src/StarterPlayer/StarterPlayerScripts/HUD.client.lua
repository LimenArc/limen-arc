--!strict
-- Small persistent HUD: coin count, active monster, selected trap, key hints.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))
local MonsterData = require(Modules:WaitForChild("MonsterData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "HUDGui"
screen.ResetOnSpawn = false
screen.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 16, 1, -16)
panel.Size = UDim2.fromOffset(320, 112)
panel.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = screen
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local function line(i: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Position = UDim2.fromOffset(12, 6 + (i - 1) * 22)
	l.Size = UDim2.new(1, -20, 0, 22)
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Font = Enum.Font.GothamBold
	l.TextSize = 14
	l.TextColor3 = color
	l.Text = ""
	l.Parent = panel
	return l
end

local coinsLine = line(1, Color3.fromRGB(240, 210, 120))
local monLine   = line(2, Color3.fromRGB(200, 230, 240))
local trapLine  = line(3, Color3.fromRGB(210, 200, 240))
local hintLine  = line(4, Color3.fromRGB(160, 160, 180))
hintLine.Text   = "[M] mod menu   [B] backpack   [F] trap   [E] market"

local function refresh()
	local save = _G.SaveCache and _G.SaveCache.Save
	if save then
		coinsLine.Text = ("Coins: %d"):format(save.Coins or 0)
		if save.ActiveMonsterUuid then
			for _, mon in ipairs(save.Monsters) do
				if mon.Uuid == save.ActiveMonsterUuid then
					local def = MonsterData.Get(mon.SpeciesId)
					if def then
						monLine.Text = ("Active: %s  Lv %d  (%d/%d HP)"):format(
							mon.Nickname or def.DisplayName, mon.Level, mon.CurrentHP, mon.MaxHP)
					end
					break
				end
			end
		else
			monLine.Text = "Active: none — catch one!"
		end
	else
		coinsLine.Text = "Coins: —"
		monLine.Text = "Active: —"
	end
	local trapId = _G.SelectedTrap and _G.SelectedTrap() or "trap_basic"
	local trap = ItemData.Get(trapId)
	trapLine.Text = ("Trap [1–5]: %s"):format(if trap then trap.DisplayName else trapId)
end

RunService.Heartbeat:Connect(refresh)
