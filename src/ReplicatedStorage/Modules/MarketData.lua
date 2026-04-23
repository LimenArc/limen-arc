--!strict
-- Market stock. Which item ids appear in the buy tab, and at what markup.
-- Sells use ItemData.SellPrice; buys use ItemData.Price * Markup.

local ItemData = require(script.Parent.ItemData)

local MarketData = {}

-- All market listings. If Markup ~= 1, price is multiplied.
MarketData.Listings = {
	-- Weapons
	{ Id = "stick",           Markup = 1.0 },
	{ Id = "sling",           Markup = 1.0 },
	{ Id = "bow",             Markup = 1.0 },
	{ Id = "shockrod",        Markup = 1.1 },
	{ Id = "enchantedblade",  Markup = 1.15 },

	-- Traps
	{ Id = "trap_basic",      Markup = 1.0 },
	{ Id = "trap_strong",     Markup = 1.0 },
	{ Id = "trap_shock",      Markup = 1.05 },
	{ Id = "trap_lure",       Markup = 1.05 },
	{ Id = "trap_master",     Markup = 1.2 },

	-- Consumables
	{ Id = "potion_hp",       Markup = 1.0 },
	{ Id = "potion_hp_super", Markup = 1.0 },
	{ Id = "potion_stamina",  Markup = 1.0 },
	{ Id = "candy_xp",        Markup = 1.0 },
	{ Id = "revival",         Markup = 1.0 },
}

function MarketData.BuyPrice(itemId: string): number?
	for _, listing in ipairs(MarketData.Listings) do
		if listing.Id == itemId then
			local def = ItemData.Get(itemId)
			if not def then return nil end
			return math.floor(def.Price * listing.Markup + 0.5)
		end
	end
	return nil
end

function MarketData.SellPrice(itemId: string): number
	local def = ItemData.Get(itemId)
	if not def then return 0 end
	return def.SellPrice
end

return MarketData
