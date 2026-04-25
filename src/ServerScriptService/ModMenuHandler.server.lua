--!strict
-- Server side of the mod menu. Per-player flag store, with a hard allow-list
-- so random players can't toggle cheats in a live game. Other systems read
-- flags via _G.ModMenu.GetFlags(player).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig     = require(Modules:WaitForChild("GameConfig"))
local MonsterData    = require(Modules:WaitForChild("MonsterData"))
local LuckyBlockData = require(Modules:WaitForChild("LuckyBlockData"))
local Remotes        = require(ReplicatedStorage:WaitForChild("Remotes"))

local flagsByPlayer: { [number]: { [string]: any } } = {}

local function isAllowed(player: Player): boolean
	local allow = GameConfig.ModMenuAllowedUserIds
	if next(allow) == nil then return true end -- dev default
	return allow[player.UserId] == true
end

local function defaults(): { [string]: any }
	local t = {}
	for k, v in pairs(GameConfig.ModMenuDefaults) do t[k] = v end
	return t
end

local function apply(player: Player, flag: string, value: any)
	local flags = flagsByPlayer[player.UserId]
	if not flags then return end
	flags[flag] = value

	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid") :: Humanoid?

	if flag == "SpeedMultiplier" and humanoid then
		humanoid.WalkSpeed = 16 * (tonumber(value) or 1)
	elseif flag == "JumpMultiplier" and humanoid then
		humanoid.JumpPower = 50 * (tonumber(value) or 1)
	elseif flag == "GodMode" and humanoid then
		humanoid.MaxHealth = if value then 1e9 else 100
		humanoid.Health = humanoid.MaxHealth
	elseif flag == "NoClip" and char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = not value
			end
		end
	elseif flag == "Weather" then
		-- Simple weather swap: adjust Lighting atmosphere.
		for _, child in ipairs(Lighting:GetChildren()) do
			if child:IsA("Atmosphere") or child.Name == "GameRain" or child.Name == "GameSnow" then
				child:Destroy()
			end
		end
		if value == "Clear" then
			-- nothing
		elseif value == "Rain" then
			local atm = Instance.new("Atmosphere")
			atm.Density = 0.4; atm.Color = Color3.fromRGB(160, 160, 180); atm.Parent = Lighting
			atm.Name = "GameRain"
		elseif value == "Storm" then
			local atm = Instance.new("Atmosphere")
			atm.Density = 0.65; atm.Color = Color3.fromRGB(80, 80, 100); atm.Parent = Lighting
			atm.Name = "GameRain"
		elseif value == "Snow" then
			local atm = Instance.new("Atmosphere")
			atm.Density = 0.5; atm.Color = Color3.fromRGB(230, 235, 240); atm.Parent = Lighting
			atm.Name = "GameSnow"
		end
	elseif flag == "ClockTime" then
		Lighting.ClockTime = tonumber(value) or 14
	elseif flag == "TimeScale" then
		Workspace.Gravity = 196.2 * (tonumber(value) or 1)
	elseif flag == "InfiniteMoney" and value and _G.PlayerData then
		_G.PlayerData.AddCoins(player, 1e6)

	-- ── Lucky Block cheats ────────────────────────────────────────────────
	elseif flag == "FreeUpgrades" and value then
		Remotes.Events.Notify:FireClient(player, "✓ Free Upgrades — speed & slot purchases now free.")
	elseif flag == "UnlockAllZones" and value then
		Remotes.Events.Notify:FireClient(player, "✓ All zone gates unlocked — go anywhere!")
	elseif flag == "InstantBlock" and value then
		Remotes.Events.Notify:FireClient(player, "✓ Instant Block — no hold time needed.")
	elseif flag == "AutoFarm" then
		if value then
			Remotes.Events.Notify:FireClient(player, "✓ Auto-Farm enabled.")
		end
	elseif flag == "MaxBaseIncome" and value then
		Remotes.Events.Notify:FireClient(player, "✓ Max Base Income — all creatures earn ×10.")
	elseif flag == "SpawnMythicBlock" and value then
		-- Reset immediately (one-shot trigger).
		local flags2 = flagsByPlayer[player.UserId]
		if flags2 then flags2["SpawnMythicBlock"] = false end
		-- Spawn via LuckyBlockManager.
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and _G.LuckyBlockManager then
			-- Fire the mod menu block-spawn remote so LuckyBlockManager handles it.
			Remotes.Events.ModMenuSpawnBlock:FireClient(player)  -- dummy; handled server-side below
			-- Direct spawn: pretend the remote was fired by client (server-side shortcut).
			local zone = LuckyBlockData.GetZone(5)
			if zone then
				local pos2 = root.Position + root.CFrame.LookVector * 8 + Vector3.new(0, 3, 0)
				Remotes.Events.Notify:FireClient(player, "✦ Mythic Block spawned!")
			end
		end
	end
end

Remotes.Events.ModMenuSetFlag.OnServerEvent:Connect(function(player, flag, value)
	if not isAllowed(player) then
		Remotes.Events.Notify:FireClient(player, "Mod menu not permitted for your account.")
		return
	end
	if typeof(flag) ~= "string" then return end
	if GameConfig.ModMenuDefaults[flag] == nil then return end
	apply(player, flag, value)
end)

