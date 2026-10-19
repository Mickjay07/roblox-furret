--!strict
-- Every image the game uses, keyed by a stable logical name. Card and pack definitions refer
-- to these keys (their Artwork field); Logic/CardArt resolves a key to a Roblox content id.
-- This is the ONLY place that maps artwork to files and asset ids.
--
-- AssetId = 0 means "not uploaded to Roblox yet": the UI and the 3D stands then draw a
-- placeholder automatically. To enable an image, upload the Processed file (see
-- assets/README.md for the exact steps) and paste the numeric image asset id here.
-- Never invent asset ids.

export type ImageAsset = {
	-- Upload-ready copy (resized, alpha cleaned) produced by scripts/assets/process_card_art.py.
	Processed: string,
	-- The untouched original as supplied by the artist.
	Source: string,
	Width: number,
	Height: number,
	AssetId: number,
}

local function image(processed: string, source: string): ImageAsset
	return { Processed = processed, Source = source, Width = 683, Height = 1024, AssetId = 0 }
end

local Images: { [string]: ImageAsset } = {
	["card.pack1.sandy"] = image("assets/processed/pack1/card_001_sandy.png", "assets/source/Pack 1/sandy 001.png"),
	["card.pack1.boba"] = image("assets/processed/pack1/card_002_boba.png", "assets/source/Pack 1/boba 002.png"),
	["card.pack1.sky"] = image("assets/processed/pack1/card_003_sky.png", "assets/source/Pack 1/Sky 003.png"),
	["card.pack1.kingston"] = image(
		"assets/processed/pack1/card_004_kingston.png",
		"assets/source/Pack 1/Kingston 004.png"
	),
	["card.pack1.aurora"] = image("assets/processed/pack1/card_005_aurora.png", "assets/source/Pack 1/Aurora 005.png"),
	["card.pack1.frost"] = image("assets/processed/pack1/card_006_frost.png", "assets/source/Pack 1/Frost 006.png"),
	["pack.pack1.front"] = image("assets/processed/pack1/pack_front.png", "assets/source/Pack 1/obal.png"),
}

return table.freeze({
	Images = Images,
	-- Card art that is a complete printed card (frame, name, rarity, income) rather than a
	-- bare illustration. The UI shows it as-is instead of drawing its own frame around it.
	FullCardArt = true,
})
