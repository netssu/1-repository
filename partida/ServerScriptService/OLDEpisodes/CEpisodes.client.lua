--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local MarketplaceService : MarketplaceService = game:GetService('MarketplaceService')

local osdate = os.date
local format = string.format
local insert = table.insert

local max = math.max
local floor = math.floor
local clamp = math.clamp

local InfoType = Enum.InfoType
local GamePass = InfoType.GamePass
local Product = InfoType.Product

local Gradients = script.Gradients
local wwwassetid = 'http://www.roblox.com/asset/?id='
local IconIds = {
	['Gems'] = 72506401786714,
	['Coins'] = 134912142304203,
	['SquidCoins'] = 110724750963578,
	['Super Lucky'] = 124040406550722,
	['Ultra Lucky'] = 109754841387255,
	['PowerPoint'] = 78796346246015,
	['TraitPoint'] = 117354512832182,
	['JunkOfferings'] = 112012989406115,
}

local Check = 'rbxassetid://77864255244610'
local Lock = 'rbxassetid://94403550723191'

local Placement = ReplicatedStorage:WaitForChild('EpisodeConfig')
local EpisodeConfig : typeof( require( script.Parent.EpisodeConfig ) ) = require( Placement )
local XPHandler : typeof( require( script.Parent.EpisodeConfig.XPHandler ) ) = require( Placement:WaitForChild('XPHandler') )
local CurrentEpisode : number = EpisodeConfig.CurrentEpisode
local EpisodeInfo = EpisodeConfig.EpisodeData[CurrentEpisode]

--

local LocalPlayer = game:GetService('Players').LocalPlayer
if not LocalPlayer then
	return
end
local PlayerGui = LocalPlayer.PlayerGui

repeat task.wait() until PlayerGui:FindFirstChild('CoreGameUI')
local CoreGameUI = PlayerGui:WaitForChild('CoreGameUI')
if not CoreGameUI then
	return
end
local SeasonPassFrame = CoreGameUI.SeasonPass.SeasonPassFrame

local Core = SeasonPassFrame.Core ; Core.EXTRAS.Visible = true
local CoreContents = Core.Contents
local PremiumLock = Core.PremiumPassLOCK

local Main_Reward = Core.Main_Reward
local TierDisplayLabel = Main_Reward.TierDisplay
local XPDisplayLabel = Main_Reward.XPDisplay
local Bar = Main_Reward.Refresh_Bar.Contents.Bar ; Bar.Size = UDim2.fromScale( 0 , 1 )

--local Thread
local X_CloseHandler = LocalPlayer.PlayerScripts:FindFirstChild('X_CloseHandler') :: typeof( game.StarterPlayer.StarterPlayerScripts.X_CloseHandler )
if X_CloseHandler then
	require( X_CloseHandler ).work( {
		Button = Core.X_Close,
		Callback = function()
			--if Thread then
			--	task.cancel( Thread )
			--end
		end,
	} )
end



local GetMarketInfoByName = ReplicatedStorage:WaitForChild('Functions').GetMarketInfoByName
local BuyEvent = ReplicatedStorage:WaitForChild('Events').Buy
local GiftFolder = CoreGameUI.Gift
local GiftFrame = GiftFolder.GiftFrame
local SelectedGiftId = GiftFolder.SelectedGiftId

local DisplayCache : { [string] : any } = {}
local OnDisplay = function( InfoName : string , StandardButton : GuiButton , GiftButton : GuiButton )
	local Info = DisplayCache[InfoName] or GetMarketInfoByName:InvokeServer( InfoName )
	if not Info then
		warn( `{InfoName} ui does not have a market info` )
		return
	end
	DisplayCache[InfoName] = Info
	--
	local InfoId , InfoGiftId = Info.Id , Info.GiftId
	StandardButton.MouseButton1Down:Connect(function()
		print(InfoId,InfoName)
		BuyEvent:FireServer( InfoId )
	end)
	GiftButton.MouseButton1Down:Connect(function()
		SelectedGiftId.Value = InfoGiftId
		GiftFrame.Visible = true
	end)
end
local Skip10Frame = SeasonPassFrame.Side_Shop.Contents.Skip_10.Contents ; OnDisplay( 'Skip 10 Tiers' , Skip10Frame.Buy , Skip10Frame.Gift )
local PremiumPassFrame = PremiumLock.Contents ; OnDisplay( 'Premium Season Pass' , PremiumPassFrame.Buy , PremiumPassFrame.Gift )



local TierTemplate = script.TierTemplate
local TierDisplay = CoreContents.Rewards_Frame.Bar

local TierInfo = EpisodeConfig.TierData[CurrentEpisode]
if not TierInfo then
	warn('wehre the hel is the info')
