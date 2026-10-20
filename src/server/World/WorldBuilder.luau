--!strict
-- Builds the shared game world from Config.World (layout) and Config.Visuals (palette):
-- ground, spawn plaza with a landmark, paths, stations, a little decoration, lighting, and
-- the player plots with their physical display stands.
--
-- Hierarchy (gameplay objects are kept apart from decoration):
--   Workspace.World.Environment   ground, plaza, paths, decoration (no gameplay meaning)
--   Workspace.World.Stations      one Model per station (attribute Station = id)
--   Workspace.Plots.Plot_01 ...   plot models; stands are Plot_xx.Stands.Stand_yy
--
-- The world is generated at server start, so it appears when you press Play (Studio's edit
-- view shows only the template). Construction helpers are reusable for future areas.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PlotLayout = require(Shared.Logic.PlotLayout)

local WorldConfig = Config.World
local Palette = Config.Visuals.World
local FLOOR = WorldConfig.Floor

local WorldBuilder = {}

export type PartProps = {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	CanCollide: boolean?,
	Transparency: number?,
	CastShadow: boolean?,
	Parent: Instance,
}

-- Anchored part with sensible defaults.
function WorldBuilder.part(props: PartProps): Part
	local part = Instance.new("Part")
	part.Name = props.Name
	part.Anchored = true
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color
	part.Material = props.Material or Enum.Material.SmoothPlastic
	if props.Shape then
		part.Shape = props.Shape
	end
	part.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	part.Transparency = props.Transparency or 0
	part.CastShadow = if props.CastShadow == nil then true else props.CastShadow
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.Parent
	return part
end

