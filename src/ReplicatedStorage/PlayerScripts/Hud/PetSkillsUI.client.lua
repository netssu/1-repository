------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

------------------//VARIABLES
local SkillsData = require(ReplicatedStorage.Modules.Datas.PetsSkillsData)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local uiRoot = playerGui:WaitForChild("UI")
local hud = uiRoot:WaitForChild("GameHUD")

local petSkillsUI = hud:WaitForChild("PetSkills")
local skillIcon = petSkillsUI:WaitForChild("IconImage")
local skillBindText = petSkillsUI:WaitForChild("BindText")
local skillName = petSkillsUI:WaitForChild("SkillName")
local skillTimeText = petSkillsUI:WaitForChild("Time") 

local timerConnection = nil

------------------//FUNCTIONS
local function startCooldownAnim(duration)
	if timerConnection then 
		timerConnection:Disconnect() 
		timerConnection = nil 
	end
	
	skillTimeText.Visible = true
	
	local endTime = os.clock() + duration
	
	timerConnection = RunService.RenderStepped:Connect(function()
		local remaining = endTime - os.clock()
		
		if remaining > 0 then
			skillTimeText.Text = string.format("%.1f", remaining)
		else
			skillTimeText.Visible = false
			if timerConnection then
				timerConnection:Disconnect()
				timerConnection = nil
			end
		end
	end)
end

local function updateUI()
	local equippedSkillId = player:GetAttribute("EquippedSkill")
	
	if equippedSkillId and equippedSkillId ~= "" then
		local skillInfo = SkillsData.GetSkillData(equippedSkillId)
		
		if skillInfo then
			petSkillsUI.Visible = true
			skillIcon.Image = skillInfo.Icon
			skillName.Text = skillInfo.Name
			
			if skillInfo.Type == "Active" then
				skillBindText.Visible = true
			else
				skillBindText.Visible = false
			end
		end
	else
		petSkillsUI.Visible = false
	end
end

------------------//INIT
skillTimeText.Visible = false

player:GetAttributeChangedSignal("EquippedSkill"):Connect(updateUI)

player:GetAttributeChangedSignal("SkillCooldownEnd"):Connect(function()
	local endTime = player:GetAttribute("SkillCooldownEnd")
	if endTime then
		local remaining = endTime - os.clock()
		if remaining > 0 then
			startCooldownAnim(remaining)
		end
	end
end)

updateUI()