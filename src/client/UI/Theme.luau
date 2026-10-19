--!strict
-- Visual language from the reference screenshots: chunky rounded white text with a dark
-- outline, saturated pill buttons with darker borders, dark rounded panels.

local Theme = {}

Theme.Font = Enum.Font.FredokaOne

Theme.Colors = {
	Text = Color3.fromRGB(255, 255, 255),
	TextStroke = Color3.fromRGB(20, 20, 26),
	Muted = Color3.fromRGB(170, 172, 186),
	Panel = Color3.fromRGB(34, 34, 42),
	PanelHeader = Color3.fromRGB(48, 48, 58),
	PanelInset = Color3.fromRGB(24, 24, 30),
	Border = Color3.fromRGB(12, 12, 16),
	Cash = Color3.fromRGB(128, 240, 92),
	Treats = Color3.fromRGB(245, 176, 84),
	Level = Color3.fromRGB(64, 200, 220),
}

-- Button palettes: { fill, border }
Theme.Buttons = {
	Green = { Color3.fromRGB(96, 220, 64), Color3.fromRGB(34, 112, 22) },
	Blue = { Color3.fromRGB(64, 156, 255), Color3.fromRGB(22, 74, 160) },
	Orange = { Color3.fromRGB(255, 166, 44), Color3.fromRGB(150, 82, 10) },
	Purple = { Color3.fromRGB(196, 96, 255), Color3.fromRGB(96, 30, 150) },
	Pink = { Color3.fromRGB(255, 96, 170), Color3.fromRGB(150, 30, 90) },
	Red = { Color3.fromRGB(240, 72, 84), Color3.fromRGB(130, 20, 30) },
	Gray = { Color3.fromRGB(120, 124, 140), Color3.fromRGB(56, 58, 70) },
}

Theme.NotificationColors = {
	info = Color3.fromRGB(64, 156, 255),
	success = Color3.fromRGB(96, 220, 64),
	warning = Color3.fromRGB(255, 166, 44),
	error = Color3.fromRGB(240, 72, 84),
}

Theme.Corner = UDim.new(0, 12)

return Theme
