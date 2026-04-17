script.Parent.ClansFrame.Visible = false
require(script.Invites)
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UIHandler = require(ReplicatedStorage.Modules.Client.UIHandler)
local ClanRemotes = ReplicatedStorage.Remotes.Clans
local UpdateVariable = ClanRemotes.UpdateVariable
local blockOpen = true
local ClansFrame = script.Parent.ClansFrame
local ID = 'rbxassetid://1842036358'
local Bindables = ReplicatedStorage.Bindables
local LoadNewMusic = Bindables.LoadMusic
local CategorySwitcher = require(script.CategorySwitcher)
local PromptModule = require(script.PromptModule)
local ClanDataLoading = require(script.ClanDataLoading)
local TriggerGuide = require(script.Parent.Guide.TriggerGuide)
local ContentProvider = game:GetService("ContentProvider")

task.spawn(function()
	for i,v in ClansFrame.Parent.Guide:GetDescendants() do
		local preload = {}
		
		if v:IsA('ImageLabel') then
			table.insert(preload, v.Image)
		end
		
		ContentProvider:PreloadAsync(preload)
	end
end)

PromptModule.enablePrompt('Loading')

TweenService:Create(ClansFrame.PatternPreview, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0), {Position = UDim2.fromScale(0,1)}):Play()

local CurrentClan = Players.LocalPlayer.ClanData.CurrentClan

ClansFrame:GetPropertyChangedSignal('Visible'):Connect(function()
	if blockOpen then
		_G.CloseAll()
		return
	end
	
	if ClansFrame.Visible then
		-- hide all UI
		UIHandler.DisableAllButtons()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		LoadNewMusic:Fire(ID)
		--_G.CloseAll()
	else
		UIHandler.EnableAllButtons()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
		LoadNewMusic:Fire() -- lobby music defualt		
	end
end)

local waitUntilLoad = Instance.new('BindableEvent')
local conn = nil
local CloseButton = ClansFrame.CloseButton

task.spawn(function()
	waitUntilLoad.Event:Wait()
	waitUntilLoad:Destroy()
	conn:Disconnect()
	conn = nil
	--repeat task.wait() until _G.CloseAllEnabled -- remove this later -- REMOVE THIS LATERRRR VERY IMPORTANT!!
	-- SeenClanSplash
	
	blockOpen = false
	
	--script.Parent.ClansFrame.Visible = true
	--_G.CloseAll('ClansFrame') -- REMOVE THIS LATER - ITS ALSO VERY IMPORTANT TO REMOVE THIS!!
	
	-- Clans has loaded	
	CloseButton.Activated:Connect(function()
		_G.CloseAll()
	end)
	
	local function check()
		-- Check if we are inside a clan
		if CurrentClan.Value ~= 'None' then
			print('We are in a clan')
			CategorySwitcher.generateSideButtons({'Home', 'Members', 'Vault', 'Leaderboards', 'Quests'})
			ClanDataLoading.LoadData(CurrentClan.Value) -- This will load clan data
		else
			print('We are not in a clan')
			CategorySwitcher.generateSideButtons({'Info', 'Create', 'Join', 'Leaderboards'})
		end
	end
	
	check()
	CurrentClan.Changed:Connect(check)

	require(script.Main) -- refactoring
	require(script.MailboxFilter)
	PromptModule.disablePrompt()
	
	if not Players.LocalPlayer.Variables['SeenClanSplash'].Value then
		repeat task.wait() until script.Parent.ClansFrame.Visible

		TriggerGuide.toggle(true)
		UpdateVariable:FireServer('SeenClanSplash')
	end
end)


conn = Players.LocalPlayer.ChildAdded:Connect(function(obj)
	if obj.Name == 'ClansLoaded' then
		waitUntilLoad:Fire()
	end
end)

if Players.LocalPlayer:FindFirstChild('ClansLoaded') then
	waitUntilLoad:Fire()
end