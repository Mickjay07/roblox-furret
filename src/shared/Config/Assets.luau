--!strict
-- Every image the game uses, keyed by a stable logical name. Card and pack definitions refer
-- to these keys (their Artwork field); Logic/CardArt resolves a key to a Roblox content id.
-- This is the ONLY place that maps artwork to files and asset ids.
--
-- AssetId is the numeric Roblox IMAGE asset id (Asset Manager -> right-click the image ->
-- Copy ID). Edit the AssetId field of the entry itself; CardArt turns it into
-- "rbxassetid://<AssetId>". AssetId = 0 means "not uploaded to Roblox yet": the UI and the
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
}

local Images: { [string]: ImageAsset } = {
	["card.pack1.sandy"] = {
		Processed = "assets/processed/pack1/card_001_sandy.png",
		Source = "assets/source/Pack 1/sandy 001.png",
		Width = 683,
		Height = 1024,
		AssetId = 140074029273080,
	},
	["card.pack1.boba"] = {
		Processed = "assets/processed/pack1/card_002_boba.png",
		Source = "assets/source/Pack 1/boba 002.png",
		Width = 683,
		Height = 1024,
		AssetId = 84086042476135,
	},
	["card.pack1.sky"] = {
		Processed = "assets/processed/pack1/card_003_sky.png",
		Source = "assets/source/Pack 1/Sky 003.png",
		Width = 683,
		Height = 1024,
		AssetId = 123215287639771,
	},
	["card.pack1.kingston"] = {
		Processed = "assets/processed/pack1/card_004_kingston.png",
		Source = "assets/source/Pack 1/Kingston 004.png",
		Width = 683,
		Height = 1024,
		AssetId = 84803898229705,
	},
	["card.pack1.aurora"] = {
		Processed = "assets/processed/pack1/card_005_aurora.png",
		Source = "assets/source/Pack 1/Aurora 005.png",
		Width = 683,
		Height = 1024,
		AssetId = 79241250970768,
	},
	["card.pack1.frost"] = {
		Processed = "assets/processed/pack1/card_006_frost.png",
		Source = "assets/source/Pack 1/Frost 006.png",
		Width = 683,
		Height = 1024,
		AssetId = 128361345866040,
	},
	["pack.pack1.front"] = {
		Processed = "assets/processed/pack1/pack_front.png",
		Source = "assets/source/Pack 1/obal.png",
		Width = 683,
		Height = 1024,
		AssetId = 104453844983670,
	},
}

return table.freeze({
	Images = Images,
	-- Card art that is a complete printed card (frame, name, rarity, income) rather than a
	-- bare illustration. The UI shows it as-is instead of drawing its own frame around it.
	FullCardArt = true,
})
