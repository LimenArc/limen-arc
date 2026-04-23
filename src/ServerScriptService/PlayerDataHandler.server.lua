--!strict
-- Per-player save lifecycle. Loads from DataStore on join, pushes a snapshot
-- to the client, auto-saves periodically, and exposes accessors for other
-- server systems via _G.PlayerData.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Inventory = require(Modules:WaitForChild("Inventory"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local store
pcall(function()
	store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
end)

local saves: { [number]: Inventory.PlayerSave } = {}

local function keyFor(userId: number): string
	return ("player_%d"):format(userId)
end

local function loadSave(userId: number): Inventory.PlayerSave
	if store then
		local ok, data = pcall(function()
			return store:GetAsync(keyFor(userId))
		end)
		if ok and type(data) == "table" then
			return Inventory.MigrateSave(data)
		end
	end
	local fresh = Inventory.NewSave(GameConfig.StartingCoins)
	-- Starter kit.
	Inventory.AddItem(fresh, "stick", 1)
	Inventory.AddItem(fresh, "trap_basic", 5)
	Inventory.AddItem(fresh, "potion_hp", 3)
	fresh.EquippedWeaponId = "stick"
	fresh.LifetimeCoins = fresh.Coins
	return fresh
end

local function persist(userId: number)
	if not store then return end
	local save = saves[userId]
	if not save then return end
	pcall(function()
		store:SetAsync(keyFor(userId), save)
	end)
end

local function pushSnapshot(player: Player)
	local save = saves[player.UserId]
	if save then
		Remotes.Events.RequestSave:FireClient(player, save)
	end
end

-- Public API -------------------------------------------------------------
local PlayerData = {}
_G.PlayerData = PlayerData

function PlayerData.Get(userId: number): Inventory.PlayerSave?
	return saves[userId]
end

function PlayerData.Push(player: Player)
	pushSnapshot(player)
end

function PlayerData.Save(player: Player)
	persist(player.UserId)
end

function PlayerData.AddCoins(player: Player, amount: number)
	local save = saves[player.UserId]; if not save then return end
	save.Coins += amount
	if amount > 0 then
		save.LifetimeCoins += amount
		if _G.Quests then _G.Quests.OnCoinsEarned(player, amount) end
	end
	pushSnapshot(player)
end

function PlayerData.GiveItem(player: Player, itemId: string, count: number): boolean
	local save = saves[player.UserId]; if not save then return false end
	local ok = Inventory.AddItem(save, itemId, count)
	if ok then pushSnapshot(player) end
	return ok
end

function PlayerData.TakeItem(player: Player, itemId: string, count: number): boolean
	local save = saves[player.UserId]; if not save then return false end
	local ok = Inventory.RemoveItem(save, itemId, count)
	if ok then pushSnapshot(player) end
	return ok
end

function PlayerData.AddMonster(player: Player, mon: Inventory.CaughtMonster)
	local save = saves[player.UserId]; if not save then return end
	Inventory.AddMonster(save, mon)
	pushSnapshot(player)
end

-- Events -----------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	saves[player.UserId] = loadSave(player.UserId)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		pushSnapshot(player)
	end)
	pushSnapshot(player)
end)

Players.PlayerRemoving:Connect(function(player)
	persist(player.UserId)
	saves[player.UserId] = nil
end)

Remotes.Functions.GetPlayerSave.OnServerInvoke = function(player: Player)
	return saves[player.UserId]
end

Remotes.Events.SetActiveMonster.OnServerEvent:Connect(function(player, uuid)
	local save = saves[player.UserId]; if not save then return end
	if typeof(uuid) ~= "string" then return end
	for _, mon in ipairs(save.Monsters) do
		if mon.Uuid == uuid then
			save.ActiveMonsterUuid = uuid
			pushSnapshot(player)
			return
		end
	end
end)

-- Auto-save loop.
task.spawn(function()
	while true do
		task.wait(90)
		for userId in pairs(saves) do
			persist(userId)
		end
	end
end)

-- Save on shutdown.
game:BindToClose(function()
	for userId in pairs(saves) do
		persist(userId)
	end
	if RunService:IsStudio() then return end
	task.wait(2)
end)
