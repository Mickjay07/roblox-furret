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
