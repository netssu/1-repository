local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ClientDataLoaded = require(ReplicatedStorage.Modules.ClientDataLoaded)
local PlayerData = ClientDataLoaded.getPlayerData()
local Functions = require(ReplicatedStorage.Modules.Functions)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local NewUI = PlayerGui:WaitForChild("NewUI")
local NewValues = NewUI:WaitForChild("Values")

local function getValueLabel(currencyName)
	local valueFrame = NewValues:FindFirstChild(currencyName)
	if not valueFrame then return nil end

	local label = valueFrame:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		return label
	end

	return valueFrame:FindFirstChildWhichIsA("TextLabel", true)
end

local function updateCurrency(currencyName)
	local currency = PlayerData:FindFirstChild(currencyName)
	if not currency then return end

	local formattedValue = Functions.addCommas(currency.Value)

	local oldCurrencyFrame = script.Parent:FindFirstChild(currencyName)
	local oldAmount = oldCurrencyFrame and oldCurrencyFrame:FindFirstChild("Amount")
	if oldAmount and oldAmount:IsA("TextLabel") then
		oldAmount.Text = formattedValue
	end

	local newValueLabel = getValueLabel(currencyName)
	if newValueLabel then
		newValueLabel.Text = formattedValue
	end
end

local watchedCurrencies = {}

local function addWatchedCurrency(currencyName)
	if watchedCurrencies[currencyName] then return end

	local currency = PlayerData:FindFirstChild(currencyName) :: NumberValue
	if not currency then return end

	watchedCurrencies[currencyName] = true
	updateCurrency(currencyName)
	currency.Changed:Connect(function()
		updateCurrency(currencyName)
	end)
end

for _, v: Frame in script.Parent:GetChildren() do
	if v:IsA('Frame') then
		addWatchedCurrency(v.Name)
	end
end

for _, v: Frame in NewValues:GetChildren() do
	if v:IsA('Frame') then
		addWatchedCurrency(v.Name)
	end
end
