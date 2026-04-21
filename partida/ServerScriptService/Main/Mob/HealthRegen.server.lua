local mob = script.Parent
local humanoid: Humanoid = mob:FindFirstChildOfClass("Humanoid")

local function regenHealth(health)
	task.wait(3.5)

	local maxHealth = humanoid.MaxHealth

	if health >= maxHealth or health <= 0 then
		return
	end

	local missingHealth = maxHealth-health
	

	local regen = missingHealth * 0.05
	if regen > 0 then
		regen = math.floor(regen)
		humanoid.Health += regen
	end
end

humanoid.HealthChanged:Connect(function(newHealth)
	regenHealth(newHealth)
end)
