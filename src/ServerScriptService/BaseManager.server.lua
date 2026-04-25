--!strict
-- BaseManager: builds a personal plot for each player, maintains creature
-- figurines on pedestals, runs income ticks, and handles placement remotes.
-- Exposes _G.BaseManager.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig     = require(Modules:WaitForChild("GameConfig"))
local LuckyBlockData = require(Modules:WaitForChild("LuckyBlockData"))
local Inventory      = require(Modules:WaitForChild("Inventory"))
local Remotes        = require(ReplicatedStorage:WaitForChild("Remotes"))

-- ── World container ───────────────────────────────────────────────────────

local Workspace = game:GetService("Workspace")
local basesFolder: Folder
task.spawn(function()
	task.wait()
	basesFolder = Workspace:FindFirstChild("PlayerBases") :: Folder
	if not basesFolder then
		basesFolder = Instance.new("Folder")
		basesFolder.Name = "PlayerBases"
		basesFolder.Parent = Workspace
	end
end)

-- ── Plot registry ─────────────────────────────────────────────────────────

type FigurineMap = { [number]: BasePart }  -- slotIndex → figurine root part

type PlayerPlot = {
	UserId: number,
	PlotIndex: number,
	Origin: Vector3,
	PlotModel: Model,
	Pedestals: { BasePart },      -- list of pedestal parts indexed 1-MaxSlots
	Figurines: FigurineMap,
}

local plotsByUser: { [number]: PlayerPlot } = {}
local nextPlotIndex = 1

-- Slot grid constants (on the plot surface).
local PEDESTAL_COLS = 4
local PEDESTAL_SPACING = 9   -- studs between pedestal centres

-- ── Plot geometry ─────────────────────────────────────────────────────────

local RARITY_COLORS: { [string]: Color3 } = {}
do
	for rarity, def in pairs(LuckyBlockData.Rarities) do
		RARITY_COLORS[rarity] = def.Color
	end
end

local function plotWorldOrigin(plotIndex: number): Vector3
	local row = math.floor((plotIndex - 1) / GameConfig.BasePlotsPerRow)
	local col = (plotIndex - 1) % GameConfig.BasePlotsPerRow
	local origin = GameConfig.BasePlotOrigin
	return Vector3.new(
		origin.X + col * GameConfig.BasePlotSize,
		origin.Y,
		origin.Z + row * GameConfig.BasePlotSize
	)
end

local PLOT_FLOOR_COLOR = Color3.fromRGB(50, 50, 65)
local PLOT_BORDER_COLOR = Color3.fromRGB(240, 200, 80)
local PEDESTAL_COLOR = Color3.fromRGB(40, 40, 55)

