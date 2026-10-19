--!strict
-- Central home for all game-design data. Every tunable gameplay number lives in one of
-- these modules; code reads them through this table, e.g. Config.Economy.StartingCash.

return {
	Game = require(script.Game),
	Economy = require(script.Economy),
	Rarities = require(script.Rarities),
	Variants = require(script.Variants),
	Collections = require(script.Collections),
	Cards = require(script.Cards),
	Packs = require(script.Packs),
	Grading = require(script.Grading),
	Upgrades = require(script.Upgrades),
	Monetization = require(script.Monetization),
	Assets = require(script.Assets),
	World = require(script.World),
	Visuals = require(script.Visuals),
}
