--!strict
-- Makes boats drivable. Each boat hull stays anchored until a player sits
-- in its VehicleSeat, at which point it switches to unanchored physics with
-- a BodyVelocity/BodyGyro pair so WASD drives it across the water.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

-- Wait for world to build.
while not _G.WorldState do task.wait(0.1) end

local BOAT_SPEED = 32      -- studs/sec at full throttle
local BOAT_TURN = 1.6      -- radians/sec at full steer

-- Given a boat model, set up the drive binding on its VehicleSeat.
local function bindBoat(boat: Model)
	local hull = boat:FindFirstChild("Hull") :: BasePart?
	local seat = boat:FindFirstChildOfClass("VehicleSeat")
	if not (hull and seat) then return end

	local gyro: BodyGyro? = nil
	local velocity: BodyVelocity? = nil
	local heartbeatConn: RBXScriptConnection? = nil

	local function tearDown()
		if gyro then gyro:Destroy(); gyro = nil end
		if velocity then velocity:Destroy(); velocity = nil end
		if heartbeatConn then heartbeatConn:Disconnect(); heartbeatConn = nil end
		hull.Anchored = true
		seat.Anchored = true
		-- Snap back upright over the water line.
		local p = hull.Position
		hull.CFrame = CFrame.new(p.X, math.max(p.Y, 1), p.Z)
	end

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		if occupant then
			-- Mount: unanchor hull + seat, start physics drivers.
			hull.Anchored = false
			seat.Anchored = false
			for _, descendant in ipairs(boat:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.Anchored = false
				end
			end

			gyro = Instance.new("BodyGyro")
			gyro.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
			gyro.P = 2e4
			gyro.D = 500
			gyro.CFrame = hull.CFrame
			gyro.Parent = hull

			velocity = Instance.new("BodyVelocity")
			velocity.MaxForce = Vector3.new(4e5, 4e5, 4e5)
			velocity.Velocity = Vector3.zero
			velocity.Parent = hull

			heartbeatConn = game:GetService("RunService").Heartbeat:Connect(function(dt)
				if not (velocity and gyro and hull.Parent) then return end
				local throttle = seat.Throttle       -- -1 (S), 0, or 1 (W)
				local steer = seat.Steer             -- -1 (A), 0, or 1 (D)
				local forward = hull.CFrame.LookVector
				-- Keep buoyant y-velocity gentle — we want it to sit on top of water.
				local targetY = math.max(hull.Position.Y, 1) - hull.Position.Y
				velocity.Velocity = forward * (throttle * BOAT_SPEED) + Vector3.new(0, targetY * 4, 0)
				-- Apply steer by rotating the gyro target.
				local newCFrame = gyro.CFrame * CFrame.Angles(0, -steer * BOAT_TURN * dt, 0)
				-- Keep boat upright (zero out pitch/roll).
				local _, yaw, _ = newCFrame:ToEulerAnglesYXZ()
				gyro.CFrame = CFrame.new(hull.Position) * CFrame.Angles(0, yaw, 0)
			end)
		else
			-- Dismount.
			tearDown()
		end
	end)
end

for _, boat in ipairs(CollectionService:GetTagged("Boat")) do
	bindBoat(boat)
end
CollectionService:GetInstanceAddedSignal("Boat"):Connect(bindBoat)
