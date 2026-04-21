local replicatedStorage = game:GetService("ReplicatedStorage")
local UI_Animation_Module = require(replicatedStorage.Modules:WaitForChild('UI_Animations'))

for _,  ui in script.Parent:GetDescendants() do
	if ui:IsA('GuiButton') and not ui:GetAttribute("NoAnimation") then
		UI_Animation_Module.SetUp(ui)
	end
end

script.Parent.DescendantAdded:Connect(function(descendant)
	if descendant:IsA('GuiButton') and not descendant:GetAttribute("NoAnimation") then
		UI_Animation_Module.SetUp(descendant)
	end
end)