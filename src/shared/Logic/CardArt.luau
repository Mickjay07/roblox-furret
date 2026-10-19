--!strict
-- Resolves card and pack artwork through Config.Assets (the single artwork mapping).
-- Returns nil when an image is unavailable (unknown key or not uploaded yet), so callers can
-- fall back to a placeholder.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)

local CardArt = {}

local DEFAULT_ASPECT = 2 / 3

-- Content id for an asset key, e.g. "rbxassetid://123", or nil.
-- A raw "rbxassetid://<digits>" string is accepted as-is (spec §4: ArtworkAssetId).
function CardArt.image(key: string?): string?
	if type(key) ~= "string" or key == "" then
		return nil
	end
	if string.match(key, "^rbxassetid://%d+$") then
		return key
	end
	local asset = Config.Assets.Images[key]
	if not asset or type(asset.AssetId) ~= "number" or asset.AssetId <= 0 or asset.AssetId % 1 ~= 0 then
		return nil
	end
	return `rbxassetid://{asset.AssetId}`
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
