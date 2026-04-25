--!strict
-- LuckyBlockClient: plays the block opening animation, shows the reward
-- popup with rarity-coloured styling, and displays a zone status banner.
-- Listens to LuckyBlockResult and BlockOpened server events.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local LuckyBlockData = require(Modules:WaitForChild("LuckyBlockData"))
local Remotes        = require(ReplicatedStorage:WaitForChild("Remotes"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = game:GetService("Workspace").CurrentCamera

-- ── Reward popup ──────────────────────────────────────────────────────────

local popupScreen = Instance.new("ScreenGui")
popupScreen.Name = "LuckyBlockPopup"
popupScreen.ResetOnSpawn = false
popupScreen.DisplayOrder = 20
popupScreen.Parent = playerGui

-- Persistent single popup panel (reused for each reward).
local popupFrame = Instance.new("Frame")
popupFrame.Name = "RewardFrame"
popupFrame.AnchorPoint = Vector2.new(0.5, 0.5)
popupFrame.Position = UDim2.fromScale(0.5, 0.42)
popupFrame.Size = UDim2.fromOffset(360, 220)
popupFrame.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
popupFrame.BackgroundTransparency = 0.08
popupFrame.BorderSizePixel = 0
popupFrame.Visible = false
popupFrame.ZIndex = 10
popupFrame.Parent = popupScreen

Instance.new("UICorner", popupFrame).CornerRadius = UDim.new(0, 14)

local popupStroke = Instance.new("UIStroke")
popupStroke.Thickness = 2
popupStroke.Color = Color3.fromRGB(240, 200, 80)
popupStroke.Parent = popupFrame

-- Drop shadow.
local shadow = Instance.new("Frame")
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.Position = UDim2.fromScale(0.5, 0.5)
shadow.Size = UDim2.new(1, 10, 1, 10)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.55
shadow.BorderSizePixel = 0
shadow.ZIndex = 9
shadow.Parent = popupFrame
Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 16)

-- Header bar.
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundColor3 = Color3.fromRGB(22, 26, 40)
header.BorderSizePixel = 0
header.ZIndex = 11
header.Parent = popupFrame
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 14)

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0.5, 0)
headerFix.Position = UDim2.fromScale(0, 0.5)
headerFix.BackgroundColor3 = Color3.fromRGB(22, 26, 40)
headerFix.BorderSizePixel = 0
headerFix.ZIndex = 11
headerFix.Parent = header

local headerText = Instance.new("TextLabel")
headerText.Size = UDim2.fromScale(1, 1)
headerText.BackgroundTransparency = 1
headerText.Text = "✦  LUCKY BLOCK OPENED  ✦"
headerText.Font = Enum.Font.FredokaOne
headerText.TextSize = 20
headerText.TextColor3 = Color3.fromRGB(255, 225, 120)
headerText.ZIndex = 12
headerText.Parent = header

-- Rarity banner.
local rarityBanner = Instance.new("TextLabel")
rarityBanner.Position = UDim2.fromOffset(0, 44)
rarityBanner.Size = UDim2.new(1, 0, 0, 26)
rarityBanner.BackgroundTransparency = 1
rarityBanner.Font = Enum.Font.GothamBold
rarityBanner.TextSize = 17
rarityBanner.TextColor3 = Color3.fromRGB(200, 200, 200)
rarityBanner.ZIndex = 11
rarityBanner.Parent = popupFrame

-- Creature name.
local nameLbl = Instance.new("TextLabel")
nameLbl.Position = UDim2.fromOffset(0, 72)
nameLbl.Size = UDim2.new(1, 0, 0, 36)
nameLbl.BackgroundTransparency = 1
nameLbl.Font = Enum.Font.FredokaOne
nameLbl.TextSize = 30
nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
nameLbl.ZIndex = 11
nameLbl.Parent = popupFrame

