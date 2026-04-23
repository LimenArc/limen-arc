--!strict
-- Quest + story + ending orchestration.
--  · Spawns the 6 NPCs at world anchors (market, camp, cabin, caves).
--  · Receives progress events from other handlers (trap captures, market
--    spending, monster defeats, location entry) and advances quest
--    objectives.
--  · Grants rewards on completion.
--  · Triggers endings via Quest.TriggersEnding or auto-trigger rules.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Quest = require(Modules:WaitForChild("QuestData"))
local Inventory = require(Modules:WaitForChild("Inventory"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

while not _G.WorldState do task.wait(0.1) end
local WorldState = _G.WorldState

local NPCS_FOLDER = Instance.new("Folder")
NPCS_FOLDER.Name = "NPCs"
NPCS_FOLDER.Parent = Workspace:WaitForChild("World")

-- ── NPC spawning ────────────────────────────────────────────────────────

local function anchorPosition(anchor: string): Vector3?
	if anchor == "Market+E" then
		return WorldState.MarketCenter + Vector3.new(10, 2, 8)
	elseif anchor == "Market+W" then
		return WorldState.MarketCenter + Vector3.new(-10, 2, 8)
	elseif anchor == "Camp1" then
		return (WorldState.CampPositions[1] or Vector3.new(0, 4, 60)) + Vector3.new(-4, 2, 4)
	elseif anchor == "Cabin1" then
		return (WorldState.CabinPositions[1] or Vector3.new(0, 4, 80)) + Vector3.new(6, 2, 4)
	elseif anchor == "Cave1" then
		return (WorldState.CavePortals[1] or Vector3.new(60, 4, 60)) + Vector3.new(0, 2, 4)
	elseif anchor == "CaveLast" then
		local last = WorldState.CavePortals[#WorldState.CavePortals]
			or WorldState.CavePortals[1] or Vector3.new(-60, 4, -60)
		return last + Vector3.new(0, 2, 4)
	end
	return nil
end

local function C(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function buildNpcModel(def: Quest.NpcDef, pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "NPC_" .. def.Id

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.2, 3.4, 1.6)
	body.Color = C(def.BodyColor)
	body.Material = Enum.Material.Fabric
	body.Position = pos + Vector3.new(0, 1.7, 0)
	body.Anchored = true
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.Color = C(def.HeadColor)
	head.Material = Enum.Material.SmoothPlastic
	head.Position = body.Position + Vector3.new(0, 2.4, 0)
	head.Anchored = true
	head.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.DisplayName = def.DisplayName
	humanoid.WalkSpeed = 0
	humanoid.Parent = model

	local label = Instance.new("BillboardGui")
	label.Adornee = head
	label.Size = UDim2.fromOffset(220, 40)
	label.StudsOffset = Vector3.new(0, 2, 0)
	label.AlwaysOnTop = true
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = def.DisplayName
	t.Font = Enum.Font.FredokaOne
	t.TextSize = 18
	t.TextColor3 = Color3.fromRGB(255, 240, 200)
	t.TextStrokeTransparency = 0
	t.Parent = label
	label.Parent = head

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = def.DisplayName
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	local idTag = Instance.new("StringValue")
	idTag.Name = "NpcId"
	idTag.Value = def.Id
	idTag.Parent = model

	model:AddTag("NPC")
	model.PrimaryPart = body
	model.Parent = NPCS_FOLDER
	return model
end

-- Spawn all NPCs.
local npcModels: { [string]: Model } = {}
for _, def in ipairs(Quest.Npcs) do
	local pos = anchorPosition(def.Anchor)
	if pos then
		npcModels[def.Id] = buildNpcModel(def, pos)
	end
end

-- ── The Heart of the Mire boss ──────────────────────────────────────────
-- A tough tagged wild monster at the last cave. Killing it counts toward
-- the "Ashes" ending objective (defeat_any_many also accepts normal kills).
do
	local lastCave = WorldState.CavePortals[#WorldState.CavePortals]
	if lastCave then
		task.delay(2, function()
			if _G.MonsterSpawner then
				-- A boulderion acts as our mini-boss at the Heart.
				local boss = _G.MonsterSpawner.SpawnSpecies("boulderion", lastCave + Vector3.new(0, 6, 6))
				if boss then
					boss.Name = "Heart of the Mire"
					local humanoid = boss:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.MaxHealth = 600
						humanoid.Health = 600
					end
				end
			end
		end)
	end
end

-- ── Quest progress helpers ──────────────────────────────────────────────

local function saveOf(player: Player): Inventory.PlayerSave?
	return _G.PlayerData and _G.PlayerData.Get(player.UserId) or nil
end

local function isUnlocked(save: Inventory.PlayerSave, def: Quest.QuestDef): boolean
	for _, reqId in ipairs(def.Prereqs) do
		local rec = save.Quests[reqId]
		if not rec or rec.Status ~= "Completed" then return false end
	end
	return true
end

local function ensureProgress(save: Inventory.PlayerSave, questId: string)
	if not save.Quests[questId] then
		save.Quests[questId] = { Status = "Active", Progress = {} }
	end
end

local function countsForObjective(save: Inventory.PlayerSave, obj: Quest.Objective): number
	if obj.Kind == "HaveItem" and obj.ItemId then
		return Inventory.ItemCount(save, obj.ItemId)
	elseif obj.Kind == "DiscoverSpecies" then
		local n = 0
		for _ in pairs(save.DiscoveredMonsters) do n += 1 end
		return n
	elseif obj.Kind == "AccumulateCoins" then
		return save.LifetimeCoins
	elseif obj.Kind == "SpendCoins" then
		return save.LifetimeSpent
	elseif obj.Kind == "DefeatType" and obj.MonsterType then
		if obj.MonsterType == "Any" then return save.DefeatedTotal end
		return save.DefeatedByType[obj.MonsterType] or 0
	elseif obj.Kind == "VisitLocation" and obj.LocationId then
		local n = 0
		for key in pairs(save.VisitedLocations) do
			if key:sub(1, #obj.LocationId) == obj.LocationId then n += 1 end
		end
		return n
	end
	return -1  -- event-driven objectives (CatchAny, CatchSpecies, TalkToNpc) use stored counters
end

local function isObjectiveDone(save: Inventory.PlayerSave, questRec, obj: Quest.Objective): boolean
	local live = countsForObjective(save, obj)
	if live < 0 then
		live = questRec.Progress[obj.Id] or 0
	end
	return live >= obj.Target
end

local function grantRewards(player: Player, def: Quest.QuestDef)
	local save = saveOf(player); if not save then return end
	if def.Rewards.Coins and def.Rewards.Coins > 0 then
		_G.PlayerData.AddCoins(player, def.Rewards.Coins)
	end
	if def.Rewards.Items then
		for _, stack in ipairs(def.Rewards.Items) do
			_G.PlayerData.GiveItem(player, stack.Id, stack.Count)
		end
	end
end

local function triggerEnding(player: Player, endingId: string)
	local save = saveOf(player); if not save then return end
	if save.EndingAchieved then return end
	save.EndingAchieved = endingId
	_G.PlayerData.Push(player)
	_G.PlayerData.Save(player)
	local def = Quest.Endings[endingId]
	if def then
		Remotes.Events.PlayEnding:FireClient(player, def)
	end
end

local function tryCompleteQuest(player: Player, questId: string)
	local save = saveOf(player); if not save then return end
	local def = Quest.GetQuest(questId); if not def then return end
	local rec = save.Quests[questId]; if not rec or rec.Status ~= "Active" then return end

	for _, obj in ipairs(def.Objectives) do
		if not isObjectiveDone(save, rec, obj) then return end
	end

	rec.Status = "Completed"
	grantRewards(player, def)
	Remotes.Events.Notify:FireClient(player, ("✔  Quest complete: %s"):format(def.Name))
	_G.PlayerData.Push(player)

	if def.TriggersEnding then
		triggerEnding(player, def.TriggersEnding)
	end
end

local function reevaluateAll(player: Player)
	local save = saveOf(player); if not save then return end
	-- Snapshot keys because tryComplete may mutate.
	local ids = {}
	for id in pairs(save.Quests) do table.insert(ids, id) end
	for _, id in ipairs(ids) do tryCompleteQuest(player, id) end
end

-- ── Public API used by other handlers ───────────────────────────────────

local QuestAPI = {}
_G.Quests = QuestAPI

function QuestAPI.OnMonsterCaught(player: Player, speciesId: string)
	local save = saveOf(player); if not save then return end
	for questId, rec in pairs(save.Quests) do
		if rec.Status == "Active" then
			local def = Quest.GetQuest(questId)
			if def then
				for _, obj in ipairs(def.Objectives) do
					if obj.Kind == "CatchAny" then
						rec.Progress[obj.Id] = (rec.Progress[obj.Id] or 0) + 1
					elseif obj.Kind == "CatchSpecies" and obj.SpeciesId == speciesId then
						rec.Progress[obj.Id] = (rec.Progress[obj.Id] or 0) + 1
					end
				end
			end
		end
	end
	_G.PlayerData.Push(player)
	reevaluateAll(player)
end

function QuestAPI.OnMonsterDefeated(player: Player, speciesId: string, types: { string })
	local save = saveOf(player); if not save then return end
	save.DefeatedTotal += 1
	for _, t in ipairs(types) do
		save.DefeatedByType[t] = (save.DefeatedByType[t] or 0) + 1
	end
	_G.PlayerData.Push(player)
	reevaluateAll(player)
end

-- NOTE: PlayerData.AddCoins already bumps save.LifetimeCoins before calling
-- this — we just need to re-check quest completion.
function QuestAPI.OnCoinsEarned(player: Player, _amount: number)
	reevaluateAll(player)
end

function QuestAPI.OnCoinsSpent(player: Player, amount: number)
	local save = saveOf(player); if not save then return end
	save.LifetimeSpent += amount
	reevaluateAll(player)
end

function QuestAPI.OnLocationVisited(player: Player, locationKey: string)
	local save = saveOf(player); if not save then return end
	if save.VisitedLocations[locationKey] then return end
	save.VisitedLocations[locationKey] = true
	_G.PlayerData.Push(player)
	reevaluateAll(player)
end

-- ── Dialogue / talk-to-NPC ──────────────────────────────────────────────

local function availableQuestsForPlayer(save: Inventory.PlayerSave, npcId: string): { Quest.QuestDef }
	local out = {}
	for _, q in ipairs(Quest.QuestsOfferedBy(npcId)) do
		local rec = save.Quests[q.Id]
		if (not rec or rec.Status ~= "Completed") and isUnlocked(save, q) then
			table.insert(out, q)
		end
	end
	return out
end

local function activeQuestsFromNpc(save: Inventory.PlayerSave, npcId: string): { Quest.QuestDef }
	local out = {}
	for _, q in ipairs(Quest.QuestsOfferedBy(npcId)) do
		local rec = save.Quests[q.Id]
		if rec and rec.Status == "Active" then table.insert(out, q) end
	end
	return out
end

local function dialoguePayload(save: Inventory.PlayerSave, npc: Quest.NpcDef)
	local offered = availableQuestsForPlayer(save, npc.Id)
	local active = activeQuestsFromNpc(save, npc.Id)

	-- Strip to client-safe shapes.
	local function briefQuest(q: Quest.QuestDef)
		return {
			Id = q.Id, Name = q.Name, Summary = q.Summary,
			Objectives = q.Objectives, Category = q.Category,
			CompletionText = q.CompletionText,
			Rewards = q.Rewards,
		}
	end

	local offeredList = {}
	for _, q in ipairs(offered) do table.insert(offeredList, briefQuest(q)) end
	local activeList = {}
	for _, q in ipairs(active) do
		local rec = save.Quests[q.Id]
		local entry = briefQuest(q)
		entry.Progress = rec and rec.Progress or {}
		entry.IsReadyToTurnIn = true
		for _, obj in ipairs(q.Objectives) do
			if not isObjectiveDone(save, rec, obj) then entry.IsReadyToTurnIn = false; break end
		end
		table.insert(activeList, entry)
	end

	return {
		NpcId = npc.Id,
		Name = npc.DisplayName,
		Role = npc.Role,
		Greeting = npc.GreetingNoQuest,
		Offered = offeredList,
		Active = activeList,
	}
end

local function onNpcTalked(player: Player, npcId: string)
	local save = saveOf(player); if not save then return end
	local npc = Quest.GetNpc(npcId); if not npc then return end

	save.TalkedNpcs[npcId] = true

	-- Progress TalkToNpc objectives (for ANY active quest).
	for questId, rec in pairs(save.Quests) do
		if rec.Status == "Active" then
			local def = Quest.GetQuest(questId)
			if def then
				for _, obj in ipairs(def.Objectives) do
					if obj.Kind == "TalkToNpc" and obj.NpcId == npcId then
						rec.Progress[obj.Id] = math.max(rec.Progress[obj.Id] or 0, obj.Target)
					end
				end
			end
		end
	end

	_G.PlayerData.Push(player)
	reevaluateAll(player)

	-- Also push dialogue payload so the client can show offers / active quests.
	local refreshedSave = saveOf(player)
	if refreshedSave then
		Remotes.Events.DialogueLines:FireClient(player, dialoguePayload(refreshedSave, npc))
	end
end

-- NPC proximity prompts emit talk events.
for _, model in ipairs(NPCS_FOLDER:GetChildren()) do
	if model:IsA("Model") then
		local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
		local idValue = model:FindFirstChild("NpcId") :: StringValue?
		if prompt and idValue then
			prompt.Triggered:Connect(function(player)
				onNpcTalked(player, idValue.Value)
			end)
		end
	end
end

-- Client-initiated re-talk (for TalkNpc event).
Remotes.Events.TalkNpc.OnServerEvent:Connect(function(player, npcId)
	if typeof(npcId) == "string" then onNpcTalked(player, npcId) end
end)

-- Accept quest (client confirms a quest offered by an NPC).
Remotes.Events.AcceptQuest.OnServerEvent:Connect(function(player, questId)
	if typeof(questId) ~= "string" then return end
	local save = saveOf(player); if not save then return end
	local def = Quest.GetQuest(questId); if not def then return end
	if save.Quests[questId] then return end
	if not isUnlocked(save, def) then return end
	ensureProgress(save, questId)
	Remotes.Events.Notify:FireClient(player, ("New quest: %s"):format(def.Name))
	_G.PlayerData.Push(player)
end)

-- ── Intro cutscene on first join ────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(1.5)
		local save = saveOf(player)
		if save and not save.IntroSeen then
			Remotes.Events.PlayIntro:FireClient(player, Quest.StoryIntro)
			-- Auto-accept the first quest so players always have something.
			if not save.Quests["beacon"] then
				save.Quests["beacon"] = { Status = "Active", Progress = {} }
				_G.PlayerData.Push(player)
			end
		end
	end)
end)

Remotes.Events.IntroSeen.OnServerEvent:Connect(function(player)
	local save = saveOf(player); if not save then return end
	save.IntroSeen = true
	_G.PlayerData.Push(player)
end)

-- ── Location visitor loop (lakes) ───────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(2)
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				for i, lake in ipairs(WorldState.LakeCenters) do
					if (root.Position - lake.Position).Magnitude < lake.Radius + 8 then
						QuestAPI.OnLocationVisited(player, "Lake" .. i)
					end
				end
			end
		end
	end
end)

print(("[QuestHandler] spawned %d NPCs, %d quests, %d endings"):format(
	#Quest.Npcs, #Quest.Quests,
	(function() local n = 0; for _ in pairs(Quest.Endings) do n += 1 end; return n end)()
))
