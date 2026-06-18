--!strict
-- All story-layer UI in one file:
--   · Opening intro crawl (server fires PlayIntro on first spawn)
--   · NPC dialogue panel with accept-quest buttons (DialogueLines)
--   · Quest journal (press J or tap the QUEST button)
--   · Ending cutscene (PlayEnding)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local QuestData = require(Modules:WaitForChild("QuestData"))
local UiKit = require(Modules:WaitForChild("UiKit"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function Color(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- ══════════════════════════════════════════════════════════════════════════
-- Shared full-screen cutscene helper.
-- ══════════════════════════════════════════════════════════════════════════

local function buildCutscene(): (ScreenGui, Frame, TextLabel, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "StoryCutscene"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = playerGui

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0
	bg.BorderSizePixel = 0
	bg.Parent = gui

	local content = Instance.new("TextLabel")
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position = UDim2.fromScale(0.5, 0.5)
	content.Size = UDim2.new(0.8, 0, 0.7, 0)
	content.BackgroundTransparency = 1
	content.Text = ""
	content.TextColor3 = Color3.fromRGB(240, 230, 200)
	content.Font = Enum.Font.FredokaOne
	content.TextSize = 22
	content.TextWrapped = true
	content.TextYAlignment = Enum.TextYAlignment.Top
	content.Parent = bg

	local skip = Instance.new("TextButton")
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position = UDim2.new(1, -20, 1, -20)
	skip.Size = UDim2.fromOffset(120, 36)
	skip.Text = "SKIP"
	skip.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	skip.TextColor3 = Color3.fromRGB(240, 240, 240)
	skip.BorderSizePixel = 0
	skip.Font = Enum.Font.GothamBold
	skip.TextSize = 14
	skip.Parent = bg
	Instance.new("UICorner", skip).CornerRadius = UDim.new(0, 6)

	return gui, bg, content, skip
end

local function typeOutLines(label: TextLabel, lines: { string }, pacePerLine: number, onDone: () -> (), skipRequested: () -> boolean)
	local assembled = ""
	for i, line in ipairs(lines) do
		if skipRequested() then break end
		assembled = if #assembled > 0 then assembled .. "\n" .. line else line
		label.Text = assembled
		task.wait(pacePerLine)
	end
	if not skipRequested() then
		task.wait(2)
	end
	onDone()
end

-- ══════════════════════════════════════════════════════════════════════════
-- Intro: story crawl on first join.
-- ══════════════════════════════════════════════════════════════════════════
local introGui, introBg, introLabel, introSkip = buildCutscene()

Remotes.Events.PlayIntro.OnClientEvent:Connect(function(lines)
	introGui.Enabled = true
	introBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	introLabel.TextColor3 = Color3.fromRGB(240, 230, 200)
	introLabel.Text = ""

	local skipped = false
	introSkip.Text = "SKIP"
	introSkip.MouseButton1Click:Once(function() skipped = true end)

	task.spawn(function()
		typeOutLines(introLabel, lines, 1.5, function()
			TweenService:Create(introBg, TweenInfo.new(1.0), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(introLabel, TweenInfo.new(1.0), { TextTransparency = 1 }):Play()
			task.wait(1.1)
			introGui.Enabled = false
			introBg.BackgroundTransparency = 0
			introLabel.TextTransparency = 0
			Remotes.Events.IntroSeen:FireServer()
		end, function() return skipped end)
	end)
end)

-- ══════════════════════════════════════════════════════════════════════════
-- Ending cutscene.
-- ══════════════════════════════════════════════════════════════════════════
local endGui, endBg, endLabel, endSkip = buildCutscene()
endGui.DisplayOrder = 60

Remotes.Events.PlayEnding.OnClientEvent:Connect(function(def)
	endGui.Enabled = true
	local tint = Color(def.Color)
	endBg.BackgroundColor3 = Color3.new(
		tint.R * 0.15, tint.G * 0.15, tint.B * 0.15
	)
	endBg.BackgroundTransparency = 0
	endLabel.TextColor3 = tint
	endLabel.TextTransparency = 0
	endLabel.Text = ""
	endSkip.Text = "CLOSE"

	local skipped = false
	endSkip.MouseButton1Click:Once(function() skipped = true end)

	task.spawn(function()
		typeOutLines(endLabel, def.Narration, 2.2, function()
			task.wait(3)
			TweenService:Create(endBg, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(endLabel, TweenInfo.new(1.5), { TextTransparency = 1 }):Play()
			task.wait(1.6)
			endGui.Enabled = false
		end, function() return skipped end)
	end)
end)

-- ══════════════════════════════════════════════════════════════════════════
-- Dialogue panel (opens when server sends DialogueLines).
-- ══════════════════════════════════════════════════════════════════════════
local dlgGui = Instance.new("ScreenGui")
dlgGui.Name = "DialogueGui"
dlgGui.ResetOnSpawn = false
dlgGui.Enabled = false
dlgGui.Parent = playerGui

local dlgFrame = Instance.new("Frame")
dlgFrame.AnchorPoint = Vector2.new(0.5, 1)
dlgFrame.Position = UDim2.new(0.5, 0, 1, -96)
dlgFrame.Size = UDim2.fromOffset(640, 280)
dlgFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 36)
dlgFrame.BackgroundTransparency = 0.05
dlgFrame.BorderSizePixel = 0
dlgFrame.Parent = dlgGui
Instance.new("UICorner", dlgFrame).CornerRadius = UDim.new(0, 12)

UiKit.AddCloseButton(dlgFrame)
local dlgStroke = Instance.new("UIStroke")
dlgStroke.Color = Color3.fromRGB(200, 170, 80)
dlgStroke.Thickness = 1.5
dlgStroke.Parent = dlgFrame

local dlgName = Instance.new("TextLabel")
dlgName.Size = UDim2.new(1, -20, 0, 30)
dlgName.Position = UDim2.fromOffset(14, 8)
dlgName.BackgroundTransparency = 1
dlgName.TextXAlignment = Enum.TextXAlignment.Left
dlgName.Font = Enum.Font.FredokaOne
dlgName.TextSize = 20
dlgName.TextColor3 = Color3.fromRGB(255, 230, 170)
dlgName.Text = ""
dlgName.Parent = dlgFrame

local dlgRole = Instance.new("TextLabel")
dlgRole.Size = UDim2.new(1, -20, 0, 18)
dlgRole.Position = UDim2.fromOffset(14, 34)
dlgRole.BackgroundTransparency = 1
dlgRole.TextXAlignment = Enum.TextXAlignment.Left
dlgRole.Font = Enum.Font.Gotham
dlgRole.TextSize = 12
dlgRole.TextColor3 = Color3.fromRGB(160, 160, 190)
dlgRole.Text = ""
dlgRole.Parent = dlgFrame

local dlgBody = Instance.new("TextLabel")
dlgBody.Position = UDim2.fromOffset(14, 58)
dlgBody.Size = UDim2.new(1, -28, 0, 50)
dlgBody.BackgroundTransparency = 1
dlgBody.TextXAlignment = Enum.TextXAlignment.Left
dlgBody.TextYAlignment = Enum.TextYAlignment.Top
dlgBody.TextWrapped = true
dlgBody.Font = Enum.Font.Gotham
dlgBody.TextSize = 15
dlgBody.TextColor3 = Color3.fromRGB(240, 235, 220)
dlgBody.Text = ""
dlgBody.Parent = dlgFrame

local dlgList = Instance.new("ScrollingFrame")
dlgList.Position = UDim2.fromOffset(14, 118)
dlgList.Size = UDim2.new(1, -28, 1, -170)
dlgList.BackgroundTransparency = 1
dlgList.BorderSizePixel = 0
dlgList.CanvasSize = UDim2.new(0, 0, 0, 0)
dlgList.AutomaticCanvasSize = Enum.AutomaticSize.Y
dlgList.ScrollBarThickness = 3
dlgList.Parent = dlgFrame
local dlgListLayout = Instance.new("UIListLayout")
dlgListLayout.Padding = UDim.new(0, 6)
dlgListLayout.Parent = dlgList

local dlgClose = Instance.new("TextButton")
dlgClose.AnchorPoint = Vector2.new(1, 1)
dlgClose.Position = UDim2.new(1, -12, 1, -12)
dlgClose.Size = UDim2.fromOffset(100, 32)
dlgClose.Text = "Close"
dlgClose.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
dlgClose.TextColor3 = Color3.fromRGB(240, 240, 240)
dlgClose.BorderSizePixel = 0
dlgClose.Font = Enum.Font.GothamBold
dlgClose.TextSize = 13
dlgClose.Parent = dlgFrame
Instance.new("UICorner", dlgClose).CornerRadius = UDim.new(0, 6)
dlgClose.MouseButton1Click:Connect(function() dlgGui.Enabled = false end)

local function clear(list: Instance)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") and not c:IsA("UIListLayout") then c:Destroy() end
	end
end

Remotes.Events.DialogueLines.OnClientEvent:Connect(function(payload)
	dlgGui.Enabled = true
	dlgName.Text = payload.Name
	dlgRole.Text = payload.Role or ""
	dlgBody.Text = payload.Greeting or ""
	clear(dlgList)

	-- Active quests from this NPC (with turn-in state).
	for _, q in ipairs(payload.Active or {}) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 56)
		row.BackgroundColor3 = Color3.fromRGB(30, 35, 52)
		row.BorderSizePixel = 0
		row.Parent = dlgList
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

		local title = Instance.new("TextLabel")
		title.Position = UDim2.fromOffset(10, 4)
		title.Size = UDim2.new(1, -20, 0, 20)
		title.BackgroundTransparency = 1
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Font = Enum.Font.GothamBold
		title.TextSize = 13
		title.TextColor3 = Color3.fromRGB(240, 220, 160)
		title.Text = "▶ " .. q.Name .. (q.IsReadyToTurnIn and "  ✓ ready" or "  (in progress)")
		title.Parent = row

		local summ = Instance.new("TextLabel")
		summ.Position = UDim2.fromOffset(10, 26)
		summ.Size = UDim2.new(1, -20, 0, 28)
		summ.BackgroundTransparency = 1
		summ.TextXAlignment = Enum.TextXAlignment.Left
		summ.TextYAlignment = Enum.TextYAlignment.Top
		summ.TextWrapped = true
		summ.Font = Enum.Font.Gotham
		summ.TextSize = 12
		summ.TextColor3 = Color3.fromRGB(190, 190, 200)
		summ.Text = q.Summary
		summ.Parent = row
	end

	-- Available offers.
	for _, q in ipairs(payload.Offered or {}) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 72)
		row.BackgroundColor3 = Color3.fromRGB(40, 46, 70)
		row.BorderSizePixel = 0
		row.Parent = dlgList
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

		local title = Instance.new("TextLabel")
		title.Position = UDim2.fromOffset(10, 4)
		title.Size = UDim2.new(1, -130, 0, 20)
		title.BackgroundTransparency = 1
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Font = Enum.Font.GothamBold
		title.TextSize = 14
		title.TextColor3 = Color3.fromRGB(240, 230, 200)
		title.Text = ("【%s】 %s"):format(q.Category, q.Name)
		title.Parent = row

		local summ = Instance.new("TextLabel")
		summ.Position = UDim2.fromOffset(10, 26)
		summ.Size = UDim2.new(1, -20, 0, 42)
		summ.BackgroundTransparency = 1
		summ.TextXAlignment = Enum.TextXAlignment.Left
		summ.TextYAlignment = Enum.TextYAlignment.Top
		summ.TextWrapped = true
		summ.Font = Enum.Font.Gotham
		summ.TextSize = 12
		summ.TextColor3 = Color3.fromRGB(210, 210, 220)
		summ.Text = q.Summary
		summ.Parent = row

		local accept = Instance.new("TextButton")
		accept.AnchorPoint = Vector2.new(1, 0)
		accept.Position = UDim2.new(1, -8, 0, 4)
		accept.Size = UDim2.fromOffset(110, 28)
		accept.Text = "Accept"
		accept.BackgroundColor3 = Color3.fromRGB(90, 170, 110)
		accept.TextColor3 = Color3.fromRGB(30, 30, 30)
		accept.Font = Enum.Font.GothamBold
		accept.TextSize = 13
		accept.BorderSizePixel = 0
		accept.Parent = row
		Instance.new("UICorner", accept).CornerRadius = UDim.new(0, 6)
		accept.MouseButton1Click:Connect(function()
			Remotes.Events.AcceptQuest:FireServer(q.Id)
			accept.Text = "Accepted"
			accept.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
		end)
	end

	if #(payload.Active or {}) == 0 and #(payload.Offered or {}) == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 32)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 13
		empty.TextColor3 = Color3.fromRGB(160, 160, 180)
		empty.Text = "(Nothing new to say.)"
		empty.Parent = dlgList
	end
end)

-- ══════════════════════════════════════════════════════════════════════════
-- Quest journal.
-- ══════════════════════════════════════════════════════════════════════════
local journalGui = Instance.new("ScreenGui")
journalGui.Name = "QuestJournalGui"
journalGui.ResetOnSpawn = false
journalGui.Enabled = false
journalGui.Parent = playerGui

local jFrame = Instance.new("Frame")
jFrame.AnchorPoint = Vector2.new(0.5, 0.5)
jFrame.Position = UDim2.fromScale(0.5, 0.5)
jFrame.Size = UDim2.fromOffset(600, 520)
jFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 28)
jFrame.BorderSizePixel = 0
jFrame.Parent = journalGui
Instance.new("UICorner", jFrame).CornerRadius = UDim.new(0, 12)

UiKit.AddCloseButton(jFrame)

local jTitle = Instance.new("TextLabel")
jTitle.Size = UDim2.new(1, 0, 0, 40)
jTitle.BackgroundTransparency = 1
jTitle.Text = "Journal"
jTitle.Font = Enum.Font.FredokaOne
jTitle.TextSize = 24
jTitle.TextColor3 = Color3.fromRGB(240, 220, 160)
jTitle.Parent = jFrame

local jScroll = Instance.new("ScrollingFrame")
jScroll.Position = UDim2.new(0, 14, 0, 48)
jScroll.Size = UDim2.new(1, -28, 1, -60)
jScroll.BackgroundTransparency = 1
jScroll.BorderSizePixel = 0
jScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
jScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
jScroll.ScrollBarThickness = 4
jScroll.Parent = jFrame

local jLayout = Instance.new("UIListLayout")
jLayout.Padding = UDim.new(0, 8)
jLayout.Parent = jScroll

local function objectiveProgressText(save, questDef, rec)
	local lines = {}
	for _, obj in ipairs(questDef.Objectives) do
		local have = rec.Progress[obj.Id] or 0
		if obj.Kind == "HaveItem" and obj.ItemId then
			local count = 0
			for _, stack in ipairs(save.Items or {}) do
				if stack.Id == obj.ItemId then count += stack.Count end
			end
			have = count
		elseif obj.Kind == "DiscoverSpecies" then
			have = 0
			for _ in pairs(save.DiscoveredMonsters or {}) do have += 1 end
		elseif obj.Kind == "AccumulateCoins" then
			have = save.LifetimeCoins or 0
		elseif obj.Kind == "SpendCoins" then
			have = save.LifetimeSpent or 0
		elseif obj.Kind == "DefeatType" and obj.MonsterType then
			if obj.MonsterType == "Any" then
				have = save.DefeatedTotal or 0
			else
				have = (save.DefeatedByType or {})[obj.MonsterType] or 0
			end
		elseif obj.Kind == "VisitLocation" and obj.LocationId then
			local n = 0
			for key in pairs(save.VisitedLocations or {}) do
				if key:sub(1, #obj.LocationId) == obj.LocationId then n += 1 end
			end
			have = n
		end
		local check = have >= obj.Target and "☑" or "☐"
		table.insert(lines, ("   %s %s  (%d/%d)"):format(check, obj.Description, have, obj.Target))
	end
	return table.concat(lines, "\n")
end

local function renderJournal()
	for _, c in ipairs(jScroll:GetChildren()) do
		if c:IsA("GuiObject") and not c:IsA("UIListLayout") then c:Destroy() end
	end

	local save = _G.SaveCache and _G.SaveCache.Save
	if not save then
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0, 24)
		l.BackgroundTransparency = 1
		l.Text = "Loading…"
		l.TextColor3 = Color3.fromRGB(200, 200, 200)
		l.Font = Enum.Font.Gotham; l.TextSize = 14
		l.Parent = jScroll
		return
	end

	-- Group quests: Active, then Completed.
	local actives, completes = {}, {}
	for id, rec in pairs(save.Quests or {}) do
		local def = QuestData.GetQuest(id)
		if def then
			if rec.Status == "Active" then
				table.insert(actives, { def = def, rec = rec })
			else
				table.insert(completes, { def = def, rec = rec })
			end
		end
	end

	local function header(text: string, color: Color3)
		local h = Instance.new("TextLabel")
		h.Size = UDim2.new(1, 0, 0, 24)
		h.BackgroundTransparency = 1
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.Font = Enum.Font.GothamBold
		h.TextSize = 14
		h.TextColor3 = color
		h.Text = text
		h.Parent = jScroll
	end

	local function card(entry, completed: boolean)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1, 0, 0, 100)
		f.BackgroundColor3 = completed and Color3.fromRGB(24, 30, 26) or Color3.fromRGB(30, 34, 50)
		f.BorderSizePixel = 0
		f.Parent = jScroll
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

		local t = Instance.new("TextLabel")
		t.Position = UDim2.fromOffset(10, 6)
		t.Size = UDim2.new(1, -20, 0, 18)
		t.BackgroundTransparency = 1
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Font = Enum.Font.GothamBold
		t.TextSize = 14
		t.TextColor3 = completed and Color3.fromRGB(180, 210, 180) or Color3.fromRGB(240, 220, 160)
		t.Text = ("【%s】 %s"):format(entry.def.Category, entry.def.Name)
		t.Parent = f

		local s = Instance.new("TextLabel")
		s.Position = UDim2.fromOffset(10, 26)
		s.Size = UDim2.new(1, -20, 0, 24)
		s.BackgroundTransparency = 1
		s.TextXAlignment = Enum.TextXAlignment.Left
		s.TextYAlignment = Enum.TextYAlignment.Top
		s.TextWrapped = true
		s.Font = Enum.Font.Gotham
		s.TextSize = 12
		s.TextColor3 = Color3.fromRGB(180, 180, 200)
		s.Text = entry.def.Summary
		s.Parent = f

		local o = Instance.new("TextLabel")
		o.Position = UDim2.fromOffset(10, 54)
		o.Size = UDim2.new(1, -20, 0, 42)
		o.BackgroundTransparency = 1
		o.TextXAlignment = Enum.TextXAlignment.Left
		o.TextYAlignment = Enum.TextYAlignment.Top
		o.TextWrapped = true
		o.Font = Enum.Font.Gotham
		o.TextSize = 12
		o.TextColor3 = Color3.fromRGB(220, 220, 230)
		o.Text = completed and ("✔ " .. (entry.def.CompletionText or "Complete"))
			or objectiveProgressText(save, entry.def, entry.rec)
		o.Parent = f
	end

	if #actives > 0 then
		header("ACTIVE", Color3.fromRGB(240, 220, 160))
		for _, e in ipairs(actives) do card(e, false) end
	end
	if #completes > 0 then
		header("COMPLETED", Color3.fromRGB(160, 200, 160))
		for _, e in ipairs(completes) do card(e, true) end
	end
	if #actives == 0 and #completes == 0 then
		header("No quests yet. Find an NPC and talk to them.", Color3.fromRGB(180, 180, 200))
	end
	if save.EndingAchieved then
		header(("Ending reached: %s"):format(QuestData.Endings[save.EndingAchieved].Name),
			Color3.fromRGB(240, 180, 120))
	end
end

local function toggleJournal()
	journalGui.Enabled = not journalGui.Enabled
	if journalGui.Enabled then renderJournal() end
end

if _G.SaveCache then
	_G.SaveCache.Updated.Event:Connect(function()
		if journalGui.Enabled then renderJournal() end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.J then toggleJournal() end
end)

-- Journal toggle button (mobile-friendly, always visible).
local journalToggle = Instance.new("ScreenGui")
journalToggle.Name = "QuestToggle"
journalToggle.ResetOnSpawn = false
journalToggle.Parent = playerGui

local qBtn = Instance.new("TextButton")
qBtn.AnchorPoint = Vector2.new(1, 0)
qBtn.Position = UDim2.new(1, -16, 0, 160)
qBtn.Size = UDim2.fromOffset(60, 60)
qBtn.Text = "QUEST"
qBtn.Font = Enum.Font.FredokaOne
qBtn.TextSize = 13
qBtn.TextColor3 = Color3.fromRGB(30, 30, 30)
qBtn.BackgroundColor3 = Color3.fromRGB(200, 170, 230)
qBtn.BorderSizePixel = 0
qBtn.Parent = journalToggle
Instance.new("UICorner", qBtn).CornerRadius = UDim.new(1, 0)
local qStroke = Instance.new("UIStroke")
qStroke.Color = Color3.fromRGB(80, 50, 100)
qStroke.Thickness = 2
qStroke.Parent = qBtn
local qHint = Instance.new("TextLabel")
qHint.AnchorPoint = Vector2.new(0.5, 0)
qHint.Position = UDim2.new(0.5, 0, 1, 2)
qHint.Size = UDim2.fromOffset(60, 16)
qHint.BackgroundTransparency = 1
qHint.Text = "[J]"
qHint.Font = Enum.Font.Gotham
qHint.TextSize = 11
qHint.TextColor3 = Color3.fromRGB(220, 220, 220)
qHint.Parent = qBtn

qBtn.MouseButton1Click:Connect(toggleJournal)
