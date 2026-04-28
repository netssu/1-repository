-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CONSTANTS
local Events = ReplicatedStorage:WaitForChild("Events")
local ChallengesEvents = Events:WaitForChild("Challenges")
local ChallengePurchase = ChallengesEvents:WaitForChild("ChallengePurchase")
local CreditsChanged = ChallengesEvents:WaitForChild("CheckCurrency")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ViewPortModule = require(Modules:WaitForChild("ViewPortModule"))
local LoadingData = require(Modules:WaitForChild("LoadingRaidShopData"))

local MessageEvent = Events:WaitForChild("Client"):WaitForChild("Message")

-- VARIABLES
local Player = Players.LocalPlayer
local PlayerGUI = Player:WaitForChild("PlayerGui")

-- Novos Caminhos da UI
local NewUI = PlayerGUI:WaitForChild("NewUI")
local ChallengeShopGUI = NewUI:WaitForChild("ChallengeShopFrame")
local Main = ChallengeShopGUI:WaitForChild("Main")
local RewardsTab = Main:WaitForChild("RewardsTab")
local TextAmount = RewardsTab:WaitForChild("TextAmount")

-- Caminho do container de recompensas
local RewardsContainer = RewardsTab:WaitForChild("Rewards"):WaitForChild("Rewards")

-- UIs Externas
local CoreGameUI = PlayerGUI:WaitForChild("CoreGameUI")
local Prompt = CoreGameUI:WaitForChild("Prompt"):WaitForChild("Prompt")
local CurrencyCongratsLabel = PlayerGUI:WaitForChild("GameGui"):WaitForChild("PRShop"):WaitForChild("Success")

local debounceFlags = {}
local selectedItem = nil

-- Criando a tabela de botões dinamicamente com base no que existe no container
local buttons = {
	["Crystal (Green)"] = RewardsContainer:FindFirstChild("Crystal (Green)"),
	["Crystal (Blue)"] = RewardsContainer:FindFirstChild("Crystal (Blue)"),
	["Red Crystal"] = RewardsContainer:FindFirstChild("Red Crystal"),
	["Crystal (Pink)"] = RewardsContainer:FindFirstChild("Crystal (Pink)"),
	["Crystal (Celestial)"] = RewardsContainer:FindFirstChild("Crystal (Celestial)"),
	["Gems"] = RewardsContainer:FindFirstChild("Gems"),
	["Sixth Brother"] = RewardsContainer:FindFirstChild("Sixth Brother"),
	["TraitPoint"] = RewardsContainer:FindFirstChild("TraitPoint"),
	["Crystal"] = RewardsContainer:FindFirstChild("Crystal"),
}

-- FUNCTIONS
local function ShowSuccessMessage(typeOf, name, quantity)
	if typeOf == "Currency" then
		local itemName = typeof(name) == "Instance" and name.Name or tostring(name)
		CurrencyCongratsLabel.Text = tostring(quantity) .. "x " .. itemName .. " Earned!"
		CurrencyCongratsLabel.Visible = true
		task.wait(2)
		CurrencyCongratsLabel.Visible = false
	end

	if typeOf == nil then
		_G.Message("Purchase Failed", Color3.fromRGB(255, 5, 17))
	else
		_G.Message("Purchase Successful", Color3.fromRGB(28, 255, 3))
	end
end

local function SetupViewPorts()
	local viewDataNames = {
		"Crystal (Pink)",
		"Lucky Crystal",
		"Crystal (Green)",
		"Crystal (Blue)",
		"Red Crystal",
		"Crystal (Celestial)",
		"Crystal",
		"Sixth Brother"
	}

	for _, itemName in pairs(viewDataNames) do
		local itemFrame = RewardsContainer:FindFirstChild(itemName)
		if itemFrame then
			local placeholder = itemFrame:FindFirstChild("Placeholder")
			if placeholder then
				local icon = placeholder:FindFirstChild("Icon")
				if icon then
					icon.Image = "" -- Limpa a imagem antes de setar o viewport
				end

				local viewport = ViewPortModule.CreateViewPort(itemName)
				-- Adicionada verificação de segurança para evitar erro de 'nil'
				if viewport then
					viewport.Parent = placeholder
					viewport.Size = UDim2.new(1, 0, 1, 0)
				else
					warn("Modelo ViewPort não encontrado para: " .. itemName)
				end
			end
		end
	end
end

local function UpdateCurrencyDisplay()
	local creditsValue = CreditsChanged:InvokeServer(Player)
	-- Atualizando com a formatação solicitada
	TextAmount.Text = "Republic Credits: x" .. tostring(creditsValue)
end

-- INIT
Prompt.Vote_Skip.Contents.Options.Yes.Activated:Connect(function()
	if selectedItem then
		Prompt.Visible = false
		ChallengePurchase:FireServer(selectedItem)
		selectedItem = nil
	end
end)

Prompt.Vote_Skip.Contents.Options.No.Activated:Connect(function()
	Prompt.Visible = false
	selectedItem = nil
end)

ChallengeShopGUI:GetPropertyChangedSignal("Visible"):Connect(function()
	if ChallengeShopGUI.Visible then
		UpdateCurrencyDisplay()
		SetupViewPorts()

		for itemName, button in pairs(buttons) do
			if button then
				if not debounceFlags[itemName] then
					debounceFlags[itemName] = false
				end

				button.Activated:Connect(function()
					if debounceFlags[itemName] then return end
					debounceFlags[itemName] = true

					selectedItem = itemName
					Prompt.Visible = true

					task.wait(1)
					debounceFlags[itemName] = false
				end)
			end
		end
	end
end)

ChallengesEvents:WaitForChild("ChallengeShopLoading").Event:Connect(function(visible)

end)

ChallengePurchase.OnClientEvent:Connect(function(typeOf, name, quantity)
	ShowSuccessMessage(typeOf, name, quantity)
end)

local currency = Player:WaitForChild("RepublicCredits", 10)
if currency then
	currency:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateCurrencyDisplay()
	end)
end