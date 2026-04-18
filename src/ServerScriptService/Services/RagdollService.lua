--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RagdollSystem = require(ReplicatedStorage.Packages.RagdollSystem)

local RAGDOLL_TAG = "Ragdoll"

local FTRagdollService = {}

local Initialized = false

local function ActivateRagdollPhysics(ragdoll: any): ()
	if RagdollSystem._activeRagdolls < RagdollSystem:getSystemSettings().LowDetailModeThreshold then
		ragdoll:activateRagdollPhysics()
	else
		ragdoll:activateRagdollPhysicsLowDetail()
	end
end

local function DeactivateRagdollPhysics(ragdoll: any): ()
	if ragdoll.Humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
		ragdoll:deactivateRagdollPhysics()
	end
end

local function CollapseRagdoll(ragdoll: any): ()
	if RagdollSystem._activeRagdolls < RagdollSystem:getSystemSettings().LowDetailModeThreshold then
		ragdoll:collapse()
	else
		ragdoll:collapseLowDetail()
	end
end

function FTRagdollService.Init(_self: typeof(FTRagdollService)): ()
	if Initialized then
		return
	end
	Initialized = true

	RagdollSystem.Remotes.ActivateRagdoll.OnServerEvent:Connect(function(player: Player)
		local ragdoll = RagdollSystem:getPlayerRagdoll(player)
		if ragdoll then
			ActivateRagdollPhysics(ragdoll)
		end
	end)

	RagdollSystem.Remotes.DeactivateRagdoll.OnServerEvent:Connect(function(player: Player)
		local ragdoll = RagdollSystem:getPlayerRagdoll(player)
		if ragdoll then
			DeactivateRagdollPhysics(ragdoll)
		end
	end)

	RagdollSystem.Remotes.CollapseRagdoll.OnServerEvent:Connect(function(player: Player)
		local ragdoll = RagdollSystem:getPlayerRagdoll(player)
		if ragdoll then
			CollapseRagdoll(ragdoll)
		end
	end)

	RagdollSystem.Signals.ActivateRagdoll:Connect(function(ragdollModel: Model)
		local ragdoll = RagdollSystem:getRagdoll(ragdollModel)
		if ragdoll then
			ActivateRagdollPhysics(ragdoll)
		end
	end)

	RagdollSystem.Signals.DeactivateRagdoll:Connect(function(ragdollModel: Model)
		local ragdoll = RagdollSystem:getRagdoll(ragdollModel)
		if ragdoll then
			DeactivateRagdollPhysics(ragdoll)
		end
	end)

	RagdollSystem.Signals.CollapseRagdoll:Connect(function(ragdollModel: Model)
		local ragdoll = RagdollSystem:getRagdoll(ragdollModel)
		if ragdoll then
			CollapseRagdoll(ragdoll)
		end
	end)

	CollectionService:GetInstanceRemovedSignal(RAGDOLL_TAG):Connect(function(ragdollModel: Instance)
		if ragdollModel:IsA("Model") then
			RagdollSystem:removeRagdoll(ragdollModel)
		end
	end)

	RagdollSystem.RagdollFactory._blueprintAdded:Connect(function(blueprint: any)
		for model, ragdoll in RagdollSystem._ragdolls do
			if not blueprint.satisfiesRequirements(model) then
				continue
			end

			ragdoll:destroy()
			RagdollSystem._ragdolls[model] = nil
			RagdollSystem:addRagdoll(model, blueprint)
		end
	end)
end

function FTRagdollService.Start(_self: typeof(FTRagdollService)): ()
end

return FTRagdollService
