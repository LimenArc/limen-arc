--!strict
-- Builds nicer-looking creatures and NPCs from primitive parts.
-- Used by MonsterSpawner and QuestHandler so the world feels less like a
-- pile of boxes. No external assets — everything is composed from
-- Roblox's built-in shapes, materials, lights, and particle emitters.

local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Builder = {}

-- ── helpers ─────────────────────────────────────────────────────────────
local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true        -- joints are added later, then anchored only on PrimaryPart
	p.CanCollide = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function ball(name: string, diameter: number, color: Color3, material: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.Size = Vector3.new(diameter, diameter, diameter)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function weld(p0: BasePart, p1: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = p0
	w.Part1 = p1
	w.Parent = p0
end

local function darken(c: Color3, by: number): Color3
	return Color3.new(
		math.clamp(c.R * (1 - by), 0, 1),
		math.clamp(c.G * (1 - by), 0, 1),
		math.clamp(c.B * (1 - by), 0, 1)
	)
end

-- Lazily-built textures for type-specific particles. Roblox ships free
-- "rbxasset://textures/" assets we can use without ID hunting.
local PARTICLE_TEXTURES = {
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Splash = "rbxasset://textures/particles/explosion01_implosion_main.dds",
}

local function attachParticles(host: BasePart, types: { string })
	for _, ty in ipairs(types) do
		if ty == "Fire" then
			local fire = Instance.new("Fire")
			fire.Heat = 6
			fire.Size = math.clamp(host.Size.Magnitude * 0.6, 3, 8)
			fire.Color = Color3.fromRGB(255, 140, 30)
			fire.SecondaryColor = Color3.fromRGB(120, 30, 10)
			fire.Parent = host
		elseif ty == "Water" then
			local em = Instance.new("ParticleEmitter")
			em.Texture = PARTICLE_TEXTURES.Splash
			em.Color = ColorSequence.new(Color3.fromRGB(100, 200, 240))
			em.Rate = 6
			em.Lifetime = NumberRange.new(0.6, 1.0)
			em.Speed = NumberRange.new(2, 4)
			em.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(1, 0.0),
			})
			em.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			})
			em.Parent = host
		elseif ty == "Electric" then
			local sp = Instance.new("Sparkles")
			sp.SparkleColor = Color3.fromRGB(240, 230, 80)
			sp.Parent = host
		elseif ty == "Grass" then
			local em = Instance.new("ParticleEmitter")
			em.Texture = PARTICLE_TEXTURES.Sparkle
			em.Color = ColorSequence.new(Color3.fromRGB(120, 200, 80))
			em.Rate = 3
			em.Lifetime = NumberRange.new(1, 2)
			em.Speed = NumberRange.new(0.5, 1.5)
			em.Size = NumberSequence.new(0.4)
			em.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			})
			em.Parent = host
		elseif ty == "Psychic" then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(180, 100, 220)
			light.Range = 8
			light.Brightness = 1.5
			light.Parent = host
		elseif ty == "Ghost" then
			local em = Instance.new("ParticleEmitter")
			em.Texture = PARTICLE_TEXTURES.Smoke
			em.Color = ColorSequence.new(Color3.fromRGB(180, 180, 220))
			em.Rate = 4
			em.Lifetime = NumberRange.new(1.5, 2.5)
			em.Speed = NumberRange.new(0.5, 1.5)
			em.Size = NumberSequence.new(1.2)
			em.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			})
			em.Parent = host
		elseif ty == "Ice" then
			local sp = Instance.new("Sparkles")
			sp.SparkleColor = Color3.fromRGB(180, 220, 255)
			sp.Parent = host
		elseif ty == "Dark" then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(80, 30, 100)
			light.Range = 6
			light.Brightness = 0.6
			light.Parent = host
		elseif ty == "Dragon" then
			local fire = Instance.new("Fire")
			fire.Heat = 12
			fire.Size = 6
			fire.Color = Color3.fromRGB(160, 60, 220)
			fire.SecondaryColor = Color3.fromRGB(40, 10, 60)
			fire.Parent = host
		end
	end
end

-- Subtle breathing / bobbing tween on the body part.
local function breathe(body: BasePart)
	local origin = body.CFrame
	task.spawn(function()
		while body.Parent do
			local up = TweenService:Create(body, TweenInfo.new(2.0,
				Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ CFrame = origin * CFrame.new(0, 0.15, 0) })
			up:Play(); up.Completed:Wait()
			if not body.Parent then break end
			local down = TweenService:Create(body, TweenInfo.new(2.0,
				Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ CFrame = origin })
			down:Play(); down.Completed:Wait()
		end
	end)
end

-- ── Monster construction ────────────────────────────────────────────────
-- Returns a Model whose PrimaryPart is the body. Caller weld-anchors it,
-- adds Humanoid, etc.

export type MonsterArt = {
	DisplayName: string,
	Types: { string },
	Size: Vector3,
	PrimaryColor: Color3,
	SecondaryColor: Color3,
}

