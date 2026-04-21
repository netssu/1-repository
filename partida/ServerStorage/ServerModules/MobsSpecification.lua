local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local upgradesModule = require(ReplicatedStorage:WaitForChild("Upgrades"))

local function getEffectFolder(target)
	local folderName = "Debuffs"
	local folder = target:FindFirstChild(folderName)

	if not folder then
		folder = Instance.new("Configuration")
		folder.Name = folderName
		folder.Parent = target
	end

	return folder
end

local function findExistingEffect(source, target)
	local folder = getEffectFolder(target)
	for _, v in folder:GetChildren() do
		if v:IsA("ObjectValue") and v.Value == source then
			return v
		end
	end
	return nil
end

local function attachEmitterVisuals(source, target)
	local success, err = pcall(function()
		if not target:FindFirstChild("Torso") or target.Torso:FindFirstChild("UpgradeEmitter") then return end
		local visuals = script["Upgrade Aura"]
		
		for _, visualGroup in visuals:GetChildren() do
			local match = target:FindFirstChild(visualGroup.Name)
			if match then
				for _, emitter in visualGroup:GetChildren() do
					local cloned = emitter:Clone()
					cloned.Name = "UpgradeEmitter"
					cloned.Parent = match
				end
			end
		end
	end)

	if not success then
		warn(err)
	end
end

function module.applyEffect(source, target, effectType, statName, amount)
	print("Applying effect: " .. effectType, " to tower: " .. target.Name)
	
	local folder = getEffectFolder(target, effectType)
	local existing = findExistingEffect(source, target, effectType)
	if existing then
		existing:Destroy()
	end

	-- Visuals (optional)
	if effectType == "Debuff" then
		attachEmitterVisuals(source, target)
	end

	local objVal = Instance.new("ObjectValue")
	objVal.Name = source.Name
	objVal.Value = source

	local statVal = Instance.new("IntValue")
	statVal.Name = statName
	statVal.Value = amount
	statVal.Parent = objVal

	objVal.Parent = folder
end

function module.clearEffectsFromSource(source, tower, effectType)
	for _, target in workspace.Towers:GetChildren() do
		if target ~= tower then continue end
		
		local folder = getEffectFolder(target, effectType)
		for _, obj in folder:GetChildren() do
			if obj:IsA("ObjectValue") and obj.Value == source then
				obj:Destroy()
			end
		end

		for _, v in target:GetDescendants() do
			if v:IsA("ParticleEmitter") and v.Name == "UpgradeEmitter" then
				v:Destroy()
			end
		end
	end
end

return module
