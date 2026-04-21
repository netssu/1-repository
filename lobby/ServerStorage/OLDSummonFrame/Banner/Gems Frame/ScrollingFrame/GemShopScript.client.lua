local mod = require(game.ReplicatedStorage.Modules.MarketModule).Gems
local MPS = game:GetService("MarketplaceService")

for i=1,#mod do
	local button = script.Template:Clone()
	button.LayoutOrder = i
	button.Activated:Connect(function()
		MPS:PromptProductPurchase(game.Players.LocalPlayer,mod[i].ProductID)
	end)
	button.PackName.Text = mod[i].Name
	button.Value.Text = mod[i].Value
	button.Price.Text = mod[i].Price
	button.Discount.Text = mod[i].Discount
	button.Parent = script.Parent
	button.Image = mod[i].ImageID
end