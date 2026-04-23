--!strict
-- Buy / sell at the market. Server checks coins, inventory, and market listings.
-- Selling captured monsters is supported via a Uuid-based "SellMonster" path.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))
local MarketData = require(Modules:WaitForChild("MarketData"))
local MonsterData = require(Modules:WaitForChild("MonsterData"))
local Inventory = require(Modules:WaitForChild("Inventory"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local function inRangeOfMarket(player: Player): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return false end
	local center = _G.WorldState and _G.WorldState.MarketCenter or Vector3.zero
	return (root.Position - center).Magnitude < 60
end

Remotes.Functions.GetMarketCatalog.OnServerInvoke = function()
	local catalog = {}
	for _, listing in ipairs(MarketData.Listings) do
		local def = ItemData.Get(listing.Id)
		if def then
			table.insert(catalog, {
				Id = def.Id,
				DisplayName = def.DisplayName,
				Kind = def.Kind,
				Description = def.Description,
				BuyPrice = MarketData.BuyPrice(def.Id),
				SellPrice = def.SellPrice,
			})
		end
	end
	return catalog
end

Remotes.Events.MarketBuy.OnServerEvent:Connect(function(player, itemId, qty)
	if typeof(itemId) ~= "string" then return end
	qty = tonumber(qty) or 1
	if qty < 1 or qty > 99 then return end
	if not inRangeOfMarket(player) then
		Remotes.Events.Notify:FireClient(player, "You're too far from the market.")
		return
	end

	local save = _G.PlayerData.Get(player.UserId); if not save then return end
	local price = MarketData.BuyPrice(itemId); if not price then return end
	local flags = _G.ModMenu and _G.ModMenu.GetFlags(player) or {}

	local total = price * qty
	if not flags.InfiniteMoney and save.Coins < total then
		Remotes.Events.Notify:FireClient(player, "Not enough coins.")
		return
	end

	if not flags.InfiniteMoney then
		save.Coins -= total
	end
	_G.PlayerData.GiveItem(player, itemId, qty)
	Remotes.Events.Notify:FireClient(player, ("Bought %d × %s."):format(qty, itemId))
end)

Remotes.Events.MarketSell.OnServerEvent:Connect(function(player, kind, id, qty)
	if not inRangeOfMarket(player) then
		Remotes.Events.Notify:FireClient(player, "You're too far from the market.")
		return
	end
	local save = _G.PlayerData.Get(player.UserId); if not save then return end

	if kind == "item" and typeof(id) == "string" then
		qty = tonumber(qty) or 1
		if qty < 1 then return end
		if Inventory.ItemCount(save, id) < qty then
			Remotes.Events.Notify:FireClient(player, "You don't have that many.")
			return
		end
		local price = MarketData.SellPrice(id)
		_G.PlayerData.TakeItem(player, id, qty)
		_G.PlayerData.AddCoins(player, price * qty)
		Remotes.Events.Notify:FireClient(player, ("Sold %d × %s for %d."):format(qty, id, price * qty))
	elseif kind == "monster" and typeof(id) == "string" then
		local mon = Inventory.FindMonster(save, id)
		if not mon then return end
		local def = MonsterData.Get(mon.SpeciesId)
		if not def then return end
		local price = math.floor(def.CoinValue * (1 + (mon.Level - 1) * 0.15))
		Inventory.RemoveMonster(save, id)
		_G.PlayerData.AddCoins(player, price)
		_G.PlayerData.Push(player)
		Remotes.Events.Notify:FireClient(player, ("Sold %s for %d."):format(def.DisplayName, price))
	end
end)
