--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local FlowBuffs: any = require(ReplicatedStorage.Modules.Game.FlowBuffs)
local SharedSkills: any = require(ReplicatedStorage.Modules.Game.Skills)
local PlayerDataGuard: any = require(ReplicatedStorage.Modules.Game.PlayerDataGuard)
local SkillAssetPreloader: any = require(ReplicatedStorage.Modules.Game.Skills.Utils.SkillAssetPreloader)
local CameraController: any = require(ReplicatedStorage.Controllers.CameraController)
local SennaAwaken: any = require(script.SennaAwaken)
local HirumaAwaken: any = require(script.HirumaAwaken)
local FatGuyAwaken: any = require(script.FatGuyAwaken)
local TesterAwaken: any = require(script.TesterAwaken)
local HirumaPerfectPass: any = require(script.HirumaPerfectPass)

type SharedSkillsModule = typeof(SharedSkills)
type AwakenController = {
	HandleStatus: ((Status: string, Duration: number) -> ())?,
	Cleanup: () -> (),
	CleanupCutsceneOnly: (() -> ())?,
	PlayForPlayer: ((SourcePlayer: Player, CutsceneDuration: number?) -> ())?,
}

local Initi = {}
local LocalPlayer: Player = Players.LocalPlayer
local SkillsData: SharedSkillsModule = SharedSkills

local ZERO: number = 0
local ONE: number = 1
local AWAKEN_STATUS_START: string = "Start"
local DEFAULT_WALKSPEED: number = 16
local DEFAULT_JUMPPOWER: number = 50
local DEFAULT_JUMPHEIGHT: number = 7.2
local ATTR_SKILL_LOCKED: string = "FTSkillLocked"
local ATTR_AWAKEN_CUTSCENE_ACTIVE: string = "FTAwakenCutsceneActive"
local ATTR_CUTSCENE_HUD_HIDDEN: string = "FTCutsceneHudHidden"
local IsInitialized: boolean = false
local AwakenCutsceneFailsafeToken: number = 0
local AWAKEN_SHIFTLOCK_BLOCKERS: {string} = {
	"FatGuyAwaken",
	"HirumaAwaken",
	"SennaAwaken",
	"TesterAwaken",
}

local AwakenControllers: {[string]: AwakenController} = {
	SennaAwaken = SennaAwaken,
	HirumaAwaken = HirumaAwaken,
	FatGuyAwaken = FatGuyAwaken,
	TesterAwaken = TesterAwaken,
}

local function ForceReleaseLocalAwakenState(): ()
	local Character: Model? = LocalPlayer.Character
	local Root: BasePart? = if Character then Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local HumanoidInstance: Humanoid? = if Character then Character:FindFirstChildOfClass("Humanoid") else nil

	local HadAwakenState: boolean =
		LocalPlayer:GetAttribute(ATTR_AWAKEN_CUTSCENE_ACTIVE) == true
		or LocalPlayer:GetAttribute(ATTR_CUTSCENE_HUD_HIDDEN) == true
		or LocalPlayer:GetAttribute(ATTR_SKILL_LOCKED) == true
		or (
			Character ~= nil
			and (
				Character:GetAttribute(ATTR_AWAKEN_CUTSCENE_ACTIVE) == true
				or Character:GetAttribute(ATTR_CUTSCENE_HUD_HIDDEN) == true
				or Character:GetAttribute(ATTR_SKILL_LOCKED) == true
			)
		)
		or (Root ~= nil and Root.Anchored)
		or (
			HumanoidInstance ~= nil
			and (
				HumanoidInstance.WalkSpeed <= ZERO
				or (HumanoidInstance.UseJumpPower and HumanoidInstance.JumpPower <= ZERO)
				or (not HumanoidInstance.UseJumpPower and HumanoidInstance.JumpHeight <= ZERO)
			)
		)

	if not HadAwakenState then
		return
	end

	LocalPlayer:SetAttribute(ATTR_AWAKEN_CUTSCENE_ACTIVE, false)
	LocalPlayer:SetAttribute(ATTR_CUTSCENE_HUD_HIDDEN, false)
	LocalPlayer:SetAttribute(ATTR_SKILL_LOCKED, false)

	if Character then
		Character:SetAttribute(ATTR_AWAKEN_CUTSCENE_ACTIVE, false)
		Character:SetAttribute(ATTR_CUTSCENE_HUD_HIDDEN, false)
		Character:SetAttribute(ATTR_SKILL_LOCKED, false)
	end

	if Root then
		Root.Anchored = false
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end

	if HumanoidInstance then
		if HumanoidInstance.WalkSpeed <= ZERO then
			FlowBuffs.ApplyHumanoidWalkSpeed(LocalPlayer, HumanoidInstance, DEFAULT_WALKSPEED)
		end

		if HumanoidInstance.UseJumpPower then
			if HumanoidInstance.JumpPower <= ZERO then
				HumanoidInstance.JumpPower = DEFAULT_JUMPPOWER
			end
		elseif HumanoidInstance.JumpHeight <= ZERO then
			HumanoidInstance.JumpHeight = DEFAULT_JUMPHEIGHT
		end

		HumanoidInstance.AutoRotate = true
		HumanoidInstance.PlatformStand = false
		HumanoidInstance.Sit = false
	end

	if CameraController and CameraController.SetShiftlockBlocked then
		for _, BlockerName in AWAKEN_SHIFTLOCK_BLOCKERS do
			CameraController:SetShiftlockBlocked(BlockerName, false)
		end
	end

	if CameraController and CameraController.RefreshShiftlockState then
		task.defer(function()
			CameraController:RefreshShiftlockState()
		end)
	end
