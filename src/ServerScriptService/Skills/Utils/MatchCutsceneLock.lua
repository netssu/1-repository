--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local FlowBuffs = require(ReplicatedStorage.Modules.Game.FlowBuffs)

local DEFAULT_WALKSPEED: number = 16
local DEFAULT_JUMPPOWER: number = 50
local DEFAULT_JUMPHEIGHT: number = 7.2
local ZERO: number = 0
local POSITION_EPSILON: number = 0.05

local ATTR_SKILL_LOCKED: string = "FTSkillLocked"
local DEFAULT_CUTSCENE_ATTRIBUTE: string = "FTMatchCutsceneLocked"

type MatchCutsceneLockOptions = {
	CutsceneAttributeName: string?,
	AnchorRoot: boolean?,
	EnforcePivot: boolean?,
}

type LockedCharacterState = {
	Character: Model?,
	DesiredPivot: CFrame?,
	RootAnchoredBefore: boolean?,
	HumanoidAutoRotateBefore: boolean?,
	HumanoidWalkSpeedBefore: number?,
	HumanoidJumpPowerBefore: number?,
	HumanoidJumpHeightBefore: number?,
	HumanoidUseJumpPowerBefore: boolean?,
}

type LockedPlayerState = {
	PlayerSkillLockedBefore: boolean?,
	CharacterState: LockedCharacterState,
	CharacterConnection: RBXScriptConnection?,
}

export type MatchCutsceneLock = {
	Active: boolean,
	Token: number,
	CutsceneAttributeName: string,
	AnchorRoot: boolean,
	EnforcePivot: boolean,
	LockedPlayers: {[Player]: LockedPlayerState},
	EnforceConnection: RBXScriptConnection?,
	Start: (self: MatchCutsceneLock, PlayersToLock: {Player}, Duration: number) -> number,
	CaptureCurrentPivots: (self: MatchCutsceneLock, PlayersToCapture: {Player}?) -> (),
	Stop: (self: MatchCutsceneLock, Token: number?) -> (),
	Destroy: (self: MatchCutsceneLock) -> (),
}

local MatchCutsceneLock = {}
MatchCutsceneLock.__index = MatchCutsceneLock

local function ResetCharacterState(State: LockedCharacterState): ()
	State.Character = nil
	State.DesiredPivot = nil
	State.RootAnchoredBefore = nil
	State.HumanoidAutoRotateBefore = nil
	State.HumanoidWalkSpeedBefore = nil
	State.HumanoidJumpPowerBefore = nil
	State.HumanoidJumpHeightBefore = nil
	State.HumanoidUseJumpPowerBefore = nil
end

local function EnsurePlayerState(self: MatchCutsceneLock, Player: Player): LockedPlayerState
	local Existing: LockedPlayerState? = self.LockedPlayers[Player]
	if Existing then
		return Existing
	end

	local NewState: LockedPlayerState = {
		PlayerSkillLockedBefore = Player:GetAttribute(ATTR_SKILL_LOCKED) == true,
		CharacterState = {
			Character = nil,
			DesiredPivot = nil,
			RootAnchoredBefore = nil,
			HumanoidAutoRotateBefore = nil,
			HumanoidWalkSpeedBefore = nil,
			HumanoidJumpPowerBefore = nil,
			HumanoidJumpHeightBefore = nil,
			HumanoidUseJumpPowerBefore = nil,
		},
		CharacterConnection = nil,
	}
	self.LockedPlayers[Player] = NewState
	return NewState
end

local function SetLockAttributes(
	CutsceneAttributeName: string,
	Player: Player,
	Character: Model?,
	Locked: boolean,
	MatchCutsceneLocked: boolean
): ()
	Player:SetAttribute(ATTR_SKILL_LOCKED, Locked)
	Player:SetAttribute(CutsceneAttributeName, MatchCutsceneLocked)
	if Character then
		Character:SetAttribute(ATTR_SKILL_LOCKED, Locked)
		Character:SetAttribute(CutsceneAttributeName, MatchCutsceneLocked)
	end
end

