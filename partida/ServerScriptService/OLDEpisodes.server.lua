--!strict

local MarketplaceService : MarketplaceService = game:GetService('MarketplaceService')
local ReplicatedStorage : ReplicatedStorage = game:GetService('ReplicatedStorage')
local StarterPlayerScripts : StarterPlayerScripts = game:GetService('StarterPlayer').StarterPlayerScripts

--

local XPHandler = require( script.EpisodeConfig.XPHandler )
local EpisodeConfig = require( script.EpisodeConfig )
local EntryToDate = EpisodeConfig.EntryToDate
local CurrentEpisode : number = EpisodeConfig.CurrentEpisode
local EpisodeData = EpisodeConfig.EpisodeData

local tdelay = task.delay
local insert = table.insert
local format = string.format

local HandledTasks : { EpisodeConfig.TaskType } = {}
for Index = 1 , CurrentEpisode do
	local SpecificEpisodeInfo = EpisodeData[Index]
	local StartDate , ExpiryDate = EntryToDate( SpecificEpisodeInfo.StartDate ) , EntryToDate( SpecificEpisodeInfo.ExpiryDate )
	for __ , Task : EpisodeConfig.TaskType in SpecificEpisodeInfo.Tasks do
		local Type = Task.Type
		local Amount = Task.Amount
		--
		if not Task.StartDate then
			Task.StartDate = StartDate
		else
			Task.StartDate = EntryToDate( Task.StartDate )
		end
		if not Task.ExpiryDate then
			Task.ExpiryDate = ExpiryDate
		else
			Task.ExpiryDate = EntryToDate( Task.ExpiryDate )
		end
		--
		local IntValue : IntValue = Instance.new('IntValue')
		IntValue.Name = format( '%s_%s' , Type:gsub( ' ' , ' ' .. tostring( Amount ) .. ' ' , 1 ) , Task.UniqueId )
		IntValue.Value = 0
		IntValue:SetAttribute( 'Episode' , Index )
		IntValue.Parent = script
		Task['IntValue'] = IntValue
		--
		insert( HandledTasks , Task )
	end
end

--

local Modules = ReplicatedStorage:FindFirstChild('Modules')
local yuh = Modules and Modules:FindFirstChild('PassesList')
local PassesList = yuh and require( yuh )
local PremiumGamepassId = PassesList and PassesList.Information["Premium Season Pass"].Id

for __ , Script : LocalScript | ModuleScript in script:GetChildren() do
	local IsLocalScript = Script:IsA('LocalScript')
	Script.Parent = ( IsLocalScript and StarterPlayerScripts ) or ( Script:IsA('ModuleScript') and ReplicatedStorage ) or script
	if IsLocalScript then
		( Script :: LocalScript ).Enabled = true
	end
end

--

local stringd = 'Episode' .. CurrentEpisode .. 'XP'
local OnAdded = function( Player : Player )
    repeat task.wait() until Player:FindFirstChild('EpisodePass')
	--Player:WaitForChild('EpisodePass')
	local EpisodePass : Folder | any = Player:FindFirstChild('EpisodePass')
	if not EpisodePass then
		warn('waht th hel')
		return
	end
	--
	tdelay( 5 , function()
		local TasksFolder : Folder = EpisodePass.Tasks
		for __ , Task : EpisodeConfig.TaskType in HandledTasks do
			local IntValue : IntValue? = Task.IntValue
			if not IntValue then
				continue
			end
			local TheEpisode = tostring( IntValue:GetAttribute('Episode') )
			local TheFolder = TasksFolder:FindFirstChild( TheEpisode )
			if not TheFolder then
				TheFolder = Instance.new('Folder')
				TheFolder.Name = TheEpisode
				TheFolder.Parent = TasksFolder
			end
			--
			if TheFolder:FindFirstChild( IntValue.Name ) then
				continue
			end
			IntValue:Clone().Parent = TheFolder
		end
		XPHandler.RedeemTiers( Player );
		( EpisodePass[stringd] :: IntValue ):GetPropertyChangedSignal('Value'):Connect(function()
			XPHandler.RedeemTiers( Player )
		end)
	end)
	--
	local Premium = EpisodePass.Premium :: BoolValue
	if PremiumGamepassId and not Premium.Value and MarketplaceService:UserOwnsGamePassAsync( Player.UserId , PremiumGamepassId ) then
		Premium.Value = true
	end
end

local Players : Players = game:GetService('Players')
for __ , Player : Player in Players:GetPlayers() do
	OnAdded( Player )
end
Players.PlayerAdded:Connect( OnAdded )