local function buildPlot(plotIndex: number, ownerName: string): (Model, { BasePart })
	local origin = plotWorldOrigin(plotIndex)
	local model = Instance.new("Model")
	model.Name = ("Base_%d"):format(plotIndex)

	-- Floor.
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(GameConfig.BasePlotSize, 1, GameConfig.BasePlotSize)
	floor.CFrame = CFrame.new(origin + Vector3.new(GameConfig.BasePlotSize / 2, -0.5, GameConfig.BasePlotSize / 2))
	floor.Color = PLOT_FLOOR_COLOR
	floor.Material = Enum.Material.SmoothPlastic
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.Parent = model

	-- Border walls (4 thin strips).
	local ps = GameConfig.BasePlotSize
	local cx = origin.X + ps / 2
	local cz = origin.Z + ps / 2
	local wallDefs = {
		{ pos=Vector3.new(cx, 1, origin.Z), size=Vector3.new(ps + 0.5, 2, 0.5) },
		{ pos=Vector3.new(cx, 1, origin.Z + ps), size=Vector3.new(ps + 0.5, 2, 0.5) },
		{ pos=Vector3.new(origin.X, 1, cz), size=Vector3.new(0.5, 2, ps) },
		{ pos=Vector3.new(origin.X + ps, 1, cz), size=Vector3.new(0.5, 2, ps) },
	}
	for _, wd in ipairs(wallDefs) do
		local w = Instance.new("Part")
		w.Anchored = true
		w.Size = wd.size
		w.CFrame = CFrame.new(wd.pos)
		w.Color = PLOT_BORDER_COLOR
		w.Material = Enum.Material.Neon
		w.Transparency = 0.4
		w.CastShadow = false
		w.Parent = model
	end

	-- Owner nameplate.
	local nameplate = Instance.new("Part")
	nameplate.Anchored = true
	nameplate.Size = Vector3.new(22, 3, 1)
	nameplate.CFrame = CFrame.new(origin + Vector3.new(ps / 2, 2, -1))
	nameplate.Color = Color3.fromRGB(30, 30, 45)
	nameplate.Material = Enum.Material.SmoothPlastic
	nameplate.Parent = model

	local nameBb = Instance.new("BillboardGui")
	nameBb.Adornee = nameplate
	nameBb.Size = UDim2.fromOffset(300, 50)
	nameBb.StudsOffset = Vector3.new(0, 2, 0)
	nameBb.AlwaysOnTop = false
	local nameTxt = Instance.new("TextLabel")
	nameTxt.Size = UDim2.fromScale(1, 1)
	nameTxt.BackgroundTransparency = 1
	nameTxt.Text = ownerName .. "'s Base"
	nameTxt.Font = Enum.Font.FredokaOne
	nameTxt.TextSize = 24
	nameTxt.TextColor3 = Color3.fromRGB(255, 230, 140)
	nameTxt.TextStrokeTransparency = 0
	nameTxt.Parent = nameBb
	nameBb.Parent = nameplate

	-- Pedestals (up to MaxBaseSlots).
	local maxSlots = GameConfig.MaxBaseSlots
	local pedestals: { BasePart } = {}
	for i = 1, maxSlots do
		local col = ((i - 1) % PEDESTAL_COLS)
		local row = math.floor((i - 1) / PEDESTAL_COLS)
		local px = origin.X + 10 + col * PEDESTAL_SPACING
		local pz = origin.Z + 10 + row * PEDESTAL_SPACING
		local pedestal = Instance.new("Part")
		pedestal.Name = ("Pedestal_%d"):format(i)
		pedestal.Anchored = true
		pedestal.Size = Vector3.new(3, 0.6, 3)
		pedestal.CFrame = CFrame.new(px, origin.Y + 0.3, pz)
		pedestal.Color = PEDESTAL_COLOR
		pedestal.Material = Enum.Material.SmoothPlastic
		pedestal.TopSurface = Enum.SurfaceType.Smooth
		pedestal.BottomSurface = Enum.SurfaceType.Smooth

		-- Slot number label.
		local slotBb = Instance.new("BillboardGui")
		slotBb.Adornee = pedestal
		slotBb.Size = UDim2.fromOffset(50, 22)
		slotBb.StudsOffset = Vector3.new(0, 1, 0)
		local slotTxt = Instance.new("TextLabel")
		slotTxt.Size = UDim2.fromScale(1, 1)
		slotTxt.BackgroundTransparency = 1
		slotTxt.Text = tostring(i)
		slotTxt.Font = Enum.Font.GothamBold
		slotTxt.TextSize = 14
		slotTxt.TextColor3 = Color3.fromRGB(120, 120, 140)
		slotTxt.Parent = slotBb
		slotBb.Parent = pedestal

		pedestal.Parent = model
		pedestals[i] = pedestal
	end

	model.PrimaryPart = floor
	return model, pedestals
end

-- ── Figurine builder ──────────────────────────────────────────────────────

-- Builds a small creature figurine on the given pedestal using shape hints.
local SHAPE_PARAMS: { [string]: { bodyScale: Vector3, headScale: Vector3, neckOffset: number } } = {
	round  = { bodyScale=Vector3.new(2.2, 2.2, 2.2), headScale=Vector3.new(1.4, 1.4, 1.4), neckOffset=2.0 },
	tall   = { bodyScale=Vector3.new(1.6, 2.8, 1.6), headScale=Vector3.new(1.3, 1.3, 1.3), neckOffset=2.6 },
	wide   = { bodyScale=Vector3.new(2.8, 1.6, 2.0), headScale=Vector3.new(1.5, 1.5, 1.5), neckOffset=1.6 },
	dragon = { bodyScale=Vector3.new(2.0, 1.6, 3.2), headScale=Vector3.new(1.6, 1.4, 1.8), neckOffset=1.9 },
	orb    = { bodyScale=Vector3.new(2.6, 2.6, 2.6), headScale=Vector3.new(0,   0,   0  ), neckOffset=0   },
}

