local floor = math.floor

local EpisodeConfig = require(script.Parent)
local CurrentEpisode = EpisodeConfig.CurrentEpisode
local EpisodeInfo = EpisodeConfig.EpisodeData[CurrentEpisode]

local TierInfo = EpisodeConfig.TierData[CurrentEpisode]

local MaxTier = #TierInfo
local XPCurve = EpisodeInfo.XPCurve
local Exponent = 1.5
local MinXPPerTier = 35

local TotalWeight = 0
for Index = 1, MaxTier do
	TotalWeight += Index ^ Exponent
end

local XPHandler = {}

--

local FindMatchingUniqueId = function( ValueName : string )
	local UniqueId = ValueName:split('_')[2]
	for __ , Task in EpisodeInfo.Tasks do
		if Task.UniqueId == UniqueId then
			return Task
		end
	end
	return nil
end

XPHandler.UpdateQuests = function( Player : Player , QuestType : 'Defeat Enemies' | 'Defeat Bosses' | 'Clear Acts' | 'Complete Raids' )
	Player:WaitForChild('EpisodePass')
	local EpisodePass : Folder | any = Player:FindFirstChild('EpisodePass')
	if not EpisodePass then
		--warn('episoda pass no exista')
		return
	end
	--
	for __ , NumberValue : NumberValue in EpisodePass.Tasks[CurrentEpisode]:GetChildren() do
		local Task = FindMatchingUniqueId( NumberValue.Name )
		if not Task then
			--warn('unabl to find task to upda')
			continue
		end
		if Task.Type ~= QuestType then
			continue
		end
		--
		if NumberValue.Value == -2 then -- quest was claimed
			--print('alr claimed')
			continue
		end
		if NumberValue.Value >= 0 then -- update value
			NumberValue.Value = NumberValue.Value + 1
			--print('updated 1')
		end
		if NumberValue.Value >= Task.Amount then -- quest needs to be claimed
			--print('needa be claimed')
			NumberValue.Value = -1
		end
	end
end

--

function XPHandler.GetXPForTier( Tier : number ) : number
	local Weight = 0
	for Index = 1 , Tier do
		Weight += Index ^ Exponent
	end
	local ScaledXP = ( Weight / TotalWeight ) * XPCurve
	local TotalXP = ScaledXP + MinXPPerTier * Tier
	return floor( TotalXP + 0.5 )
end

function XPHandler.GetCurrentTier(CurrentXP)
	local Tier = 1
	while CurrentXP >= XPHandler.GetXPForTier( Tier ) do
		Tier += 1
	end
	return Tier
end

--

local noshinydjango = function( Player : Player , actual : BoolValue )
	if not actual or actual:FindFirstChild('recompensation') then
		return
	end
	local gotthatshinyalr = false
	local tochangeunit
	for __ , tower in Player:WaitForChild('OwnedTowers'):GetChildren() do
		if tower.Name == 'Django' then
			tochangeunit = tower
			if tower:GetAttribute('Shiny') then
				--print('ooh, so u got shiny alr uhuh')
				gotthatshinyalr = true
			end
		end
	end
	if not gotthatshinyalr and tochangeunit then
		--print('gav that shiny')
		local b = Instance.new('BoolValue')
		b.Name = 'recompensation'
		b.Value = true
		b.Parent = actual
		tochangeunit:SetAttribute('Shiny',true)
	end
end

local clamp = math.clamp
local stringd = 'Episode' .. CurrentEpisode ..'XP'
XPHandler.RedeemTiers = function( Player : Player )
	Player:WaitForChild('EpisodePass')
	local EpisodePass : Folder | any = Player:FindFirstChild('EpisodePass')
	if not EpisodePass then
		warn('episoda pass no exista')
		return
	end
	--
	
	local episodeXP = EpisodePass:WaitForChild(stringd)
	
	local ownspremium = Player.OwnGamePasses['Premium Season Pass']
	local RewardsClaimed = EpisodePass.RewardsClaimed
	for Index = 1 , clamp( XPHandler.GetCurrentTier( episodeXP.Value :: number ) - 1 , 0 , MaxTier ) do
		for freeopremium , titlenamount in TierInfo[Index] do
			if freeopremium == 'Premium' and not ownspremium.Value then
				continue
			end
			--print('b')
			local wannaname = CurrentEpisode..Index..freeopremium
			local actual = RewardsClaimed:FindFirstChild(wannaname)
			if wannaname == '130Premium' then
				print('h')
				noshinydjango( Player , actual )
			end
			--print('1')
			if actual then
				continue
			end
			--
			local Title = titlenamount.Title
			print( Title , Title:find('SHINY') )
			local wasawarded = false
			local justavalue = ( Player:FindFirstChild( Title ) or Player.Items:FindFirstChild( Title ) ) :: NumberValue
			if justavalue then
				--print( justavalue , justavalue.Value )
				justavalue.Value += titlenamount.Amount
				--print( justavalue.Value )
				wasawarded = true
			else
				for indexyuh = 1 , titlenamount.Amount do
					--print( { Shiny = ( Title:find('SHINY') ) and true or false } )
					_G.createTower( Player.OwnedTowers , Title:find('SHINY') and Title:split('SHINY ')[2] or Title , '' , { Shiny = string.find(Title, "SHINY")} )
				end
				print('gg')
				wasawarded = true
			end
			--
			if wasawarded then
				local nV = Instance.new('BoolValue')
				nV.Name = wannaname
				nV.Value = true
				nV.Parent = RewardsClaimed
			end
		end
	end
end

if game:GetService('RunService'):IsServer() then
	local RequestClaim = game:GetService('ReplicatedStorage').Events.RequestClaim
	RequestClaim.OnServerEvent:Connect(function( Player : Player , ValueName : string )
		Player:WaitForChild('EpisodePass')
		local EpisodePass : Folder | any = Player:FindFirstChild('EpisodePass')
		if not EpisodePass then
			warn('episoda pass no exista')
			return
		end
		local XPValue = EpisodePass:WaitForChild( ( 'Episode' .. CurrentEpisode .. 'XP' ) ) :: NumberValue
		local TheValue = EpisodePass.Tasks[CurrentEpisode]:FindFirstChild( ValueName ) :: NumberValue
		if TheValue and TheValue.Value == -1 and XPValue then
			local Task = FindMatchingUniqueId( ValueName )
			if not Task then
				return
			end
			XPValue.Value += Task.XPOverride or XPHandler.XPPerQuest
			TheValue.Value = -2
			XPHandler.RedeemTiers( Player )
		end
	end)
end

--

local Total = 0
for Index = 1 , 30 do
	local GivenXP = XPHandler.GetXPForTier( Index )
	--print( 'Tier ' .. Index .. ' XP' , GivenXP )
	Total += GivenXP
end
--print( 'Total XP Needed:' .. Total )

XPHandler.MaxTier = MaxTier
XPHandler.XPPerQuest = Total / #EpisodeInfo.Tasks

return XPHandler