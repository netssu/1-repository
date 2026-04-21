local ServerScriptService = game:GetService("ServerScriptService")
repeat task.wait(.1) until _G.LoadingScreenComplete
--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Dependencies
local funcs = require(ReplicatedStorage.Modules.Functions)
local tutorialStartSteps = require(script.TutotrialStartSteps)
local tutorialEndSteps = require(script.TutotrialEndSteps)
local events = require(script.Events)

--// Frames
local dialogueFrame = script.Parent.Dialogue
local pointer = script.Parent.Pointers.Pointer

local contents = dialogueFrame.Contents

local bgText = contents.Bg_Text
local viewport = bgText.ViewportFrame
local label = bgText.TextLabel

local player = game.Players.LocalPlayer
repeat task.wait(.1) until player:FindFirstChild("DataLoaded")

--if player:FindFirstChild("TutorialCompleted").Value == true or player:FindFirstChild("TutorialModeCompleted").Value == true then return end
if player:GetAttribute("TutorialCompleted") or player:GetAttribute("TutorialModeCompleted") then return end
local tutorialCompleted = player:WaitForChild("TutorialCompleted")
local tutorialWin = player:WaitForChild("TutorialWin")
local tutorialMode = player:FindFirstChild("TutorialModeCompleted")

local UnitButton = nil :: TextButton
local GetUnits = ReplicatedStorage.GetUnitsButton
UnitButton = GetUnits:Invoke()



local debugStart, debugEnd = false, false
local textThread = nil

local coords = UnitButton.AbsolutePosition :: Vector2
print(coords)

local POINTER_POSITIONS = {
	[2] = UDim2.fromScale(0.066,0.62), -- Welcome?
	[3] = UDim2.fromScale(0.54,0.72), -- Press Summon x10
	-- skip 4?
	[5] = UDim2.new(1,-44,0.03,0)  ,-- UDim2.fromScale(0.923,0.03), -- Equip unit {0.033, 0},{0.41, 0}
	[7] = UDim2.fromScale(0.6, 0.28),
	
	[8] = UDim2.fromScale(0.062,0.73)
}

local END_POINTER_POS = {
	[1] = UDim2.fromScale(0.066,0.62),
	[2] = UDim2.new(0.411,0,0.669,0),
}

--// Helper Functions
local function animateText(step, start)
	local characters = string.split(step.text, "")
	if #characters == 0 then
		warn('no characters in this tut') 
		script.Parent.Dialogue.Visible = false
		pointer.Visible = false
		return
	else
		script.Parent.Dialogue.Visible = true
	end
	
	local waitTime = 0.01

	local pointerPos = if start then POINTER_POSITIONS[step.index] else END_POINTER_POS[step.index]

	pointer.Visible = false
	pointer.Parent.Visible = false

	label.Text = ""

	for index = 1, #characters do
		local character = characters[index]

		label.Text ..= character

		task.wait(waitTime)
	end

	if not pointerPos  then
		pointer.Visible = false
		pointer.Parent.Visible = false
	else
		pointer.Position = pointerPos
		pointer.Visible = true
		pointer.Parent.Visible = true
	end
end

local function RunTutorial()
	local info = TweenInfo.new(.35, Enum.EasingStyle.Exponential)
	local goal = {
		Scale = 1
	}

	local function runStart()
		dialogueFrame.Visible = true
		--funcs.tween(dialogueFrame.UIScale, info, goal):Play()

		for stepNum, step in ipairs(tutorialStartSteps) do
			print('Staring step:')
			print(stepNum)
			
			if textThread then
				task.cancel(textThread)
				textThread = nil

				warn("Cancelling Text..")
			end

			textThread = task.spawn(animateText, step, true)

			local waitFunc = events[step.waitFor]
			if waitFunc then
				waitFunc(function()
					warn("Completed step: " .. stepNum)
				end)
			else
				warn("Missing tutorial event for: " .. step.waitFor)
			end
		end

		funcs.tween(dialogueFrame.UIScale, info, {Scale = 0}):Play()
	end

	local function runEnd()
		dialogueFrame.Visible = true
		--funcs.tween(dialogueFrame.UIScale, info, goal):Play()p

		dialogueFrame.Contents.Options.Continue.Visible = false
		for stepNum, step in ipairs(tutorialEndSteps) do
			if textThread then
				task.cancel(textThread)
				textThread = nil
			end
			
			if step.index == 1 then
				if tutorialWin.Value == false then
					ReplicatedStorage.Events.Client.RewardGems:FireServer()
					
					textThread = task.spawn(animateText, {
						index = 1,
						text = "Seems like you lost, no worries. I'll reward you with crystals so you can summon more units to aid you to victory next time!"
					})
				else
					textThread = task.spawn(animateText, step)
				end
				
			else
				textThread = task.spawn(animateText, step)
			end

			local waitFunc = events[step.waitFor]
			if waitFunc then
				waitFunc(function()
					warn("Completed step: " .. stepNum)
				end)
			else
				warn("Missing tutorial event for: " .. step.waitFor)
			end
		end

		warn("Tutorial Completed!")
		funcs.tween(dialogueFrame.UIScale, info, {Scale = 0}):Play()
	end

	print(tutorialWin.Value)
	print(tutorialCompleted.Value)
	print(tutorialMode.Value)

	if player.FirstTime.Value == true then
		if tutorialCompleted.Value == true or #player.OwnedTowers:GetChildren() > 2 then return end
		ReplicatedStorage.Events.Client.UpdateFirstTime:FireServer()
		runStart()
	elseif tutorialMode.Value == true then
		if tutorialCompleted.Value == true or #player.OwnedTowers:GetChildren() > 2  then return end
		runEnd()
	end

	if debugStart then
		warn("Starting.")
		runStart()
	elseif debugEnd then
		warn("Ending.")
		runEnd()
	end
end

local players = game:GetService('Players')

if #players.LocalPlayer.OwnedTowers:GetChildren() < 3 then
	RunTutorial()
end