-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CONSTANTS
local ClientDataLoaded = require(ReplicatedStorage.Modules.ClientDataLoaded)

-- VARIABLES
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local plrData = ClientDataLoaded.getPlayerData()

local QuestList = script.Parent:WaitForChild("QuestList")
local pullup = script.Parent:WaitForChild("pullup")
local HideQuestsBtn = pullup:WaitForChild("HideQuests")

local NewUI = PlayerGui:WaitForChild("NewUI")
local MainQuestFrame = NewUI:WaitForChild("Quests")
local MainContainer = MainQuestFrame:WaitForChild("Main")
local Selection = MainQuestFrame:WaitForChild("Selection")
local AllQuests = Selection:WaitForChild("ALL")

local availableQuests = {}
local associatedConnections = {}
local module = {}

-- FUNCTIONS
function module.createContainer(ref)
	local claimBtn = ref:FindFirstChild("Claim") or ref:FindFirstChild("Bg") or ref
	local claimStatus = claimBtn:FindFirstChild("TextLabel") or claimBtn:FindFirstChild("Status")

	if not claimStatus or claimStatus.Text == 'Completed' then return end

	local foundLater = QuestList:FindFirstChild('Later')
	if foundLater then foundLater:Destroy() end

	local found = table.find(availableQuests, ref)
	if not found then
		table.insert(availableQuests, ref)
	end

	local count = 0
	for _, v in ipairs(QuestList:GetChildren()) do 
		if v:IsA('GuiBase2d') then count += 1 end 
	end
	if count == 3 then return end

	local QuestContainer = QuestList.UIListLayout.Quest:Clone()
	QuestContainer.Name = ref.Name

	associatedConnections[QuestContainer] = {}

	local barFrame = ref:FindFirstChild("Bar")
	local innerBar = barFrame and barFrame:FindFirstChild("Bar")
	local refFront = innerBar and innerBar:FindFirstChild("Fill")
	local refProgressText = ref:FindFirstChild("Progress")

	local function updateProgress()
		if refFront then
			local front = QuestContainer.Container.ProgressBar.Front :: Frame
			front.Size = refFront.Size
		end

		if refProgressText then
			QuestContainer.Container.progress.Text = refProgressText.Text
		end

		QuestContainer.Claim.Visible = claimStatus.Text ~= 'Completed' and claimStatus.Text ~= 'Incomplete'

		if claimStatus.Text == 'Completed' then
			module.deleteContainer(ref)
		end
	end

	updateProgress()

	local refDescription = ref:FindFirstChild("Description")
	if refDescription then
		QuestContainer.Container.quest.Text = refDescription.Text
	end

	if refFront then
		local conn = refFront:GetPropertyChangedSignal("Size"):Connect(updateProgress)
		table.insert(associatedConnections[QuestContainer], conn)
	end

	if claimStatus then
		local conn2 = claimStatus:GetPropertyChangedSignal("Text"):Connect(updateProgress)
		table.insert(associatedConnections[QuestContainer], conn2)
	end

	QuestContainer.Claim.Activated:Connect(function()
		local claimEvent = ref:FindFirstChild("Claim")
		if claimEvent and typeof(claimEvent) == "BindableEvent" then
			claimEvent:Fire()
		end

		claimStatus.Text = 'Completed'
		QuestContainer.Claim.Visible = false
	end)

	QuestContainer.Parent = QuestList
end

function module.deleteContainer(ref)
	local found = table.find(availableQuests, ref)
	if found then
		table.remove(availableQuests, found)
	end

	local foundQuestLine = QuestList:FindFirstChild(ref.Name)
	if foundQuestLine then
		if associatedConnections[foundQuestLine] then
			for _, v in ipairs(associatedConnections[foundQuestLine]) do
				v:Disconnect()
			end
			associatedConnections[foundQuestLine] = nil
		end
		foundQuestLine:Destroy() 
	end

	if #availableQuests == 0 then
		local laterTemplate = QuestList.UIListLayout:FindFirstChild("Later")
		if laterTemplate then
			laterTemplate:Clone().Parent = QuestList
		end
	else
		local foundPos = nil
		for i, v in ipairs(availableQuests) do
			if not QuestList:FindFirstChild(v.Name) then
				foundPos = i
				break
			end 
		end
		if foundPos then
			module.createContainer(availableQuests[foundPos])
		end
	end
end

-- INIT
local function init()
	QuestList.Visible = plrData.QuestsHidden.Value

	HideQuestsBtn.Activated:Connect(function()
		QuestList.Visible = not QuestList.Visible	
		ReplicatedStorage.Remotes.SetHiddenQuests:FireServer(QuestList.Visible)
	end)

	for _, v in ipairs(AllQuests:GetChildren()) do
		if v:IsA('GuiBase2d') then
			module.createContainer(v)
		end
	end

	AllQuests.ChildAdded:Connect(module.createContainer)
	AllQuests.ChildRemoved:Connect(function(child)
		module.deleteContainer(child)
	end)
end

init()