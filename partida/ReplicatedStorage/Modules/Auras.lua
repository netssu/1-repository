local auras = {}
local auraBank = {}
local Debris = game:GetService("Debris")

auras.Slowness = function(character: Model, lifetime)
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	local limbs = {}

	for _, limb in pairs(character:GetChildren()) do
		if limb:IsA("BasePart") and limb ~= torso then
			table.insert(limbs, limb)
		end
	end

	local addedEffects = {}

	if torso then
		for _, part in pairs(torso:GetChildren()) do
			for _, effect in pairs(script.Slowness.Torso:GetChildren()) do
				local clone = effect:Clone()
				clone.Parent = part
				table.insert(addedEffects, clone)
				if lifetime then
					Debris:AddItem(clone, lifetime)
				end
			end
		end
	end

	for _, limb in pairs(limbs) do
		for _, particle in pairs(script.Slowness.Other:GetChildren()) do
			local effect = particle:Clone()
			effect.Parent = limb
			table.insert(addedEffects, effect)
			if lifetime then Debris:AddItem(effect, lifetime) end
		end
	end

	return function()
		for _, effect in pairs(addedEffects) do
			if effect and effect.Parent then
				effect:Destroy()
			end
		end
	end
end

local function runAura(character, auraName, lifetime)
	local auraFunc = auras[auraName]
	if not auraFunc then return end

	local cleanup = auraFunc(character, lifetime)

	auraBank[character] = auraBank[character] or {}
	if auraBank[character][auraName] then
		auraBank[character][auraName].cleanup()
	end

	auraBank[character][auraName] = {
		cleanup = cleanup or function() end,
	}

	if lifetime then
		spawn(function()
			task.delay(lifetime, function()
				auras.RemoveAura(character, auraName)
			end)
		end)
	end
end

function auras.AddAura(character, auraName, lifetime)
	runAura(character, auraName, lifetime)
end

function auras.RemoveAura(character, auraName)
	if auraBank[character] and auraBank[character][auraName] then
		local data = auraBank[character][auraName]
		data.cleanup()
		auraBank[character][auraName] = nil
		if next(auraBank[character]) == nil then
			auraBank[character] = nil
		end
	end
end

return auras
