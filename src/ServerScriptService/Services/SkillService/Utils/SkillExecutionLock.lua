--!strict

export type SkillExecutionLock = {
	_DefaultWindow: number,
	_LockUntil: {[Player]: number},
	TryAcquire: (self: SkillExecutionLock, Player: Player, Window: number?) -> boolean,
	IsLocked: (self: SkillExecutionLock, Player: Player) -> boolean,
	Release: (self: SkillExecutionLock, Player: Player) -> (),
	ClearAll: (self: SkillExecutionLock) -> (),
}

local SkillExecutionLock = {}
SkillExecutionLock.__index = SkillExecutionLock

function SkillExecutionLock.new(DefaultWindow: number): SkillExecutionLock
	local self = setmetatable({}, SkillExecutionLock) :: any
	self._DefaultWindow = math.max(DefaultWindow, 0)
	self._LockUntil = {}
	return self :: SkillExecutionLock
end

function SkillExecutionLock:TryAcquire(Player: Player, Window: number?): boolean
	local now: number = os.clock()
	local lockUntil: number? = self._LockUntil[Player]
	if lockUntil and now < lockUntil then
		return false
	end
	local lockWindow: number = math.max(Window or self._DefaultWindow, 0)
	self._LockUntil[Player] = now + lockWindow
	return true
end

function SkillExecutionLock:IsLocked(Player: Player): boolean
	local lockUntil: number? = self._LockUntil[Player]
	if not lockUntil then
		return false
	end
	return os.clock() < lockUntil
end

function SkillExecutionLock:Release(Player: Player): ()
	self._LockUntil[Player] = nil
end

function SkillExecutionLock:ClearAll(): ()
	table.clear(self._LockUntil)
end

return SkillExecutionLock
