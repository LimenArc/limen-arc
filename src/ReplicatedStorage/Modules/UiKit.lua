--!strict
-- Tiny shared widget kit used by every menu so the chrome looks uniform.

local UiKit = {}

-- Adds a square ✕ close button to the top-right of a frame. Calls onClose
-- when clicked, or, if onClose is nil, just hides the parent ScreenGui.
function UiKit.AddCloseButton(frame: GuiObject, onClose: (() -> ())?): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = "CloseButton"
	btn.AnchorPoint = Vector2.new(1, 0)
	btn.Position = UDim2.new(1, -8, 0, 8)
	btn.Size = UDim2.fromOffset(28, 28)
	btn.Text = "✕"
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.BackgroundColor3 = Color3.fromRGB(70, 40, 50)
	btn.TextColor3 = Color3.fromRGB(240, 230, 220)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.ZIndex = (frame.ZIndex or 1) + 5
	btn.Parent = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 90, 90)
	stroke.Thickness = 1
	stroke.Parent = btn

	btn.MouseButton1Click:Connect(function()
		if onClose then
			onClose()
		else
			-- Walk up to the ScreenGui and hide it.
			local gui: Instance? = frame
			while gui and not gui:IsA("ScreenGui") do
				gui = gui.Parent
			end
			if gui then (gui :: ScreenGui).Enabled = false end
		end
	end)

	return btn
end

return UiKit
