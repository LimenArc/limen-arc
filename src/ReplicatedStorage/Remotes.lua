--!strict
-- Lazy RemoteEvent / RemoteFunction factory. Avoids manually creating each
-- instance in Studio. All names listed here are the ones the rest of the code
-- uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
end

local Events = {
	"CombatAttack",
	"ThrowTrap",
	"MarketBuy",
	"MarketSell",
	"ModMenuSetFlag",
	"ModMenuSpawnMonster",
	"ModMenuTeleport",
	"UseItem",
	"SetActiveMonster",
	"RequestSave",          -- server → client: full PlayerSave snapshot
	"CaptureResult",        -- server → client
	"Notify",               -- server → client: chat-like toast

	-- Trading
	"TradeRequest",         -- client → server: ask user X to trade
	"TradeRespond",         -- client → server: accept / decline incoming
	"TradeOffer",           -- client → server: set my current offer
	"TradeLock",            -- client → server: toggle my lock-in
	"TradeConfirm",         -- client → server: final confirm (both sides)
	"TradeCancel",          -- client → server: bail out
	"TradeUpdate",          -- server → client: full session snapshot
	"TradeIncoming",        -- server → client: someone wants to trade
	"TradeEnded",           -- server → client: session closed (success/cancel)
}

local Functions = {
	"GetPlayerSave",
	"GetMarketCatalog",
	"GetModMenuState",
}

local function ensure(className: string, name: string): Instance
	local existing = folder:FindFirstChild(name)
	if existing then return existing end
	if not RunService:IsServer() then
		-- client should wait, never create
		return folder:WaitForChild(name, 10)
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = folder
	return inst
end

local Remotes = { Events = {}, Functions = {} }

for _, name in ipairs(Events) do
	Remotes.Events[name] = ensure("RemoteEvent", name)
end
for _, name in ipairs(Functions) do
	Remotes.Functions[name] = ensure("RemoteFunction", name)
end

return Remotes
