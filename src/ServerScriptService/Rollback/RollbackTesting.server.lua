local ProfileService = require(game.ServerStorage.ServerModules.ProfileService)
local DataStore = ProfileService.GetProfileStore("UserDataV2", require(game.ServerScriptService.Rollback.RollbackTesting.DefaultData) )

local AccessKey = "300286118PlayerData"
local DataQueryLog = DataStore:ProfileVersionQuery(
	AccessKey,
	Enum.SortDirection.Ascending,
	DateTime.fromUniversalTime(2025, 5, 23)
)

local profile = DataQueryLog:NextAsync()
print(profile)
profile:ClearGlobalUpdates()
profile:OverwriteAsync()
