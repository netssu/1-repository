local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local module = {}

function module.emitVFX(obj: Instance)
	if RunService:IsClient() then
		for i,v in obj:GetDescendants() do
			if v:IsA('ParticleEmitter') then
				v:Emit()
			end
		end
	else
		ReplicatedStorage.Remotes.Client.EmitVFX:FireAllClients(obj)
	end
end

function module.enableVFX(obj: Instance)
	for i,v in obj:GetDescendants() do
		if v:IsA('ParticleEmitter') or v:IsA('Beam') or v:IsA('PointLight') then
			v.Enabled = true
		end
	end
end

function module.cutVFX(obj: Instance) 
	for i,v in obj:GetDescendants() do
		if v:IsA('ParticleEmitter') or v:IsA('Beam') or v:IsA('PointLight') then
			v.Enabled = false
		end
	end
end

return module