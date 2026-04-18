--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RagdollSystem = require(ReplicatedStorage.Packages.RagdollSystem)
local AnimationController = require(ReplicatedStorage.Controllers.AnimationController)

local RAGDOLL_TAG = "Ragdoll"
local RAGDOLL_CONSTRAINTS_FOLDER = "RagdollConstraints"

local LocalPlayer = Players.LocalPlayer
local FTRagdollController = {}

local Initialized = false
local PendingReplicatedRagdolls: {[Model]: boolean} = {}

local function PlayLocalStandUpAnimation(): ()
	local Character = LocalPlayer.Character
	if not Character then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then
		return
	end

	AnimationController.PlayStandUpAnimation()
end

local function ActivateLocalRagdollPhysics(): ()
	local ragdoll = RagdollSystem:getLocalRagdoll()
	if not ragdoll or ragdoll:isRagdolled() then
		return
	end

	ragdoll:activateRagdollPhysics()
	RagdollSystem.Remotes.ActivateRagdoll:FireServer()
end

local function DeactivateLocalRagdollPhysics(): ()
	local ragdoll = RagdollSystem:getLocalRagdoll()
	if not ragdoll or not ragdoll:isRagdolled() then
		return
	end

	ragdoll:deactivateRagdollPhysics()
	RagdollSystem.Remotes.DeactivateRagdoll:FireServer()
end

local function CollapseLocalRagdoll(): ()
	local ragdoll = RagdollSystem:getLocalRagdoll()
	if not ragdoll then
		return
	end

	ragdoll:collapse()
	RagdollSystem.Remotes.CollapseRagdoll:FireServer()
end

local function SetLocalCameraSubject(subject: Instance?): ()
	local currentCamera = Workspace.CurrentCamera
	if currentCamera and subject then
		currentCamera.CameraSubject = subject
	end
end

local function OnRagdollConstructed(ragdoll: any): ()
	if ragdoll.Character ~= LocalPlayer.Character then
		return
	end

	RagdollSystem:setLocalRagdoll(ragdoll)

	ragdoll.RagdollBegan:Connect(function()
		SetLocalCameraSubject(ragdoll.Character:FindFirstChild("Head"))
	end)

	ragdoll.RagdollEnded:Connect(function()
		SetLocalCameraSubject(ragdoll.Humanoid)
		task.defer(PlayLocalStandUpAnimation)
	end)
end

local function OnRagdollAdded(ragdollModel: Instance): ()
	if not ragdollModel:IsA("Model") then
		return
	end

	if PendingReplicatedRagdolls[ragdollModel] then
		return
	end

	local humanoid = ragdollModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		local waited = ragdollModel:WaitForChild("Humanoid", 5)
		if not waited or not waited:IsA("Humanoid") then
			return
		end
	end

	if not RagdollSystem:getRagdoll(ragdollModel) then
		PendingReplicatedRagdolls[ragdollModel] = true
		local constraintsFolder = ragdollModel:FindFirstChild(RAGDOLL_CONSTRAINTS_FOLDER)
			or ragdollModel:WaitForChild(RAGDOLL_CONSTRAINTS_FOLDER, 5)
		if not constraintsFolder then
			PendingReplicatedRagdolls[ragdollModel] = nil
			return
		end
		local success, result = pcall(function()
			return RagdollSystem:replicateRagdoll(ragdollModel)
		end)
		PendingReplicatedRagdolls[ragdollModel] = nil
		if not success then
			warn(string.format("FTRagdollController: failed to replicate ragdoll for %s: %s", ragdollModel:GetFullName(), tostring(result)))
			return
		end
	end

	if ragdollModel:GetAttribute("Ragdolled") == true then
		RagdollSystem:activateRagdoll(ragdollModel)
	end
end

function FTRagdollController.Init(): ()
	if Initialized then
		return
	end
	Initialized = true

	RagdollSystem.Signals.ActivateLocalRagdoll:Connect(ActivateLocalRagdollPhysics)
	RagdollSystem.Signals.DeactivateLocalRagdoll:Connect(DeactivateLocalRagdollPhysics)
	RagdollSystem.Signals.CollapseLocalRagdoll:Connect(CollapseLocalRagdoll)

	RagdollSystem.Signals.ActivateRagdoll:Connect(function(ragdollModel: Model)
		if ragdollModel == LocalPlayer.Character then
			ActivateLocalRagdollPhysics()
			return
		end

		local ragdoll = RagdollSystem:getRagdoll(ragdollModel)
		if not ragdoll then
			return
		end

		if RagdollSystem._activeRagdolls < RagdollSystem:getSystemSettings().LowDetailModeThreshold then
			ragdoll:activateRagdollPhysics()
		else
			ragdoll:activateRagdollPhysicsLowDetail()
		end
	end)

	RagdollSystem.Signals.DeactivateRagdoll:Connect(function(ragdollModel: Model)
		if ragdollModel == LocalPlayer.Character then
			DeactivateLocalRagdollPhysics()
			return
		end

		local ragdoll = RagdollSystem:getRagdoll(ragdollModel)
		if ragdoll then
			ragdoll:deactivateRagdollPhysics()
		end
	end)

	RagdollSystem.Signals.CollapseRagdoll:Connect(function(ragdollModel: Model)
		if ragdollModel == LocalPlayer.Character then
			CollapseLocalRagdoll()
			return
		end

		local ragdoll = RagdollSystem:getRagdoll(ragdollModel)
		if not ragdoll then
			return
		end

		if RagdollSystem._activeRagdolls < RagdollSystem:getSystemSettings().LowDetailModeThreshold then
			ragdoll:collapse()
		else
			ragdoll:collapseLowDetail()
		end
	end)

	RagdollSystem.RagdollConstructed:Connect(OnRagdollConstructed)

	for _, ragdollModel in CollectionService:GetTagged(RAGDOLL_TAG) do
		task.spawn(OnRagdollAdded, ragdollModel)
	end

	CollectionService:GetInstanceAddedSignal(RAGDOLL_TAG):Connect(OnRagdollAdded)
	CollectionService:GetInstanceRemovedSignal(RAGDOLL_TAG):Connect(function(ragdollModel: Instance)
		if ragdollModel:IsA("Model") then
			RagdollSystem:removeRagdoll(ragdollModel)
		end
	end)

	RagdollSystem.RagdollFactory._blueprintAdded:Connect(function(blueprint: any)
		for model, oldRagdoll in RagdollSystem._ragdolls do
			if not blueprint.satisfiesRequirements(model) then
				continue
			end

			oldRagdoll:destroy()
			RagdollSystem._ragdolls[model] = nil
			RagdollSystem:replicateRagdoll(model, blueprint)
		end
	end)
end

function FTRagdollController.Start(): ()
end

return FTRagdollController
