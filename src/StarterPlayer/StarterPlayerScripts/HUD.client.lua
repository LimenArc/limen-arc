--!strict
-- HUD: coin count, active monster, zone, base income, speed level, key hints.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData       = require(Modules:WaitForChild("ItemData"))
local MonsterData    = require(Modules:WaitForChild("MonsterData"))
local LuckyBlockData = require(Modules:WaitForChild("LuckyBlockData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Main panel ────────────────────────────────────────────────────────────

local screen = Instance.new("ScreenGui")
screen.Name = "HUDGui"
screen.ResetOnSpawn = false
screen.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 16, 1, -16)
panel.Size = UDim2.fromOffset(330, 178)
panel.BackgroundColor3 = Color3.fromRGB(10, 12, 22)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = screen
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 1
panelStroke.Color = Color3.fromRGB(50, 55, 80)
panelStroke.Parent = panel

local function line(i: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Position = UDim2.fromOffset(12, 6 + (i - 1) * 24)
	l.Size = UDim2.new(1, -20, 0, 22)
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Font = Enum.Font.GothamBold
	l.TextSize = 13
	l.TextColor3 = color
	l.Text = ""
	l.Parent = panel
	return l
end

local coinsLine  = line(1, Color3.fromRGB(240, 210, 120))
local zoneLine   = line(2, Color3.fromRGB(140, 200, 255))
local speedLine  = line(3, Color3.fromRGB(160, 230, 160))
local incomeLine = line(4, Color3.fromRGB(130, 200, 130))
local monLine    = line(5, Color3.fromRGB(200, 180, 240))
local hintLine   = line(6, Color3.fromRGB(100, 100, 125))
hintLine.Text   = "[E] Block  [G] Base  [U] Upgrades  [M] Mod  [B] Bag"
hintLine.TextSize = 11

-- ── Right-side zone ring indicator ───────────────────────────────────────

local zoneScreen = Instance.new("ScreenGui")
zoneScreen.Name = "ZoneHudGui"
zoneScreen.ResetOnSpawn = false
zoneScreen.Parent = playerGui

local zonePanel = Instance.new("Frame")
zonePanel.AnchorPoint = Vector2.new(1, 1)
zonePanel.Position = UDim2.new(1, -16, 1, -16)
zonePanel.Size = UDim2.fromOffset(200, 120)
zonePanel.BackgroundColor3 = Color3.fromRGB(10, 12, 22)
zonePanel.BackgroundTransparency = 0.12
zonePanel.BorderSizePixel = 0
zonePanel.Parent = zoneScreen
Instance.new("UICorner", zonePanel).CornerRadius = UDim.new(0, 12)

local zonePanelStroke = Instance.new("UIStroke")
zonePanelStroke.Thickness = 1.5
zonePanelStroke.Color = Color3.fromRGB(240, 200, 80)
zonePanelStroke.Parent = zonePanel

local zonePanelTitle = Instance.new("TextLabel")
zonePanelTitle.Size = UDim2.new(1, 0, 0, 22)
zonePanelTitle.Position = UDim2.fromOffset(0, 4)
zonePanelTitle.BackgroundTransparency = 1
zonePanelTitle.Font = Enum.Font.GothamBold
zonePanelTitle.TextSize = 11
zonePanelTitle.TextColor3 = Color3.fromRGB(180, 180, 200)
zonePanelTitle.Text = "CURRENT ZONE"
zonePanelTitle.Parent = zonePanel

local zoneNameHud = Instance.new("TextLabel")
zoneNameHud.Position = UDim2.fromOffset(0, 24)
zoneNameHud.Size = UDim2.new(1, 0, 0, 28)
zoneNameHud.BackgroundTransparency = 1
zoneNameHud.Font = Enum.Font.FredokaOne
zoneNameHud.TextSize = 18
zoneNameHud.TextColor3 = Color3.fromRGB(255, 225, 120)
zoneNameHud.Parent = zonePanel

local zoneDropsHud = Instance.new("TextLabel")
zoneDropsHud.Position = UDim2.fromOffset(0, 52)
zoneDropsHud.Size = UDim2.new(1, 0, 0, 18)
zoneDropsHud.BackgroundTransparency = 1
zoneDropsHud.Font = Enum.Font.Gotham
zoneDropsHud.TextSize = 11
zoneDropsHud.TextColor3 = Color3.fromRGB(160, 180, 220)
zoneDropsHud.TextWrapped = true
zoneDropsHud.Parent = zonePanel

local zoneNextHud = Instance.new("TextLabel")
zoneNextHud.Position = UDim2.fromOffset(0, 70)
zoneNextHud.Size = UDim2.new(1, 0, 0, 34)
zoneNextHud.BackgroundTransparency = 1
zoneNextHud.Font = Enum.Font.Gotham
zoneNextHud.TextSize = 10
zoneNextHud.TextColor3 = Color3.fromRGB(120, 130, 160)
zoneNextHud.TextWrapped = true
zoneNextHud.Parent = zonePanel

-- ── Compute base income from local save ───────────────────────────────────

local function computeLocalIncome(save: {[string]: any}?): number
	if not save then return 0 end
	local placements = save.BasePlacements or {}
	local creatures  = save.LuckyCreatures or {}
	local creatById: {[string]: {[string]: any}} = {}
	for _, e in ipairs(creatures) do creatById[e.Uid] = e end

	local total = 0
	for _, p in ipairs(placements) do
		local entry = creatById[p.Uid]
		if not entry then continue end
		local cd = LuckyBlockData.GetCreature(entry.CreatureId)
		local rd = LuckyBlockData.Rarities[entry.Rarity]
		if cd and rd then
			total += math.floor(rd.BaseIncomePerTick * cd.IncomeBonus)
		end
	end
	return total
end

-- ── Refresh ───────────────────────────────────────────────────────────────

local function refresh()
	local save = _G.SaveCache and _G.SaveCache.Save
	if save then
		coinsLine.Text = ("🪙 %d coins"):format(save.Coins or 0)

		local speedLevel = save.SpeedLevel or 0
		local speedTier = LuckyBlockData.GetSpeedTier(speedLevel)
		speedLine.Text = ("⚡ Speed: %s (WS %d)"):format(speedTier.Label, speedTier.WalkSpeed)

		local income = computeLocalIncome(save)
		incomeLine.Text = if income > 0
			then ("🏠 Base: +%d coins / 5 s"):format(income)
			else "🏠 Base: empty — place creatures!"

		if save.ActiveMonsterUuid then
			for _, mon in ipairs(save.Monsters or {}) do
				if mon.Uuid == save.ActiveMonsterUuid then
					local def = MonsterData.Get(mon.SpeciesId)
					if def then
						monLine.Text = ("★ %s Lv%d (%d/%dHP)"):format(
							mon.Nickname or def.DisplayName, mon.Level, mon.CurrentHP, mon.MaxHP)
					end
					break
				end
			end
		else
			monLine.Text = "No active monster"
		end
	else
		coinsLine.Text = "🪙 Loading..."
		speedLine.Text = ""
		incomeLine.Text = ""
		monLine.Text = ""
	end

	-- Zone panel.
	local zoneId = _G.CurrentZoneId or 1
	local zone = LuckyBlockData.GetZone(zoneId)
	if zone then
		zonePanelStroke.Color = zone.BlockGlow
		zoneNameHud.Text = ("Zone %d: %s"):format(zone.Id, zone.Name)
		zoneNameHud.TextColor3 = zone.BlockGlow
		zoneLine.Text = ("🗺 %s"):format(zone.Name)
		zoneLine.TextColor3 = zone.BlockGlow

		-- Drop summary for current zone.
		local weights = zone.Weights
		local topDrops = ""
		for _, rarity in ipairs({"Legendary","Epic","Rare"}) do
			local w = weights[rarity] or 0
			if w > 0 then
				topDrops = topDrops .. ("%s %.1f%%  "):format(rarity, w * 100)
			end
		end
		zoneDropsHud.Text = topDrops ~= "" and topDrops or "Common drops"

		-- Next zone hint.
		local nextZone = LuckyBlockData.GetZone(zoneId + 1)
		if nextZone then
			local save2 = _G.SaveCache and _G.SaveCache.Save
			local speedLevel = save2 and save2.SpeedLevel or 0
			local currentSpeed = LuckyBlockData.GetSpeedTier(speedLevel).WalkSpeed
			if currentSpeed < nextZone.MinSpeed then
				zoneNextHud.Text = ("Next: %s needs WS %d (you: %d)"):format(
					nextZone.Name, nextZone.MinSpeed, currentSpeed)
				zoneNextHud.TextColor3 = Color3.fromRGB(200, 120, 80)
			else
				zoneNextHud.Text = ("Next: %s — you're fast enough!"):format(nextZone.Name)
				zoneNextHud.TextColor3 = Color3.fromRGB(100, 220, 100)
			end
		else
			zoneNextHud.Text = "You've reached the final zone!"
			zoneNextHud.TextColor3 = Color3.fromRGB(255, 100, 200)
		end
	end
end

RunService.Heartbeat:Connect(refresh)
