------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//CONSTANTS
local STORE_NAME: string = "FormulaE"
local PROFILE_KEY_SUFFIX: string = "~PlayerProfile"

------------------//DEPENDENCIES
local replicatedModules: Folder = ReplicatedStorage:WaitForChild("Modules")
local packages: Folder = ServerStorage:WaitForChild("Packages")
local serverModules: Folder = ServerStorage:WaitForChild("Modules")
local profileStoreModule = require(packages:WaitForChild("ProfileStore"))
local dataUtility = require(replicatedModules:WaitForChild("Data"):WaitForChild("DataUtility"))
local profileData = require(serverModules:WaitForChild("ProfileData"))

------------------//VARIABLES
local store = profileStoreModule.New(STORE_NAME, profileData.create_template())
local profilesByUserId: { [number]: any } = {}

------------------//FUNCTIONS
local function attach_player_profile(player: Player): ()
	local profileKey = tostring(player.UserId) .. PROFILE_KEY_SUFFIX
	local profile = store:StartSessionAsync(profileKey)
	if not profile then
		warn("Falha ao iniciar sessão do perfil para " .. player.Name)
		return
	end

	profileData.migrate(profile.Data)
	profile:Reconcile()
	profileData.migrate(profile.Data)
	profile:AddUserId(player.UserId)
	profilesByUserId[player.UserId] = profile
	dataUtility.server.attach_profile(player, profile)

	task.spawn(function()
		while player.Parent and profilesByUserId[player.UserId] do
			task.wait(60)
			if profilesByUserId[player.UserId] then
				local currentTime = profile.Data.Profile.Statistics.Playtime or 0
				dataUtility.server.set(player, "Profile.Statistics.Playtime", currentTime + 60)
			end
		end
	end)

	profile.OnSessionEnd:Connect(function()
		dataUtility.server.detach_profile(player)
		profilesByUserId[player.UserId] = nil
	end)
end

local function release_player_profile(player: Player): ()
	local profile = profilesByUserId[player.UserId]
	if profile then
		profile:EndSession()
		profilesByUserId[player.UserId] = nil
	end
end

------------------//MAIN FUNCTIONS
local function on_player_added(player: Player): ()
	attach_player_profile(player)
end

local function on_player_removing(player: Player): ()
	release_player_profile(player)
end

------------------//INIT
dataUtility.server.ensure_remotes()

for _, player in Players:GetPlayers() do
	on_player_added(player)
end

Players.PlayerAdded:Connect(on_player_added)
Players.PlayerRemoving:Connect(on_player_removing)

profileStoreModule.OnError:Connect(function(message: string, storeName: string, key: string)
	warn(("[ProfileStore:%s %s] %s"):format(storeName, key, message))
end)
