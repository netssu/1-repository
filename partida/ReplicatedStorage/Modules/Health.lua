local Players = game:GetService("Players")

local health = {}

function health.Setup(model, screenGui)
	local newHealthBar = script.HealthGui:Clone()
	local HRP = model:WaitForChild('HumanoidRootPart', 3)
	
    if not HRP or not model.Parent then
        newHealthBar:Destroy()
		model:Destroy()
		return
	end
    
    newHealthBar:GetPropertyChangedSignal('Adornee'):Connect(function()
        if not newHealthBar.Adornee then
            newHealthBar:Destroy()
        end
    end)
    
    newHealthBar.Adornee = HRP
    
    
    
	newHealthBar.Parent = Players.LocalPlayer.PlayerGui:WaitForChild("Billboards")
	
	if workspace:WaitForChild('Info').World.Value == 5 then -- tatooine
		newHealthBar.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	end
	
	if model.Name == "Base" then
		newHealthBar.MaxDistance = 100
		newHealthBar.Size = UDim2.new(0, 200, 0, 20)

	else
		newHealthBar.MaxDistance = 30
		newHealthBar.Main.MobName.Text = model.Name
	end


	health.UpdateBarHealth(newHealthBar, model)
	if screenGui then
		health.UpdateScreenGuiHealth(screenGui, model)
	end

	model.Humanoid.HealthChanged:Connect(function()
		--if model.Humanoid.Health > 0 then
		health.UpdateBarHealth(newHealthBar, model)
		if screenGui then
			health.UpdateScreenGuiHealth(screenGui, model)
		end
		--end
	end)
end

function health.UpdateScreenGuiHealth(gui,model)
	local humanoid = model:WaitForChild("Humanoid")

	if model == nil or model.Parent == nil then
		gui:Destroy()
	end

	if humanoid and gui then
		local percent = humanoid.Health / humanoid.MaxHealth
		if gui.CurrentHealth.Size.Y.Scale == 0.5 then
			gui.CurrentHealth.Size = UDim2.new(math.max(percent, 0), 0, .5, 0)
		else
			gui.CurrentHealth.Size = UDim2.new(math.max(percent, 0), 0, 1, 0)
		end

		if humanoid.Health <= 0 then
			if model.Name == "Base" then
				gui.HpText.Text = model.Name .. " DESTROYED".. humanoid.MaxHealth .. ", GG"
				workspace.Mobs:ClearAllChildren()

			else
				--gui.HpText.Text = model.Name .. " DEAD" .. humanoid.MaxHealth
				game.Debris:AddItem(gui,0.5)
			end

		else
			gui.HpText.Text = humanoid.Health .. "/" .. humanoid.MaxHealth
		end
	end

end

function health.UpdateBarHealth(gui, model)
	local humanoid = model:WaitForChild("Humanoid", 10)

	if model == nil or model.Parent == nil then
		gui:Destroy()
	end

	if humanoid and gui then
		local percent = humanoid.Health / humanoid.MaxHealth

		gui.Main.BarFrame.Bar.Size = UDim2.fromScale(percent,1)

		if humanoid.Health <= 0 then
			if model.Name == "Base" then
				gui.Main.Health.Text = model.Name .. " DESTROYED".. humanoid.MaxHealth .. ", GG"
				
				if workspace:FindFirstChild('Mobs') then
					workspace.Mobs:ClearAllChildren()
				else
					workspace.RedMobs:ClearAllChildren()
					workspace.BlueMobs:ClearAllChildren()
				end
			else
				gui.Main.Health.Text = humanoid.Health .. "/" .. humanoid.MaxHealth
				game.Debris:AddItem(gui,0.5)
			end

		else
			gui.Main.Health.Text = humanoid.Health .. "/" .. humanoid.MaxHealth
		end
	end
end

return health