end
local GetCurrentTier = XPHandler.GetCurrentTier
local GetXPForTier = XPHandler.GetXPForTier



LocalPlayer:WaitForChild('EpisodePass')
local EpisodePass : Folder | any = LocalPlayer:FindFirstChild('EpisodePass')

local Premium = EpisodePass.Premium :: BoolValue
if not Premium.Value then
	Premium:GetPropertyChangedSignal('Value'):Connect(function()
		if Premium.Value then
			PremiumLock:Destroy()
		end
	end)
else
	PremiumLock:Destroy()
end

local Overlays : { [number] : { Frame } } = {}
local CurrentXP = EpisodePass[ 'Episode' .. tostring( CurrentEpisode ) .. 'XP'] :: IntValue
local CurrentTier = GetCurrentTier( CurrentXP.Value )
local OnXP = function()
	--print( 'currenttier' , CurrentTier - 1 )
	local CurrentXPValue = CurrentXP.Value
	CurrentTier = GetCurrentTier( CurrentXPValue )
	local TargetXP = GetXPForTier( CurrentTier )
	TierDisplayLabel.Text = format( 'Tier %2d' , CurrentTier - 1 )
	XPDisplayLabel.Text = format( '%2d/%2d XP' , CurrentXPValue , TargetXP )
	--
	local XPToEnterCurrentTier = XPHandler.GetXPForTier( max( CurrentTier - 1 , 0 ) )
	Bar.Size = UDim2.fromScale( clamp( ( CurrentXPValue - XPToEnterCurrentTier ) / ( TargetXP - XPToEnterCurrentTier ) , 0 , 1 ) , 1)
	for Index = 1 , #Overlays do
		local DualOverlays = Overlays[Index]
		for __ , Overlay : Frame in DualOverlays do
			local IsPremiumFrame = Overlay.Parent.Parent.Parent.Name == 'PremiumFrame'
			Overlay.Visible = ( ( not Premium.Value and IsPremiumFrame ) and true ) or Index > CurrentTier - 1
		end
	end
end
OnXP()
CurrentXP:GetPropertyChangedSignal('Value'):Connect( OnXP )


local QuestTemplate = script.QuestTemplate
local QuestsFrame = Core.Pass_Quests
local QuestsContents = QuestsFrame.Contents

local RequestClaim = ReplicatedStorage:WaitForChild('RequestClaim') :: RemoteEvent
task.delay( 7 , function()
	--pcall(function()
	--	print( EpisodePass )
	--	print(EpisodePass.Tasks)
	--	print(EpisodePass.Tasks[tostring(CurrentEpisode)])
	--	for __ , a in EpisodePass.Tasks[tostring(CurrentEpisode)]:GetChildren() do
	--		print( a.Name )
	--		print( a.Value )
	--	end
	--end)
	local sumsum = {}
	for __ , ihopethisteachesyouwhytypesareimportant in EpisodeInfo.Tasks do
		sumsum[format( '%s_%s' , ihopethisteachesyouwhytypesareimportant.Type:gsub( ' ' , ' ' .. tostring( ihopethisteachesyouwhytypesareimportant.Amount ) .. ' ' , 1 ) , ihopethisteachesyouwhytypesareimportant.UniqueId )] = { Amount = ihopethisteachesyouwhytypesareimportant.Amount , XPOverride = ihopethisteachesyouwhytypesareimportant.XPOverride }
	end --hardcoded af but im running outa time
	--print(sumsum)
	local WantedFolder = EpisodePass:WaitForChild('Tasks'):FindFirstChild( tostring( CurrentEpisode ) ) :: Folder
	for __ , NumberValue : NumberValue in WantedFolder:GetChildren() do
		--print('ho')
		--if not NumberValue:IsA('NumberValue') then
		--	continue
		--end
		--print( typeof(NumberValue) )
		if NumberValue.Value == -2 then
			continue
		end
		--print('gg')
		local IsCompleted = NumberValue.Value == -1
		--
		local NewQuest = QuestTemplate:Clone()
		NewQuest.Parent = QuestsContents
		local Contents = NewQuest.Contents
		local TextFrame = Contents.TextFrame
		--
		local cachedsumsum = sumsum[NumberValue.Name]
		if not cachedsumsum then
			warn( 'why isnt this working?' , NumberValue , NumberValue.Name )
			continue
		end
		--print('here now')
		local Amount = cachedsumsum.Amount
		TextFrame.Progress.Text = tostring( IsCompleted and Amount or NumberValue.Value ) .. '/' .. tostring( Amount )
		TextFrame.Subtext.Text = NumberValue.Name:split('_')[1]
		TextFrame.Title.Text = 'Season Quest'
		Contents.Reward_Amount.Text = tostring( cachedsumsum.XPOverride or XPHandler.XPPerQuest ) .. ' XP'
		if IsCompleted then
			local selfcon
			selfcon = Contents.Claim.MouseButton1Down:Connect(function()
				if NumberValue.Value == -2 and selfcon then --stop firing bc u got yo xp
					NewQuest.Visible = false
					selfcon:Disconnect()
					return
				end
				RequestClaim:FireServer( NumberValue.Name )
			end)
		end
	end
end)



