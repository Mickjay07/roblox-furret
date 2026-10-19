local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local ProfileSchema = Loader.require("src/shared/Data/ProfileSchema")
local Inventory = Loader.require("src/shared/Logic/Inventory")
local Display = Loader.require("src/shared/Logic/Display")
local IncomeLedger = Loader.require("src/shared/Logic/IncomeLedger")
local PlotAllocator = Loader.require("src/shared/Logic/PlotAllocator")
local PlotLayout = Loader.require("src/shared/Logic/PlotLayout")
local PlotView = Loader.require("src/shared/Logic/PlotView")
local SessionStore = Loader.require("src/server/Lib/SessionStore")
local MockDataStore = Loader.require("src/server/Lib/MockDataStore")

describe("PlotAllocator", function()
	it("assigns the lowest free plot automatically and keeps ownership unique", function()
		local plots = PlotAllocator.new(3)
		expect(plots:assign(101)).toBe(1)
		expect(plots:assign(202)).toBe(2)
		expect(plots:assign(101)).toBe(1) -- idempotent for the same player
		expect(plots:ownerOf(1)).toBe(101)
		expect(plots:isOwner(202, 1)).toBe(false)
		expect(plots:isOwner(202, 2)).toBe(true)
		expect(plots:freeCount()).toBe(1)
	end)

	it("releases a plot when the player leaves and reuses it", function()
		local plots = PlotAllocator.new(2)
		plots:assign(1)
		plots:assign(2)
		expect(plots:release(1)).toBe(1)
		expect(plots:ownerOf(1)).toBeNil()
		expect(plots:plotOf(1)).toBeNil()
		expect(plots:release(1)).toBeNil()
		expect(plots:assign(3)).toBe(1)
	end)

	it("returns nil when every plot is taken, without disturbing owners", function()
		local plots = PlotAllocator.new(2)
		plots:assign(1)
		plots:assign(2)
		expect(plots:assign(3)).toBeNil()
		expect(plots:ownerOf(1)).toBe(1)
		expect(plots:ownerOf(2)).toBe(2)
		expect(plots:freeCount()).toBe(0)
	end)

	it("never lets a non-owner pass the ownership check", function()
		local plots = PlotAllocator.new(4)
		plots:assign(10)
		for index = 1, 4 do
			expect(plots:isOwner(99, index)).toBe(false)
		end
		expect(plots:isOwner(10, 2)).toBe(false) -- unowned plot
	end)
end)

describe("PlotLayout", function()
	it("has enough physical stands for every unlockable display slot", function()
		expect(PlotLayout.maxStands() <= PlotLayout.standCapacity()).toBe(true)
		expect(PlotLayout.maxStands()).toBe(12)
	end)

	it("places plots without overlap, clear of the avenue and the plaza", function()
		local boxes = {}
		for i = 1, PlotLayout.count() do
			local minX, maxX, minZ, maxZ = PlotLayout.bounds(i)
			expect(maxX <= -20 or minX >= 20).toBe(true) -- avenue x in (-20, 20) stays free
			expect(minZ > Config.World.Plaza.Radius).toBe(true)
			for _, other in boxes do
				local overlap = minX < other[2] and maxX > other[1] and minZ < other[4] and maxZ > other[3]
				expect(overlap).toBe(false)
			end
			table.insert(boxes, { minX, maxX, minZ, maxZ })
		end
	end)

	it("keeps every stand inside its plot, at a unique position, with entrances facing the avenue", function()
		for i = 1, PlotLayout.count() do
			local plot = PlotLayout.plot(i)
			local minX, maxX, minZ, maxZ = PlotLayout.bounds(i)
			local seen = {}
			for slot = 1, PlotLayout.maxStands() do
				local x, z = PlotLayout.stand(i, slot)
				expect(x > minX and x < maxX and z > minZ and z < maxZ).toBe(true)
				local key = `{x},{z}`
				expect(seen[key]).toBeNil()
				seen[key] = true
			end
			local hx = PlotLayout.home(i)
			expect(math.abs(hx) < math.abs(plot.CenterX)).toBe(true) -- home is on the avenue side
		end
	end)
end)

describe("PlotView", function()
	local function player()
		local data = ProfileSchema.defaults()
		local sandy = Inventory.add(data, 1, "pack1_sandy", "Normal", 0)
		local boba = Inventory.add(data, 1, "pack1_boba", "Gold", 0)
		data.Display["1"] = sandy
		data.Display["3"] = boba
		return data, sandy, boba
	end

	it("shows the assigned card on each unlocked stand and locks the rest", function()
		local data = player()
		local states = PlotView.standStates(data, PlotLayout.maxStands())
		expect(#states).toBe(12)
		expect(states[1].CardId).toBe("pack1_sandy")
		expect(states[3].CardId).toBe("pack1_boba")
		expect(states[3].Variant).toBe("Gold")
		expect(states[2].CardId).toBeNil()
		expect(states[4].Unlocked).toBe(true)
		expect(states[5].Unlocked).toBe(false)
	end)

	it("updates when a card is replaced or removed (stand cleanup)", function()
		local data, sandy, boba = player()
		Display.place(data, boba, 1) -- replace Sandy with Boba on stand 1
		local states = PlotView.standStates(data, 12)
		expect(states[1].CardId).toBe("pack1_boba")
		expect(states[3].CardId).toBeNil() -- Boba moved, stand 3 cleared
		Display.remove(data, boba)
		expect(PlotView.standStates(data, 12)[1].CardId).toBeNil()
		Inventory.remove(data, sandy)
		for _, state in PlotView.standStates(data, 12) do
			expect(state.CardId).toBeNil()
		end
	end)

	it("never shows one card instance on two stands", function()
		local data, sandy = player()
		data.Display["2"] = sandy -- corrupted duplicate
		Display.sanitize(data)
		local count = 0
		for _, state in PlotView.standStates(data, 12) do
			if state.CardId == "pack1_sandy" then
				count += 1
			end
		end
		expect(count).toBe(1)
	end)

	it("clears every stand for an unowned plot", function()
		for _, state in PlotView.empty(12) do
			expect(state.Unlocked).toBe(false)
			expect(state.CardId).toBeNil()
		end
	end)

	it("keeps stand earnings when the displayed card changes", function()
		local data, _, boba = player()
		IncomeLedger.accrue(data, 10)
		local before = IncomeLedger.pending(data, "1")
		Display.place(data, boba, 1)
		expect(IncomeLedger.pending(data, "1")).toBe(before)
		expect(IncomeLedger.collect(data, "1")).toBe(math.floor(before))
	end)

	it("restores the same arrangement and earnings after saving and rejoining", function()
		local store = MockDataStore.new()
		local env = { now = 1000 }
		local function server(jobId)
			return SessionStore.new({
				store = store,
				jobId = jobId,
				settings = Config.Game.Data,
				defaults = ProfileSchema.defaults,
				migrate = function(raw)
					return ProfileSchema.migrate(raw)
				end,
				clock = function()
					return env.now
				end,
				wait = function() end,
			})
		end
		local a = server("A")
		local profile = a:load("Player_1")
		local sandy = Inventory.add(profile.Data, 1, "pack1_sandy", "Normal", 0)
		profile.Data.Display["2"] = sandy
		IncomeLedger.accrue(profile.Data, 5)
		local expectedStates = PlotView.standStates(profile.Data, 12)
		a:release(profile)

		local rejoined = server("B"):load("Player_1")
		expect(PlotView.standStates(rejoined.Data, 12)).toEqual(expectedStates)
		expect(IncomeLedger.pending(rejoined.Data, "2")).toBe(350)
	end)
end)
