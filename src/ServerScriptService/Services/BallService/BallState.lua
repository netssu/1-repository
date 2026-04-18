--!strict

export type BallPhysicsData = {
	LaunchTime: number,
	Power: number,
	Target: Vector3,
	SpawnPos: Vector3,
	SpinType: number,
	CurveFactor: number?,
}

export type BallStateType = {
	GetPossession: (self: BallStateType) -> Player?,
	SetPossession: (self: BallStateType, Player: Player?) -> (),
	IsInAir: (self: BallStateType) -> boolean,
	SetInAir: (self: BallStateType, InAir: boolean) -> (),
	IsFumbled: (self: BallStateType) -> boolean,
	SetFumbled: (self: BallStateType, Fumbled: boolean) -> (),
	IsOnGround: (self: BallStateType) -> boolean,
	SetOnGround: (self: BallStateType, OnGround: boolean) -> (),
	GetPhysicsData: (self: BallStateType) -> BallPhysicsData?,
	SetPhysicsData: (self: BallStateType, Data: BallPhysicsData) -> (),
	ClearPhysicsData: (self: BallStateType) -> (),
}

type BallStateData = {
	_possession: Player?,
	_inAir: boolean,
	_fumbled: boolean,
	_onGround: boolean,
	_physicsData: BallPhysicsData?,
}

local BallState = {}
BallState.__index = BallState

function BallState.new(): BallStateType
	local self = setmetatable({} :: BallStateData, BallState) :: BallStateType & BallStateData
	
	self._possession = nil
	self._inAir = false
	self._fumbled = false
	self._onGround = false
	self._physicsData = nil
	
	return self
end

function BallState:GetPossession(): Player?
	return self._possession
end

function BallState:SetPossession(Player: Player?): ()
	self._possession = Player
end

function BallState:IsInAir(): boolean
	return self._inAir
end

function BallState:SetInAir(InAir: boolean): ()
	self._inAir = InAir
end

function BallState:IsFumbled(): boolean
	return self._fumbled
end

function BallState:SetFumbled(Fumbled: boolean): ()
	self._fumbled = Fumbled
end

function BallState:IsOnGround(): boolean
	return self._onGround
end

function BallState:SetOnGround(OnGround: boolean): ()
	self._onGround = OnGround
end

function BallState:GetPhysicsData(): BallPhysicsData?
	return self._physicsData
end

function BallState:SetPhysicsData(Data: BallPhysicsData): ()
	self._physicsData = Data
end

function BallState:ClearPhysicsData(): ()
	self._physicsData = nil
end

return BallState
