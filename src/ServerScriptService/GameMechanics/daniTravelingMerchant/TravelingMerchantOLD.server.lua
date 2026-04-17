local RS = game:GetService("ReplicatedStorage")
local ItemStatsModule = require(RS:WaitForChild("ItemStats"))
local TravelingMerchant = workspace.TravelingMerchant:WaitForChild("Merchant")
local BuyTravelingMerchantItem = RS:WaitForChild("Functions"):WaitForChild("BuyTravelingMerchantItem")
local ClosedSign = workspace.TravelingMerchant:WaitForChild("ClosedSign")
--local Salesman = workspace.TravelingMerchant:WaitForChild("Object_3")
local GetItemModule = require(RS.Modules.GetItemModel)
local latestUpdatedHour = 0

function GetSellableItems()
	local list = {}
	for _,info in ItemStatsModule do
		if info.InMerchant then
			table.insert(list,info)
		end
	end
	return list
end

function GetNewSetOfItemStats(uniqueSeed)
	local rng = Random.new(uniqueSeed)
	local newList = {}
	local foundNewSet = false
	local sellableItems = GetSellableItems()

	while not foundNewSet do
		local newItemIndex = rng:NextInteger(1,#sellableItems)
		if not table.find(newList,sellableItems[newItemIndex]) then
			table.insert(newList,sellableItems[newItemIndex])
		end
		if #newList >= 3 then
			break
		end
		task.wait()
	end

	local playersAlreadyBough = {}
	return newList
end

function Update()
	local currentHour = math.floor(os.time()/3600)
	local currentMinutePerHour = math.floor(os.time()/60) % 60

	local function CalculateLeaveTime()
		--if (currentHour % 3 == 1) then
		--	return (currentHour + 0.5) * 3600
		--else
		--	return (currentHour + 1) * 3600
		--end
		--return (currentHour + 1.5) * 3600

		local leaveAt, returnAt

		if (currentHour % 3 == 0) then
			leaveAt = (currentHour + 1) * 3600
			returnAt = currentHour * 3600
		elseif (currentHour % 3 == 1) then
			if currentMinutePerHour < 30 then
				leaveAt = currentHour * 3600
				returnAt = (currentHour + 0.5 ) * 3600
			else
				leaveAt = (currentHour + 1.5 ) * 3600
				returnAt = (currentHour + 2 ) * 3600
			end

		elseif (currentHour % 3 == 2) then
			--if currentMinutePerHour < 30 then
			leaveAt = (currentHour + 0.5) * 3600
			returnAt = (currentHour + 1) * 3600
			--else
			--leaveAt = (currentHour + 2) * 3600
			--returnAt = (currentHour - 0.5) * 3600
			--end

		end

		return leaveAt, returnAt

	end

	local function UpdateLeaveReturnValue()
		local leaveAtTime, returnAtTime = CalculateLeaveTime()
		TravelingMerchant.LeavingAt.Value = leaveAtTime
		TravelingMerchant.ReturnAt.Value = returnAtTime
	end
	UpdateLeaveReturnValue()

	if TravelingMerchant.isOpen.Value then
		--if Salesman.Parent ~= workspace.TravelingMerchant then
		--	Salesman.Parent = workspace.TravelingMerchant
		--end
		if ClosedSign.Parent ~= RS then
			ClosedSign.Parent = RS
		end
	else
		--if Salesman.Parent ~= RS then
		--	Salesman.Parent = RS
		--end
		if ClosedSign.Parent ~= workspace.TravelingMerchant then
			ClosedSign.Parent = workspace.TravelingMerchant
		end
	end

	if 
		( (currentHour % 3 == 1) and currentMinutePerHour <  30) or
		( (currentHour % 3 == 2) and currentMinutePerHour >= 30)
	then
		--print(`Merchant Close, Open back in {currentMinutePerHour % 30} Minute` )

		if TravelingMerchant.isOpen.Value then
			TravelingMerchant.isOpen.Value = false
			TravelingMerchant.Items:ClearAllChildren()
		end

		return
	end
	if currentHour ~= latestUpdatedHour then

		TravelingMerchant.Items:ClearAllChildren()
		--local leaveAtTime, returnAtTime = CalculateLeaveTime()
		--TravelingMerchant.LeavingAt.Value = leaveAtTime
		--TravelingMerchant.ReturnAt.Value = returnAtTime
		local newItems = GetNewSetOfItemStats(currentHour)

		for index,itemStats in newItems do
			local itemClone = GetItemModule[itemStats.Name]:Clone()
			itemClone.HumanoidRootPart.CFrame = TravelingMerchant.ItemSlots[tostring(index)].CFrame
			itemClone.HumanoidRootPart.Anchored = true
			itemClone.Parent = TravelingMerchant.Items
		end

		latestUpdatedHour = currentHour
		TravelingMerchant.isOpen.Value = true
	end
end

function BuyRequest(player,itemName)
	if not TravelingMerchant.Items:FindFirstChild(itemName) then return "Invalid","Item Not In Shop" end

	local itemStats = ItemStatsModule[itemName]

	local priceType = itemStats.Price.Type
	local priceAmount = itemStats.Price.Amount

	if player[priceType].Value < priceAmount then return "Invalid", `Not Enought {priceType}` end

	local playerBoughtFromTravelingMerchant = player["BoughtFromTravelingMerchant"]
	local merchantLeavingTime = playerBoughtFromTravelingMerchant.MerchantLeavingTime
	local itemsBought = playerBoughtFromTravelingMerchant.ItemsBought

	if merchantLeavingTime.Value ~= TravelingMerchant.LeavingAt.Value then
		itemsBought:ClearAllChildren()
		merchantLeavingTime.Value = TravelingMerchant.LeavingAt.Value
	elseif itemsBought:FindFirstChild(itemName) then return "Invalid","Already Bought Item" end
	local newItem = Instance.new("NumberValue")
	newItem.Name = itemName
	newItem.Parent = itemsBought

	local TraitPointsNumber = tonumber(string.match(itemName, "%d+"))
	if TraitPointsNumber ~= nil then
		player[priceType].Value -= priceAmount
		player.TraitPoint.Value += TraitPointsNumber
	else
        player[priceType].Value -= priceAmount
        
        if player.Items[itemName].Value < 0 then -- just to patch a holocron bug
            player.Items[itemName].Value = 0
        end
        
		player.Items[itemName].Value += 1
	end
	
	--TravelingMerchant.Items[itemName]:Destroy()
	return "Valid",`Successfully Purchase {itemName} For {priceAmount}{priceType}`
end

BuyTravelingMerchantItem.OnServerInvoke = BuyRequest

while true do
	Update()
	task.wait()
end