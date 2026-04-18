--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WalkSpeedController = {}

--\\ TYPES \\ -- TR
type WalkSpeedRequest = {
	Id: string,
	WalkSpeed: number,
	Duration: number,
	Priority: number,
	StartTime: number,
	EndTime: number,
}

--\\ CONSTANTS \\ -- TR
local DEFAULT_WALKSPEED: number = 16
local UPDATE_INTERVAL: number = 0.1

--\\ MODULE STATE \\ -- TR
local LocalPlayer = Players.LocalPlayer
local ActiveRequests: {[string]: WalkSpeedRequest} = {}
local CurrentAppliedSpeed: number = DEFAULT_WALKSPEED
local UpdateConnection: RBXScriptConnection? = nil
local LastUpdateTime: number = 0

--\\ PRIVATE FUNCTIONS \\ -- TR
local function GetHumanoid(): Humanoid?
	local Character = LocalPlayer.Character
	if not Character then return nil end
	return Character:FindFirstChildOfClass("Humanoid")
end

local function GetHighestPriorityRequest(): WalkSpeedRequest?
	local CurrentTime = os.clock()
	local BestRequest: WalkSpeedRequest? = nil
	local ExpiredRequests: {string} = {}
	
	for Id, Request in ActiveRequests do
		if CurrentTime >= Request.EndTime then
			table.insert(ExpiredRequests, Id)
		else
			if not BestRequest then
				BestRequest = Request
			else
				local RequestTimeRemaining = Request.EndTime - CurrentTime
				local BestTimeRemaining = BestRequest.EndTime - CurrentTime
				
				if Request.WalkSpeed < BestRequest.WalkSpeed then
					BestRequest = Request
				elseif Request.WalkSpeed == BestRequest.WalkSpeed then
					if RequestTimeRemaining > BestTimeRemaining then
						BestRequest = Request
					end
				end
			end
		end
	end
	
	for _, Id in ExpiredRequests do
		ActiveRequests[Id] = nil
	end
	
	return BestRequest
end

local function ApplyWalkSpeed(Speed: number): ()
	local Humanoid = GetHumanoid()
	if not Humanoid then return end
	
	if CurrentAppliedSpeed ~= Speed then
		CurrentAppliedSpeed = Speed
		Humanoid.WalkSpeed = Speed
	end
end

local function UpdateWalkSpeed(): ()
	local CurrentTime = os.clock()
	if CurrentTime - LastUpdateTime < UPDATE_INTERVAL then return end
	LastUpdateTime = CurrentTime
	
	local BestRequest = GetHighestPriorityRequest()
	
	if BestRequest then
		ApplyWalkSpeed(BestRequest.WalkSpeed)
	else
		ApplyWalkSpeed(DEFAULT_WALKSPEED)
	end
end

local function StartUpdateLoop(): ()
	if UpdateConnection then return end
	
	UpdateConnection = RunService.Heartbeat:Connect(UpdateWalkSpeed)
end

local function StopUpdateLoop(): ()
	if not UpdateConnection then return end
	
	UpdateConnection:Disconnect()
	UpdateConnection = nil
end

local function OnCharacterAdded(Character: Model): ()
	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	
	local BestRequest = GetHighestPriorityRequest()
	if BestRequest then
		Humanoid.WalkSpeed = BestRequest.WalkSpeed
		CurrentAppliedSpeed = BestRequest.WalkSpeed
	else
		Humanoid.WalkSpeed = DEFAULT_WALKSPEED
		CurrentAppliedSpeed = DEFAULT_WALKSPEED
	end
end

--\\ PUBLIC FUNCTIONS \\ -- TR
function WalkSpeedController.Init(): ()
	StartUpdateLoop()
	
	LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)
	
	if LocalPlayer.Character then
		OnCharacterAdded(LocalPlayer.Character)
	end
end

function WalkSpeedController.Start(): ()
end

function WalkSpeedController.AddRequest(Id: string, WalkSpeed: number, Duration: number, Priority: number?): ()
	local CurrentTime = os.clock()
	local ActualPriority = Priority or 1
	
	local Request: WalkSpeedRequest = {
		Id = Id,
		WalkSpeed = WalkSpeed,
		Duration = Duration,
		Priority = ActualPriority,
		StartTime = CurrentTime,
		EndTime = CurrentTime + Duration,
	}
	
	ActiveRequests[Id] = Request
	
	UpdateWalkSpeed()
end

function WalkSpeedController.RemoveRequest(Id: string): ()
	ActiveRequests[Id] = nil
	
	UpdateWalkSpeed()
end

function WalkSpeedController.HasActiveRequests(): boolean
	local CurrentTime = os.clock()
	
	for Id, Request in ActiveRequests do
		if CurrentTime < Request.EndTime then
			return true
		end
	end
	
	return false
end

function WalkSpeedController.GetCurrentWalkSpeed(): number
	return CurrentAppliedSpeed
end

function WalkSpeedController.ClearAllRequests(): ()
	table.clear(ActiveRequests)
	ApplyWalkSpeed(DEFAULT_WALKSPEED)
end

function WalkSpeedController.SetDefaultWalkSpeed(Speed: number): ()
	DEFAULT_WALKSPEED = Speed
	
	if not WalkSpeedController.HasActiveRequests() then
		ApplyWalkSpeed(DEFAULT_WALKSPEED)
	end
end

function WalkSpeedController.GetActiveRequestCount(): number
	local Count = 0
	local CurrentTime = os.clock()
	
	for _, Request in ActiveRequests do
		if CurrentTime < Request.EndTime then
			Count = Count + 1
		end
	end
	
	return Count
end

return WalkSpeedController
