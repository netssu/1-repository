local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ProfileStore = require(script.Parent.Shared.ProfileStore)

local Promise = require(script.Parent.Shared.Promise)
local Replica = require(script.Parent.Shared.Replica)
local Signal = require(script.Parent.Shared.Signal)

local TOKEN = Replica.Token("PlayerData")
local DATA_LOG_PREFIX = "[PlayerDataManager]"

local playerStore: typeof(ProfileStore.New(...))
local dataLoaded = Signal.new() :: Signal.Signal<Player>
local hasBoundStoreSignals = false

type CacheData = {
	Profile: ProfileStore.Profile<any>,
	Replica: typeof(Replica.New()),
	ValueChangedSignals: { [string]: Signal.Signal<any, any>? },
	ValueInsertedSignals: { [string]: Signal.Signal<any, number?>? },
	ValueRemovedSignals: { [string]: Signal.Signal<any, number>? },
}

local PlayerDataManager = {
	_dataStoreKey = "PlayerStore",
	_template = nil,
	_cache = {} :: { [Player]: CacheData },
}

local function describePlayer(player: Player): string
	return `{player.Name} ({player.UserId})`
end

local function logData(message: string): ()
	print(`{DATA_LOG_PREFIX} {message}`)
end

local function warnData(message: string): ()
	warn(`{DATA_LOG_PREFIX} {message}`)
end

local function removeData(self: PlayerDataManager, player: Player): ()
	local playerCacheData = self._cache[player]
	if not playerCacheData then
		return
	end

	local playerReplica = playerCacheData.Replica
	if playerReplica then
		playerReplica:Destroy()
	end

	self._cache[player] = nil

	if player.Parent == Players then
		player:Kick("Profile session ended. Please rejoin")
	end
end

local function getCacheData(self: PlayerDataManager, player: Player): CacheData
	if self._cache[player] then
		return self._cache[player]
	end

	local dataPromise = Promise.new(function(resolve, _, onCancel)
		local connection
		connection = dataLoaded:Connect(function(loadedPlayer)
			if loadedPlayer == player then
				connection:Disconnect()
				resolve(self._cache[player])
			end
		end)

		onCancel(function()
			if connection then
				connection:Disconnect()
			end
		end)
	end)

	local success, result = dataPromise:timeout(15):await()

	if success then
		return result
	else
		warnData(`Timed out waiting for cache data for {describePlayer(player)}: {tostring(result)}`)
		error(`Failed to get {player.Name} cache data: {result}`)
	end
end