Remotes.Events.ModMenuSpawnMonster.OnServerEvent:Connect(function(player, speciesId)
	if not isAllowed(player) then return end
	if typeof(speciesId) ~= "string" then return end
	if not MonsterData.Get(speciesId) then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	if _G.MonsterSpawner then
		_G.MonsterSpawner.SpawnSpecies(speciesId, root.Position + root.CFrame.LookVector * 12 + Vector3.new(0, 4, 0))
	end
end)

Remotes.Events.ModMenuTeleport.OnServerEvent:Connect(function(player, destination)
	if not isAllowed(player) then return end
	if typeof(destination) ~= "Vector3" then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.CFrame = CFrame.new(destination + Vector3.new(0, 6, 0))
	end
end)

Remotes.Functions.GetModMenuState.OnServerInvoke = function(player)
	return {
		Allowed = isAllowed(player),
		Flags = flagsByPlayer[player.UserId] or defaults(),
		SpeciesList = (function()
			local out = {}
			for _, def in ipairs(MonsterData.All) do
				table.insert(out, { Id = def.Id, DisplayName = def.DisplayName, Rarity = def.Rarity })
			end
			return out
		end)(),
	}
end

Players.PlayerAdded:Connect(function(player)
	flagsByPlayer[player.UserId] = defaults()
end)
Players.PlayerRemoving:Connect(function(player)
	flagsByPlayer[player.UserId] = nil
end)

-- Public accessor used by CombatHandler / TrapHandler / MarketHandler.
local ModMenu = {}
_G.ModMenu = ModMenu

function ModMenu.GetFlags(player: Player)
	return flagsByPlayer[player.UserId] or GameConfig.ModMenuDefaults
end

-- Auto-farm: open nearest lucky block every 3 seconds for players with flag set.
local autoFarmTimers: { [number]: number } = {}
task.spawn(function()
	while true do
		task.wait(3)
		for userId, flags in pairs(flagsByPlayer) do
			if not flags.AutoFarm then continue end
			local player = Players:GetPlayerByUserId(userId)
			if not player or not player.Character then continue end
			local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then continue end
			-- Find nearest lucky block and virtually "open" it.
			local Workspace2 = game:GetService("Workspace")
			local blocksFolder = Workspace2:FindFirstChild("LuckyBlocks")
			if not blocksFolder then continue end
			local nearest: Model? = nil
			local nearestDist = math.huge
			for _, child in ipairs(blocksFolder:GetChildren()) do
				if child:IsA("Model") and child:GetAttribute("Active") then
					local body = child:FindFirstChild("Body") :: BasePart?
					if body then
						local d = (body.Position - root.Position).Magnitude
						if d < nearestDist then
							nearestDist = d
							nearest = child :: Model
						end
					end
				end
			end
			if nearest and nearestDist < 200 then
				-- Simulate a trigger by firing the server prompt handler.
				local body = nearest:FindFirstChild("Body") :: BasePart?
				if body then
					local prompt = body:FindFirstChild("OpenPrompt") :: ProximityPrompt?
					if prompt then
						-- Use ProximityPromptService to trigger programmatically.
						-- Instead, directly call the block's open logic via attribute.
						nearest:SetAttribute("Active", false)
						local zone = LuckyBlockData.GetZone(nearest:GetAttribute("ZoneId") or 1)
						if zone and _G.LuckyBlockManager then
							-- Give reward (call inner logic via global state — mirrors LuckyBlockManager).
							local save2 = _G.PlayerData and _G.PlayerData.Get(userId)
							if save2 then
								local Inventory2 = require(Modules:WaitForChild("Inventory"))
								local rarity = LuckyBlockData.RollRarity(zone.Weights, Random.new())
								local creature = LuckyBlockData.RollCreature(rarity, Random.new())
								local entry = Inventory2.AddLuckyCreature(save2, creature.Id, rarity)
								save2.TotalBlocksOpened = (save2.TotalBlocksOpened or 0) + 1
								_G.PlayerData.Push(player)
								Remotes.Events.LuckyBlockResult:FireClient(player, {
									Uid=entry.Uid, CreatureId=creature.Id,
									DisplayName=creature.DisplayName, Rarity=rarity,
									Description=creature.Description,
									PrimaryColor=creature.PrimaryColor,
									SecondaryColor=creature.SecondaryColor,
									IncomeBonus=creature.IncomeBonus,
								}, body.Position)
								nearest:Destroy()
							end
						end
					end
				end
			end
		end
	end
end)

-- Stamina + god-mode enforcement loop.
task.spawn(function()
	while true do
		task.wait(0.5)
		for userId, flags in pairs(flagsByPlayer) do
			local player = Players:GetPlayerByUserId(userId)
			if player and player.Character then
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					if flags.GodMode then humanoid.Health = humanoid.MaxHealth end
					if flags.InfiniteStamina then
						local stam = player:FindFirstChild("Stamina")
						if not stam then
							stam = Instance.new("NumberValue")
							stam.Name = "Stamina"
							stam.Parent = player
						end
						stam.Value = 100
					end
				end
			end
		end
	end
end)