function Builder.BuildMonster(art: MonsterArt, anchorPos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = art.DisplayName
	local s = art.Size
	local primary = art.PrimaryColor
	local accent = art.SecondaryColor
	local belly = darken(primary, 0.15)

	-- Body: rounded torso (slightly tapered).
	local body = part("Body", Vector3.new(s.X, s.Y * 0.7, s.Z),
		primary, Enum.Material.SmoothPlastic)
	body.Position = anchorPos + Vector3.new(0, s.Y * 0.5, 0)
	body.Parent = model

	-- Belly underside (lighter / darker accent for visual depth).
	local under = part("Belly", Vector3.new(s.X * 0.85, s.Y * 0.35, s.Z * 0.9),
		belly, Enum.Material.SmoothPlastic)
	under.CFrame = body.CFrame * CFrame.new(0, -s.Y * 0.18, 0)
	under.Parent = model
	weld(body, under)

	-- Head: ball, leaning forward.
	local headDia = math.max(s.X, s.Y) * 0.65
	local head = ball("Head", headDia, primary, Enum.Material.SmoothPlastic)
	head.CFrame = body.CFrame * CFrame.new(0, s.Y * 0.3, -s.Z * 0.55)
	head.Parent = model
	weld(body, head)

	-- Eyes: two small dark balls, then white pupils.
	for _, sx in ipairs({ -0.22, 0.22 }) do
		local eye = ball("Eye", headDia * 0.28, Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
		eye.CFrame = head.CFrame * CFrame.new(sx * headDia, 0.05 * headDia, -headDia * 0.42)
		eye.Parent = model
		weld(head, eye)
		local pupil = ball("Pupil", headDia * 0.14, Color3.fromRGB(15, 15, 25), Enum.Material.SmoothPlastic)
		pupil.CFrame = eye.CFrame * CFrame.new(0, 0, -headDia * 0.08)
		pupil.Parent = model
		weld(eye, pupil)
	end

	-- Ears / horns / fins — pick based on dominant type.
	local primaryType = art.Types[1]
	if primaryType == "Fire" or primaryType == "Dragon" or primaryType == "Rock" then
		-- Two horns
		for _, sx in ipairs({ -0.4, 0.4 }) do
			local horn = part("Horn", Vector3.new(headDia * 0.18, headDia * 0.7, headDia * 0.18),
				accent, Enum.Material.Slate)
			horn.CFrame = head.CFrame * CFrame.new(sx * headDia, headDia * 0.55, headDia * 0.1)
				* CFrame.Angles(math.rad(15), 0, math.rad(sx > 0 and 15 or -15))
			horn.Parent = model
			weld(head, horn)
		end
	elseif primaryType == "Flying" then
		-- Two wings on the body.
		for _, sx in ipairs({ -1, 1 }) do
			local wing = part("Wing", Vector3.new(0.3, s.Y * 0.9, s.Z * 0.85),
				accent, Enum.Material.SmoothPlastic)
			wing.CFrame = body.CFrame * CFrame.new(sx * s.X * 0.55, 0, 0)
				* CFrame.Angles(0, 0, math.rad(sx * 25))
			wing.Parent = model
			weld(body, wing)
		end
	elseif primaryType == "Water" or primaryType == "Ice" then
		-- A single dorsal fin.
		local fin = part("Fin", Vector3.new(0.3, s.Y * 0.7, s.Z * 0.6),
			accent, Enum.Material.SmoothPlastic)
		fin.CFrame = body.CFrame * CFrame.new(0, s.Y * 0.55, 0)
			* CFrame.Angles(0, 0, 0)
		fin.Parent = model
		weld(body, fin)
	else
		-- Two ears.
		for _, sx in ipairs({ -0.3, 0.3 }) do
			local ear = part("Ear", Vector3.new(headDia * 0.18, headDia * 0.45, headDia * 0.05),
				accent, Enum.Material.SmoothPlastic)
			ear.CFrame = head.CFrame * CFrame.new(sx * headDia, headDia * 0.5, 0)
				* CFrame.Angles(0, 0, math.rad(sx > 0 and -10 or 10))
			ear.Parent = model
			weld(head, ear)
		end
	end

	-- Four legs (or two for flying / fish).
	local legCount = (primaryType == "Flying" or primaryType == "Water") and 0 or 4
	for i = 1, legCount do
		local sx = (i % 2 == 0) and 1 or -1
		local sz = (i <= 2) and -1 or 1
		local leg = part("Leg", Vector3.new(s.X * 0.18, s.Y * 0.5, s.X * 0.18),
			darken(primary, 0.1), Enum.Material.SmoothPlastic)
		leg.CFrame = body.CFrame * CFrame.new(sx * s.X * 0.35, -s.Y * 0.5, sz * s.Z * 0.3)
		leg.Parent = model
		weld(body, leg)
	end

	-- Tail (most species).
	if primaryType ~= "Ghost" then
		local tail = part("Tail", Vector3.new(s.X * 0.25, s.Y * 0.3, s.Z * 0.5),
			accent, Enum.Material.SmoothPlastic)
		tail.CFrame = body.CFrame * CFrame.new(0, 0, s.Z * 0.55)
			* CFrame.Angles(math.rad(-20), 0, 0)
		tail.Parent = model
		weld(body, tail)
	end

	-- Type particles attached to body.
	attachParticles(body, art.Types)

	-- Make the BODY collidable (others hover around the body) and unanchor
	-- everything else so the welds drag them along.
	body.CanCollide = true
	body.Anchored = false
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") and child ~= body then
			child.Anchored = false
		end
	end

	model.PrimaryPart = body
	breathe(body)
	return model
end

-- ── NPC construction ────────────────────────────────────────────────────
export type NpcArt = {
	DisplayName: string,
	HeadColor: Color3,
	BodyColor: Color3,
}

function Builder.BuildNpc(art: NpcArt, pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "NPC_" .. art.DisplayName

	-- Torso
	local torso = part("Body", Vector3.new(2.2, 2.4, 1.4), art.BodyColor, Enum.Material.Fabric)
	torso.Position = pos + Vector3.new(0, 2.2, 0)
	torso.Parent = model

	-- Hips (wider)
	local hips = part("Hips", Vector3.new(2.4, 0.6, 1.4), darken(art.BodyColor, 0.1), Enum.Material.Fabric)
	hips.CFrame = torso.CFrame * CFrame.new(0, -1.5, 0)
	hips.Parent = model
	weld(torso, hips)

	-- Legs
	for _, sx in ipairs({ -0.6, 0.6 }) do
		local leg = part("Leg", Vector3.new(0.9, 2.4, 1.0),
			darken(art.BodyColor, 0.25), Enum.Material.Fabric)
		leg.CFrame = hips.CFrame * CFrame.new(sx, -1.4, 0)
		leg.Parent = model
		weld(hips, leg)
		local foot = part("Foot", Vector3.new(1.0, 0.4, 1.4),
			Color3.fromRGB(50, 35, 25), Enum.Material.Wood)
		foot.CFrame = leg.CFrame * CFrame.new(0, -1.4, 0.1)
		foot.Parent = model
		weld(leg, foot)
	end

	-- Arms
	for _, sx in ipairs({ -1.4, 1.4 }) do
		local arm = part("Arm", Vector3.new(0.7, 2.0, 0.9),
			darken(art.BodyColor, 0.15), Enum.Material.Fabric)
		arm.CFrame = torso.CFrame * CFrame.new(sx, -0.2, 0)
			* CFrame.Angles(0, 0, math.rad(sx > 0 and -8 or 8))
		arm.Parent = model
		weld(torso, arm)
		-- Hand
		local hand = ball("Hand", 0.7, art.HeadColor, Enum.Material.SmoothPlastic)
		hand.CFrame = arm.CFrame * CFrame.new(0, -1.1, 0)
		hand.Parent = model
		weld(arm, hand)
	end

	-- Neck
	local neck = part("Neck", Vector3.new(0.6, 0.6, 0.6),
		darken(art.HeadColor, 0.2), Enum.Material.SmoothPlastic)
	neck.CFrame = torso.CFrame * CFrame.new(0, 1.4, 0)
	neck.Parent = model
	weld(torso, neck)

	-- Head
	local head = ball("Head", 1.6, art.HeadColor, Enum.Material.SmoothPlastic)
	head.CFrame = neck.CFrame * CFrame.new(0, 1.0, 0)
	head.Parent = model
	weld(neck, head)

	-- Eyes + pupils
	for _, sx in ipairs({ -0.3, 0.3 }) do
		local eye = ball("Eye", 0.32, Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
		eye.CFrame = head.CFrame * CFrame.new(sx, 0.05, -0.7)
		eye.Parent = model
		weld(head, eye)
		local pupil = ball("Pupil", 0.16, Color3.fromRGB(20, 20, 30), Enum.Material.SmoothPlastic)
		pupil.CFrame = eye.CFrame * CFrame.new(0, 0, -0.1)
		pupil.Parent = model
		weld(eye, pupil)
	end

	-- Mouth (smile)
	local mouth = part("Mouth", Vector3.new(0.8, 0.08, 0.05),
		Color3.fromRGB(70, 30, 30), Enum.Material.SmoothPlastic)
	mouth.CFrame = head.CFrame * CFrame.new(0, -0.35, -0.78)
	mouth.Parent = model
	weld(head, mouth)

	-- Hair (simple cap)
	local hair = part("Hair", Vector3.new(1.7, 0.6, 1.7),
		Color3.fromRGB(60, 40, 25), Enum.Material.Fabric)
	hair.CFrame = head.CFrame * CFrame.new(0, 0.7, 0.05)
	hair.Parent = model
	weld(head, hair)

	-- Body collide; other parts ride along.
	torso.CanCollide = true
	torso.Anchored = false
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") and child ~= torso then
			child.Anchored = false
		end
	end

	model.PrimaryPart = torso
	breathe(torso)
	return model
end

return Builder