end

local function GetAwakenControllerForStyle(StyleId: string): (string?, AwakenController?)
	local ControllerName: string? = SkillsData.GetAwakenVFXControllerName(StyleId)
	if not ControllerName then
		return nil, nil
	end
	return ControllerName, AwakenControllers[ControllerName]
end

local function GetStyleId(): string
	local SelectedSlot: number = PlayerDataGuard.GetOrDefault(LocalPlayer, {"SelectedSlot"}, ONE)
	local Slots: {[string]: string} = PlayerDataGuard.GetOrDefault(LocalPlayer, {"StyleSlots"}, {})
	return SkillsData.ResolveStyleFromSlots(SelectedSlot, Slots)
end

local function CleanupAllAwakenControllers(): ()
	for _, Controller in AwakenControllers do
		Controller.Cleanup()
	end
	HirumaPerfectPass.Cleanup()
end

local function CleanupControllersForPerfectPass(): ()
	for Name, Controller in AwakenControllers do
		if Name == "HirumaAwaken" and Controller.CleanupCutsceneOnly then
			Controller.CleanupCutsceneOnly()
		else
			Controller.Cleanup()
		end
	end
	HirumaPerfectPass.Cleanup()
end

local function StartAwakenController(
	Controller: AwakenController,
	StyleId: string,
	Status: string,
	Duration: number
): ()
	if type(Controller.HandleStatus) == "function" then
		Controller.HandleStatus(Status, Duration)
		return
	end

	local CutsceneDuration: number = math.max(SkillsData.GetAwakenCutsceneDuration(StyleId), ZERO)
	if type(Controller.PlayForPlayer) == "function" then
		Controller.PlayForPlayer(LocalPlayer, CutsceneDuration)
		return
	end

	Controller.Cleanup()
end

local function StopAwakenController(Controller: AwakenController, Status: string, Duration: number): ()
	if type(Controller.HandleStatus) == "function" then
		Controller.HandleStatus(Status, Duration)
		return
	end

	if Controller.CleanupCutsceneOnly then
		Controller.CleanupCutsceneOnly()
		return
	end

	Controller.Cleanup()
end