local function buildFigurine(
	creatureDef: LuckyBlockData.LuckyCreatureDef,
	pedestal: BasePart
): BasePart
	local params = SHAPE_PARAMS[creatureDef.BodyShape] or SHAPE_PARAMS.round
	local pedestalPos = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0)
	local rarityDef = LuckyBlockData.Rarities[creatureDef.Rarity]

	local fig = Instance.new("Model")
	fig.Name = "Figurine_" .. creatureDef.Id

	-- Body.
	local body = Instance.new("Part")
	body.Anchored = true
	body.CanCollide = false
	body.Shape = Enum.PartType.Ball
	body.Size = params.bodyScale
	body.CFrame = CFrame.new(pedestalPos + Vector3.new(0, params.bodyScale.Y / 2, 0))
	body.Color = creatureDef.PrimaryColor
	body.Material = Enum.Material.SmoothPlastic
	body.CastShadow = false
	body.Name = "FigBody"
	body.Parent = fig

	-- Head (omit for orb shape).
	if params.headScale.X > 0 then
		local head = Instance.new("Part")
		head.Anchored = true
		head.CanCollide = false
		head.Shape = Enum.PartType.Ball
		head.Size = params.headScale
		head.CFrame = CFrame.new(
			pedestalPos + Vector3.new(0, params.bodyScale.Y / 2 + params.neckOffset, 0)
		)
		head.Color = creatureDef.SecondaryColor
		head.Material = Enum.Material.SmoothPlastic
		head.CastShadow = false
		head.Parent = fig
	end

	-- Neon glow halo.
	local halo = Instance.new("Part")
	halo.Anchored = true
	halo.CanCollide = false
	halo.Shape = Enum.PartType.Ball
	halo.Size = params.bodyScale * 1.25
	halo.CFrame = body.CFrame
	halo.Color = rarityDef.GlowColor
	halo.Material = Enum.Material.Neon
	halo.Transparency = 0.7
	halo.CastShadow = false
	halo.Parent = fig

	-- Point light.
	local light = Instance.new("PointLight")
	light.Brightness = 1.5
	light.Range = 12
	light.Color = rarityDef.GlowColor
	light.Parent = body

	-- Name/income BillboardGui.
	local bb = Instance.new("BillboardGui")
	bb.Adornee = body
	bb.Size = UDim2.fromOffset(200, 50)
	bb.StudsOffset = Vector3.new(0, params.bodyScale.Y / 2 + params.neckOffset + 1.2, 0)
	bb.AlwaysOnTop = false

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = creatureDef.DisplayName
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 14
	nameLbl.TextColor3 = rarityDef.Color
	nameLbl.TextStrokeTransparency = 0
	nameLbl.Parent = bb

	local rarityLbl = Instance.new("TextLabel")
	rarityLbl.Size = UDim2.new(1, 0, 0.45, 0)
	rarityLbl.Position = UDim2.fromScale(0, 0.55)
	rarityLbl.BackgroundTransparency = 1
	local incomePerTick = math.floor(rarityDef.BaseIncomePerTick * creatureDef.IncomeBonus)
	rarityLbl.Text = ("⬆ %d /tick"):format(incomePerTick)
	rarityLbl.Font = Enum.Font.Gotham
	rarityLbl.TextSize = 12
	rarityLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
	rarityLbl.Parent = bb

	bb.Parent = body

	fig.PrimaryPart = body
	fig.Parent = pedestal.Parent  -- same model as the plot

	return body
end

-- ── Plot management ───────────────────────────────────────────────────────

local function refreshFigurines(plot: PlayerPlot)
	-- Destroy existing figurines.
	for _, fig in pairs(plot.Figurines) do
		local figModel = fig.Parent
		if figModel then figModel:Destroy() end
	end
	plot.Figurines = {}

	local save = _G.PlayerData and _G.PlayerData.Get(plot.UserId)
	if not save then return end

	for _, placement in ipairs(save.BasePlacements) do
		if placement.SlotIndex > save.BaseSlotCount then continue end
		local entry = Inventory.FindLuckyCreature(save, placement.Uid)
		if not entry then continue end
		local creatureDef = LuckyBlockData.GetCreature(entry.CreatureId)
		if not creatureDef then continue end
		local pedestal = plot.Pedestals[placement.SlotIndex]
		if not pedestal then continue end
		local figBody = buildFigurine(creatureDef, pedestal)
		plot.Figurines[placement.SlotIndex] = figBody
	end
end

-- ── Player join / leave ───────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	-- Wait until PlayerData is loaded.
	local deadline = os.clock() + 15
	repeat task.wait(0.2) until (_G.PlayerData and _G.PlayerData.Get(player.UserId)) or os.clock() > deadline

	-- Assign a plot.
	local plotIndex = nextPlotIndex
	nextPlotIndex += 1

	-- Build geometry.
	local plotModel, pedestals = buildPlot(plotIndex, player.Name)
	plotModel.Parent = basesFolder or Workspace

	local plot: PlayerPlot = {
		UserId = player.UserId,
		PlotIndex = plotIndex,
		Origin = plotWorldOrigin(plotIndex),
		PlotModel = plotModel,
		Pedestals = pedestals,
		Figurines = {},
	}
	plotsByUser[player.UserId] = plot
	refreshFigurines(plot)
end)

Players.PlayerRemoving:Connect(function(player)
	local plot = plotsByUser[player.UserId]
	if plot then
		plot.PlotModel:Destroy()
		plotsByUser[player.UserId] = nil
	end
end)

-- ── Remote: place creature ────────────────────────────────────────────────