-- Description.
local descLbl = Instance.new("TextLabel")
descLbl.Position = UDim2.fromOffset(20, 112)
descLbl.Size = UDim2.new(1, -40, 0, 40)
descLbl.BackgroundTransparency = 1
descLbl.Font = Enum.Font.Gotham
descLbl.TextSize = 13
descLbl.TextColor3 = Color3.fromRGB(180, 180, 200)
descLbl.TextWrapped = true
descLbl.TextXAlignment = Enum.TextXAlignment.Center
descLbl.ZIndex = 11
descLbl.Parent = popupFrame

-- Income label.
local incomeLbl = Instance.new("TextLabel")
incomeLbl.Position = UDim2.fromOffset(0, 155)
incomeLbl.Size = UDim2.new(1, 0, 0, 22)
incomeLbl.BackgroundTransparency = 1
incomeLbl.Font = Enum.Font.GothamBold
incomeLbl.TextSize = 14
incomeLbl.TextColor3 = Color3.fromRGB(140, 220, 140)
incomeLbl.ZIndex = 11
incomeLbl.Parent = popupFrame

-- Dismiss hint.
local dismissLbl = Instance.new("TextLabel")
dismissLbl.Position = UDim2.fromOffset(0, 182)
dismissLbl.Size = UDim2.new(1, 0, 0, 18)
dismissLbl.BackgroundTransparency = 1
dismissLbl.Font = Enum.Font.Gotham
dismissLbl.TextSize = 11
dismissLbl.TextColor3 = Color3.fromRGB(120, 120, 140)
dismissLbl.Text = "Click anywhere to dismiss"
dismissLbl.ZIndex = 11
dismissLbl.Parent = popupFrame

-- ── Animation helpers ─────────────────────────────────────────────────────

local showTween = TweenService:Create(popupFrame,
	TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	{ Size = UDim2.fromOffset(360, 220) }
)
local hideTween = TweenService:Create(popupFrame,
	TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	{ Size = UDim2.fromOffset(360, 0) }
)

local dismissTimer: thread? = nil
local function showReward(rewardData: {[string]: any})
	if dismissTimer then
		task.cancel(dismissTimer)
		dismissTimer = nil
	end

	local rarityDef = LuckyBlockData.Rarities[rewardData.Rarity]
		or LuckyBlockData.Rarities["Common"]

	-- Update content.
	rarityBanner.Text = ("★  %s  ★"):format(rewardData.Rarity:upper())
	rarityBanner.TextColor3 = rarityDef.Color
	nameLbl.Text = rewardData.DisplayName
	nameLbl.TextColor3 = rarityDef.GlowColor
	descLbl.Text = rewardData.Description
	popupStroke.Color = rarityDef.Color
	headerText.TextColor3 = rarityDef.GlowColor

	local baseIncome = math.floor(rarityDef.BaseIncomePerTick * (rewardData.IncomeBonus or 1))
	incomeLbl.Text = ("⬆ %d coins / %d s in your base"):format(
		baseIncome, 5)

	-- Animate in.
	popupFrame.Size = UDim2.fromOffset(360, 0)
	popupFrame.Visible = true
	showTween:Play()

	-- Auto-dismiss after 5 s.
	dismissTimer = task.delay(5, function()
		hideTween:Play()
		hideTween.Completed:Wait()
		popupFrame.Visible = false
	end)
end

-- Click-anywhere dismiss.
local inputService = game:GetService("UserInputService")
inputService.InputBegan:Connect(function(inp, consumed)
	if consumed then return end
	if not popupFrame.Visible then return end
	if inp.UserInputType == Enum.UserInputType.MouseButton1
	   or inp.UserInputType == Enum.UserInputType.Touch then
		if dismissTimer then task.cancel(dismissTimer); dismissTimer = nil end
		hideTween:Play()
		hideTween.Completed:Wait()
		popupFrame.Visible = false
	end
end)

-- ── World-space burst effect at block position ─────────────────────────────
-- Creates short-lived local particle parts when a block is opened.

