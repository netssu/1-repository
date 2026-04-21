local module = {}

module.CurrentRound = 0
module.MaxWave = 1
module.Challenge = -1
module.mobLimit = 0

module.Skip = false
module.SkipVotes = 0
module.voteStart = false
module.votedMap = nil
module.startTime = nil

module.Players = {}
module.PlayersVotedForStart = {}

module.ActStats = nil
module.RoundStats = nil

-- Gamemode States
module.infinity = false
module.challenge = -1
module.raid = false

module.healthMultiplier = 1
module.died = false
module.win = false
module.map = nil

module.raidLuckIncrease = 0

-- Currencies
module.ticketCounts = {}
module.gemCounts = {}

module.infinityTowerReward = {}
module.infinityWaveReward = 200


return module