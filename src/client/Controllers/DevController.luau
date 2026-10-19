--!strict
-- Studio-only developer panel (roadmap A1). It appears only when the server created the
-- DevCommand remote, which DevService does exclusively inside Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UI = script.Parent.Parent.UI
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Windows = require(UI.Windows)
local Net = require(script.Parent.Parent.Lib.Remotes)

local DevController = {}

local QUICK = {
	{ "+100K CASH", "cash 100000" },
	{ "+5 PACK 1", "packs pack1 5" },
	{ "ALL CARDS", "allcards" },
	{ "ACCRUE 1H", "accrue 3600" },
	{ "OFFLINE 3H", "offline 10800" },
	{ "STANDS", "stands" },
	{ "INCOME", "income" },
	{ "PLOTS", "plots" },
	{ "ROLL PACK 1", "roll pack1 5000" },
	{ "SAVE NOW", "save" },
	{ "GO HOME", "home" },
	{ "HELP", "help" },
}

function DevController:Start()
	if not RunService:IsStudio() then
		return
	end
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	if not folder:WaitForChild(Remotes.DevFunctions.DevCommand, 10) then
		return
	end

	local output: TextLabel
	local function run(line: string)
		local result = Net.invoke(Remotes.DevFunctions.DevCommand, line)
		output.Text = `> {line}\n{result.message or result.error or "?"}`
	end

	Windows.register("Dev", {
		Title = "Developer (Studio only)",
		Accent = "Pink",
		Size = Vector2.new(860, 560),
		Build = function(content: Frame)
			local input: TextBox = Create("TextBox", {
				Size = UDim2.new(1, -150, 0, 44),
				BackgroundColor3 = Theme.Colors.PanelInset,
				TextColor3 = Theme.Colors.Text,
				PlaceholderText = "command, e.g. cash 5000   (help for the list)",
				Text = "",
				Font = Enum.Font.Code,
				TextSize = 20,
				ClearTextOnFocus = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = content,
			}, { Components.corner(UDim.new(0, 10)), Create("UIPadding", { PaddingLeft = UDim.new(0, 10) }) })
			Components.button({
				Text = "RUN",
				Style = "Pink",
				Size = UDim2.fromOffset(136, 44),
				Position = UDim2.new(1, 0, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				Parent = content,
				OnClick = function()
					run(input.Text)
				end,
			})
			input.FocusLost:Connect(function(enterPressed)
				if enterPressed and input.Text ~= "" then
					run(input.Text)
				end
			end)
			local quick = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 104),
				Position = UDim2.fromOffset(0, 54),
				BackgroundTransparency = 1,
				Parent = content,
			}, {
				Create("UIGridLayout", {
					CellSize = UDim2.fromOffset(196, 46),
					CellPadding = UDim2.fromOffset(8, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			for i, entry in QUICK do
				Components.button({
					Text = entry[1],
					Style = "Purple",
					LayoutOrder = i,
					Parent = quick,
					OnClick = function()
						run(entry[2])
					end,
				})
			end
			local scroll = Create("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, -170),
				Position = UDim2.fromOffset(0, 170),
				BackgroundColor3 = Theme.Colors.PanelInset,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 8,
				Parent = content,
			}, { Components.corner(UDim.new(0, 10)) })
			output = Create("TextLabel", {
				Size = UDim2.new(1, -20, 0, 0),
				Position = UDim2.fromOffset(10, 8),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Font = Enum.Font.Code,
				TextSize = 18,
				TextColor3 = Theme.Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
				Text = "Developer commands run on the server, for your own data only.",
				Parent = scroll,
			})
			return nil
		end,
	})

	local gui = Create("ScreenGui", {
		Name = "DevButton",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	Components.button({
		Text = "DEV",
		Style = "Pink",
		Size = UDim2.fromOffset(80, 40),
		Position = UDim2.new(0, 16, 1, -16),
		AnchorPoint = Vector2.new(0, 1),
		Parent = gui,
		OnClick = function()
			Windows.toggle("Dev")
		end,
	})
end

return DevController
