local module = {}

--.applyBuff(script.Parent, tower, "BuffType", amount)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Upgrades = require(ReplicatedStorage.Upgrades)
local Towers = workspace.Towers
local upgradesModule = require(ReplicatedStorage.Upgrades)

local function mag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local function unitApplyingBuff(source, tower)
	local found = false
	
	if tower:FindFirstChild('Buffs') then
		for i,v in tower.Buffs:GetChildren() do
			if v.Value.Name == source.Name then
				found = v
				break
			end
		end
	end
	
	return found
end

function module.applyBuff(tower, target, buffType, amount)
	local config = tower.Config
	--local damage = config.Damage.Value
	local upgradeStats = upgradesModule[tower.Name]["Upgrades"][config.Upgrades.Value]
	local found = unitApplyingBuff(tower, target)
	
	if found then
		local foundNum = found:FindFirstChildOfClass('NumberValue')
		
		if foundNum then
			if foundNum.Value == amount then
				return -- no need to apply it again i think
			else
			end
		end
		
		found:Destroy()
	end
	
	if not target:FindFirstChild('Buffs') then
		Instance.new("Configuration", target).Name = 'Buffs'
	end
	
	local s,e = pcall(function()
		if not target.Torso:FindFirstChild('UpgradeEmitter') then
			for i,v in script["Upgrade Aura"]:GetChildren() do
				if target:FindFirstChild(v.Name) then
					for i, emitter in v:GetChildren() do
						local cloned = emitter:Clone()
						cloned.Parent = target[v.Name]
					end
				end
			end
		end
	end)
	
	if not s then
		warn(e)
	end
	
	local objVal = Instance.new('ObjectValue')
	objVal.Name = tower.Name
	objVal.Value = tower
	
	local StringVal = Instance.new('NumberValue', objVal)
	StringVal.Name = buffType
	StringVal.Value = amount
	
	objVal.Parent = target.Buffs
end

function module.clearBuffs(tower)
	for i, target in workspace.Towers:GetChildren() do
		local found = unitApplyingBuff(tower, target)
		
		if found then
			found:Destroy()
		end
		
		for i,v in target:GetDescendants() do
			if v.Name == 'UpgradeEmitter' then
				v:Destroy()
			end
		end
	end
end

return module