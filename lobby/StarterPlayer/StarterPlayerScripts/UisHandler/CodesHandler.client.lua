-- SERVICES
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

-- CONSTANTS
local Zone = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Zone"))
local CodesModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Codes"))
local UI_Handler = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIHandler"))
local RequestRedeemCode = ReplicatedStorage:WaitForChild("Functions"):WaitForChild("RequestRedeemCode")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local newUI = playerGui:WaitForChild("NewUI")
local codesUI = newUI:WaitForChild("Codes")
local mainFrame = codesUI:WaitForChild("Main")

local textBox = mainFrame:WaitForChild("Input"):WaitForChild("TextBox")
local submitBtn = mainFrame:WaitForChild("Button"):WaitForChild("Btn")

local codesArea = workspace:WaitForChild('CodesArea'):WaitForChild('Hitbox')
local container = Zone.new(codesArea)
local sounds = script:WaitForChild("Sounds")

-- FUNCTIONS
local function ConfirmPress()
	local givenCode = textBox.Text
	local requestServerValidation = RequestRedeemCode:InvokeServer(givenCode)

	if requestServerValidation == true then
		textBox.Text = "Redeemed!"
		UI_Handler.CreateConfetti()

		if sounds:FindFirstChild("Redeem") then
			sounds.Redeem:Play()
		end
	else
		if requestServerValidation then
			textBox.Text = requestServerValidation
		end

		if sounds:FindFirstChild("Error") then
			sounds.Error:Play()
		end
	end
end

-- INIT
submitBtn.Activated:Connect(ConfirmPress)

container.playerEntered:Connect(function(plr)
	if plr == player then
		if _G.CloseAll then 
			_G.CloseAll('Codes') 
		end
	end
end)

container.playerExited:Connect(function(plr)
	if plr == player then
		if _G.CloseAll then 
			_G.CloseAll() 
		end
	end
end)