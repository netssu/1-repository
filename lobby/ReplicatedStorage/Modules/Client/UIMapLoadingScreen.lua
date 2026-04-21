local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StoryModeStatsModule = require(ReplicatedStorage:WaitForChild("StoryModeStats"))

local LoadingGui = script:WaitForChild("LoadingGui")

local Hints = {
	"You can use codes for gems",
	"Did you know there are 4 secrets in the game?",
	"Encounter Bugs? Join the community server to report them",
}


local module = {}

function module.CreateLoadingGui(locationType, ...)
	--LocationType: Lobby, Game(...: worldNumber, actNumber, mode: 1 for normal, 2 for hard), AFKChamber
	
	local screenGui = LoadingGui:Clone()
	local worldImage = screenGui.WorldImage
	local main = worldImage.Main
	local hintsFrame = main.Hints
	local teleportInfoFrame = main.TeleportInfo
	
	
	if locationType == "Game" then
		local worldNumber, actNumber, mode = ...
		
		local WorldName = StoryModeStatsModule.Worlds[worldNumber]
		local ActName = StoryModeStatsModule.LevelName[WorldName][actNumber]
		local WorldImageID = StoryModeStatsModule.LoadScreenImages[WorldName]
		
		if mode == 1 then
			teleportInfoFrame.NormalMode.Visible = true
			teleportInfoFrame.HardMode.Visible = false
		else
			teleportInfoFrame.NormalMode.Visible = false
			teleportInfoFrame.HardMode.Visible = true
		end
		
		worldImage.Image = WorldImageID
		teleportInfoFrame.MapName.Text = WorldName
		teleportInfoFrame.Act.Text = `Teleporting To: Act {actNumber} - {ActName}`
	elseif locationType == "Lobby" then
		local WorldImageID = StoryModeStatsModule.LoadScreenImages["Lobby"]
		worldImage.Image = WorldImageID
		teleportInfoFrame.MapName.Text = "Lobby"
		
		teleportInfoFrame.Act.Visible = false
		teleportInfoFrame.HardMode.Visible = false
		teleportInfoFrame.NormalMode.Visible = false
	elseif locationType == "AFKChamber" then
		local WorldImageID = StoryModeStatsModule.LoadScreenImages["Lobby"]
		worldImage.Image = WorldImageID
		teleportInfoFrame.MapName.Text = "AFk Chamber"
		
		teleportInfoFrame.Act.Visible = false
		teleportInfoFrame.HardMode.Visible = false
		teleportInfoFrame.NormalMode.Visible = false
	end
	
	local alreadyPickedHints = {}
	for i = 1, 3 do
		local random = math.random(1, #Hints)
		local pickHint = Hints[random]
		while table.find(alreadyPickedHints, pickHint) do
			random = math.random(1, #Hints)
			pickHint = Hints[random]
			task.wait()
		end
		
		table.insert(alreadyPickedHints, pickHint)
	end
	
	local counter = 1
	print(alreadyPickedHints)
	for index, frame in hintsFrame:GetChildren() do
		if not frame:IsA("Frame") then continue end
		frame.Info.Text = alreadyPickedHints[counter]
		counter += 1
	end
	
	return screenGui
end

--function module.DisplayLoadingScreenWorld(locationType,worldNumber, actNumber)
--	--LocationType: Lobby, Game, AFKChamber
--	print(worldNumber, actNumber)
--	local WorldName = StoryModeStatsModule.Worlds[worldNumber]
--	local ActName = StoryModeStatsModule.LevelName[WorldName][actNumber]
--	local WorldImageID = StoryModeStatsModule.LoadScreenImages[WorldName]


--	local screenGui = module.CreateLoadingGui(WorldImageID, `Act {actNumber} - {ActName}`)

--	--WorldImage.Image = WorldImageID
--	--ActNameLabel.Text = `Act {actNumber} - {ActName}`
--	--WorldImage.Visible = true
--end

return module
