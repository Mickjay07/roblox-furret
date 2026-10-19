--!strict
-- Every image the game uses, keyed by a stable logical name. Card and pack definitions refer
-- to these keys (their Artwork field); Logic/CardArt resolves a key to a Roblox content id.
-- This is the ONLY place that maps artwork to files and asset ids.
--
-- AssetId is the numeric Roblox IMAGE asset id (Asset Manager -> right-click the image ->
-- Copy ID), passed as the third argument of image(...) for that entry; CardArt turns it
-- into "rbxassetid://<AssetId>". AssetId = 0 means "not uploaded to Roblox yet": the UI and the
-- 3D stands then draw a placeholder automatically (and log why in Studio's Output).
-- See assets/README.md for the upload steps. Never invent asset ids.

export type ImageAsset = {
	-- Upload-ready copy (resized, alpha cleaned) produced by scripts/assets/process_card_art.py.
	Processed: string,
	-- The untouched original as supplied by the artist.
	Source: string,
	Width: number,
	Height: number,
	AssetId: number,
	-- Optional small copy (assets/processed/<set>/thumbs/, 256x384) for small UI tiles.
	-- 0 or nil = not uploaded: tiles use the full image (AssetId) instead.
	ThumbAssetId: number?,
}

local function image(processed: string, source: string, assetId: number): ImageAsset
	return {
		Processed = processed,
		Source = source,
		Width = 683,
		Height = 1024,
		AssetId = assetId,
	}
end

local Images: { [string]: ImageAsset } = {
	["card.pack1.sandy"] = image(
		"assets/processed/pack1/card_001_sandy.png",
		"assets/source/Pack 1/sandy 001.png",
		140074029273080
	),
	["card.pack1.boba"] = image(
		"assets/processed/pack1/card_002_boba.png",
		"assets/source/Pack 1/boba 002.png",
		84086042476135
	),
	["card.pack1.sky"] = image(
		"assets/processed/pack1/card_003_sky.png",
		"assets/source/Pack 1/Sky 003.png",
		123215287639771
	),
	["card.pack1.kingston"] = image(
		"assets/processed/pack1/card_004_kingston.png",
		"assets/source/Pack 1/Kingston 004.png",
		84803898229705
	),
	["card.pack1.aurora"] = image(
		"assets/processed/pack1/card_005_aurora.png",
		"assets/source/Pack 1/Aurora 005.png",
		79241250970768
	),
	["card.pack1.frost"] = image(
		"assets/processed/pack1/card_006_frost.png",
		"assets/source/Pack 1/Frost 006.png",
		128361345866040
	),
	["pack.pack1.front"] = image(
		"assets/processed/pack1/pack_front.png",
		"assets/source/Pack 1/obal.png",
		104453844983670
	),
	-- Shared back of every card (unrevealed cards in the pack opening). Uploaded to Roblox
	-- directly by the owner; there is no source file in the repository. Displayed at the
	-- card fronts' 2:3 shape.
	["card.back"] = image("", "", 129297477524368),
}

return table.freeze({
	Images = Images,
	-- Card art that is a complete printed card (frame, name, rarity, income) rather than a
	-- bare illustration. The UI shows it as-is instead of drawing its own frame around it.
	FullCardArt = true,
})
