--!strict
-- Opening owned packs from the pack inventory (Backpack > PACKS) and reading the Robux
-- prices the server published. Shared by the Backpack, Pack Shop and Premium Shop windows.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Entitlements = require(Shared.Logic.Entitlements)

local PackReveal = require(script.Parent.Parent.UI.PackReveal)
local Request = require(script.Parent.Request)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local PackOpening = {}

-- One pack opening at a time: set from the OPEN click until the reveal is closed.
local opening = false

function PackOpening.isBusy(): boolean
	return opening or PackReveal.isOpen()
end

-- Opens `packs` owned packs together (1, or 3 / 6 with Multi Opening). The server checks the
-- unlock and the pack count, consumes the packs and grants the cards before replying; the
-- request id makes a repeated request (double click, retry) return the same result
-- instead of opening more packs. The reveal is purely visual.
function PackOpening.open(pack: Types.PackDef, packs: number)
	if PackOpening.isBusy() then
		return
	end
	local data = DataController:Get()
	if not data or (data.Packs[pack.Id] or 0) < packs or not Entitlements.canUseMode(data, packs) then
		return
	end
	opening = true
	local requestId = HttpService:GenerateGUID(false)
	local result = Request(Remotes.Functions.OpenPack, pack.Id, requestId, packs)
	if not result.ok or type(result.cards) ~= "table" then
		opening = false
		return
	end
	PackReveal.play(pack, result.cards, result.packs, result.cardsPerPack, function()
		opening = false
	end)
end

-- Sale state and Robux price published by the server after reading GetProductInfo
-- (unavailable / nil until then, or when the item is not for sale or could not be read).
function PackOpening.productState(key: string): (boolean, number?)
	local folder = ReplicatedStorage:FindFirstChild("ProductInfo")
	if not folder then
		return false, nil
	end
	local price = folder:GetAttribute(`{key}_Price`)
	return folder:GetAttribute(`{key}_Available`) == true, if type(price) == "number" then price else nil
end

-- Calls `callback` whenever published prices / availability change.
function PackOpening.onProductInfo(callback: () -> ())
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("ProductInfo", 30)
		if folder then
			folder.AttributeChanged:Connect(callback)
			callback()
		end
	end)
end

return PackOpening