local function playOpenBurst(worldPos: Vector3, glowColor: Color3)
	local Workspace = game:GetService("Workspace")
	local burstCount = 14
	for i = 1, burstCount do
		local part = Instance.new("Part")
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Size = Vector3.new(0.5, 0.5, 0.5)
		part.Shape = Enum.PartType.Ball
		part.Position = worldPos + Vector3.new(0, 2, 0)
		part.Color = glowColor
		part.Material = Enum.Material.Neon
		part.Transparency = 0.2
		part.CastShadow = false

		-- Random outward velocity.
		local vel = Instance.new("LinearVelocity")
		vel.Attachment0 = Instance.new("Attachment", part)
		local angle = math.random() * math.pi * 2
		local upBias = math.random() * 5 + 8
		vel.VectorVelocity = Vector3.new(
			math.cos(angle) * math.random(6, 14),
			upBias,
			math.sin(angle) * math.random(6, 14)
		)
		vel.MaxForce = 1e5
		vel.Parent = part
		part.Parent = Workspace

		-- Fade out and destroy.
		task.delay(0.6, function()
			local fadeTween = TweenService:Create(part,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) })
			fadeTween:Play()
			fadeTween.Completed:Connect(function() part:Destroy() end)
		end)
	end

	-- Central flash ring.
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 1, 1)
	ring.CFrame = CFrame.new(worldPos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = glowColor
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.1
	ring.CastShadow = false
	ring.Parent = Workspace

	TweenService:Create(ring,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, 20, 20), Transparency = 1 }
	):Play()
	task.delay(0.55, function() ring:Destroy() end)
end

-- ── Zone status banner ────────────────────────────────────────────────────

local zoneBannerScreen = Instance.new("ScreenGui")
zoneBannerScreen.Name = "ZoneBannerGui"
zoneBannerScreen.ResetOnSpawn = false
zoneBannerScreen.DisplayOrder = 15
zoneBannerScreen.Parent = playerGui

local zoneBanner = Instance.new("Frame")
zoneBanner.AnchorPoint = Vector2.new(0.5, 0)
zoneBanner.Position = UDim2.new(0.5, 0, 0, 70)
zoneBanner.Size = UDim2.fromOffset(340, 52)
zoneBanner.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
zoneBanner.BackgroundTransparency = 0.15
zoneBanner.BorderSizePixel = 0
zoneBanner.Visible = false
zoneBanner.ZIndex = 8
zoneBanner.Parent = zoneBannerScreen
Instance.new("UICorner", zoneBanner).CornerRadius = UDim.new(0, 10)

local zoneBannerStroke = Instance.new("UIStroke")
zoneBannerStroke.Thickness = 1.5
zoneBannerStroke.Color = Color3.fromRGB(240, 200, 80)
zoneBannerStroke.Parent = zoneBanner

local zoneNameLbl = Instance.new("TextLabel")
zoneNameLbl.Size = UDim2.new(1, 0, 0.55, 0)
zoneNameLbl.BackgroundTransparency = 1
zoneNameLbl.Font = Enum.Font.FredokaOne
zoneNameLbl.TextSize = 20
zoneNameLbl.TextColor3 = Color3.fromRGB(255, 225, 120)
zoneNameLbl.ZIndex = 9
zoneNameLbl.Parent = zoneBanner

local zoneSubLbl = Instance.new("TextLabel")
zoneSubLbl.Position = UDim2.fromScale(0, 0.55)
zoneSubLbl.Size = UDim2.new(1, 0, 0.45, 0)
zoneSubLbl.BackgroundTransparency = 1
zoneSubLbl.Font = Enum.Font.Gotham
zoneSubLbl.TextSize = 13
zoneSubLbl.TextColor3 = Color3.fromRGB(180, 180, 200)
zoneSubLbl.ZIndex = 9
zoneSubLbl.Parent = zoneBanner

