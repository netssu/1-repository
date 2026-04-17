local RS = game:GetService("ReplicatedStorage")
local ItemStatsModule = require(RS:WaitForChild("ItemStats"))
local TravelingMerchant = workspace.TravelingMerchant:WaitForChild("Merchant")
local BuyTravelingMerchantItem = RS:WaitForChild("Functions"):WaitForChild("BuyTravelingMerchantItem")
local ClosedSign = workspace.TravelingMerchant:WaitForChild("ClosedSign")
local GetItemModule = require(RS.Modules.GetItemModel)
local latestUpdatedQuarter = -1

function GetSellableItems()
    local list = {}
    for _, info in ItemStatsModule do
        if info.InMerchant then
            table.insert(list, info)
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
        local newItemIndex = rng:NextInteger(1, #sellableItems)
        if not table.find(newList, sellableItems[newItemIndex]) then
            table.insert(newList, sellableItems[newItemIndex])
        end
        if #newList >= 3 then
            break
        end
        task.wait()
    end

    local playersAlreadyBough = {}
    return newList
end

local function CalculateLeaveTime()
    local currentTime = os.time()
    local currentMinute = math.floor(currentTime / 60) % 60
    local currentHour = math.floor(currentTime / 3600)

    local quarter = math.floor(currentMinute / 15)
    local nextQuarterStart = (currentHour * 3600) + ((quarter + 1) * 15 * 60)
    local leaveAt = nextQuarterStart
    local returnAt = leaveAt + (15 * 60)

    return leaveAt, returnAt
end

function Update()
    local now = os.time()
    local currentQuarter = math.floor(now / (15 * 60))

    local function UpdateLeaveReturnValue()
        local leaveAtTime, returnAtTime = CalculateLeaveTime()
        TravelingMerchant.LeavingAt.Value = leaveAtTime
        TravelingMerchant.ReturnAt.Value = returnAtTime
    end
    UpdateLeaveReturnValue()

    if now >= TravelingMerchant.LeavingAt.Value and now < TravelingMerchant.ReturnAt.Value then
        if TravelingMerchant.isOpen.Value then
            TravelingMerchant.isOpen.Value = false
            TravelingMerchant.Items:ClearAllChildren()
        end
        if ClosedSign.Parent ~= workspace.TravelingMerchant then
            ClosedSign.Parent = workspace.TravelingMerchant
        end
        return
    else
        if ClosedSign.Parent ~= RS then
            ClosedSign.Parent = RS
        end
    end

    if currentQuarter ~= latestUpdatedQuarter then
        TravelingMerchant.Items:ClearAllChildren()

        local newItems = GetNewSetOfItemStats(currentQuarter)
        for index, itemStats in newItems do
            local itemClone = GetItemModule[itemStats.Name]:Clone()
            itemClone.HumanoidRootPart.CFrame = TravelingMerchant.ItemSlots[tostring(index)].CFrame
            itemClone.HumanoidRootPart.Anchored = true
            itemClone.Parent = TravelingMerchant.Items
        end

        latestUpdatedQuarter = currentQuarter
        TravelingMerchant.isOpen.Value = true
    end
end

function BuyRequest(player, itemName)
    if not TravelingMerchant.Items:FindFirstChild(itemName) then return "Invalid", "Item Not In Shop" end

    local itemStats = ItemStatsModule[itemName]
    local priceType = itemStats.Price.Type
    local priceAmount = itemStats.Price.Amount

    if player[priceType].Value < priceAmount then return "Invalid", `Not Enough {priceType}` end

    local playerBoughtFromTravelingMerchant = player["BoughtFromTravelingMerchant"]
    local merchantLeavingTime = playerBoughtFromTravelingMerchant.MerchantLeavingTime
    local itemsBought = playerBoughtFromTravelingMerchant.ItemsBought

    if merchantLeavingTime.Value ~= TravelingMerchant.LeavingAt.Value then
        itemsBought:ClearAllChildren()
        merchantLeavingTime.Value = TravelingMerchant.LeavingAt.Value
    elseif itemsBought:FindFirstChild(itemName) then
        return "Invalid", "Already Bought Item"
    end

    local newItem = Instance.new("NumberValue")
    newItem.Name = itemName
    newItem.Parent = itemsBought

    local TraitPointsNumber = tonumber(string.match(itemName, "%d+"))
    if TraitPointsNumber ~= nil then
        player[priceType].Value -= priceAmount
        player.TraitPoint.Value += TraitPointsNumber
    else
        player[priceType].Value -= priceAmount

        if player.Items[itemName].Value < 0 then
            player.Items[itemName].Value = 0
        end

        player.Items[itemName].Value += 1
    end

    return "Valid", `Successfully Purchased {itemName} For {priceAmount} {priceType}`
end

BuyTravelingMerchantItem.OnServerInvoke = BuyRequest

while true do
    Update()
	task.wait()
end