function WorldBuilder.folder(name: string, parent: Instance): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- A readable sign: text on the front face of `part` (front = the part's LookVector).
function WorldBuilder.sign(part: BasePart, text: string, textColor: Color3?, background: Color3?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background or Palette.SignBackground
	label.BackgroundTransparency = if background then 0 else 0.05
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = textColor or Palette.SignText
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(20, 20, 26)
	stroke.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = label
	label.Parent = gui
	return label
end

-- CFrame on the floor at (x, z), lifted by `height`, facing towards (tx, tz).
local function facing(x: number, height: number, z: number, tx: number, tz: number): CFrame
	local position = Vector3.new(x, FLOOR + height, z)
	return CFrame.lookAt(position, Vector3.new(tx, FLOOR + height, tz))
end

-- Decoration -----------------------------------------------------------------

local function tree(x: number, z: number, scale: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Tree"
	WorldBuilder.part({
		Name = "Trunk",
		Size = Vector3.new(1.6, 6, 1.6) * scale,
		CFrame = CFrame.new(x, FLOOR + 3 * scale, z),
		Color = Palette.Trunk,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	for i, offset in { Vector3.new(0, 7.5, 0), Vector3.new(1.4, 6.2, 0.8), Vector3.new(-1.2, 6.4, -0.9) } do
		WorldBuilder.part({
			Name = "Leaves" .. i,
			Size = Vector3.one * (if i == 1 then 6 else 4.4) * scale,
			CFrame = CFrame.new(Vector3.new(x, FLOOR, z) + offset * scale),
			Color = if i == 1 then Palette.Leaves else Palette.GrassDark,
			Shape = Enum.PartType.Ball,
			Parent = model,
		})
	end
	model.Parent = parent
end

local function lamp(x: number, z: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Lamp"
	WorldBuilder.part({
		Name = "Pole",
		Size = Vector3.new(0.6, 9, 0.6),
		CFrame = CFrame.new(x, FLOOR + 4.5, z),
		Color = Palette.SignBackground,
		CastShadow = false,
		Parent = model,
	})
	local bulb = WorldBuilder.part({
		Name = "Bulb",
		Size = Vector3.one * 1.6,
		CFrame = CFrame.new(x, FLOOR + 9.4, z),
		Color = Palette.LampGlow,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Brightness = 0.8
	light.Range = 14
	light.Color = Palette.LampGlow
	light.Parent = bulb
	model.Parent = parent
end

-- Environment ----------------------------------------------------------------

local function buildGround(parent: Instance)
	local g = WorldConfig.Ground
	WorldBuilder.part({
		Name = "Ground",
		Size = Vector3.new(g.MaxX - g.MinX, 4, g.MaxZ - g.MinZ),
		CFrame = CFrame.new((g.MinX + g.MaxX) / 2, FLOOR - 2, (g.MinZ + g.MaxZ) / 2),
		Color = Palette.Grass,
		Material = Enum.Material.Grass,
		Parent = parent,
	})
	-- Avenue towards the plots.
	local plots = WorldConfig.Plots
	local lastZ = plots.FirstRowZ + (math.ceil(plots.Count / 2) - 1) * plots.RowSpacing + plots.Width / 2 + 10
	local startZ = WorldConfig.Plaza.Radius - 2
	WorldBuilder.part({
		Name = "Avenue",
		Size = Vector3.new(26, 0.2, lastZ - startZ),
		CFrame = CFrame.new(0, FLOOR + 0.1, (startZ + lastZ) / 2),
		Color = Palette.Path,
		Parent = parent,
	})
	for _, side in { -1, 1 } do
		WorldBuilder.part({
			Name = "AvenueEdge",
			Size = Vector3.new(1, 0.3, lastZ - startZ),
			CFrame = CFrame.new(13.5 * side, FLOOR + 0.15, (startZ + lastZ) / 2),
			Color = Palette.PathEdge,
			Parent = parent,
		})
	end
	-- Short paths from the plaza to each station.
	local plaza = WorldConfig.Plaza
	for _, station in WorldConfig.Stations do
		local dx, dz = station.X - plaza.X, station.Z - plaza.Z
		local length = math.sqrt(dx * dx + dz * dz)
		local midX, midZ = plaza.X + dx / 2, plaza.Z + dz / 2
		WorldBuilder.part({
			Name = "Path_" .. station.Id,
			Size = Vector3.new(10, 0.2, length),
			CFrame = CFrame.lookAt(
				Vector3.new(midX, FLOOR + 0.1, midZ),
				Vector3.new(station.X, FLOOR + 0.1, station.Z)
			),
			Color = Palette.Path,
			Parent = parent,
		})
	end
end

local function buildPlaza(parent: Instance)
	local plaza = WorldConfig.Plaza
	local center = Vector3.new(plaza.X, FLOOR, plaza.Z)
	-- Cylinders lie along X, so rotate them upright.
	local upright = CFrame.Angles(0, 0, math.rad(90))
	WorldBuilder.part({
		Name = "PlazaRing",
		Size = Vector3.new(0.4, plaza.Radius * 2 + 4, plaza.Radius * 2 + 4),
		CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * upright,
		Color = Palette.PlazaRing,
		Shape = Enum.PartType.Cylinder,
		Parent = parent,
	})
	WorldBuilder.part({
		Name = "PlazaFloor",
		Size = Vector3.new(0.5, plaza.Radius * 2, plaza.Radius * 2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.25, 0)) * upright,
		Color = Palette.Plaza,
		Material = Enum.Material.Pavement,
		Shape = Enum.PartType.Cylinder,
		Parent = parent,
	})
	-- Landmark: a fountain with a giant card monument.
	WorldBuilder.part({
		Name = "FountainBasin",
		Size = Vector3.new(2, 18, 18),
		CFrame = CFrame.new(center + Vector3.new(0, 1, 0)) * upright,
		Color = Palette.PlazaRing,
		Shape = Enum.PartType.Cylinder,
		Parent = parent,
	})
	WorldBuilder.part({
		Name = "FountainWater",
		Size = Vector3.new(0.4, 15, 15),
		CFrame = CFrame.new(center + Vector3.new(0, 1.9, 0)) * upright,
		Color = Palette.Water,
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = parent,
	})
	for _, angle in { 0, 180 } do
		local monument = WorldBuilder.part({
			Name = "Monument",
			Size = Vector3.new(9, 13, 0.8),
			CFrame = CFrame.new(center + Vector3.new(0, 9, 0)) * CFrame.Angles(0, math.rad(angle), 0),
			Color = Color3.fromRGB(70, 170, 255),
			Parent = parent,
		})
		WorldBuilder.sign(monument, "FERRET\nCARD\nTYCOON", Color3.fromRGB(255, 230, 120))
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.6, 8)
	spawn.CFrame = CFrame.new(center + Vector3.new(0, 0.6, 22))
	spawn.Color = Palette.PlazaRing
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = parent
end

local function buildStation(station: any, parent: Instance): Model
	local plaza = WorldConfig.Plaza
	local model = Instance.new("Model")
	model.Name = station.Id
	model:SetAttribute("Station", station.Id)
	model:SetAttribute("Reserved", station.Reserved)
	local base = facing(station.X, 0, station.Z, plaza.X, plaza.Z)
	WorldBuilder.part({
		Name = "Platform",
		Size = Vector3.new(18, 1, 14),
		CFrame = base * CFrame.new(0, 0.5, 0),
		Color = Palette.Plaza,
		Parent = model,
	})
	local counter = WorldBuilder.part({
		Name = "Counter",
		Size = Vector3.new(12, 3.5, 3),
		CFrame = base * CFrame.new(0, 2.75, -2),
		Color = station.Color,
		Parent = model,
	})
	for _, side in { -1, 1 } do
		WorldBuilder.part({
			Name = "Pillar",
			Size = Vector3.new(1, 9, 1),
			CFrame = base * CFrame.new(7.5 * side, 5.5, 4),
			Color = Palette.Wood,
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	WorldBuilder.part({
		Name = "Roof",
		Size = Vector3.new(18, 1.2, 12),
		CFrame = base * CFrame.new(0, 10.5, 1) * CFrame.Angles(math.rad(-8), 0, 0),
		Color = if station.Reserved then Palette.PlotFree else Palette.Roof,
		Parent = model,
	})
	local board = WorldBuilder.part({
		Name = "SignBoard",
		Size = Vector3.new(14, 3.2, 0.6),
		CFrame = base * CFrame.new(0, 12.6, -4.8),
		Color = Palette.SignBackground,
		Parent = model,
	})
	WorldBuilder.sign(board, if station.Reserved then station.Label .. " - SOON" else station.Label, station.Color)
	-- Interaction point (client-side ProximityPrompts attach here).
	local interact = WorldBuilder.part({
		Name = "Interact",
		Size = Vector3.new(4, 4, 4),
		CFrame = counter.CFrame * CFrame.new(0, 0, -3),
		Color = station.Color,
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})
	interact:SetAttribute("Station", station.Id)
	model.PrimaryPart = interact
	model.Parent = parent
	return model
end

local function buildDecor(parent: Instance)
	local plots = WorldConfig.Plots
	local rows = math.ceil(plots.Count / 2)
	-- Lamps along the avenue between plot rows.
	for row = 0, rows do
		local z = plots.FirstRowZ - plots.RowSpacing / 2 + row * plots.RowSpacing
		lamp(-16, z, parent)
		lamp(16, z, parent)
	end
	-- Trees framing the plaza and the outer edges.
	local spots = {
		{ -30, -40 },
		{ 30, -40 },
		{ -78, -30 },
		{ 78, -30 },
		{ -78, 34 },
		{ 78, 34 },
		{ -112, 120 },
		{ 112, 120 },
		{ -112, 220 },
		{ 112, 220 },
		{ -112, 320 },
		{ 112, 320 },
	}
	for i, spot in spots do
		tree(spot[1], spot[2], 0.9 + (i % 3) * 0.15, parent)
	end
end

local function applyLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(110, 100, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 150)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.25
		atmosphere.Color = Color3.fromRGB(255, 236, 214)
		atmosphere.Decay = Color3.fromRGB(150, 180, 255)
		atmosphere.Haze = 1
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChild("FerretColor") then
		local correction = Instance.new("ColorCorrectionEffect")
		correction.Name = "FerretColor"
		correction.Saturation = 0.12
		correction.Contrast = 0.05
		correction.Parent = Lighting
	end
end

-- Removes the Studio "Baseplate" template's floor and spawn so they don't overlap the world.
local function removeTemplate()
	for _, name in { "Baseplate", "SpawnLocation" } do
		local object = workspace:FindFirstChild(name)
		if object and object:IsA("BasePart") then
			object:Destroy()
		end
	end
end

-- Builds the static world. Returns the station models by id.
function WorldBuilder.buildWorld(): { [string]: Model }
	removeTemplate()
	local world = WorldBuilder.folder("World", workspace)
	local environment = WorldBuilder.folder("Environment", world)
	local stationsFolder = WorldBuilder.folder("Stations", world)
	buildGround(environment)
	buildPlaza(environment)
	local decor = WorldBuilder.folder("Decoration", environment)
	buildDecor(decor)
	local stations: { [string]: Model } = {}
	for _, station in WorldConfig.Stations do
		stations[station.Id] = buildStation(station, stationsFolder)
	end
	applyLighting()
	return stations
end

-- Plots ------------------------------------------------------------------------

export type PlotRefs = {
	Model: Model,
	OwnerLabel: TextLabel,
	Floor: BasePart,
	Home: BasePart,
	Stands: { [number]: Model },
}

local function plotCFrame(plot: PlotLayout.Plot, u: number, height: number, v: number): CFrame
	local x, z = PlotLayout.toWorld(plot, u, v)
	-- Face the entrance (towards the avenue).
	return facing(x, height, z, x + plot.Facing, z)
end

local function buildStand(plot: PlotLayout.Plot, slot: number, parent: Instance): Model
	local u, v = PlotLayout.standLocal(slot)
	local model = Instance.new("Model")
	model.Name = string.format("Stand_%02d", slot)
	model:SetAttribute("PlotIndex", plot.Index)
	model:SetAttribute("Slot", slot)
	local upright = CFrame.Angles(0, 0, math.rad(90))
	-- Wooden body with a wider foot, a gold rim and a felt top (PlotService colours the top
	-- for locked / unlocked and shows the glow ring when a card is on display).
	local base = WorldBuilder.part({
		Name = "Base",
		Size = Vector3.new(2.4, 3.4, 3.4),
		CFrame = plotCFrame(plot, u, 1.2 + 0.3, v) * upright,
		Color = Palette.PedestalBase,
		Material = Enum.Material.Wood,
		Shape = Enum.PartType.Cylinder,
		Parent = model,
	})
	WorldBuilder.part({
		Name = "Foot",
		Size = Vector3.new(0.5, 4.2, 4.2),
		CFrame = plotCFrame(plot, u, 0.55, v) * upright,
		Color = Palette.PedestalBase:Lerp(Color3.new(0, 0, 0), 0.25),
		Material = Enum.Material.Wood,
		Shape = Enum.PartType.Cylinder,
		Parent = model,
	})
	WorldBuilder.part({
		Name = "Rim",
		Size = Vector3.new(0.3, 4.5, 4.5),
		CFrame = plotCFrame(plot, u, 2.72, v) * upright,
		Color = Palette.PedestalRim,
		Material = Enum.Material.Metal,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = model,
	})
	local top = WorldBuilder.part({
		Name = "Top",
		Size = Vector3.new(0.4, 4.1, 4.1),
		CFrame = plotCFrame(plot, u, 2.95, v) * upright,
		Color = Palette.PedestalLocked,
		Material = Enum.Material.Fabric,
		Shape = Enum.PartType.Cylinder,
		Parent = model,
	})
	local glow = WorldBuilder.part({
		Name = "Glow",
		-- Just under the rim and wider than it: shows as a glowing ring around the edge
		-- without covering the felt top.
		Size = Vector3.new(0.15, 4.8, 4.8),
		CFrame = plotCFrame(plot, u, 2.5, v) * upright,
		Color = Palette.PedestalGlow,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Cylinder,
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})
	glow.CanQuery = false
	glow.CanTouch = false
	local label = WorldBuilder.part({
		Name = "Label",
		Size = Vector3.new(1.5, 0.75, 0.1),
		CFrame = plotCFrame(plot, u, 1.5, v) * CFrame.new(0, 0, -1.76),
		Color = Palette.StandPlate,
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})
	WorldBuilder.sign(label, `#{slot}`, Palette.StandPlateText, Palette.StandPlate)
	-- Invisible anchor for the floating illustration and effects (client-side).
	local anchor = WorldBuilder.part({
		Name = "Anchor",
		Size = Vector3.one,
		CFrame = plotCFrame(plot, u, 3.2, v),
		Color = Color3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})
	anchor.CanQuery = false
	anchor.CanTouch = false
	model.PrimaryPart = base
	model:SetAttribute("Unlocked", false)
	model.Parent = parent
	local _ = top
	return model
end

function WorldBuilder.buildPlot(index: number, parent: Instance): PlotRefs
	local plot = PlotLayout.plot(index)
	local features = WorldConfig.PlotFeatures
	local model = Instance.new("Model")
	model.Name = string.format("Plot_%02d", index)
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)

	local floor = WorldBuilder.part({
		Name = "Floor",
		Size = Vector3.new(plot.Depth, 0.6, plot.Width),
		CFrame = CFrame.new(plot.CenterX, FLOOR + 0.3, plot.CenterZ),
		Color = Palette.PlotFree,
		Material = Enum.Material.Grass,
		Parent = model,
	})
	-- Low border with a gap for the entrance on the avenue side.
	local halfDepth, halfWidth = plot.Depth / 2, plot.Width / 2
	local borders = {
		{ u = -halfDepth, v = 0, sizeU = 1, sizeV = plot.Width },
		{ u = 0, v = -halfWidth, sizeU = plot.Depth, sizeV = 1 },
		{ u = 0, v = halfWidth, sizeU = plot.Depth, sizeV = 1 },
		{ u = halfDepth, v = -(halfWidth + 6) / 2, sizeU = 1, sizeV = halfWidth - 6 },
		{ u = halfDepth, v = (halfWidth + 6) / 2, sizeU = 1, sizeV = halfWidth - 6 },
	}
	for i, border in borders do
		local x, z = PlotLayout.toWorld(plot, border.u, border.v)
		WorldBuilder.part({
			Name = "Border" .. i,
			Size = Vector3.new(border.sizeU, 1.4, border.sizeV),
			CFrame = CFrame.new(x, FLOOR + 0.7, z),
			Color = Palette.PlotBorder,
			Parent = model,
		})
	end
	-- Entrance arch with the owner sign (readable from the avenue and from inside).
	for _, side in { -1, 1 } do
		WorldBuilder.part({
			Name = "ArchPost",
			Size = Vector3.new(1.2, 10, 1.2),
			CFrame = plotCFrame(plot, features.EntranceU + 2, 5, 6.5 * side),
			Color = Palette.Wood,
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	local signFront = WorldBuilder.part({
		Name = "OwnerSign",
		Size = Vector3.new(14, 3, 0.6),
		CFrame = plotCFrame(plot, features.EntranceU + 2, 10.5, 0),
		Color = Palette.SignBackground,
		Parent = model,
	})
	local ownerLabel = WorldBuilder.sign(signFront, "FREE PLOT")
	local signBack = WorldBuilder.part({
		Name = "OwnerSignBack",
		Size = Vector3.new(14, 3, 0.6),
		CFrame = plotCFrame(plot, features.EntranceU + 2, 10.5, 0)
			* CFrame.new(0, 0, 0.6)
			* CFrame.Angles(0, math.pi, 0),
		Color = Palette.SignBackground,
		Parent = model,
	})
	local backLabel = WorldBuilder.sign(signBack, "FREE PLOT")
	ownerLabel:SetAttribute("Mirror", true)
	ownerLabel:GetPropertyChangedSignal("Text"):Connect(function()
		backLabel.Text = ownerLabel.Text
	end)

	local home = WorldBuilder.part({
		Name = "Home",
		Size = Vector3.new(4, 1, 4),
		CFrame = plotCFrame(plot, features.HomeU, 0.6, 0) * CFrame.Angles(0, math.pi, 0),
		Color = Palette.Path,
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})

	local standsFolder = Instance.new("Folder")
	standsFolder.Name = "Stands"
	standsFolder.Parent = model
	local stands: { [number]: Model } = {}
	for slot = 1, PlotLayout.maxStands() do
		stands[slot] = buildStand(plot, slot, standsFolder)
	end

	model.PrimaryPart = floor
	model.Parent = parent
	return { Model = model, OwnerLabel = ownerLabel, Floor = floor, Home = home, Stands = stands }
end

return WorldBuilder
