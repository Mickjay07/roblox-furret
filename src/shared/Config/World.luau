--!strict
-- Layout of the shared game world (spec §18), in studs. Plain numbers only, so the layout
-- maths (Logic/PlotLayout) is unit-tested without Roblox. The server builds the world from
-- this at startup (server/World/WorldBuilder).
--
-- Axes: Y is up; the spawn plaza is at the origin; the plot avenue runs towards +Z.

return table.freeze({
	-- Walkable ground height.
	Floor = 0,

	Ground = table.freeze({ MinX = -130, MaxX = 130, MinZ = -110, MaxZ = 350 }),

	Plaza = table.freeze({ X = 0, Z = 0, Radius = 36 }),

	-- Stations around the plaza. Kind decides behaviour (client prompts); Reserved stations
	-- exist in the world but their system is not implemented yet.
	Stations = table.freeze({
		{ Id = "PackShop", Label = "PACK SHOP", X = 0, Z = -60, Color = Color3.fromRGB(96, 220, 64), Reserved = false },
		{
			Id = "Upgrades",
			Label = "UPGRADES",
			X = -60,
			Z = 0,
			Color = Color3.fromRGB(255, 166, 44),
			Reserved = false,
		},
		{ Id = "Grader", Label = "GRADER", X = 60, Z = 0, Color = Color3.fromRGB(176, 86, 255), Reserved = true },
		{
			Id = "Collect",
			Label = "COLLECT ALL",
			X = -44,
			Z = 48,
			Color = Color3.fromRGB(255, 205, 60),
			Reserved = false,
		},
	}),

	Plots = table.freeze({
		-- Set the experience's Max Players to this (or fewer) so every player gets a plot.
		Count = 8,
		-- Plot centre X for the left (-) and right (+) column; the avenue lies between them.
		ColumnX = 56,
		FirstRowZ = 96,
		RowSpacing = 70,
		-- Width along the avenue (Z) and depth away from it (X).
		Width = 56,
		Depth = 64,
	}),

	-- Stand positions in plot-local coordinates: U points from the back of the plot towards
	-- its entrance on the avenue, V runs along the avenue. 12 stands = base 4 + 8 upgrades.
	Stands = table.freeze({
		RowsU = table.freeze({ -16, 0 }),
		FirstV = -20,
		SpacingV = 8,
		PerRow = 6,
	}),

	-- Plot-local positions of other plot features.
	PlotFeatures = table.freeze({
		HomeU = 20,
		EntranceU = 30,
		-- Back strip kept free for future decorations / plot upgrades (spec §8).
		DecorationStripU = -28,
	}),
})