local function ApplyCharacterLock(self: MatchCutsceneLock, Player: Player, State: LockedPlayerState, Character: Model): ()
	local CharacterState: LockedCharacterState = State.CharacterState
	local PreviousDesiredPivot: CFrame? = CharacterState.DesiredPivot
	ResetCharacterState(CharacterState)
	CharacterState.Character = Character
	CharacterState.DesiredPivot = PreviousDesiredPivot or Character:GetPivot()

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if Root then
		CharacterState.RootAnchoredBefore = Root.Anchored
		if self.AnchorRoot then
			Root.Anchored = true
		end
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end

	local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
	if HumanoidInstance then
		CharacterState.HumanoidAutoRotateBefore = HumanoidInstance.AutoRotate
		CharacterState.HumanoidWalkSpeedBefore = HumanoidInstance.WalkSpeed
		CharacterState.HumanoidJumpPowerBefore = HumanoidInstance.JumpPower
		CharacterState.HumanoidJumpHeightBefore = HumanoidInstance.JumpHeight
		CharacterState.HumanoidUseJumpPowerBefore = HumanoidInstance.UseJumpPower

		HumanoidInstance.AutoRotate = false
		HumanoidInstance.WalkSpeed = ZERO
		if HumanoidInstance.UseJumpPower then
			HumanoidInstance.JumpPower = ZERO
		else
			HumanoidInstance.JumpHeight = ZERO
		end
		HumanoidInstance.PlatformStand = false
		HumanoidInstance.Sit = false
	end

	SetLockAttributes(self.CutsceneAttributeName, Player, Character, true, true)
end

local function EnforceLockedCharacter(self: MatchCutsceneLock, State: LockedPlayerState): ()
	local CharacterState: LockedCharacterState = State.CharacterState
	local Character: Model? = CharacterState.Character
	local DesiredPivot: CFrame? = CharacterState.DesiredPivot
	if not Character or Character.Parent == nil or not DesiredPivot then
		return
	end

	if self.EnforcePivot then
		local CurrentPivot: CFrame = Character:GetPivot()
		if (CurrentPivot.Position - DesiredPivot.Position).Magnitude > POSITION_EPSILON then
			Character:PivotTo(DesiredPivot)
		end
	end

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if Root then
		if self.AnchorRoot then
			Root.Anchored = true
		end
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end

	local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
	if HumanoidInstance then
		HumanoidInstance.WalkSpeed = ZERO
		if HumanoidInstance.UseJumpPower then
			HumanoidInstance.JumpPower = ZERO
		else
			HumanoidInstance.JumpHeight = ZERO
		end
		HumanoidInstance.AutoRotate = false
		HumanoidInstance.PlatformStand = false
		HumanoidInstance.Sit = false
		HumanoidInstance:Move(Vector3.zero, false)
	end
end

local function RestoreCharacterLock(self: MatchCutsceneLock, Player: Player, State: LockedPlayerState): ()
	local CharacterState: LockedCharacterState = State.CharacterState
	local Character: Model? = Player.Character
	if Character == nil or Character.Parent == nil then
		Character = CharacterState.Character
	end

	if Character and Character.Parent ~= nil then
		local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if Root then
			Root.AssemblyLinearVelocity = Vector3.zero
			Root.AssemblyAngularVelocity = Vector3.zero
			if self.AnchorRoot then
				if CharacterState.RootAnchoredBefore ~= nil then
					Root.Anchored = CharacterState.RootAnchoredBefore
				else
					Root.Anchored = false
				end
			end
		end

		local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
		if HumanoidInstance then
			HumanoidInstance.AutoRotate = true

			if CharacterState.HumanoidWalkSpeedBefore ~= nil and CharacterState.HumanoidWalkSpeedBefore > ZERO then
				HumanoidInstance.WalkSpeed =
					FlowBuffs.ResolveRestoredWalkSpeed(Player, CharacterState.HumanoidWalkSpeedBefore, DEFAULT_WALKSPEED)
			elseif HumanoidInstance.WalkSpeed <= ZERO then
				FlowBuffs.ApplyHumanoidWalkSpeed(Player, HumanoidInstance, DEFAULT_WALKSPEED)
			end

			HumanoidInstance.UseJumpPower = CharacterState.HumanoidUseJumpPowerBefore ~= false
			if HumanoidInstance.UseJumpPower then
				if CharacterState.HumanoidJumpPowerBefore ~= nil and CharacterState.HumanoidJumpPowerBefore > ZERO then
					HumanoidInstance.JumpPower = CharacterState.HumanoidJumpPowerBefore
				else
					HumanoidInstance.JumpPower = DEFAULT_JUMPPOWER
				end
			else
				if CharacterState.HumanoidJumpHeightBefore ~= nil and CharacterState.HumanoidJumpHeightBefore > ZERO then
					HumanoidInstance.JumpHeight = CharacterState.HumanoidJumpHeightBefore
				elseif HumanoidInstance.JumpHeight <= ZERO then
					HumanoidInstance.JumpHeight = DEFAULT_JUMPHEIGHT
				end
			end
			HumanoidInstance.PlatformStand = false
			HumanoidInstance.Sit = false
		end
	end

	SetLockAttributes(self.CutsceneAttributeName, Player, Character, State.PlayerSkillLockedBefore == true, false)
	ResetCharacterState(CharacterState)
