-- Test entry point: `lune run tests/run` from the repo root.
-- Runs every *.spec.luau under tests/unit and tests/build.

local fs = require("@lune/fs")
local process = require("@lune/process")
local TestKit = require("./TestKit")

for _, dir in { "unit", "build" } do
	local full = `tests/{dir}`
	if fs.isDir(full) then
		local names = fs.readDir(full)
		table.sort(names)
		for _, name in names do
			if string.match(name, "%.spec%.luau$") then
				require(`./{dir}/{string.gsub(name, "%.luau$", "")}`)
			end
		end
	end
end

local results = TestKit.results()
for _, failure in results.failures do
	print(`FAIL {failure}`)
end
print(`\n{results.passed} passed, {results.failed} failed`)
process.exit(if results.failed > 0 then 1 else 0)
