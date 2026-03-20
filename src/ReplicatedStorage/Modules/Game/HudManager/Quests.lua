------------------// SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

------------------// CONSTANTS
local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local QuestConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("QuestConfig"))
local NotificationSystem = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("NotificationUtility"))

------------------// VARIABLES
local Quests = {}
local localPlayer = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local claimRemote = remotesFolder:WaitForChild("ClaimQuest")
local completedRemote = remotesFolder:WaitForChild("QuestCompleted")

local createdFrames = {} 
local activeConnections = {}

------------------// FUNCTIONS
local function format_number(n)
	return tostring(n):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

local function get_ui_references()
	local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
	if not playerGui then return nil end

	local UI = playerGui:WaitForChild("UI", 10)
	if not UI then return nil end

	local mainGui = UI:FindFirstChild("Quests", true)
	if not mainGui then return nil end

	local bg = mainGui:FindFirstChild("QuestsBG")
	local scroll = bg and bg:FindFirstChild("ListScrollingFrame")
	local template = scroll and scroll:FindFirstChild("Template")

	return {
		Main = mainGui,
		ScrollingFrame = scroll,
		Template = template
	}
end

local function animate_bar(bar, current, goal)
	if not bar then return end

	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.new(0, 0, 0.5, 0)

	local percent = math.clamp(current / goal, 0, 1)
	local targetSize = UDim2.new(percent, 0, 1, 0)

	TweenService:Create(
		bar,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = targetSize}
	):Play()
end

local function update_entry(frame, questData)
	local config = QuestConfig.TYPES[questData.Type]
	if not config then return end

	local titleTx = frame:FindFirstChild("NameQuestTX")
	local descTx = frame:FindFirstChild("DescriptionTX")
	local iconImg = frame:FindFirstChild("Reference")

	local barBG = frame:FindFirstChild("BarBG")
	local bar = barBG and barBG:FindFirstChild("Bar")

	local progressTx = (barBG and barBG:FindFirstChild("Progress")) or frame:FindFirstChild("Progress")
	local claimBt = frame:FindFirstChild("Reference") and frame.Reference:FindFirstChild("ClaimBT")

	local receivedTx = frame:FindFirstChild("ReceivedTX")

	if titleTx then
		titleTx.Text = config.Title
	end

	if iconImg then
		iconImg.Image = config.ImageId
	end

	if descTx then
		descTx.RichText = true
		descTx.Text = string.format(config.Description, format_number(questData.Goal))
	end

	if progressTx then
		progressTx.Text = format_number(questData.Progress) .. " / " .. format_number(questData.Goal)
	end

	if receivedTx then
		local totalReward = questData.Goal * config.RewardPerUnit
		receivedTx.Text = "Reward: $" .. format_number(totalReward)
		receivedTx.TextColor3 = Color3.fromRGB(225, 255, 225) 
	end

	animate_bar(bar, questData.Progress, questData.Goal)

	if claimBt then
		local btnText = claimBt:FindFirstChild("BTTX")
		claimBt.Visible = true

		if questData.Progress >= questData.Goal then
			claimBt.BackgroundColor3 = Color3.fromRGB(0, 255, 127)
			claimBt.AutoButtonColor = true
			if btnText then btnText.Text = "CLAIM" end

			if not activeConnections[questData.Id] then
				local connection = claimBt.Activated:Connect(function()
					claimBt.AutoButtonColor = false
					claimBt.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
					if btnText then btnText.Text = "..." end

					local resultReward = nil
					local success = pcall(function()
						resultReward = claimRemote:InvokeServer(questData.Id)
					end)

					if success and resultReward then
						NotificationSystem:Success("Received " .. format_number(resultReward) .. " Coins!")
					else
						task.wait(0.5)
						claimBt.AutoButtonColor = true
						claimBt.BackgroundColor3 = Color3.fromRGB(0, 255, 127)
						if btnText then btnText.Text = "CLAIM" end
					end
				end)
				activeConnections[questData.Id] = connection
			end
		else
			claimBt.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			claimBt.AutoButtonColor = false
			if btnText then btnText.Text = "LOCKED" end

			if activeConnections[questData.Id] then
				activeConnections[questData.Id]:Disconnect()
				activeConnections[questData.Id] = nil
			end
		end
	end
end

local function sort_quests(questsData)
	table.sort(questsData, function(a, b)
		local aReady = (a.Progress >= a.Goal)
		local bReady = (b.Progress >= b.Goal)

		if aReady ~= bReady then
			return aReady
		end

		return a.Progress / a.Goal > b.Progress / b.Goal
	end)
end

local function render_quests()
	local ui = get_ui_references()
	if not ui or not ui.Template then return end

	ui.Template.Visible = false

	local questsData = DataUtility.client.get("Quests")
	if not questsData then return end

	sort_quests(questsData)

	local currentQuestIds = {}

	for i, quest in ipairs(questsData) do
		currentQuestIds[quest.Id] = true

		local frame = createdFrames[quest.Id]

		if not frame then
			frame = ui.Template:Clone()
			frame.Name = quest.Type
			frame.Visible = true
			frame.Parent = ui.ScrollingFrame
			createdFrames[quest.Id] = frame

			local barBG = frame:FindFirstChild("BarBG")
			local bar = barBG and barBG:FindFirstChild("Bar")
			if bar then
				local percent = math.clamp(quest.Progress / quest.Goal, 0, 1)
				bar.AnchorPoint = Vector2.new(0, 0.5)
				bar.Position = UDim2.new(0, 0, 0.5, 0)
				bar.Size = UDim2.new(percent, 0, 1, 0)
			end
		end

		frame.LayoutOrder = i
		update_entry(frame, quest)
	end

	for questId, frame in pairs(createdFrames) do
		if not currentQuestIds[questId] then
			frame:Destroy()
			createdFrames[questId] = nil

			if activeConnections[questId] then
				activeConnections[questId]:Disconnect()
				activeConnections[questId] = nil
			end
		end
	end
end

------------------// INIT
DataUtility.client.ensure_remotes()

DataUtility.client.bind("Quests", function(val)
	render_quests()
end)

completedRemote.OnClientEvent:Connect(function(questTitle)
	NotificationSystem:Info("Quest Completed: " .. tostring(questTitle))
end)

task.spawn(function()
	local ui = get_ui_references()
	if ui then
		render_quests()
	end
end)

return Quests