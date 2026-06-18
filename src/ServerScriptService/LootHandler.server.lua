--!strict
-- Handles ProximityPrompt triggers on Chests and LuckyBlocks. Rolls from
-- the appropriate loot table and applies the reward (or penalty) to the
-- player via PlayerData. Containers are consumed on open; lucky blocks
-- respawn after a cooldown so the map stays populated.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local LootData = require(Modules:WaitForChild("LootData"))
local ItemData = require(Modules:WaitForChild("ItemData"))
local MonsterData = require(Modules:WaitForChild("MonsterData"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local rng = Random.new()

local LUCKY_BLOCK_RESPAWN = 180  -- seconds

local function applyLoot(player: Player, entry: LootData.LootEntry): string
	local kind = entry.Kind

	if kind == "Coins" then
		local n = rng:NextInteger(entry.MinCount or 1, entry.MaxCount or 1)
		_G.PlayerData.AddCoins(player, n)
		return (entry.Message or "+%d coins"):format(n)

	elseif kind == "Item" and entry.Id then
		local n = rng:NextInteger(entry.MinCount or 1, entry.MaxCount or 1)
		_G.PlayerData.GiveItem(player, entry.Id, n)
		local def = ItemData.Get(entry.Id)
		local name = def and def.DisplayName or entry.Id
		return entry.Message or ("Found %d × %s"):format(n, name)

	elseif kind == "Monster" and entry.Id then
		local def = MonsterData.Get(entry.Id)
		if not def then return "Nothing" end
		local mon = {
			Uuid = HttpService:GenerateGUID(false),
			SpeciesId = def.Id,
			Nickname = nil,
			Level = 5,
			XP = 0,
			CurrentHP = def.BaseHP,
			MaxHP = def.BaseHP,
		}
		_G.PlayerData.AddMonster(player, mon)
		return entry.Message or ("A wild %s joined you!"):format(def.DisplayName)

	elseif kind == "Penalty" then
		if entry.Id == "coins" then
			local n = rng:NextInteger(entry.MinCount or 10, entry.MaxCount or 40)
			local save = _G.PlayerData.Get(player.UserId)
			if save then
				local taken = math.min(save.Coins, n)
				save.Coins -= taken
				_G.PlayerData.Push(player)
				return (entry.Message or "Pickpocketed! -%d coins"):format(taken)
			end
		elseif entry.Id == "teleport" then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				root.CFrame = CFrame.new(0, 10, 30)
			end
			return entry.Message or "Yoinked!"
		end
	end

	return "Nothing"
end

local function handleChestOpen(chestModel: Model, player: Player)
	local entry = LootData.RollChest(rng)
	local msg = applyLoot(player, entry)
	Remotes.Events.Notify:FireClient(player, "Chest: " .. msg)

	-- Small "opening" animation before removal.
	local lid = chestModel:FindFirstChild("ChestLid") :: BasePart?
	if lid then
		lid.CFrame = lid.CFrame * CFrame.Angles(math.rad(-60), 0, 0)
	end
	task.delay(1.2, function()
		if chestModel.Parent then chestModel:Destroy() end
	end)
end

local function handleLuckyOpen(luckyModel: Model, player: Player)
	local entry = LootData.RollLuckyBlock(rng)
	local msg = applyLoot(player, entry)
	Remotes.Events.Notify:FireClient(player, "Lucky Block: " .. msg)

	-- Effect: shrink, then hide + respawn after cooldown.
	local core = luckyModel:FindFirstChild("LuckyCore") :: BasePart?
	local originalCFrame = core and core.CFrame
	if core then
		core.Transparency = 1
		local prompt = core:FindFirstChildOfClass("ProximityPrompt")
		if prompt then prompt.Enabled = false end
		-- Hide floating "?" billboard too.
		for _, d in ipairs(core:GetChildren()) do
			if d:IsA("BillboardGui") then d.Enabled = false end
		end
	end

	task.delay(LUCKY_BLOCK_RESPAWN, function()
		if not luckyModel.Parent then return end
		if core then
			core.Transparency = 0
			local prompt = core:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt.Enabled = true end
			for _, d in ipairs(core:GetChildren()) do
				if d:IsA("BillboardGui") then d.Enabled = true end
			end
			if originalCFrame then core.CFrame = originalCFrame end
		end
	end)
end

local function hookPromptsFor(model: Model, isLucky: boolean)
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then return end
	prompt.Triggered:Connect(function(player)
		if isLucky then
			handleLuckyOpen(model, player)
		else
			handleChestOpen(model, player)
		end
	end)
end

for _, m in ipairs(CollectionService:GetTagged("Chest")) do hookPromptsFor(m, false) end
for _, m in ipairs(CollectionService:GetTagged("LuckyBlock")) do hookPromptsFor(m, true) end

CollectionService:GetInstanceAddedSignal("Chest"):Connect(function(m) hookPromptsFor(m, false) end)
CollectionService:GetInstanceAddedSignal("LuckyBlock"):Connect(function(m) hookPromptsFor(m, true) end)

-- Slow spin for lucky blocks — server-side so everyone sees the same rotation.
task.spawn(function()
	while true do
		local dt = task.wait(0.05)
		for _, m in ipairs(CollectionService:GetTagged("LuckyBlock")) do
			local core = m:FindFirstChild("LuckyCore") :: BasePart?
			if core then
				core.CFrame = core.CFrame * CFrame.Angles(0, math.rad(60) * dt, 0)
			end
		end
	end
end)