end

function MatchCutsceneLock.new(Options: MatchCutsceneLockOptions?): MatchCutsceneLock
	local self = setmetatable({}, MatchCutsceneLock) :: any
	self.Active = false
	self.Token = 0
	self.CutsceneAttributeName = if Options and type(Options.CutsceneAttributeName) == "string" and Options.CutsceneAttributeName ~= ""
		then Options.CutsceneAttributeName
		else DEFAULT_CUTSCENE_ATTRIBUTE
	self.AnchorRoot = if Options and Options.AnchorRoot ~= nil then Options.AnchorRoot == true else true
	self.EnforcePivot = if Options and Options.EnforcePivot ~= nil then Options.EnforcePivot == true else true
	self.LockedPlayers = {}
	self.EnforceConnection = nil
	return self :: MatchCutsceneLock
end

function MatchCutsceneLock:Start(PlayersToLock: {Player}, Duration: number): number
	self:Stop(nil)

	self.Token += 1
	local Token: number = self.Token
	self.Active = true

	for _, Player in PlayersToLock do
		local State: LockedPlayerState = EnsurePlayerState(self, Player)
		if State.CharacterConnection then
			State.CharacterConnection:Disconnect()
			State.CharacterConnection = nil
		end

		State.PlayerSkillLockedBefore = Player:GetAttribute(ATTR_SKILL_LOCKED) == true
		SetLockAttributes(self.CutsceneAttributeName, Player, Player.Character, true, true)

		if Player.Character then
			ApplyCharacterLock(self, Player, State, Player.Character)
		end

		State.CharacterConnection = Player.CharacterAdded:Connect(function(Character: Model)
			if not self.Active or self.Token ~= Token then
				return
			end
			ApplyCharacterLock(self, Player, State, Character)
		end)
	end

	if self.EnforceConnection then
		self.EnforceConnection:Disconnect()
		self.EnforceConnection = nil
	end

	self.EnforceConnection = RunService.Heartbeat:Connect(function()
		if not self.Active or self.Token ~= Token then
			return
		end

		for _, State in self.LockedPlayers do
			EnforceLockedCharacter(self, State)
		end
	end)

	if Duration > ZERO then
		task.delay(Duration, function()
			self:Stop(Token)
		end)
	end

	return Token
end

function MatchCutsceneLock:CaptureCurrentPivots(PlayersToCapture: {Player}?): ()
	if not self.Active then
		return
	end

	local function CaptureForPlayer(Player: Player): ()
		local State: LockedPlayerState? = self.LockedPlayers[Player]
		if not State then
			return
		end

		local Character: Model? = Player.Character
		if Character == nil or Character.Parent == nil then
			return
		end

		State.CharacterState.Character = Character
		State.CharacterState.DesiredPivot = Character:GetPivot()

		local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if Root then
			Root.AssemblyLinearVelocity = Vector3.zero
			Root.AssemblyAngularVelocity = Vector3.zero
		end
	end

	if PlayersToCapture then
		for _, Player in PlayersToCapture do
			CaptureForPlayer(Player)
		end
		return
	end

	for Player in self.LockedPlayers do
		CaptureForPlayer(Player)
	end
end

function MatchCutsceneLock:Stop(Token: number?): ()
	if not self.Active then
		return
	end
	if Token ~= nil and self.Token ~= Token then
		return
	end

	self.Active = false

	if self.EnforceConnection then
		self.EnforceConnection:Disconnect()
		self.EnforceConnection = nil
	end

	for Player, State in self.LockedPlayers do
		if State.CharacterConnection then
			State.CharacterConnection:Disconnect()
			State.CharacterConnection = nil
		end
		RestoreCharacterLock(self, Player, State)
		self.LockedPlayers[Player] = nil
	end
end

function MatchCutsceneLock:Destroy(): ()
	self:Stop(nil)
end

return MatchCutsceneLock
