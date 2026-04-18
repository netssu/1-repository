--!strict

local RunService: RunService = game:GetService("RunService")

export type TickCallback = (Remaining: number) -> ()
export type EndCallback = () -> ()

export type SkillCooldownTracker = {
	_EndTimes: {[number]: number},
	_Tokens: {[number]: number},
	IsOnCooldown: (self: SkillCooldownTracker, SlotIndex: number) -> boolean,
	Begin: (self: SkillCooldownTracker, SlotIndex: number, Duration: number, OnTick: TickCallback?, OnEnd: EndCallback?) -> (),
	Clear: (self: SkillCooldownTracker, SlotIndex: number) -> (),
	ClearAll: (self: SkillCooldownTracker, MinSlot: number, MaxSlot: number) -> (),
}

local SkillCooldownTracker = {}
SkillCooldownTracker.__index = SkillCooldownTracker

function SkillCooldownTracker.new(): SkillCooldownTracker
	local self = setmetatable({}, SkillCooldownTracker) :: any
	self._EndTimes = {}
	self._Tokens = {}
	return self :: SkillCooldownTracker
end

function SkillCooldownTracker:IsOnCooldown(SlotIndex: number): boolean
	local endTime = self._EndTimes[SlotIndex]
	if not endTime then
		return false
	end
	return os.clock() < endTime
end

function SkillCooldownTracker:Begin(
	SlotIndex: number,
	Duration: number,
	OnTick: TickCallback?,
	OnEnd: EndCallback?
): ()
	local clampedDuration = math.max(Duration, 0)
	local token = (self._Tokens[SlotIndex] or 0) + 1
	self._Tokens[SlotIndex] = token
	self._EndTimes[SlotIndex] = os.clock() + clampedDuration

	if clampedDuration <= 0 then
		self._EndTimes[SlotIndex] = nil
		if OnTick then
			OnTick(0)
		end
		if OnEnd then
			OnEnd()
		end
		return
	end

	task.spawn(function()
		local connection: RBXScriptConnection? = nil
		local function finish(): ()
			if connection then
				connection:Disconnect()
				connection = nil
			end
			if self._Tokens[SlotIndex] ~= token then
				return
			end
			self._EndTimes[SlotIndex] = nil
			if OnTick then
				OnTick(0)
			end
			if OnEnd then
				OnEnd()
			end
		end

		connection = RunService.Heartbeat:Connect(function()
			if self._Tokens[SlotIndex] ~= token then
				if connection then
					connection:Disconnect()
					connection = nil
				end
				return
			end
			local remaining = (self._EndTimes[SlotIndex] or 0) - os.clock()
			if remaining <= 0 then
				finish()
				return
			end
			if OnTick then
				OnTick(remaining)
			end
		end)
	end)
end

function SkillCooldownTracker:Clear(SlotIndex: number): ()
	self._Tokens[SlotIndex] = (self._Tokens[SlotIndex] or 0) + 1
	self._EndTimes[SlotIndex] = nil
end

function SkillCooldownTracker:ClearAll(MinSlot: number, MaxSlot: number): ()
	for slot = MinSlot, MaxSlot do
		self:Clear(slot)
	end
end

return SkillCooldownTracker