local function start(self: PlayerDataManager): ()
	playerStore = ProfileStore.New(self._dataStoreKey, self._template)
	logData(`Starting store "{self._dataStoreKey}" (state={playerStore.DataStoreState}, studio={tostring(RunService:IsStudio())})`)

	if not hasBoundStoreSignals then
		hasBoundStoreSignals = true

		playerStore.OnError:Connect(function(message, storeName, profileKey)
			warnData(`ProfileStore error [store={storeName}; key={profileKey}; state={playerStore.DataStoreState}] {message}`)
		end)

		playerStore.OnCriticalToggle:Connect(function(isCritical)
			local stateLabel = if isCritical then "entered" else "left"
			warnData(`ProfileStore {stateLabel} critical state (DataStoreState={playerStore.DataStoreState})`)
		end)
	end

	local function onPlayerAdded(player: Player): ()
		logData(`Starting session load for {describePlayer(player)} (DataStoreState={playerStore.DataStoreState})`)

		local loadSuccess, playerProfileOrError = pcall(function()
			return playerStore:StartSessionAsync(tostring(player.UserId), {
				Cancel = function()
					return player.Parent ~= Players
				end,
			})
		end)

		if not loadSuccess then
			warnData(`StartSessionAsync failed for {describePlayer(player)}: {tostring(playerProfileOrError)}`)
			player:Kick("Profile load failed. Please rejoin")
			return
		end

		local playerProfile = playerProfileOrError

		if not playerProfile then
			warnData(`Profile session returned nil for {describePlayer(player)} (DataStoreState={playerStore.DataStoreState})`)
			player:Kick("Profile load failed. Please rejoin")
			return
		end

		playerProfile:AddUserId(player.UserId)
		logData(`Session started for {describePlayer(player)}`)

		local reconcileSuccess, reconcileError = pcall(function()
			playerProfile:Reconcile()
		end)
		if not reconcileSuccess then
			warnData(`Reconcile failed for {describePlayer(player)}: {tostring(reconcileError)}`)
			playerProfile:EndSession()
			player:Kick("Profile reconcile failed. Please rejoin")
			return
		end
		logData(`Profile reconciled for {describePlayer(player)}`)

		playerProfile.OnSave:Connect(function()
			logData(`Saving profile for {describePlayer(player)}`)
		end)

		playerProfile.OnAfterSave:Connect(function()
			logData(`Save finished for {describePlayer(player)}`)
		end)

		playerProfile.OnLastSave:Connect(function(reason)
			logData(`Last save requested for {describePlayer(player)} (reason={reason})`)
		end)

		playerProfile.OnSessionEnd:Connect(function()
			logData(`Session ended for {describePlayer(player)}`)
			removeData(self, player)
		end)

		if player.Parent ~= Players then
			logData(`Player left before replica creation for {describePlayer(player)}; ending session`)
			playerProfile:EndSession()
			return
		end

		local playerReplica = Replica.New({
			Token = TOKEN,
			Data = playerProfile.Data,
			Tags = { Player = player },
		})

		playerReplica:Replicate()

		self._cache[player] = {
			Profile = playerProfile,
			Replica = playerReplica,
			ValueChangedSignals = {},
			ValueInsertedSignals = {},
			ValueRemovedSignals = {},
		}

		dataLoaded:Fire(player)
		logData(`Data cache ready for {describePlayer(player)}`)
	end

	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local playerCacheData = self._cache[player]
		if not playerCacheData then
			warnData(`PlayerRemoving received without cache for {describePlayer(player)}`)
			return
		end

		logData(`PlayerRemoving -> ending session for {describePlayer(player)}`)
		local success, errorMessage = pcall(function()
			playerCacheData.Profile:EndSession()
		end)
		if not success then
			warnData(`Failed to end session for {describePlayer(player)} on PlayerRemoving: {tostring(errorMessage)}`)
		end
	end)

	game:BindToClose(function()
		local players = Players:GetPlayers()
		logData(`BindToClose received; ending {#players} active profile session(s)`)

		for _, player in pairs(Players:GetPlayers()) do
			local playerCacheData = self._cache[player]
			if not playerCacheData then
				warnData(`BindToClose skipping {describePlayer(player)} because cache data is missing`)
			else
				local success, errorMessage = pcall(function()
					playerCacheData.Profile:EndSession()
				end)
				if success then
					logData(`Shutdown end session requested for {describePlayer(player)}`)
				else
					warnData(`Shutdown end session failed for {describePlayer(player)}: {tostring(errorMessage)}`)
				end
			end
		end
	end)
end
-- Sets the default data structure used when creating a profile.
function PlayerDataManager.SetTemplate(self: PlayerDataManager, template: { [any]: any }): ()
	if type(template) ~= "table" then
		error("Template must be a table")
	end

	self._template = template
	start(self)
end
-- Sets the Data Store key used for saving and loading player profile data.
function PlayerDataManager.SetDataStoreKey(self: PlayerDataManager, key: string): ()
	self._dataStoreKey = key
end
-- Returns the value from a player's profile data at the given path.
function PlayerDataManager.Get(self: PlayerDataManager, player: Player, path: { string | number }): any
	local pointer = getCacheData(self, player).Profile.Data
	for _, key in ipairs(path) do
		pointer = pointer[key]
	end

	return pointer
