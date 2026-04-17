local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientDataLoaded = require(ReplicatedStorage.Modules.ClientDataLoaded)
local PlayerData = ClientDataLoaded.getPlayerData()
local Functions = require(ReplicatedStorage.Modules.Functions)


for i,v:Frame in script.Parent:GetChildren() do
	if v:IsA('Frame') then
		local currency = PlayerData[v.Name] :: NumberValue
		local function update()
			v.Amount.Text = Functions.addCommas(currency.Value)
		end
		
		update()
		currency.Changed:Connect(update)
	end
end