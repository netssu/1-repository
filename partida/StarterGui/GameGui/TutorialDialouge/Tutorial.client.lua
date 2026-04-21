--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Info = workspace:WaitForChild("Info")

--// Dependencies
local tutorialSteps = require(script.TutotrialSteps)
local events = require(script.Events)

local eventsFolder = ReplicatedStorage:WaitForChild("Events")

--// Frames
local dialogueFrame = script.Parent.Dialogue
--local pointer = script.Parent.Pointers.Pointer


local contents = dialogueFrame.Contents

local bgText = contents.Bg_Text
local viewport = bgText.ViewportFrame
local label = bgText.TextLabel

local textThread = nil

local lostText = "Oh no! You ended up losing, no worries, you can try again."

--[[local POINTER_POSITIOTNS = {
	[1] = UDim2.new(0.475,0,0.222,0),
	[2] = UDim2.new(0.334,0,0.948,0)
}]]

--// Helper Functions
local function animateText(text: string)
	local characters = string.split(text, "")
	local waitTime = 0.01

	label.Text = ""

	for index = 1, #characters do
		local character = characters[index]

		label.Text ..= character

		task.wait(waitTime)
	end
end

local function tween(instance: Instance, tweenInfo: TweenInfo, props: { [string]: any })
	local tween = TweenService:Create(instance, tweenInfo, props)

	tween:Play()

	return tween
end


local function RunTutorial()
	if workspace.Info.Raid.Value == true or workspace.Info.Infinity.Value == true or Info.Event.Value == true or Info.ChallengeNumber.Value ~= -1 then return end
	dialogueFrame.Visible = true

	local tweenInfo = TweenInfo.new(.35, Enum.EasingStyle.Exponential)
	local goal = {
		Scale = 1
	}

	tween(dialogueFrame.UIScale, tweenInfo, goal):Play()

	local lost = false
	
	Info.GameOver.Changed:Connect(function()
		if not Info.Victory.Value then
			if textThread  then
				task.cancel(textThread)
				textThread = nil
			end
			
			textThread = task.spawn(function()
				animateText(lostText)
			end)
			
			task.delay(2, function()
				tween(dialogueFrame.UIScale, tweenInfo, {Scale = 0}):Play()
			end)
			
			lost = true
		end
	end)

	for stepNum, step in ipairs(tutorialSteps) do	
		if workspace.Info.Victory.Value == true or lost then break end

		if step.callback then
			step.callback()
		end
		
		if textThread then
			task.cancel(textThread)
			textThread = nil
		end
		textThread = task.spawn(animateText, step.text)
	
		local waitFunc = events[step.waitFor]
		if waitFunc then
			waitFunc(function()
				warn("Completed step: " .. stepNum)
			end)
		else
			warn("Missing tutorial event for: " .. step.waitFor)
		end
	end

	if lost then
		return
	end

	tween(dialogueFrame.UIScale, tweenInfo, {Scale = 0}):Play()

	warn("[TUTORIAL]: Completed :)")
end

local players = game:GetService('Players')
if players.LocalPlayer:GetAttribute("TutorialWin") then return end
repeat task.wait(.1) until players.LocalPlayer:FindFirstChild("DataLoaded")
warn("Data Loaded.")

local Player = players.LocalPlayer

local condition = players.LocalPlayer:FindFirstChild("TutorialModeCompleted")
local TutorialWin = Player.TutorialWin.Value
if condition and condition.Value == true and not TutorialWin then
	RunTutorial()
end