local function HandleAwakenStatus(Status: string, Duration: number): ()
	if typeof(Status) ~= "string" then
		return
	end

	AwakenCutsceneFailsafeToken += 1
	if Status == AWAKEN_STATUS_START then
		local StyleId: string = GetStyleId()
		local ControllerName: string?, CurrentController: AwakenController? = GetAwakenControllerForStyle(StyleId)
		local FailsafeToken: number = AwakenCutsceneFailsafeToken

		for Name, Controller in AwakenControllers do
			if not ControllerName or Name ~= ControllerName then
				Controller.Cleanup()
			end
		end

		if CurrentController then
			StartAwakenController(CurrentController, StyleId, Status, Duration)
		end
		local CutsceneDuration: number = math.max(SkillsData.GetAwakenCutsceneDuration(StyleId), ZERO)
		if CutsceneDuration > ZERO then
			task.delay(CutsceneDuration + 0.35, function()
				if AwakenCutsceneFailsafeToken ~= FailsafeToken then
					return
				end
				local Character: Model? = LocalPlayer.Character
				local CutsceneStillActive: boolean =
					LocalPlayer:GetAttribute(ATTR_AWAKEN_CUTSCENE_ACTIVE) == true
					or LocalPlayer:GetAttribute(ATTR_CUTSCENE_HUD_HIDDEN) == true
					or LocalPlayer:GetAttribute(ATTR_SKILL_LOCKED) == true
					or (
						Character ~= nil
						and (
							Character:GetAttribute(ATTR_AWAKEN_CUTSCENE_ACTIVE) == true
							or Character:GetAttribute(ATTR_CUTSCENE_HUD_HIDDEN) == true
							or Character:GetAttribute(ATTR_SKILL_LOCKED) == true
						)
					)
				if not CutsceneStillActive then
					return
				end
				if CurrentController and CurrentController.CleanupCutsceneOnly then
					CurrentController.CleanupCutsceneOnly()
				end
				task.defer(ForceReleaseLocalAwakenState)
			end)
		end
		return
	end

	for _, Controller in AwakenControllers do
		StopAwakenController(Controller, Status, Duration)
	end
	task.defer(ForceReleaseLocalAwakenState)
end

local function HandleAwakenCutscene(StyleId: string, SourceUserId: number, CutsceneDuration: number): ()
	if typeof(StyleId) ~= "string" or type(SourceUserId) ~= "number" then
		return
	end

	local SourcePlayer: Player? = Players:GetPlayerByUserId(math.floor(SourceUserId + 0.5))
	if not SourcePlayer or SourcePlayer == LocalPlayer then
		return
	end

	local _ControllerName: string?, Controller: AwakenController? = GetAwakenControllerForStyle(StyleId)
	if not Controller or not Controller.PlayForPlayer then
		return
	end

	CleanupAllAwakenControllers()
	Controller.PlayForPlayer(SourcePlayer, CutsceneDuration)
end

local function HandlePerfectPassCutscene(
	SourceUserId: number,
	AnchorPosition: Vector3,
	AnchorForward: Vector3,
	Duration: number,
	ServerToken: number,
	EnemyOneUserId: number,
	EnemyTwoUserId: number,
	ReceiverUserId: number
): ()
	if typeof(SourceUserId) ~= "number"
		or typeof(AnchorPosition) ~= "Vector3"
		or typeof(AnchorForward) ~= "Vector3"
		or typeof(ServerToken) ~= "number"
	then
		return
	end

	CleanupControllersForPerfectPass()
	HirumaPerfectPass.Play(
		SourceUserId,
		AnchorPosition,
		AnchorForward,
		Duration,
		ServerToken,
		EnemyOneUserId,
		EnemyTwoUserId,
		ReceiverUserId
	)
end

function Initi.Init(): ()
	if IsInitialized then
		return
	end
	IsInitialized = true

	task.defer(function()
		SkillAssetPreloader.PreloadAll()
		SkillAssetPreloader.PreloadForCharacter(LocalPlayer.Character)
	end)

	LocalPlayer.CharacterAdded:Connect(function(Character: Model)
		task.defer(function()
			SkillAssetPreloader.PreloadForCharacter(Character)
		end)
	end)

	Packets.AwakenStatus.OnClientEvent:Connect(HandleAwakenStatus)
	Packets.AwakenCutscene.OnClientEvent:Connect(HandleAwakenCutscene)
	Packets.PerfectPassCutscene.OnClientEvent:Connect(HandlePerfectPassCutscene)
end

function Initi.Cleanup(): ()
	CleanupAllAwakenControllers()
	ForceReleaseLocalAwakenState()
end

return Initi
