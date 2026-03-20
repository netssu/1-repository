local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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
local skillButton = petSkillsUI:WaitForChild("Button")

local timerConnection = nil

local tooltipFrame = Instance.new("Frame")
tooltipFrame.Name = "SkillTooltip"
tooltipFrame.Size = UDim2.new(0, 180, 0, 70)
tooltipFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 15)
tooltipFrame.BackgroundTransparency = 0.1
tooltipFrame.ZIndex = 100
tooltipFrame.Visible = false
tooltipFrame.Parent = hud

local tooltipCorner = Instance.new("UICorner", tooltipFrame)
tooltipCorner.CornerRadius = UDim.new(0, 6)

local tooltipStroke = Instance.new("UIStroke", tooltipFrame)
tooltipStroke.Color = Color3.fromRGB(200, 150, 50)
tooltipStroke.Thickness = 1.5

local tooltipText = Instance.new("TextLabel", tooltipFrame)
tooltipText.Name = "DescText"
tooltipText.Size = UDim2.new(1, -16, 1, -16)
tooltipText.Position = UDim2.new(0.5, 0, 0.5, 0)
tooltipText.AnchorPoint = Vector2.new(0.5, 0.5)
tooltipText.BackgroundTransparency = 1
tooltipText.TextColor3 = Color3.fromRGB(240, 240, 240)
tooltipText.Font = Enum.Font.GothamMedium
tooltipText.TextSize = 12
tooltipText.TextWrapped = true
tooltipText.TextXAlignment = Enum.TextXAlignment.Center
tooltipText.TextYAlignment = Enum.TextYAlignment.Center
tooltipText.Text = ""
tooltipText.ZIndex = 101

local function startCooldownAnim(duration)
	if timerConnection then 
		timerConnection:Disconnect() 
		timerConnection = nil 
	end
	
	if duration <= 0 then
		skillTimeText.Visible = false
		return
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
			tooltipText.Text = skillInfo.Description
			
			if skillInfo.Type == "Active" then
				skillBindText.Visible = true
			else
				skillBindText.Visible = false
			end
			
			local cdEnd = player:GetAttribute("SkillCooldownEnd")
			if cdEnd then
				local remaining = cdEnd - os.clock()
				if remaining > 0 then
					startCooldownAnim(remaining)
				else
					startCooldownAnim(0)
				end
			else
				startCooldownAnim(0)
			end
		end
	else
		petSkillsUI.Visible = false
		tooltipFrame.Visible = false
	end
end

skillButton.MouseEnter:Connect(function()
	local equippedSkillId = player:GetAttribute("EquippedSkill")
	if equippedSkillId and equippedSkillId ~= "" then
		tooltipFrame.Visible = true
	end
end)

skillButton.MouseLeave:Connect(function()
	tooltipFrame.Visible = false
end)

RunService.RenderStepped:Connect(function()
	if tooltipFrame.Visible then
		local mousePos = UserInputService:GetMouseLocation()
		tooltipFrame.Position = UDim2.new(0, mousePos.X - 190, 0, mousePos.Y - 50)
	end
end)

skillButton.Activated:Connect(function()
	local equippedSkillId = player:GetAttribute("EquippedSkill")
	if equippedSkillId and equippedSkillId ~= "" then
		local skillInfo = SkillsData.GetSkillData(equippedSkillId)
		if skillInfo and skillInfo.Type == "Active" then
			player:SetAttribute("TriggerActiveSkill", os.clock())
		end
	end
end)

skillTimeText.Visible = false

player:GetAttributeChangedSignal("EquippedSkill"):Connect(updateUI)

player:GetAttributeChangedSignal("SkillCooldownEnd"):Connect(function()
	local endTime = player:GetAttribute("SkillCooldownEnd")
	if endTime then
		local remaining = endTime - os.clock()
		if remaining > 0 then
			startCooldownAnim(remaining)
		else
			startCooldownAnim(0)
		end
	end
end)

updateUI()