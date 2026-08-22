------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

------------------//DEPENDENCIES
local dictionary = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("Dictionary"))

------------------//CONSTANTS
local REMOTE_FOLDER_NAME = "ProfileRemotes"
local GET_REMOTE_NAME = "GetData"
local CHANGED_REMOTE_NAME = "OnDataChanged"

------------------//VARIABLES
local isServer: boolean = RunService:IsServer()
local isClient: boolean = RunService:IsClient()

local remotesFolder: Folder?
local getRemote: RemoteFunction?
local changedRemote: RemoteEvent?

local serverProfiles: {[number]: any} = {}
local serverSignals: {[number]: {[string]: any}} = {}

local clientCache: any = nil
local clientSignals: {[string]: any} = {}
local clientInitialized = false

------------------//FUNCTIONS
local function new_signal()
	local listeners: {(...any) -> ()} = {}
	local signal = {}

	function signal:connect(fn: (...any) -> ())
		listeners[#listeners + 1] = fn

		local connection = {}

		function connection:disconnect()
			for i, listener in listeners do
				if listener == fn then
					table.remove(listeners, i)
					break
				end
			end
		end

		return connection
	end

	function signal:fire(...)
		for _, fn in listeners do
			fn(...)
		end
	end

	return signal
end

local function publish_server_change(player: Player, path: string, value: any): ()
	local sigs = serverSignals[player.UserId]
	if sigs then
		local sig = sigs[path]
		if not sig then
			sig = new_signal()
			sigs[path] = sig
		end
		sig:fire(value)
	end

	if changedRemote then
		changedRemote:FireClient(player, {
			path = path,
			value = value,
		})
	end
end

local function ensure_remotes_server(): ()
	remotesFolder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME) :: Folder?
	if not remotesFolder then
		local f = Instance.new("Folder")
		f.Name = REMOTE_FOLDER_NAME
		f.Parent = ReplicatedStorage
		remotesFolder = f
	end

	getRemote = remotesFolder:FindFirstChild(GET_REMOTE_NAME) :: RemoteFunction?
	if not getRemote then
		local rf = Instance.new("RemoteFunction")
		rf.Name = GET_REMOTE_NAME
		rf.Parent = remotesFolder
		getRemote = rf
	end

	changedRemote = remotesFolder:FindFirstChild(CHANGED_REMOTE_NAME) :: RemoteEvent?
	if not changedRemote then
		local re = Instance.new("RemoteEvent")
		re.Name = CHANGED_REMOTE_NAME
		re.Parent = remotesFolder
		changedRemote = re
	end

	getRemote.OnServerInvoke = function(player: Player, path: string?)
		local profile = serverProfiles[player.UserId]
		local start = os.clock()

		while not profile and os.clock() - start < 5 do
			task.wait()
			profile = serverProfiles[player.UserId]
		end

		if not profile then
			return nil
		end
		
		return dictionary.get_by_path(profile.Data, path)
	end
end

local function ensure_remotes_client(): ()
	if clientInitialized then return end

	remotesFolder = ReplicatedStorage:WaitForChild(REMOTE_FOLDER_NAME) :: Folder
	getRemote = remotesFolder:WaitForChild(GET_REMOTE_NAME) :: RemoteFunction
	changedRemote = remotesFolder:WaitForChild(CHANGED_REMOTE_NAME) :: RemoteEvent

	clientCache = getRemote:InvokeServer(nil)
	clientInitialized = true

	changedRemote.OnClientEvent:Connect(function(payload: {path: string, value: any})
		if not clientCache then
			clientCache = {}
		end

		dictionary.set_by_path(clientCache, payload.path, payload.value)

		local sig = clientSignals[payload.path]
		if sig then
			sig:fire(payload.value)
		end
	end)
end

------------------//MAIN FUNCTIONS
local dataUtility = {}

dataUtility.server = {}
dataUtility.client = {}

function dataUtility.server.ensure_remotes(): ()
	if isServer then
		ensure_remotes_server()
	end
end

function dataUtility.server.attach_profile(player: Player, profile: any): ()
	serverProfiles[player.UserId] = profile
	serverSignals[player.UserId] = serverSignals[player.UserId] or {}
end

function dataUtility.server.detach_profile(player: Player): ()
	serverProfiles[player.UserId] = nil
	serverSignals[player.UserId] = nil
end

function dataUtility.server.get(player: Player, path: string?): any
	local start = os.clock()
	local profile = serverProfiles[player.UserId]

	while not profile and os.clock() - start < 10 do
		task.wait()
		profile = serverProfiles[player.UserId]
	end

	if not profile then
		return nil
	end

	return dictionary.get_by_path(profile.Data, path)
end

function dataUtility.server.set(player: Player, path: string, value: any): ()
	local profile = serverProfiles[player.UserId]
	if not profile then
		return
	end

	dictionary.set_by_path(profile.Data, path, value)
	publish_server_change(player, path, value)
	profile:Save()
end

function dataUtility.server.update(player: Player, updateFunction: (data: any) -> ({ [string]: any }?)): boolean
	local profile = serverProfiles[player.UserId]
	if not profile then
		return false
	end

	local changes = updateFunction(profile.Data)
	if changes then
		for path, value in changes do
			publish_server_change(player, path, value)
		end
	end

	profile:Save()
	return true
end

function dataUtility.server.bind(player: Player, path: string, fn: (any) -> ()): ({disconnect: (self: any) -> ()})?
	if not serverSignals[player.UserId] then
		serverSignals[player.UserId] = {}
	end

	local sigs = serverSignals[player.UserId]

	local sig = sigs[path]
	if not sig then
		sig = new_signal()
		sigs[path] = sig
	end

	return sig:connect(fn)
end

function dataUtility.client.ensure_remotes(): ()
	if isClient then
		ensure_remotes_client()
	end
end

function dataUtility.client.get(path: string?): any
	if isClient and not clientInitialized then
		ensure_remotes_client()
	end

	return dictionary.get_by_path(clientCache, path)
end

function dataUtility.client.bind(path: string, fn: (any) -> ()): ({disconnect: (self: any) -> ()})?
	if isClient and not clientInitialized then
		ensure_remotes_client()
	end

	local sig = clientSignals[path]
	if not sig then
		sig = new_signal()
		clientSignals[path] = sig
	end

	return sig:connect(fn)
end

------------------//INIT
return dataUtility
