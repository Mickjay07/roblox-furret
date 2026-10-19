--!strict
-- Preloads card and pack images through ContentProvider so they are ready before they are
-- shown (no pop-in on the first backpack view or card flip), and measures it.
--
--   * preloadAll(): once at startup, in the background - every uploaded image in
--     Config.Assets (card fronts, card back, pack fronts, thumbnails when uploaded).
--   * preload(ids, label): specific images, e.g. the cards of a pack being opened, started
--     while the pack animation plays.
-- Each content id is preloaded at most once per session. In Studio the Output shows how
-- long each image took ("[Art] preload ... 0.42s") - the evidence for any speed claim.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardArt = require(Shared.Logic.CardArt)

local ImagePreloader = {}

local IS_STUDIO = RunService:IsStudio()
local requested: { [string]: boolean } = {}
local loaded: { [string]: boolean } = {}

function ImagePreloader.isLoaded(contentId: string): boolean
	return loaded[contentId] == true
end

-- Preloads the ids not requested before. Returns immediately; the work runs in the
-- background. `label` names the batch in the Studio log.
function ImagePreloader.preload(contentIds: { string }, label: string)
	local batch = {}
	for _, id in contentIds do
		if not requested[id] then
			requested[id] = true
			table.insert(batch, id)
		end
	end
	if #batch == 0 then
		return
	end
	task.spawn(function()
		local started = os.clock()
		local failed = 0
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(batch, function(id: string, status: Enum.AssetFetchStatus)
				if status == Enum.AssetFetchStatus.Success then
					loaded[id] = true
					if IS_STUDIO then
						print(`[Art] preload {label}: {id} {string.format("%.2f", os.clock() - started)}s`)
					end
				else
					failed += 1
					-- Allow a later retry.
					requested[id] = nil
					warn(`[Art] preload {label}: {id} failed ({status.Name})`)
				end
			end)
		end)
		if not ok then
			warn(`[Art] preload {label} error: {err}`)
		elseif IS_STUDIO then
			print(
				`[Art] preload {label}: {#batch - failed}/{#batch} images in {string.format(
					"%.2f",
					os.clock() - started
				)}s`
			)
		end
	end)
end

function ImagePreloader.preloadAll()
	ImagePreloader.preload(CardArt.allContentIds(true), "startup")
end

return ImagePreloader
