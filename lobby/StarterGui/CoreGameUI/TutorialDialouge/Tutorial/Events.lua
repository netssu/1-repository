--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// Vars
local Player = Players.LocalPlayer
local Gui = Player.PlayerGui
local GameGui = Gui:WaitForChild("GameGui")
local CoreGameGui = Gui:WaitForChild("CoreGameUI")
local NewUI = Gui:WaitForChild("NewUI", 5)

--// Frames
local Dialogue = CoreGameGui:WaitForChild("TutorialDialouge"):WaitForChild("Dialogue")

local Contents = Dialogue:WaitForChild("Contents")
local ContinueButton = Contents:WaitForChild("Options"):WaitForChild("Continue")

local tutorialEvents = {}

if Player:GetAttribute("TutorialCompleted") then return end

local function getGuiButtonFromItem(item)
	if not item then return nil end
	if item:IsA("GuiButton") then return item end

	local btn = item:FindFirstChild("Btn", true)
		or item:FindFirstChild("Button", true)

	if btn and btn:IsA("GuiButton") then
		return btn
	end

	return item:FindFirstChildWhichIsA("GuiButton", true)
end

local function findButtonInSideMenu(name)
	NewUI = NewUI or Gui:FindFirstChild("NewUI")
	local sideMenu = NewUI and (NewUI:FindFirstChild("sideMenu") or NewUI:FindFirstChild("HUDButtons"))
	if not sideMenu then return nil end

	local lowerName = string.lower(name)

	for _, item in sideMenu:GetDescendants() do
		if string.lower(item.Name) == lowerName then
			local button = getGuiButtonFromItem(item)
			if button then
				return button
			end
		end
	end

	return nil
end

local function findLegacyHudButton(name)
	local hud = CoreGameGui:FindFirstChild("HUD")
	local leftPanel = hud and hud:FindFirstChild("LeftPanel")
	if not leftPanel then return nil end

	local lowerName = string.lower(name)

	for _, item in leftPanel:GetChildren() do
		if string.lower(item.Name) == lowerName then
			return getGuiButtonFromItem(item)
		end
	end

	return nil
end

local function waitForMenuButton(name)
	local button = findButtonInSideMenu(name) or findLegacyHudButton(name)

	while not button do
		task.wait(0.1)
		button = findButtonInSideMenu(name) or findLegacyHudButton(name)
	end

	button.Activated:Wait()
end

local function findUnitsFrame()
	NewUI = NewUI or Gui:FindFirstChild("NewUI")

	if NewUI and NewUI:FindFirstChild("Units") then
		return NewUI.Units
	end

	local unitsGui = Gui:FindFirstChild("UnitsGui")
	local inventory = unitsGui and unitsGui:FindFirstChild("Inventory")

	return inventory and inventory:FindFirstChild("Units")
end

local function waitForUnitsVisibilityChanged()
	local unitsFrame = findUnitsFrame()

	while not unitsFrame do
		task.wait(0.1)
		unitsFrame = findUnitsFrame()
	end

	unitsFrame:GetPropertyChangedSignal('Visible'):Wait()
end

tutorialEvents["Continue"] = function(callback)
	ContinueButton.Visible = true
	ContinueButton.Activated:Wait()
	ContinueButton.Visible = false
	callback()
end

tutorialEvents["SummonButton"] = function(callback)
	waitForMenuButton("summon")

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

	waitForUnitsVisibilityChanged()

	callback()
end

tutorialEvents["CloseMenu"] = function(callback)
	print('Waiting for them to close menu')

	waitForUnitsVisibilityChanged()

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
	waitForMenuButton("play")
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
	waitForMenuButton("summon")
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
