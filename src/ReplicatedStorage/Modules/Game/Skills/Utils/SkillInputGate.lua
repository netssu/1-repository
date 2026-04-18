--!strict

export type SkillInputGate = {
	_Timestamps: {[string]: number},
	TryAcquire: (self: SkillInputGate, Key: string, Cooldown: number) -> boolean,
	Reset: (self: SkillInputGate, Key: string?) -> (),
}

local SkillInputGate = {}
SkillInputGate.__index = SkillInputGate

function SkillInputGate.new(): SkillInputGate
	local self = setmetatable({}, SkillInputGate) :: any
	self._Timestamps = {}
	return self :: SkillInputGate
end

function SkillInputGate:TryAcquire(Key: string, Cooldown: number): boolean
	local now = os.clock()
	local last = self._Timestamps[Key]
	if last and now - last < Cooldown then
		return false
	end
	self._Timestamps[Key] = now
	return true
end

function SkillInputGate:Reset(Key: string?): ()
	if Key then
		self._Timestamps[Key] = nil
		return
	end
	table.clear(self._Timestamps)
end

return SkillInputGate
