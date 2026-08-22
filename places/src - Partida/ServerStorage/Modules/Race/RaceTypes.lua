------------------//TYPES
export type Participant = {
	player: Player,
	userId: number,
	sessionId: string,
	vehicle: Model?,
	spawn: BasePart?,
	state: string,
	currentCheckpoint: number,
	currentLap: number,
	lapStartedAt: number?,
	sectorStartedAt: number?,
	sectorTwoReached: boolean,
	sectorThreeReached: boolean,
	lapValid: boolean,
	lastLapTime: number?,
	qualifyingTime: number?,
	finishedAt: number?,
	finishPosition: number?,
	rewarded: boolean,
}

export type MapDefinition = {
	mapName: string?,
	fesystem: Instance,
	info: Instance?,
	start: BasePart?,
	sectorTwo: BasePart?,
	sectorThree: BasePart?,
	finish: BasePart?,
	checkpoints: { BasePart },
	gridSpawns: { BasePart },
	raceLight: Instance?,
	cornerCuts: { BasePart },
	pitStop: Instance?,
	attackZone: Instance?,
	maxLaps: number,
	isQualifyingEnabled: boolean,
}

export type TrackCallbacks = {
	on_lap_started: (Participant) -> (),
	on_lap_completed: (Participant, number, number) -> (),
	on_checkpoint: (Participant, number) -> (),
	on_sector: (Participant, string, number) -> (),
	on_lap_invalid: (Participant) -> (),
	on_finished: (Participant) -> (),
	on_qualifying_finished: (Participant, number) -> (),
}

export type ParticipantRegistry = {
	get_by_vehicle: (Model) -> Participant?,
}

------------------//INIT
return {}
