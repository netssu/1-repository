-- message from ace:
-- who tf left this unfinished

local Towers = workspace:WaitForChild("Towers")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerGUI : BillboardGui = ReplicatedStorage["TOWER BUFF GUI"] 
local Support = {
	["Echo"] = function (Model : Model)
		local dmg : IntValue = Model:FindFirstChild("Echo"):FindFirstChild("DMG")
	end,
	["Mas Med"] = function ()

	end,
	["Tech"] = function ()

	end,
}


--for i,v in workspace.Towers:GetDescendants() do	
--	if v:IsA("Model") then
--		local SupportTower = Support[v](v)
--	else
--		return
--	end
	
	
	
--end

