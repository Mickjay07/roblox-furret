--!strict
-- Plot and stand geometry derived from Config.World. Pure maths (no Roblox types) so it can be
-- tested: positions are returned as plain X/Z numbers on the world floor.
local Config = require(script.Parent.Parent.Config)

export type Plot = {
	Index: number,
	CenterX: number,
	CenterZ: number,
	-- +1: entrance faces +X (left column); -1: entrance faces -X (right column).
	Facing: number,
	Width: number,
	Depth: number,
}

local PlotLayout = {}

local plots = Config.World.Plots
local stands = Config.World.Stands

function PlotLayout.count(): number
	return plots.Count
end

-- Highest number of stands any player can unlock (base + every DisplaySlots upgrade).
function PlotLayout.maxStands(): number
	local upgrade = Config.Upgrades.ById.DisplaySlots
	local extra = if upgrade then upgrade.MaxLevel * upgrade.PerLevel else 0
	return Config.Game.Display.BaseSlots + math.floor(extra)
end

function PlotLayout.standCapacity(): number
	return #stands.RowsU * stands.PerRow
end

-- Plots alternate left/right, nearest to the plaza first: 1 = left row 1, 2 = right row 1, ...
function PlotLayout.plot(index: number): Plot
	assert(index >= 1 and index <= plots.Count and index % 1 == 0, `PlotLayout: invalid plot {index}`)
	local row = (index - 1) // 2
	local left = (index - 1) % 2 == 0
	return {
		Index = index,
		CenterX = if left then -plots.ColumnX else plots.ColumnX,
		CenterZ = plots.FirstRowZ + row * plots.RowSpacing,
		Facing = if left then 1 else -1,
		Width = plots.Width,
		Depth = plots.Depth,
	}
end

-- Plot-local (U towards the entrance, V along the avenue) to world X/Z.
function PlotLayout.toWorld(plot: Plot, u: number, v: number): (number, number)
	return plot.CenterX + u * plot.Facing, plot.CenterZ + v * plot.Facing
end

function PlotLayout.standLocal(slot: number): (number, number)
	assert(slot >= 1 and slot <= PlotLayout.standCapacity() and slot % 1 == 0, `PlotLayout: invalid stand {slot}`)
	local row = (slot - 1) // stands.PerRow + 1
	local column = (slot - 1) % stands.PerRow
	return stands.RowsU[row], stands.FirstV + column * stands.SpacingV
end

function PlotLayout.stand(index: number, slot: number): (number, number)
	local u, v = PlotLayout.standLocal(slot)
	return PlotLayout.toWorld(PlotLayout.plot(index), u, v)
end

function PlotLayout.home(index: number): (number, number)
	return PlotLayout.toWorld(PlotLayout.plot(index), Config.World.PlotFeatures.HomeU, 0)
end

-- Axis-aligned bounds of a plot on the floor.
function PlotLayout.bounds(index: number): (number, number, number, number)
	local plot = PlotLayout.plot(index)
	return plot.CenterX - plot.Depth / 2,
		plot.CenterX + plot.Depth / 2,
		plot.CenterZ - plot.Width / 2,
		plot.CenterZ + plot.Width / 2
end

return PlotLayout