end
-- Sets the value in a player's profile data at the given path.
function PlayerDataManager.Set(self: PlayerDataManager, player: Player, path: { string | number }, value: any): ()
	local playerCacheData = getCacheData(self, player)
	local concatedPath = table.concat(path, "/")

	local oldValue = self:Get(player, path)
	if oldValue == nil then
		error(`No value found in path "{concatedPath}"`)
	end

	local pointer = playerCacheData.Profile.Data
	for i = 1, #path - 1 do
		pointer = pointer[path[i]]
	end

	pointer[path[#path]] = value
	playerCacheData.Replica:Set(path, value)

	local valueChangedSignal = playerCacheData.ValueChangedSignals[concatedPath]
	if valueChangedSignal then
		valueChangedSignal:Fire(value, oldValue)
	end
end
-- Returns a Signal that fires when the value at the given path is changed.
function PlayerDataManager.GetValueChangedSignal(
	self: PlayerDataManager,
	player: Player,
	path: { string | number }
): Signal.Signal<any, any>
	local playerCacheData = getCacheData(self, player)
	local concatedPath = table.concat(path, "/")

	local valueChangedSignal = playerCacheData.ValueChangedSignals[concatedPath]
	if valueChangedSignal then
		return valueChangedSignal
	else
		valueChangedSignal = Signal.new()

		playerCacheData.ValueChangedSignals[concatedPath] = valueChangedSignal

		return valueChangedSignal
	end
end
-- Inserts the given value into a player's profile table at the given path, and index, if provided.
function PlayerDataManager.Insert(
	self: PlayerDataManager,
	player: Player,
	path: { string | number },
	value: any,
	index: number?
): ()
	local playerCacheData = getCacheData(self, player)
	local pointer = playerCacheData.Profile.Data
	for _, key in ipairs(path) do
		pointer = pointer[key]
	end

	if index then
		table.insert(pointer, index, value)
	else
		table.insert(pointer, value)
	end

	playerCacheData.Replica:TableInsert(path, value, index or nil)

	local concatedPath = table.concat(path, "/")
	local valueInsertedSignal = playerCacheData.ValueInsertedSignals[concatedPath]
	if valueInsertedSignal then
		valueInsertedSignal:Fire(value, index or nil)
	end
end
-- Returns a Signal that fires when a value is inserted into the table at the given path.
function PlayerDataManager.GetValueInsertedSignal(
	self: PlayerDataManager,
	player: Player,
	path: { string | number }
): Signal.Signal<any, number?>
	local playerCacheData = getCacheData(self, player)
	local concatedPath = table.concat(path, "/")

	local valueInsertedSignal = playerCacheData.ValueInsertedSignals[concatedPath]
	if valueInsertedSignal then
		return valueInsertedSignal
	else
		valueInsertedSignal = Signal.new()

		playerCacheData.ValueInsertedSignals[concatedPath] = valueInsertedSignal

		return valueInsertedSignal
	end
end
-- Removes an element from a table at the given path by index.
function PlayerDataManager.Remove(self: PlayerDataManager, player: Player, path: { string | number }, index: number): ()
	local playerCacheData = getCacheData(self, player)
	local pointer = playerCacheData.Profile.Data
	for _, key in ipairs(path) do
		pointer = pointer[key]
	end

	local concatedPath = table.concat(path, "/")

	local valueRemoved = table.remove(pointer, index)
	if valueRemoved == nil then
		error(`No index "{index}" at path "{concatedPath}"`)
	end

	playerCacheData.Replica:TableRemove(path, index)

	local valueRemovedSignal = playerCacheData.ValueRemovedSignals[concatedPath]
	if valueRemovedSignal then
		valueRemovedSignal:Fire(valueRemoved, index)
	end
end
-- Returns a Signal that fires when a value is removed from the table at the given path.
function PlayerDataManager.GetValueRemovedSignal(
	self: PlayerDataManager,
	player: Player,
	path: { string | number }
): Signal.Signal<any, number>
	local playerCacheData = getCacheData(self, player)
	local concatedPath = table.concat(path, "/")

	local valueRemovedSignal = playerCacheData.ValueRemovedSignals[concatedPath]
	if valueRemovedSignal then
		return valueRemovedSignal
	else
		valueRemovedSignal = Signal.new()

		playerCacheData.ValueRemovedSignals[concatedPath] = valueRemovedSignal

		return valueRemovedSignal
	end
end
-- Increment the value at the given path, by the given amount.
function PlayerDataManager.Increment(self: PlayerDataManager, player: Player, path: { string | number }, increment: number): ()
	local oldValue = self:Get(player, path)
	local newValue = oldValue + increment

	self:Set(player, path, newValue)
end

type PlayerDataManager = typeof(PlayerDataManager)

return PlayerDataManager :: PlayerDataManager