local ViewPortModule = require( ReplicatedStorage.Modules.ViewPortModule )
local CreateViewPort = ViewPortModule.CreateViewPort

type ContentsFrameType = typeof( TierTemplate.FreeFrame.Reward.Contents ) | typeof( TierTemplate.PremiumFrame.Reward.Contents )
local SetupIndividualFrame = function( ContentsFrame : ContentsFrameType , IndividualTypeInfo : any | EpisodeConfig.TierType , Index : number )
	local Title : string = IndividualTypeInfo.Title
	local Amount : number = IndividualTypeInfo.Amount
	if ( not ( Title or Amount ) ) or Title == '' or Amount == 0 then
		warn('y use templat')
		return
	end
	local IsPremiumFrame = ContentsFrame.Parent.Parent.Name == 'PremiumFrame'
	--
	local DisplayIcon = ContentsFrame.DisplayIcon
	local Icon = IconIds[Title]
	if Icon then
		DisplayIcon.Image = wwwassetid .. tostring( Icon )
		local SpecificGradient = Gradients:FindFirstChild( Title )
		if SpecificGradient then
			DisplayIcon.UIGradient:Destroy()
			SpecificGradient:Clone().Parent = DisplayIcon
		end
	else
		local IsShiny = Title:find('SHINY') and true
		local NewViewport : ViewportFrame? = CreateViewPort( IsShiny and Title:split('SHINY ')[2] or Title , IsShiny )
		if NewViewport then
			NewViewport.ZIndex = DisplayIcon.ZIndex
			NewViewport.Position = DisplayIcon.Position
			NewViewport.Size = DisplayIcon.Size
			NewViewport.AnchorPoint = DisplayIcon.AnchorPoint
			NewViewport.Parent = DisplayIcon.Parent
			DisplayIcon:Destroy()
		end
	end
	ContentsFrame.AmountLabel.Text = 'x' .. tostring( Amount )
	ContentsFrame.Overlay.Visible = ( ( not Premium.Value and IsPremiumFrame ) and true ) or Index > CurrentTier - 1
	if not Overlays[Index] then
		Overlays[Index] = {}
	end
	insert( Overlays[Index] , ContentsFrame.Overlay )
end

for Index = 1 , #TierInfo do
	local IndividualInfo = TierInfo[Index]
	if not IndividualInfo then
		return
	end
	--
	local NewTierTemplate = TierTemplate:Clone()
	NewTierTemplate.TierDisplay.Level_Template.Contents.TextLabel.Text = 'Tier ' .. tostring( Index )
	--
	SetupIndividualFrame( NewTierTemplate.FreeFrame.Reward.Contents , IndividualInfo.Free , Index )
	SetupIndividualFrame( NewTierTemplate.PremiumFrame.Reward.Contents , IndividualInfo.Premium , Index )
	--
	NewTierTemplate.Parent = TierDisplay
end



local QuestsnRewards = Main_Reward.QuestsnRewards
local QuestsnRewardsLabel = QuestsnRewards.Contents.Contents.Pass_Text

local Toggle = function( boolean : boolean )
	CoreContents.Visible = boolean
	PremiumPassFrame.Visible = boolean
	QuestsFrame.Visible = not boolean
	QuestsnRewardsLabel.Text = not boolean and 'Rewards' or 'Quests'
end ; Toggle( false )
QuestsnRewards.MouseButton1Down:Connect(function()
	Toggle( QuestsnRewardsLabel.Text == 'Rewards' and true or false )
end)

--

local MDHMS = function( Seconds : number ) : string
	return format( '%02d:%02d:%02d:%02d' , floor( Seconds / 86400 ) , floor( ( Seconds % 86400 ) / 3600) , floor( ( Seconds % 3600 ) / 60 ) , Seconds % 60 )
end
local ExpiryDate = EpisodeConfig.EntryToDate( EpisodeInfo.ExpiryDate )
function TimeCreation()
	return task.spawn(function()
		while task.wait( 1 ) do
			local TimeRemaining : number = ExpiryDate - os.time()
			if 0 >= TimeRemaining then
				break
			end
			local StringdTimeRemaining = format( 'Time Remaining: %s' , MDHMS( TimeRemaining ) )
			--print( StringdTimeRemaining )
		end
	end)
end ; TimeCreation()
--Thread = TimeCreation()