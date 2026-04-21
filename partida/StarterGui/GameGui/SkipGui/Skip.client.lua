-- SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- CONSTANTS

-- VARIABLES
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Referenciando a nova UI que configuramos anteriormente
local SkipUI = playerGui:WaitForChild("NewUI"):WaitForChild("Skip")

local playerSettings = nil
local UIHandler = require(ReplicatedStorage.Modules.Client.UIHandler)

-- FUNCTIONS

-- INIT
repeat task.wait() until player:FindFirstChild('DataLoaded')
playerSettings = player:WaitForChild("Settings")

ReplicatedStorage.Events.SkipGui.OnClientEvent:Connect(function(visible, SecondArgument : {})

	if SecondArgument then
		if SecondArgument.Yes then
			-- Verifica se o texto existe antes de alterar para evitar erros na nova UI
			local voteText = SkipUI:FindFirstChild("PlayersVoteText", true)
			if voteText then
				voteText.Text = `{SecondArgument.Yes}/{math.ceil(#Players:GetPlayers()) }` 
			end
			UIHandler.PlaySound("Skip")
			return
		end

		if SecondArgument.Required then
			local voteText = SkipUI:FindFirstChild("PlayersVoteText", true)
			if voteText then
				voteText.Text = `{0}/{math.ceil(#Players:GetPlayers())}` 
			end
		end
	end

	if visible and playerSettings.AutoSkip.Value then
		return ReplicatedStorage.Functions.VoteForSkip:InvokeServer()
	end

	SkipUI.Visible = visible

	if visible == true then
		-- A animação agora ocorre na nova UI
		TweenService:Create(SkipUI, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Position = UDim2.new(0.786, 0, 0.34, 0)}):Play()

		if UserInputService.GamepadEnabled then
			local btnToSelect = SkipUI:IsA("GuiButton") and SkipUI or SkipUI:FindFirstChildWhichIsA("GuiButton", true)
			if btnToSelect then
				GuiService.SelectedObject = btnToSelect
			end
		end
	end

	if visible == true and Workspace.Info.SkipValue.Value == true then
		while (#Workspace.Mobs:GetChildren() > Workspace.Info.MobLimit.Value) and not playerSettings.AutoSkip.Value do
			task.wait(0.1)
		end

		local result = ReplicatedStorage.Functions.VoteForSkip:InvokeServer()

		if typeof(result) == "string" then
			-- Opcional: Lidar com o retorno de string
		else
			SkipUI.Visible = false
		end
	else
		SkipUI.Visible = visible
	end
end)