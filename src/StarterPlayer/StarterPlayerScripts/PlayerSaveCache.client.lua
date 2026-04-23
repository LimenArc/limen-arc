--!strict
-- Holds the latest PlayerSave snapshot from the server so every UI reads
-- the same source of truth. Fires `Updated` when a push arrives.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local Cache = {
	Save = nil :: any,
	Updated = Instance.new("BindableEvent"),
}
_G.SaveCache = Cache

Remotes.Events.RequestSave.OnClientEvent:Connect(function(save)
	Cache.Save = save
	Cache.Updated:Fire(save)
end)

-- Pull once on join.
task.spawn(function()
	local ok, save = pcall(function() return Remotes.Functions.GetPlayerSave:InvokeServer() end)
	if ok and save then
		Cache.Save = save
		Cache.Updated:Fire(save)
	end
end)

return Cache
