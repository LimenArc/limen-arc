--!strict
-- On-screen action bar. Every input a mobile player needs without a
-- keyboard, laid out above the Roblox default jump button.
--   [Bag]     toggles backpack
--   [Market]  opens/closes market (server enforces proximity)
--   [Trap ▾]  cycles through the 5 trap tiers
--   [Catch]   throws the currently-selected trap at the nearest monster
--   [Attack]  strikes the nearest monster with the equipped weapon
-- The existing MOD and TRADE buttons from other scripts stay where they are.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TRAP_CYCLE = { "trap_basic", "trap_strong", "trap_shock", "trap_lure", "trap_master" }

local screen = Instance.new("ScreenGui")
screen.Name = "MobileActionBar"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.Parent = playerGui

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -12)
bar.Size = UDim2.fromOffset(480, 64)
bar.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
bar.BackgroundTransparency = 0.2
bar.BorderSizePixel = 0
bar.Parent = screen

Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 14)

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.Parent = bar

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = bar

local function makeButton(label: string, width: number, color: Color3): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(width, 48)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Text = label
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.fromRGB(30, 30, 30)
	btn.Parent = bar
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
	return btn
end

local bagBtn    = makeButton("BAG",    72, Color3.fromRGB(200, 180, 120))
local marketBtn = makeButton("MARKET", 86, Color3.fromRGB(180, 150, 220))
local trapBtn   = makeButton("TRAP",   84, Color3.fromRGB(150, 200, 160))
local catchBtn  = makeButton("CATCH",  80, Color3.fromRGB(130, 200, 220))
local attackBtn = makeButton("ATTACK", 90, Color3.fromRGB(230, 130, 110))

-- ── Hook into other GUIs by finding them under PlayerGui. ────────────────
-- Each feature's script exposes its ScreenGui with a known Name, so we just
-- flip `.Enabled`. Simple + decoupled.
local function toggleScreen(name: string)
	local gui = playerGui:FindFirstChild(name)
	if gui and gui:IsA("ScreenGui") then
		gui.Enabled = not gui.Enabled
	end
end

bagBtn.MouseButton1Click:Connect(function()
	toggleScreen("BackpackGui")
end)

marketBtn.MouseButton1Click:Connect(function()
	-- The market gui manages its own proximity guard when a user opens it
	-- via E. We mirror the same behaviour: if we can't find it in range,
	-- still flip it — the server will reject buys/sells anyway.
	toggleScreen("MarketGui")
end)

-- Cycle through trap tiers. Label shows the current one.
local trapIndex = 1
local function refreshTrapLabel()
	local id = TRAP_CYCLE[trapIndex]
	local def = ItemData.Get(id)
	trapBtn.Text = def and ("TRAP\n" .. def.DisplayName:gsub(" Trap", "")) or "TRAP"
	if _G.Combat then _G.Combat.SetTrap(id) end
end
refreshTrapLabel()

trapBtn.MouseButton1Click:Connect(function()
	trapIndex = trapIndex % #TRAP_CYCLE + 1
	refreshTrapLabel()
end)

-- CATCH button:
--   · short tap          → immediate throw at the nearest monster
--   · long press (>0.5s) → enter "trap aim mode": next tap on a monster
--                          throws the trap. Tap CATCH again to exit.
local pressStart = 0
local trapModeOn = false

local function setTrapModeBtn(on: boolean)
	trapModeOn = on
	if _G.Combat then _G.Combat.SetTrapMode(on, on) end
	catchBtn.BackgroundColor3 = on
		and Color3.fromRGB(220, 130, 60)
		or Color3.fromRGB(130, 200, 220)
	catchBtn.Text = on and "AIM\nTRAP" or "CATCH"
end

catchBtn.MouseButton1Down:Connect(function() pressStart = os.clock() end)
catchBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		pressStart = os.clock()
	end
end)

catchBtn.MouseButton1Click:Connect(function()
	if trapModeOn then
		setTrapModeBtn(false)
		return
	end
	if pressStart > 0 and os.clock() - pressStart > 0.5 then
		setTrapModeBtn(true)
	else
		if _G.Combat then _G.Combat.Throw(nil) end
	end
	pressStart = 0
end)

attackBtn.MouseButton1Click:Connect(function()
	if trapModeOn then setTrapModeBtn(false) end
	if _G.Combat then _G.Combat.Attack(nil) end
end)

-- Banner shown across the top of the screen when aim mode is on.
local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 80)
banner.Size = UDim2.fromOffset(280, 32)
banner.BackgroundColor3 = Color3.fromRGB(220, 130, 60)
banner.BackgroundTransparency = 0.1
banner.BorderSizePixel = 0
banner.Font = Enum.Font.GothamBold
banner.TextSize = 14
banner.TextColor3 = Color3.fromRGB(30, 20, 10)
banner.Text = "Tap a monster to throw the trap"
banner.Visible = false
banner.Parent = screen
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 8)

task.spawn(function()
	while true do
		task.wait(0.15)
		banner.Visible = trapModeOn
	end
end)

-- Hide the bar on large-screen PCs so it doesn't clutter. Heuristic: if
-- touch is not enabled, hide it. Mobile and tablet get it; desktop
-- keeps using the keyboard shortcuts + HUD hint.
local function updateVisibility()
	bar.Visible = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end
updateVisibility()
UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(updateVisibility)
UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(updateVisibility)
