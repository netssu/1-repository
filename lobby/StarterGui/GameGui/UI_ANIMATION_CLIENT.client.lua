local replicatedStorage = game:GetService("ReplicatedStorage")
local UI_Animation_Module = require(replicatedStorage.Modules:WaitForChild('UI_Animations'))

if true then print('UI hover animations disabled') return end

for i,v in pairs(script.Parent.Parent:GetChildren()) do
	if v:IsA('ScreenGui') then
		for _,  ui in v:GetDescendants() do
            if ui:IsA('GuiButton') and not ui:GetAttribute("NoAnimation") and not string.find(ui.Name, 'Act') then
                --if ui:FindFirstChild('Contents') then
                --    print('setting up in contents')
                --    UI_Animation_Module.SetUp(ui.Contents)
                --    continue
                --end
                
                UI_Animation_Module.SetUp(ui)
			end
		end
	end
end

for i,v in pairs(script.Parent.Parent:GetChildren()) do
	if v:IsA('ScreenGui') then
		script.Parent.DescendantAdded:Connect(function(descendant)
			if descendant:IsA('GuiButton') and not descendant:GetAttribute("NoAnimation") and not string.find(descendant.Name, 'Act') then
                --if descendant:FindFirstChild('Contents') then
                --    UI_Animation_Module.SetUp(descendant.Contents)
                --    return
                --end

                UI_Animation_Module.SetUp(descendant)
			end
		end)
	end
end