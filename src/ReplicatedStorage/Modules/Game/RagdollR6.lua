--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packets = require(ReplicatedStorage.Modules.Game.Packets)

local RAGDOLL_TAG = "Ragdoll"
local RAGDOLLED_ATTRIBUTE = "Ragdolled"
local RAGDOLL_CONSTRAINTS_FOLDER = "RagdollConstraints"

type RagdollState = {
	Token: number,
	Ragdoll: any?,
}

local States: {[Model]: RagdollState} = {}

local CachedRagdollSystem: any = nil
local PendingRagdollCreation: {[Model]: boolean} = {}

local function ResolveExistingConstraintsFolder(Character: Model, PreferredFolder: Folder?): Folder?
	local ResolvedPreferredFolder = PreferredFolder

	if ResolvedPreferredFolder and ResolvedPreferredFolder.Parent ~= Character then
		ResolvedPreferredFolder = nil
	end

	for _, Child in Character:GetChildren() do
		if Child:IsA("Folder") and Child.Name == RAGDOLL_CONSTRAINTS_FOLDER then
			local HasSockets = Child:FindFirstChild("BallSocketConstraints") ~= nil
			local HasNoCollisions = Child:FindFirstChild("NoCollisionConstraints") ~= nil
			local IsValidFolder = HasSockets and HasNoCollisions
			if not IsValidFolder then
				if Child == ResolvedPreferredFolder then
					ResolvedPreferredFolder = nil
				end
				Child:Destroy()
			elseif ResolvedPreferredFolder == nil then
				ResolvedPreferredFolder = Child
			elseif Child ~= ResolvedPreferredFolder then
				Child:Destroy()
			end
		end
	end

	return ResolvedPreferredFolder
end

local function FindVersionedPackageModule(prefix: string, moduleName: string): ModuleScript?
	local PackagesFolder = ReplicatedStorage:WaitForChild("Packages")
	local IndexFolder = PackagesFolder:WaitForChild("_Index")
	for _, child in IndexFolder:GetChildren() do
		if child:IsA("Folder") and string.sub(child.Name, 1, #prefix) == prefix then
			local packageModule = child:FindFirstChild(moduleName)
			if packageModule and packageModule:IsA("ModuleScript") then
				return packageModule
			end
		end
	end
	return nil
end

local function GetRagdollSystem(): any
	if CachedRagdollSystem ~= nil then
		return CachedRagdollSystem
	end

	local packagesFolder = ReplicatedStorage:FindFirstChild("Packages")
	local directModule = packagesFolder and packagesFolder:FindFirstChild("RagdollSystem")
	if directModule and directModule:IsA("ModuleScript") then
		CachedRagdollSystem = require(directModule)
		return CachedRagdollSystem
	end

	local packageModule = FindVersionedPackageModule("leostormer_ragdoll-system@", "ragdoll-system")
	if not packageModule then
		error("RagdollSystem package module not found in ReplicatedStorage.Packages")
	end

	CachedRagdollSystem = require(packageModule)
	return CachedRagdollSystem
end

local function EnsureRagdoll(Character: Model): any?
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Humanoid or not Root or not Root:IsA("BasePart") then
		return nil
	end

	local RagdollSystem = GetRagdollSystem()
	local ExistingRagdoll = RagdollSystem:getRagdoll(Character)
	if ExistingRagdoll then
		ResolveExistingConstraintsFolder(Character, ExistingRagdoll._constraintsFolder)
		return ExistingRagdoll
	end

	if not CollectionService:HasTag(Character, RAGDOLL_TAG) then
		CollectionService:AddTag(Character, RAGDOLL_TAG)
	end

	if PendingRagdollCreation[Character] then
		local deadline = os.clock() + 1
		repeat
			task.wait()
			ExistingRagdoll = RagdollSystem:getRagdoll(Character)
			if ExistingRagdoll then
				return ExistingRagdoll
			end
		until Character.Parent == nil or os.clock() >= deadline or not PendingRagdollCreation[Character]
		return RagdollSystem:getRagdoll(Character)
	end

	PendingRagdollCreation[Character] = true

	local Success: boolean, Result: any = pcall(function()
		local ConstraintsFolder = ResolveExistingConstraintsFolder(Character)
		if ConstraintsFolder then
			local ReplicatedRagdoll = RagdollSystem:replicateRagdoll(Character)
			ResolveExistingConstraintsFolder(Character, ReplicatedRagdoll and ReplicatedRagdoll._constraintsFolder)
			return ReplicatedRagdoll
		end
		local CreatedRagdoll = RagdollSystem:addRagdoll(Character)
		ResolveExistingConstraintsFolder(Character, CreatedRagdoll and CreatedRagdoll._constraintsFolder)
		return CreatedRagdoll
	end)

	PendingRagdollCreation[Character] = nil

	if not Success then
		warn(string.format("RagdollR6: failed to construct ragdoll for %s: %s", Character:GetFullName(), tostring(Result)))
		return nil
	end

	return Result
end

local function NotifyRagdollState(Character: Model, Enabled: boolean, Duration: number?): ()
	if not RunService:IsServer() then
		return
	end

	local Player = Players:GetPlayerFromCharacter(Character)
	if not Player or not Packets.RagdollState then
		return
	end

	Packets.RagdollState:FireClient(Player, Enabled, math.max(Duration or 0, 0))
end

local RagdollR6 = {}

function RagdollR6.Apply(Character: Model, Duration: number?): ()
	if not Character or not Character:IsA("Model") then
		return
	end

	local State = States[Character]
	if not State then
		State = {
			Token = 0,
		}
		States[Character] = State
	end

	State.Token += 1
	local Token = State.Token

	local Ragdoll = EnsureRagdoll(Character)
	if not Ragdoll then
		return
	end

	State.Ragdoll = Ragdoll
	if not Ragdoll:isRagdolled() then
		Ragdoll:activateRagdollPhysics()
	end
	Character:SetAttribute(RAGDOLLED_ATTRIBUTE, true)
	NotifyRagdollState(Character, true, Duration)

	if Duration and Duration > 0 then
		task.delay(Duration, function()
			if Character.Parent == nil then
				States[Character] = nil
				return
			end

			local CurrentState = States[Character]
			if CurrentState and CurrentState.Token == Token then
				RagdollR6.Clear(Character)
			end
		end)
	end
end

function RagdollR6.Clear(Character: Model): ()
	if not Character or not Character:IsA("Model") then
		return
	end

	local State = States[Character]
	local Ragdoll = State and State.Ragdoll
	if not Ragdoll then
		local RagdollSystem = GetRagdollSystem()
		Ragdoll = RagdollSystem:getRagdoll(Character)
	end

	if Ragdoll and Ragdoll:isRagdolled() then
		Ragdoll:deactivateRagdollPhysics()
	end

	States[Character] = nil
	Character:SetAttribute(RAGDOLLED_ATTRIBUTE, false)
	NotifyRagdollState(Character, false, 0)
end

return RagdollR6
