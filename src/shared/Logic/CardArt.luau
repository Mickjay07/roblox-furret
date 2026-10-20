--!strict
-- Resolves card and pack artwork through Config.Assets (the single artwork mapping).
-- Returns nil when an image is unavailable (unknown key or not uploaded yet), so callers can
-- fall back to a placeholder.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)

local CardArt = {}

local DEFAULT_ASPECT = 2 / 3

-- Resolves an artwork key. Returns the content id (e.g. "rbxassetid://123") or nil plus a
-- human-readable reason, so diagnostics can say exactly why a placeholder is shown.
-- A raw "rbxassetid://<digits>" string is accepted as-is (spec §4: ArtworkAssetId).
function CardArt.resolve(key: string?): (string?, string)
	if type(key) ~= "string" or key == "" then
		return nil, "no artwork key"
	end
	if string.match(key, "^rbxassetid://%d+$") then
		return key, "raw content id"
	end
	local asset = Config.Assets.Images[key]
	if not asset then
		return nil, `unknown key (not in Config.Assets.Images)`
	end
	local id = asset.AssetId
	if type(id) ~= "number" then
		return nil, `AssetId is a {type(id)}, expected a number`
	end
	if id == 0 then
		return nil, "AssetId = 0 (not uploaded)"
	end
	if id < 0 or id % 1 ~= 0 then
		return nil, `AssetId {id} is not a positive integer`
	end
	return `rbxassetid://{id}`, `AssetId {id}`
end

-- Content id for an asset key, or nil when it can't be resolved (see CardArt.resolve).
function CardArt.image(key: string?): string?
	local contentId = CardArt.resolve(key)
	return contentId
end

-- Width / height of the artwork (2:3 card shape by default).
function CardArt.aspect(key: string?): number
	local asset = if type(key) == "string" then Config.Assets.Images[key] else nil
	if asset and asset.Width > 0 and asset.Height > 0 then
		return asset.Width / asset.Height
	end
	return DEFAULT_ASPECT
end

-- The shared card back (unrevealed cards), or nil when it isn't uploaded.
CardArt.BACK_KEY = "card.back"
function CardArt.back(): string?
	return CardArt.image(CardArt.BACK_KEY)
end

-- The card back for a pack's cards: its own (e.g. the Promo Ferret back) or the shared one.
function CardArt.backFor(pack: Types.PackDef?): string?
	local own = if pack and pack.CardBack then CardArt.image(pack.CardBack) else nil
	return own or CardArt.back()
end

-- Small copy for little UI tiles: the thumbnail when uploaded, else the full image.
function CardArt.thumbnail(key: string?): string?
	local asset = if type(key) == "string" then Config.Assets.Images[key] else nil
	local thumb = if asset then asset.ThumbAssetId else nil
	if type(thumb) == "number" and thumb > 0 and thumb % 1 == 0 then
		return `rbxassetid://{thumb}`
	end
	return CardArt.image(key)
end

-- Every uploaded image a client may need soon (card fronts, card back, pack fronts), for
-- ContentProvider preloading. `thumbnails` also adds uploaded thumbnails.
function CardArt.allContentIds(thumbnails: boolean?): { string }
	local ids = {}
	for key, asset in Config.Assets.Images do
		local id = CardArt.image(key)
		if id then
			table.insert(ids, id)
		end
		if thumbnails and type(asset.ThumbAssetId) == "number" and (asset.ThumbAssetId :: number) > 0 then
			table.insert(ids, `rbxassetid://{asset.ThumbAssetId}`)
		end
	end
	table.sort(ids)
	return ids
end

function CardArt.forCard(def: Types.CardDef): string?
	return CardArt.image(def.Artwork)
end

function CardArt.forPack(def: Types.PackDef): string?
	return CardArt.image(def.Artwork)
end

-- True when the key refers to a configured asset entry (uploaded or not) or a raw content id.
function CardArt.isKnownKey(key: string): boolean
	return key == "" or string.match(key, "^rbxassetid://%d+$") ~= nil or Config.Assets.Images[key] ~= nil
end

return CardArt
