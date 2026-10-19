--!strict
-- Card grading. A grade roll scores four sub-grades (1-10); the card's grade is the floor of
-- their average. The grade multiplies the card's income and sale value.

return table.freeze({
	SubGrades = table.freeze({ "Corners", "Centering", "Surface", "Edges" }),

	-- Relative weight of each sub-grade value 1..10 when rolled.
	SubGradeWeights = table.freeze({ 2, 4, 6, 10, 16, 20, 18, 12, 8, 4 }),

	Labels = table.freeze({
		"POOR",
		"FAIR",
		"GOOD",
		"GOOD",
		"VERY GOOD",
		"VERY GOOD",
		"EXCELLENT",
		"NEAR MINT",
		"MINT",
		"GEM MINT",
	}),

	-- Income / sale multiplier by grade 1..10. Ungraded cards use 1.
	Multipliers = table.freeze({ 0.8, 0.85, 0.9, 0.95, 1, 1.1, 1.2, 1.5, 2, 3 }),

	-- Cost of one grading roll = BaseCost + card BaseSaleValue * SaleValueFactor (Cash).
	Cost = table.freeze({
		Currency = "Cash",
		BaseCost = 50,
		SaleValueFactor = 0.5,
	}),
})
