--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// Vars
local Player = Players.LocalPlayer
local Gui = Player.PlayerGui
local GameGui = Gui:WaitForChild("GameGui")
local CoreGameGui = Gui:WaitForChild("CoreGameUI")

--// Frames
local Dialogue = CoreGameGui:WaitForChild("TutorialDialouge"):WaitForChild("Dialogue")

local Buttons = CoreGameGui.Buttons.Buttons

local HUD = CoreGameGui.HUD
local LeftPanel = HUD.LeftPanel
local SummonButton = LeftPanel.Summon
local PlayButton = LeftPanel.Play

local Contents = Dialogue:WaitForChild("Contents")
local ContinueButton = Contents:WaitForChild("Options"):WaitForChild("Continue")

local tutorialEvents = {}

if Player:GetAttribute("TutorialCompleted") then return end

tutorialEvents["Continue"] = function(callback)
	ContinueButton.Visible = true
	ContinueButton.Activated:Wait()
	ContinueButton.Visible = false
	callback()
end

tutorialEvents["SummonButton"] = function(callback)
	CoreGameGui.HUD.LeftPanel.Summon.Activated:Wait()
	
	callback()
end

tutorialEvents["SummonUnit"] = function(callback)
	print('Waiting for them to summon a unit')
	local clickedOnSummon = false
	local BottomBar = CoreGameGui.Summon.SummonFrame.Banner.Bottom_Bar.Bottom_Bar

	for _, button in BottomBar:GetChildren() do
		if not button:IsA("ImageButton") then continue end
		button.Activated:Once(function()
			clickedOnSummon = true
		end)
	end

	repeat task.wait(.1) until clickedOnSummon

	callback()
end

tutorialEvents["EquipUnit"] = function(callback)
	print('Waiting for them to equip a unit')
	
	CoreGameGui.Parent.UnitsGui.Inventory.Units:GetPropertyChangedSignal('Visible'):Wait()

	callback()
end

tutorialEvents["CloseMenu"] = function(callback)
	print('Waiting for them to close menu')

	CoreGameGui.Parent.UnitsGui.Inventory.Units:GetPropertyChangedSignal('Visible'):Wait()

	callback()
end


tutorialEvents['WaitForEquipUnit'] = function(callback)
	local conn = Instance.new('BindableEvent')
	
	for i,v: BoolValue in Player.OwnedTowers:GetChildren() do
		v:GetAttributeChangedSignal('EquippedSlot'):Once(function()
			conn:Fire()
		end)
	end
	
	conn.Event:Wait()
	
	
	callback()
end

tutorialEvents['ExitSummonArea'] = function(callback)

	--repeat task.wait() until CoreGameGui.Buttons.Settings.Position == UDim2.fromScale(0.99,0.99)
	CoreGameGui.Summon.SummonFrame:GetPropertyChangedSignal('Visible'):Wait()
	
	-- how can we wait till we finished summoning?
	repeat task.wait() until ReplicatedStorage:FindFirstChild('SummonDone') 
	
	
	callback()
end

tutorialEvents["PlayButton"] = function(callback)
	PlayButton.Activated:Wait()
	callback()
end

tutorialEvents["Elevator"] = function(callback)
	ReplicatedStorage.Events:WaitForChild("Elevator").OnClientEvent:Wait()
	callback()
end

tutorialEvents["FinalPlay"] = function(callback)
	script.Parent.Parent.Parent.Parent.CoreGameUI.Story.StoryFrame.Frame.Bottom_Bar.Bottom_Bar.Play.Activated:Wait()
	callback()
end

tutorialEvents["Finished"] = function(callback)
	ReplicatedStorage.Events.Client.Tutorial:FireServer()
	task.wait(6)
	callback()
end

tutorialEvents["Summon2"] = function(callback)
	CoreGameGui.Buttons.Buttons["Left Panel"]["HUD Main Buttons Left"].Summon.Activated:Wait()
	callback()
end

tutorialEvents["SummonUnit2"] = function(callback)
	local clickedOnSummon = false
	local BottomBar = CoreGameGui.Summon.SummonFrame.Banner.Bottom_Bar.Bottom_Bar

	for _, button in BottomBar:GetChildren() do
		if not button:IsA("ImageButton") then continue end
		button.Activated:Once(function()
			clickedOnSummon = true
		end)
	end

	repeat task.wait(.1) until clickedOnSummon

	callback()
end

tutorialEvents["Finished2"] = function(callback)
	ReplicatedStorage.Events.Client.Tutorial:FireServer()
	task.wait(6)
	callback()
end

return tutorialEvents