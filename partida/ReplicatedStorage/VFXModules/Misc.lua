local module = {}


function module.DamageIndicator(damageNumber,HRP)
	if not HRP or not HRP.Parent then return end
	local clone = game.ReplicatedStorage.VFX.DamagePart:Clone()
	clone.Position = HRP.Position
	clone.Parent = workspace

	game:GetService("TweenService"):Create(clone.DamageIndicator.Damage,TweenInfo.new(0.3),{
		TextColor3 = Color3.fromRGB(255, 0, 0)
	}):Play()
	task.delay(0.3,function()
		game:GetService("TweenService"):Create(clone.DamageIndicator.Damage,TweenInfo.new(1),{
		TextTransparency = 1
	}):Play()
	game:GetService("TweenService"):Create(clone.DamageIndicator.Damage.UIStroke,TweenInfo.new(1),{
		Transparency = 1
	}):Play()
	end)
	
	clone.DamageIndicator.Damage.Text = damageNumber
	
	clone.AssemblyLinearVelocity = Vector3.new(math.random(-20,20),50,math.random(-20,20))
	
	game.Debris:AddItem(clone,1.5)
end


return module
