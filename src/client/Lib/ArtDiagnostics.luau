--!strict
-- Makes artwork problems visible in the Output window instead of failing silently:
--   * report():   once (Studio only) - every Config.Assets entry with its key, AssetId and
--                 the final content id, or why it falls back to a placeholder.
--   * fallback(): once per key - a configured artwork key was drawn as a placeholder.
--   * watch():    once per content id - preloads an assigned image and warns when Roblox
--                 cannot load it (for example a decal id pasted instead of the image id,
--                 an image still in moderation, or one the game's owner can't use).

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CardArt = require(Shared.Logic.CardArt)

local ArtDiagnostics = {}

local IS_STUDIO = RunService:IsStudio()
local reported = false
local fallbacks: { [string]: boolean } = {}
local watched: { [string]: boolean } = {}

function ArtDiagnostics.report()
	if reported or not IS_STUDIO then
		return
	end
	reported = true
	local keys = {}
	for key in Config.Assets.Images do
		table.insert(keys, key)
	end
	table.sort(keys)
	print(`[Art] Config.Assets has {#keys} images:`)
	for _, key in keys do
		local contentId, reason = CardArt.resolve(key)
		print(`[Art]   {key}: {reason} -> {contentId or "placeholder"}`)
	end
end

-- Call where a placeholder is drawn instead of artwork. Cards without an artwork key are
-- expected to use the placeholder and are not reported.
function ArtDiagnostics.fallback(where: string, key: string?)
	if type(key) ~= "string" or key == "" or fallbacks[key] then
		return
	end
	fallbacks[key] = true
	local _, reason = CardArt.resolve(key)
	warn(`[Art] {where}: showing a placeholder for "{key}" because {reason}`)
end

-- Call after assigning contentId to an Image property.
function ArtDiagnostics.watch(where: string, key: string?, contentId: string)
	if watched[contentId] then
		return
	end
	watched[contentId] = true
	task.spawn(function()
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync({ contentId }, function(_: string, status: Enum.AssetFetchStatus)
				if status == Enum.AssetFetchStatus.Success then
					if IS_STUDIO then
						print(`[Art] loaded {tostring(key)} -> {contentId}`)
					end
				else
					warn(
						`[Art] {where}: {contentId} ({tostring(key)}) failed to load: {status.Name}. `
							.. "Check it is the IMAGE id (not a decal id) and that the image passed moderation."
					)
				end
			end)
		end)
		if not ok then
			warn(`[Art] {where}: could not preload {contentId} ({tostring(key)}): {err}`)
		end
	end)
end

return ArtDiagnostics
