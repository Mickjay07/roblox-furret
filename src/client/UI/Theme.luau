--!strict
-- Ferret Frenzy visual identity: deep forest-green panels, gold and warm-brown trim, cream
-- text with a dark outline, chunky rounded buttons. Every window, tile and button reads its
-- colours from here, so the whole interface stays consistent.

local Theme = {}

Theme.Font = Enum.Font.FredokaOne

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Theme.Colors = {
	-- Text
	Text = rgb(255, 249, 232), -- warm cream
	TextStroke = rgb(24, 30, 16),
	Muted = rgb(186, 206, 170),
	-- Forest-green surfaces (light -> deep)
	PanelHeader = rgb(44, 102, 62),
	Panel = rgb(30, 76, 47),
	PanelInset = rgb(19, 52, 33),
	PanelDeep = rgb(12, 36, 23),
	Border = rgb(10, 28, 17),
	-- Trim
	Gold = rgb(242, 194, 82),
	GoldLight = rgb(255, 229, 146),
	GoldDark = rgb(156, 104, 30),
	Brown = rgb(126, 82, 44),
	BrownDark = rgb(72, 44, 22),
	Leaf = rgb(96, 178, 86),
	-- Values
	Cash = rgb(134, 240, 96),
	Treats = rgb(247, 180, 88),
	Level = rgb(80, 206, 220),
	Danger = rgb(236, 76, 76),
	Shiny = rgb(170, 236, 255),
}

-- Button palettes: { fill, border }. Names are used throughout the controllers.
Theme.Buttons = {
	Green = { rgb(104, 204, 70), rgb(30, 92, 22) },
	Gold = { rgb(246, 196, 72), rgb(140, 88, 18) },
	Brown = { rgb(150, 100, 56), rgb(70, 42, 20) },
	Blue = { rgb(70, 160, 246), rgb(24, 72, 150) },
	Orange = { rgb(250, 160, 50), rgb(146, 78, 12) },
	Purple = { rgb(184, 104, 240), rgb(90, 34, 140) },
	Pink = { rgb(250, 104, 170), rgb(146, 30, 90) },
	Red = { rgb(232, 74, 80), rgb(122, 22, 30) },
	Gray = { rgb(112, 124, 108), rgb(50, 60, 48) },
}

Theme.NotificationColors = {
	info = rgb(80, 170, 246),
	success = rgb(110, 214, 74),
	warning = rgb(246, 176, 60),
	error = rgb(236, 76, 76),
}

Theme.Corner = UDim.new(0, 14)

return Theme