local bannerHideTimer: thread? = nil

local function showZoneBanner(zoneId: number)
	local zone = LuckyBlockData.GetZone(zoneId)
	if not zone then return end
	if bannerHideTimer then task.cancel(bannerHideTimer) end

	zoneBannerStroke.Color = zone.BlockGlow
	zoneNameLbl.Text = ("➜  Zone %d: %s"):format(zone.Id, zone.Name)
	zoneNameLbl.TextColor3 = zone.BlockGlow
	zoneSubLbl.Text = if zone.MinSpeed > 0
		then ("Requires WalkSpeed %d+  •  %s drops"):format(zone.MinSpeed, zone.Name)
		else "Starter zone  •  Common & Uncommon drops"

	zoneBanner.Visible = true
	TweenService:Create(zoneBanner,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.15 }):Play()

	bannerHideTimer = task.delay(4, function()
		TweenService:Create(zoneBanner,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }):Play()
		task.wait(0.45)
		zoneBanner.Visible = false
	end)
end

-- ── Remote listeners ──────────────────────────────────────────────────────

Remotes.Events.LuckyBlockResult.OnClientEvent:Connect(function(rewardData, _blockPos)
	showReward(rewardData)
end)

Remotes.Events.BlockOpened.OnClientEvent:Connect(function(blockPos: Vector3, glowColor: Color3)
	playOpenBurst(blockPos, glowColor)
end)

Remotes.Events.ZoneChanged.OnClientEvent:Connect(function(newZoneId: number)
	_G.CurrentZoneId = newZoneId
	showZoneBanner(newZoneId)
end)

-- ── Nearest block HUD indicator ───────────────────────────────────────────
-- Small screen-space label showing distance to nearest block.

local blockHudScreen = Instance.new("ScreenGui")
blockHudScreen.Name = "BlockHudGui"
blockHudScreen.ResetOnSpawn = false
blockHudScreen.Parent = playerGui

local blockHudFrame = Instance.new("Frame")
blockHudFrame.AnchorPoint = Vector2.new(1, 0)
blockHudFrame.Position = UDim2.new(1, -16, 0, 70)
blockHudFrame.Size = UDim2.fromOffset(200, 44)
blockHudFrame.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
blockHudFrame.BackgroundTransparency = 0.2
blockHudFrame.BorderSizePixel = 0
blockHudFrame.Parent = blockHudScreen
Instance.new("UICorner", blockHudFrame).CornerRadius = UDim.new(0, 8)

local blockHudLbl = Instance.new("TextLabel")
blockHudLbl.Size = UDim2.fromScale(1, 1)
blockHudLbl.BackgroundTransparency = 1
blockHudLbl.Font = Enum.Font.GothamBold
blockHudLbl.TextSize = 13
blockHudLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
blockHudLbl.TextWrapped = true
blockHudLbl.Parent = blockHudFrame

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then blockHudLbl.Text = ""; return end

	local Workspace = game:GetService("Workspace")
	local blocksFolder = Workspace:FindFirstChild("LuckyBlocks")
	if not blocksFolder then blockHudLbl.Text = ""; return end

	local nearest: number = math.huge
	local nearestZone = ""
	for _, child in ipairs(blocksFolder:GetChildren()) do
		if child:IsA("Model") then
			local body = child:FindFirstChild("Body") :: BasePart?
			if body then
				local d = (body.Position - root.Position).Magnitude
				if d < nearest then
					nearest = d
					local zId = child:GetAttribute("ZoneId") or 1
					local z = LuckyBlockData.GetZone(zId)
					nearestZone = z and z.Name or "?"
				end
			end
		end
	end

	if nearest < 500 then
		blockHudLbl.Text = ("📦 Block: %.0f studs\n%s"):format(nearest, nearestZone)
	else
		blockHudLbl.Text = "No block nearby"
	end
end)

print("[LuckyBlockClient] ready")
