local module = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')

function module.isDataLoaded(plr: Player)
	return plr:FindFirstChild('DataLoaded')
end

function module.hasAura(plr, aura)
	if not module.isDataLoaded(plr) then return end
	
	local found = nil
	
	for i,v in plr.OwnedAuras:GetChildren() do
		if v.Value == aura then
			found = v
			break
		end
	end
	
	return found
end

local function hasAura(fol, aura)
	for i,v in fol:GetChildren() do
		if v.Value == aura then return v end 
	end
end

function module.giveAura(plr, aura)
	if not module.isDataLoaded(plr) then return end
	if aura == 'Nothing' then return end

	local has = hasAura(plr.OwnedAuras, aura)

	if ReplicatedStorage.Auras:FindFirstChild(aura) and not has then
		local val = Instance.new('StringValue')
		val.Name = #plr.OwnedAuras:GetChildren()
		val.Value = aura
		val.Parent = plr.OwnedAuras
	end
end

function module.removeAura(plr, aura)
	if not module.isDataLoaded(plr) then return end
	
	if plr.EquippedAura.Value == aura then
		plr.EquippedAura.Value = 'Nothing'
	end
	local has = hasAura(plr.OwnedAuras, aura)
	
	if has then
		has:Destroy()
	end
end


function module.unequipAura(plr)
	-- search through character to see if they have any auras then remove it
	if plr.Character then
		-- Remove Any:
		-- AuraEffect
		-- AuraAttachment
		-- AuraLight
		-- AuraWeld
		
		-- Remove Unknown Baseparts
		local objs = plr.Character:GetChildren()
		
		for i,v in pairs(objs) do
			if v:IsA('BasePart') then
				if v.Name ~= 'Head' and v.Name ~= 'Torso' and v.Name ~= 'Left Arm' and v.Name ~= 'Right Arm' and v.Name ~= 'Left Leg' and v.Name ~= 'Right Leg' and v.Name ~= 'HumanoidRootPart' then
					v:Destroy()
				end
			end
		end
		
		for i,v in pairs(plr.Character:GetDescendants()) do
			if v.Name == 'AuraEffect' or v.Name == 'AuraAttachment' or v.Name == 'AuraLight' or v.Name == 'AuraWeld' then
				v:Destroy()
			end
		end
		
		objs = nil
	end
end

function module.equipAura(plr, aura, bypass)
	if not module.isDataLoaded(plr) then return end
	if (module.hasAura(plr, aura) or bypass) and plr.Character then
		module.unequipAura(plr) -- clear aura
		
		plr.EquippedAura.Value = aura
		
		-- Set equippedAura value inside profileservice
		if aura ~= 'Nothing' and plr.Character then
			
			local Aura = ReplicatedStorage.Auras[aura]
			local AuraModel = Aura.Content.Model:Clone() -- Clone model with all attachment part references etc connected
			
			for i,v in pairs(AuraModel:GetDescendants()) do
				if v:IsA('ManualWeld') then
					local plrHasPart = plr.Character:FindFirstChild(v.Part1.Name)
					if plrHasPart then
						v.Part1 = plrHasPart
					else
						warn("Bad Aura configuration error: " .. aura)
					end
				end
			end
			
			for i,v in pairs(AuraModel:GetChildren()) do -- loop through model
				if plr.Character:FindFirstChild(v.Name) then -- check if players' character has same body-part
					for x,y in pairs(AuraModel[v.Name]:GetChildren()) do -- loop through a child of model
						y.Parent = plr.Character[v.Name] -- add it to character
					end
					AuraModel[v.Name]:Destroy()
				end
			end
			
			for i,v in pairs(AuraModel:GetChildren()) do
				v.Parent = plr.Character
			end
		
			AuraModel = nil
		end
	end
end

return module