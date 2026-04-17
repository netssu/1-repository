
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ItemStatsModule = require( ReplicatedStorage:WaitForChild('ItemStats') )
local GetItemModule = require( ReplicatedStorage.Modules.GetItemModel )

local workspaceTravelingMerchant = workspace.TravelingMerchant
local ClosedSign = workspace:WaitForChild("ClosedSign")

local TravelingMerchant = workspace:WaitForChild("Merchant")
local TravelingMerchantItems = TravelingMerchant.Items
local TravelingMerchantItemSlots = TravelingMerchant.ItemSlots
local LeavingAt = TravelingMerchant.LeavingAt
local ReturnAt = TravelingMerchant.ReturnAt
local isOpen = TravelingMerchant.isOpen
local CheckCurrency = require(ReplicatedStorage.ShopSystem).CheckCurrency
local IsRoll = false



ReplicatedStorage:WaitForChild('Functions'):WaitForChild('BuyTravelingMerchantItem').OnServerInvoke = function( Player : Player , ItemName : string )
	if not TravelingMerchantItems:FindFirstChild( ItemName ) then
		return 'Invalid' , 'Item Not In Shop'
	end
	local ItemStats = ItemStatsModule[ItemName]
	local PriceType = ItemStats.Price.Type
	local PriceAmount = ItemStats.Price.Amount
	local Quantity = ItemStats.MerchantQuantity
	if Player[PriceType].Value < PriceAmount then
		return 'Invalid' , `Not Enough {PriceType}`
	end
	--
	local PlayerBoughtFromTravelingMerchant = Player['BoughtFromTravelingMerchant']
	local MerchantLeavingTime = PlayerBoughtFromTravelingMerchant.MerchantLeavingTime
	local ItemsBought = PlayerBoughtFromTravelingMerchant.ItemsBought
	if MerchantLeavingTime.Value ~= LeavingAt.Value then
		ItemsBought:ClearAllChildren()
		MerchantLeavingTime.Value = LeavingAt.Value
	elseif ItemsBought:FindFirstChild( ItemName ) then
		return 'Invalid' , 'Already Bought Item'
	end
	--
	Player[PriceType].Value -= PriceAmount
	local TraitPointsNumber = tonumber( ItemName:match('%d+') )
	if TraitPointsNumber ~= nil then
		Player.TraitPoint.Value += TraitPointsNumber
	else
		local SpecificItem = Player.Items[ItemName]
		
		
		if SpecificItem.Value < 0 then
			SpecificItem.Value = 0
		end
		
		if Quantity then
			print(Quantity)
			SpecificItem.Value += Quantity
		else
			SpecificItem.Value += 1	
		end
		
	end
	--
	local NewItem = Instance.new('NumberValue')
	NewItem.Name = ItemName
	NewItem.Parent = ItemsBought
	return 'Valid' , `Successfully Purchased {ItemName} For {PriceAmount} {PriceType}`
end





local insert = table.insert
local find = table.find
local floor = math.floor

local function GetSellableItems()
	
	
	
	local List = {}
	
	--insert(List, "LuckySpins")
	
	for __ , Info in ItemStatsModule do
		if Info.InMerchant then
			insert( List , Info )
		end
	end
	return List
end

local function GetNewSetOfItemStats( UniqueSeed )
	local rng = Random.new( UniqueSeed )
	local NewList = {}
	local SellableItems = GetSellableItems()
	
	while #NewList < 3 do
		local NewItemIndex = rng:NextInteger( 1 , #SellableItems )
		
		--if NewItemIndex == "LuckySpins" then
			
		--end
		
		if not find( NewList , SellableItems[NewItemIndex] ) then
			insert( NewList , SellableItems[NewItemIndex] )
		end
		task.wait()
	end
	return NewList
end

local function CalculateLeaveTime()
	local CurrentTime = os.time()
	local LeaveAt = ( floor( CurrentTime / 3600 ) * 3600 ) + ( ( ( floor( ( floor( CurrentTime / 60 ) % 60 ) / 15 ) ) + 1 ) * 15 * 60)
	return LeaveAt , LeaveAt + ( 15 * 60 )
end

local LatestUpdatedQuarter = -1
while task.wait( 1 ) do
	local TimeNow = os.time()
	local CurrentQuarter = floor( TimeNow / ( 15 * 60 ) )
	local LeaveAtTime , ReturnAtTime = CalculateLeaveTime()
	LeavingAt.Value = LeaveAtTime
	ReturnAt.Value = ReturnAtTime
	--
	local MiddleMet = TimeNow >= LeaveAtTime and TimeNow < ReturnAtTime
	if MiddleMet and isOpen.Value then
		isOpen.Value = false
		TravelingMerchantItems:ClearAllChildren()
	end
	local CSNP = ( MiddleMet and workspaceTravelingMerchant or ReplicatedStorage ) :: Instance
	if ClosedSign.Parent ~= CSNP then
		ClosedSign.Parent = CSNP
	end
	if MiddleMet then
		return
	end
	--
	if CurrentQuarter ~= LatestUpdatedQuarter then
		TravelingMerchantItems:ClearAllChildren()
		for Index , ItemStats in GetNewSetOfItemStats( CurrentQuarter ) do
			local ItemClone = GetItemModule[ItemStats.Name]
			if not ItemClone then continue end
			
			ItemClone = ItemClone:Clone()
			
			local PrimaryPart = ItemClone.PrimaryPart
			if not PrimaryPart then
				continue
			end
			PrimaryPart.CFrame = TravelingMerchantItemSlots[tostring(Index)].CFrame
			PrimaryPart.Anchored = true
			ItemClone.Parent = TravelingMerchantItems
		end
		LatestUpdatedQuarter = CurrentQuarter
		isOpen.Value = true
	end
end