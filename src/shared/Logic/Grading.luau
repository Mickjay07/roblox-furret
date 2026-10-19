--!strict
-- Card grading rules: roll four sub-grades, combine into a 1-10 grade.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)
local WeightedRandom = require(script.Parent.Parent.Util.WeightedRandom)

export type SubGrades = { [string]: number }

local Grading = {}

local valueEntries: { WeightedRandom.Entry<number> } = {}
for value, weight in Config.Grading.SubGradeWeights do
	table.insert(valueEntries, { value = value, weight = weight })
end

function Grading.rollSubGrades(roll: (() -> number)?): SubGrades
	local out = {}
	for _, name in Config.Grading.SubGrades do
		out[name] = WeightedRandom.pick(valueEntries, roll)
	end
	return out
end

-- Average of the sub-grades (the "score"), e.g. 6.25.
function Grading.score(subGrades: SubGrades): number
	local total, count = 0, 0
	for _, name in Config.Grading.SubGrades do
		local value = subGrades[name]
		assert(type(value) == "number", `Grading: missing sub-grade {name}`)
		total += value
		count += 1
	end
	return total / count
end

function Grading.grade(subGrades: SubGrades): number
	return math.clamp(math.floor(Grading.score(subGrades) + 1e-9), 1, 10)
end

function Grading.label(grade: number): string
	return Config.Grading.Labels[grade] or "UNGRADED"
end

function Grading.cost(def: Types.CardDef): number
	local c = Config.Grading.Cost
	return math.floor(c.BaseCost + def.BaseSaleValue * c.SaleValueFactor)
end

return Grading