Remotes.Events.PlaceBaseCreature.OnServerEvent:Connect(function(player, uid, slotIndex)
	if typeof(uid) ~= "string" or typeof(slotIndex) ~= "number" then return end
	local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
	if not save then return end
	if slotIndex < 1 or slotIndex > save.BaseSlotCount then
		Remotes.Events.Notify:FireClient(player, "Slot not unlocked yet. Buy more base slots!")
		return
	end
	if not Inventory.PlaceInBase(save, uid, slotIndex) then
		Remotes.Events.Notify:FireClient(player, "Creature not found in inventory.")
		return
	end
	_G.PlayerData.Push(player)
	local plot = plotsByUser[player.UserId]
	if plot then refreshFigurines(plot) end
	sendBaseUpdate(player, save)
end)

-- ── Remote: remove creature ───────────────────────────────────────────────

Remotes.Events.RemoveBaseCreature.OnServerEvent:Connect(function(player, slotIndex)
	if typeof(slotIndex) ~= "number" then return end
	local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
	if not save then return end
	Inventory.RemoveFromBase(save, slotIndex)
	_G.PlayerData.Push(player)
	local plot = plotsByUser[player.UserId]
	if plot then refreshFigurines(plot) end
	sendBaseUpdate(player, save)
end)

-- ── Remote: sell creature ─────────────────────────────────────────────────

Remotes.Events.SellBaseCreature.OnServerEvent:Connect(function(player, slotIndex)
	if typeof(slotIndex) ~= "number" then return end
	local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
	if not save then return end
	-- Find what's in the slot.
	local placement: Inventory.BasePlacement? = nil
	for _, p in ipairs(save.BasePlacements) do
		if p.SlotIndex == slotIndex then placement = p; break end
	end
	if not placement then
		Remotes.Events.Notify:FireClient(player, "No creature in that slot.")
		return
	end
	local entry = Inventory.FindLuckyCreature(save, placement.Uid)
	if not entry then return end
	local rarityDef = LuckyBlockData.Rarities[entry.Rarity]
	local shardValue = rarityDef and rarityDef.ShardValue or 0
	Inventory.RemoveLuckyCreature(save, placement.Uid)
	save.Coins += shardValue
	_G.PlayerData.Push(player)
	local plot = plotsByUser[player.UserId]
	if plot then refreshFigurines(plot) end
	sendBaseUpdate(player, save)
	Remotes.Events.Notify:FireClient(player, ("Sold for %d coins!"):format(shardValue))
end)

-- ── Base update helper ────────────────────────────────────────────────────

function sendBaseUpdate(player: Player, save: Inventory.PlayerSave)
	Remotes.Events.BaseUpdate:FireClient(player, {
		BaseSlotCount = save.BaseSlotCount,
		Placements = save.BasePlacements,
		LuckyCreatures = save.LuckyCreatures,
	})
end

Remotes.Functions.GetBaseState.OnServerInvoke = function(player: Player)
	local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
	if not save then return nil end
	return {
		BaseSlotCount = save.BaseSlotCount,
		Placements = save.BasePlacements,
		LuckyCreatures = save.LuckyCreatures,
	}
end

-- ── Income tick loop ──────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(GameConfig.BaseIncomeTickRate)
		for userId, plot in pairs(plotsByUser) do
			local player = Players:GetPlayerByUserId(userId)
			if not player then continue end
			local save = _G.PlayerData and _G.PlayerData.Get(userId)
			if not save then continue end
			local flags = _G.ModMenu and _G.ModMenu.GetFlags(player) or {}

			local totalIncome = 0
			for _, placement in ipairs(save.BasePlacements) do
				if placement.SlotIndex > save.BaseSlotCount then continue end
				local entry = Inventory.FindLuckyCreature(save, placement.Uid)
				if not entry then continue end
				local creatureDef = LuckyBlockData.GetCreature(entry.CreatureId)
				if not creatureDef then continue end
				local rarityDef = LuckyBlockData.Rarities[entry.Rarity]
				if not rarityDef then continue end
				local income = math.floor(rarityDef.BaseIncomePerTick * creatureDef.IncomeBonus)
				if flags.MaxBaseIncome then income = income * 10 end
				totalIncome += income
			end

			if flags.InfiniteMoney then totalIncome = totalIncome + 500 end

			if totalIncome > 0 then
				save.Coins += totalIncome
				_G.PlayerData.Push(player)
			end
		end
	end
end)

-- ── Public API ────────────────────────────────────────────────────────────

local BaseManager = {}
_G.BaseManager = BaseManager

function BaseManager.RefreshPlot(userId: number)
	local plot = plotsByUser[userId]
	if plot then refreshFigurines(plot) end
end

function BaseManager.GetPlotOrigin(userId: number): Vector3?
	local plot = plotsByUser[userId]
	return plot and plot.Origin or nil
end

print("[BaseManager] ready")
