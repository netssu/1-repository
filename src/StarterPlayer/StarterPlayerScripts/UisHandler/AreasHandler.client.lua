-- SERVICES
local Players = game:GetService("Players")

-- CONSTANTS

-- VARIABLES
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local areateleports = workspace:WaitForChild("areateleports")

-- FUNCTIONS

-- INIT
local newUI = playerGui:WaitForChild("NewUI")
local contentArea = newUI:WaitForChild("Areas"):WaitForChild("Main"):WaitForChild("Content"):WaitForChild("Content")

task.wait(1) 

for i, v in contentArea:GetChildren() do
	if v:IsA("Frame") then
		local btn = v:WaitForChild("Button"):WaitForChild("Btn")

		btn.Activated:Connect(function()
			print("Clicou em:", v.Name)

			local character = player.Character

			if character and character:FindFirstChild("HumanoidRootPart") then
				local teleportPart = areateleports:FindFirstChild(v.Name)

				if teleportPart then
					character:PivotTo(teleportPart.CFrame)
				else
					warn("AVISO: Não foi encontrada a part de teleporte para '" .. v.Name .. "'. Verifique letras maiúsculas/minúsculas e espaços.")
				end
			end

			_G.CloseAll()
		end)
	end
end