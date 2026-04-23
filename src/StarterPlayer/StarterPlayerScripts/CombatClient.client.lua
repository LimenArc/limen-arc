--!strict
-- Click-to-attack + F-to-trap targeting. Sends intents to the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local selectedTrapId = "trap_basic"

local function findWildMonsterFromInstance(inst: Instance?): Model?
	while inst do
		if inst:IsA("Model") and CollectionService:HasTag(inst, "WildMonster") then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

mouse.Button1Down:Connect(function()
	local target = findWildMonsterFromInstance(mouse.Target)
	if target then
		Remotes.Events.CombatAttack:FireServer(target)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F then
		local target = findWildMonsterFromInstance(mouse.Target)
		if target then
			Remotes.Events.ThrowTrap:FireServer(selectedTrapId, target)
		end
	elseif input.KeyCode == Enum.KeyCode.One then
		selectedTrapId = "trap_basic"
	elseif input.KeyCode == Enum.KeyCode.Two then
		selectedTrapId = "trap_strong"
	elseif input.KeyCode == Enum.KeyCode.Three then
		selectedTrapId = "trap_shock"
	elseif input.KeyCode == Enum.KeyCode.Four then
		selectedTrapId = "trap_lure"
	elseif input.KeyCode == Enum.KeyCode.Five then
		selectedTrapId = "trap_master"
	end
end)

-- Expose the selected trap to the HUD.
_G.SelectedTrap = function() return selectedTrapId end
