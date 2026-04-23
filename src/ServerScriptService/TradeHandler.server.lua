--!strict
-- Player-to-player trading. Session-based, proximity-gated, with a
-- double-confirm step to prevent swap-bait attacks.
--
-- Protocol:
--   A → TradeRequest(B)                    server → B: TradeIncoming(A)
--   B → TradeRespond(A, true)              server creates session, both
--                                           sides receive TradeUpdate
--   (either) → TradeOffer({items, monsters, coins})
--                                           server snapshots, clears locks,
--                                           pushes TradeUpdate to both
--   (either) → TradeLock(true)             server sets that side's Locked=true
--                                           (only valid while both offers unchanged)
--   both Locked → server pushes TradeUpdate with bothLocked=true
--   either → TradeConfirm                  when both have confirmed while
--                                           both locked, the transfer fires
--                                           atomically on PlayerData saves
--   either → TradeCancel                   server tears the session down

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Inventory = require(Modules:WaitForChild("Inventory"))
local ItemData = require(Modules:WaitForChild("ItemData"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

type Offer = {
	Items: { [string]: number },   -- itemId -> count
	Monsters: { [string]: true },  -- monster uuid set
	Coins: number,
}

type Session = {
	Id: string,
	A: Player,
	B: Player,
	Offers: { [number]: Offer },     -- keyed by UserId
	Locked: { [number]: boolean },
	Confirmed: { [number]: boolean },
}

local sessions: { [string]: Session } = {}
local sessionByUser: { [number]: string } = {}
local pendingRequests: { [number]: { fromUserId: number, expires: number } } = {}

local function newOffer(): Offer
	return { Items = {}, Monsters = {}, Coins = 0 }
end

local function sessionIdFor(a: Player, b: Player): string
	local lo, hi = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	return ("%d_%d_%d"):format(lo, hi, math.floor(os.clock() * 1000))
end

local function snapshotOfferForClient(offer: Offer)
	local items: { { Id: string, Count: number } } = {}
	for id, count in pairs(offer.Items) do
		table.insert(items, { Id = id, Count = count })
	end
	local monsters: { string } = {}
	for uuid in pairs(offer.Monsters) do
		table.insert(monsters, uuid)
	end
	return { Items = items, Monsters = monsters, Coins = offer.Coins }
end

local function broadcast(session: Session)
	local aLocked = session.Locked[session.A.UserId] == true
	local bLocked = session.Locked[session.B.UserId] == true
	local bothLocked = aLocked and bLocked

	for _, player in ipairs({ session.A, session.B }) do
		local other = if player == session.A then session.B else session.A
		Remotes.Events.TradeUpdate:FireClient(player, {
			SessionId = session.Id,
			Partner = {
				UserId = other.UserId,
				Name = other.Name,
			},
			MyOffer = snapshotOfferForClient(session.Offers[player.UserId]),
			TheirOffer = snapshotOfferForClient(session.Offers[other.UserId]),
			MyLocked = session.Locked[player.UserId] == true,
			TheirLocked = session.Locked[other.UserId] == true,
			BothLocked = bothLocked,
			MyConfirmed = session.Confirmed[player.UserId] == true,
			TheirConfirmed = session.Confirmed[other.UserId] == true,
		})
	end
end

local function inRange(a: Player, b: Player): boolean
	local aChar, bChar = a.Character, b.Character
	if not (aChar and bChar) then return false end
	local aRoot = aChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local bRoot = bChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (aRoot and bRoot) then return false end
	return (aRoot.Position - bRoot.Position).Magnitude < 32
end

local function endSession(sessionId: string, reason: string, succeeded: boolean)
	local session = sessions[sessionId]
	if not session then return end
	sessionByUser[session.A.UserId] = nil
	sessionByUser[session.B.UserId] = nil
	sessions[sessionId] = nil
	for _, p in ipairs({ session.A, session.B }) do
		Remotes.Events.TradeEnded:FireClient(p, { Reason = reason, Succeeded = succeeded })
	end
end

local function validateOffer(player: Player, offer: Offer): boolean
	local save = _G.PlayerData and _G.PlayerData.Get(player.UserId)
	if not save then return false end
	if offer.Coins < 0 or offer.Coins > save.Coins then return false end
	for id, count in pairs(offer.Items) do
		if count <= 0 then return false end
		if Inventory.ItemCount(save, id) < count then return false end
		if not ItemData.Get(id) then return false end
	end
	for uuid in pairs(offer.Monsters) do
		if not Inventory.FindMonster(save, uuid) then return false end
	end
	return true
end

-- Atomically apply a session's offers by swapping items/monsters/coins.
local function applyTrade(session: Session): boolean
	local saveA = _G.PlayerData.Get(session.A.UserId)
	local saveB = _G.PlayerData.Get(session.B.UserId)
	if not (saveA and saveB) then return false end

	local offerA = session.Offers[session.A.UserId]
	local offerB = session.Offers[session.B.UserId]

	-- Re-validate both sides against current saves.
	if not validateOffer(session.A, offerA) then return false end
	if not validateOffer(session.B, offerB) then return false end

	-- Coins.
	saveA.Coins = saveA.Coins - offerA.Coins + offerB.Coins
	saveB.Coins = saveB.Coins - offerB.Coins + offerA.Coins

	-- Items.
	for id, count in pairs(offerA.Items) do
		Inventory.RemoveItem(saveA, id, count)
		Inventory.AddItem(saveB, id, count)
	end
	for id, count in pairs(offerB.Items) do
		Inventory.RemoveItem(saveB, id, count)
		Inventory.AddItem(saveA, id, count)
	end

	-- Monsters.
	for uuid in pairs(offerA.Monsters) do
		local mon = Inventory.FindMonster(saveA, uuid)
		if mon then
			Inventory.RemoveMonster(saveA, uuid)
			Inventory.AddMonster(saveB, mon)
		end
	end
	for uuid in pairs(offerB.Monsters) do
		local mon = Inventory.FindMonster(saveB, uuid)
		if mon then
			Inventory.RemoveMonster(saveB, uuid)
			Inventory.AddMonster(saveA, mon)
		end
	end

	_G.PlayerData.Push(session.A)
	_G.PlayerData.Push(session.B)
	_G.PlayerData.Save(session.A)
	_G.PlayerData.Save(session.B)
	return true
end

-- ── Remote handlers ──────────────────────────────────────────────────────

Remotes.Events.TradeRequest.OnServerEvent:Connect(function(player, targetUserId)
	targetUserId = tonumber(targetUserId)
	if not targetUserId or targetUserId == player.UserId then return end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then return end
	if sessionByUser[player.UserId] or sessionByUser[target.UserId] then
		Remotes.Events.Notify:FireClient(player, "One of you is already trading.")
		return
	end
	if not inRange(player, target) then
		Remotes.Events.Notify:FireClient(player, "Stand closer to that player.")
		return
	end

	pendingRequests[target.UserId] = { fromUserId = player.UserId, expires = os.clock() + 30 }
	Remotes.Events.TradeIncoming:FireClient(target, { FromUserId = player.UserId, FromName = player.Name })
	Remotes.Events.Notify:FireClient(player, ("Trade request sent to %s."):format(target.Name))
end)

Remotes.Events.TradeRespond.OnServerEvent:Connect(function(player, accept)
	local req = pendingRequests[player.UserId]
	if not req or req.expires < os.clock() then
		pendingRequests[player.UserId] = nil
		return
	end
	local requester = Players:GetPlayerByUserId(req.fromUserId)
	pendingRequests[player.UserId] = nil
	if not requester then return end

	if not accept then
		Remotes.Events.Notify:FireClient(requester, ("%s declined the trade."):format(player.Name))
		return
	end

	if sessionByUser[player.UserId] or sessionByUser[requester.UserId] then return end
	if not inRange(player, requester) then
		Remotes.Events.Notify:FireClient(player, "Too far from them to start a trade.")
		return
	end

	local id = sessionIdFor(requester, player)
	local session: Session = {
		Id = id, A = requester, B = player,
		Offers = {
			[requester.UserId] = newOffer(),
			[player.UserId] = newOffer(),
		},
		Locked = {}, Confirmed = {},
	}
	sessions[id] = session
	sessionByUser[requester.UserId] = id
	sessionByUser[player.UserId] = id
	broadcast(session)
end)

Remotes.Events.TradeOffer.OnServerEvent:Connect(function(player, payload)
	local sid = sessionByUser[player.UserId]; if not sid then return end
	local session = sessions[sid]; if not session then return end
	if typeof(payload) ~= "table" then return end

	local proposed: Offer = newOffer()
	if typeof(payload.Coins) == "number" then
		proposed.Coins = math.max(0, math.floor(payload.Coins))
	end
	if typeof(payload.Items) == "table" then
		for _, entry in ipairs(payload.Items) do
			if typeof(entry) == "table" and typeof(entry.Id) == "string" and typeof(entry.Count) == "number" then
				proposed.Items[entry.Id] = (proposed.Items[entry.Id] or 0) + math.max(0, math.floor(entry.Count))
			end
		end
	end
	if typeof(payload.Monsters) == "table" then
		for _, uuid in ipairs(payload.Monsters) do
			if typeof(uuid) == "string" then proposed.Monsters[uuid] = true end
		end
	end

	if not validateOffer(player, proposed) then
		Remotes.Events.Notify:FireClient(player, "Can't offer items you don't own.")
		return
	end

	session.Offers[player.UserId] = proposed
	-- Any change clears both locks and confirms.
	session.Locked[session.A.UserId] = false
	session.Locked[session.B.UserId] = false
	session.Confirmed[session.A.UserId] = false
	session.Confirmed[session.B.UserId] = false
	broadcast(session)
end)

Remotes.Events.TradeLock.OnServerEvent:Connect(function(player, locked)
	local sid = sessionByUser[player.UserId]; if not sid then return end
	local session = sessions[sid]; if not session then return end
	session.Locked[player.UserId] = locked and true or false
	-- Locking/unlocking resets confirmations.
	session.Confirmed[session.A.UserId] = false
	session.Confirmed[session.B.UserId] = false
	broadcast(session)
end)

Remotes.Events.TradeConfirm.OnServerEvent:Connect(function(player)
	local sid = sessionByUser[player.UserId]; if not sid then return end
	local session = sessions[sid]; if not session then return end
	if not (session.Locked[session.A.UserId] and session.Locked[session.B.UserId]) then
		return
	end
	session.Confirmed[player.UserId] = true
	broadcast(session)

	if session.Confirmed[session.A.UserId] and session.Confirmed[session.B.UserId] then
		local ok = applyTrade(session)
		if ok then
			Remotes.Events.Notify:FireClient(session.A, ("Trade with %s complete."):format(session.B.Name))
			Remotes.Events.Notify:FireClient(session.B, ("Trade with %s complete."):format(session.A.Name))
			endSession(sid, "Completed", true)
		else
			Remotes.Events.Notify:FireClient(session.A, "Trade failed — inventory changed.")
			Remotes.Events.Notify:FireClient(session.B, "Trade failed — inventory changed.")
			endSession(sid, "ValidationFailed", false)
		end
	end
end)

Remotes.Events.TradeCancel.OnServerEvent:Connect(function(player)
	local sid = sessionByUser[player.UserId]; if not sid then return end
	endSession(sid, "Cancelled", false)
end)

Players.PlayerRemoving:Connect(function(player)
	pendingRequests[player.UserId] = nil
	local sid = sessionByUser[player.UserId]
	if sid then endSession(sid, "PlayerLeft", false) end
end)

-- Enforce proximity continuously.
task.spawn(function()
	while true do
		task.wait(2)
		for sid, session in pairs(sessions) do
			if not inRange(session.A, session.B) then
				Remotes.Events.Notify:FireClient(session.A, "Trade cancelled: too far apart.")
				Remotes.Events.Notify:FireClient(session.B, "Trade cancelled: too far apart.")
				endSession(sid, "OutOfRange", false)
			end
		end
	end
end)
