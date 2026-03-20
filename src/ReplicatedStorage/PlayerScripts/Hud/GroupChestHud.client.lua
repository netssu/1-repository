------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local REMOTE_FOLDER_NAME: string = "ZoneRewardRemotes"
local NOTIFY_REMOTE_NAME: string = "Notify"

------------------//VARIABLES
local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local utilityFolder: Folder = modulesFolder:WaitForChild("Utility")
local NotificationUtility = require(utilityFolder:WaitForChild("NotificationUtility"))

local remotesFolder: Folder
local notifyRemote: RemoteEvent

------------------//FUNCTIONS
local function setup_remotes(): ()
	remotesFolder = ReplicatedStorage:WaitForChild(REMOTE_FOLDER_NAME)
	notifyRemote = remotesFolder:WaitForChild(NOTIFY_REMOTE_NAME)
end

local function handle_notification(payload: any): ()
	if type(payload) ~= "table" or not payload.message then
		return
	end
	NotificationUtility:Show(payload)
end

------------------//INIT
setup_remotes()

if notifyRemote then
	notifyRemote.OnClientEvent:Connect(handle_notification)
end