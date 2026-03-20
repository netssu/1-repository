------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//VARIABLES
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local RebirthShopData = require(ReplicatedStorage.Modules.Datas.RebirthShopData)

local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local shopEvent = remotesFolder:FindFirstChild("RebirthShopEvent") or Instance.new("RemoteEvent", remotesFolder)

------------------//INIT
shopEvent.Name = "RebirthShopEvent"
DataUtility.server.ensure_remotes()

------------------//FUNCTIONS
local function handle_purchase(player: Player, itemId: string)
	local itemData
	for _, item in ipairs(RebirthShopData.Items) do
		if item.Id == itemId then 
			itemData = item 
			break 
		end
	end

	if not itemData then return end

	-- CORREÇÃO CRUCIAL: Usando "RebirthTokens" conforme o ProfileTemplate
	local currentTokens = DataUtility.server.get(player, "RebirthTokens") or 0
	local owned = DataUtility.server.get(player, "OwnedRebirthUpgrades") or {}

	-- Verifica se tem Tokens suficientes e se já não tem o item
	if not table.find(owned, itemId) and currentTokens >= itemData.Price then
		-- Desconta do valor correto
		DataUtility.server.set(player, "RebirthTokens", currentTokens - itemData.Price)

		table.insert(owned, itemId)
		DataUtility.server.set(player, "OwnedRebirthUpgrades", owned)

		print(player.Name .. " comprou " .. itemId .. ". Novo saldo: " .. (currentTokens - itemData.Price))
	else
		print(player.Name .. " tentou comprar " .. itemId .. " mas falhou. Tokens: " .. currentTokens)
	end
end

------------------//INIT
shopEvent.OnServerEvent:Connect(function(player, action, itemId)
	if action == "Purchase" then
		handle_purchase(player, itemId)
	end
end)