--!strict
-- Builds the static game world (spec §18) when the server starts. Plots are built by
-- PlotService. Station behaviour lives on the client (prompts that open windows) and in the
-- existing validated remotes, so the world itself holds no gameplay state.

local World = script.Parent.Parent.World
local WorldBuilder = require(World.WorldBuilder)

local WorldService = {}

WorldService.Stations = {} :: { [string]: Model }

function WorldService:Init()
	-- Built in Init (synchronous, no yielding) so PlotService and players find it ready.
	WorldService.Stations = WorldBuilder.buildWorld()
end

return WorldService
