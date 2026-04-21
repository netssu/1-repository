local ReplicatedStorage = game:GetService('ReplicatedStorage')
local PassesList = require(ReplicatedStorage.Modules.PassesList).Information
local MarketPlaceService = game:GetService('MarketplaceService')

local RobuxChar = ''

for i,v in pairs(script.Parent:GetChildren()) do
   if v:IsA('Frame') then
        for _, pass in pairs(v:GetChildren()) do
           if pass:IsA('Frame') then
                if PassesList[pass.Name] then
                    --PassesList[pass.Name].Id
                    local assetType = nil
                    local dat = nil
                    
                    if PassesList[pass.Name].IsGamePass then
                        dat = MarketPlaceService:GetProductInfo(PassesList[pass.Name].Id, Enum.InfoType.GamePass)
                    else
                        dat = MarketPlaceService:GetProductInfo(PassesList[pass.Name].Id, Enum.InfoType.Product)
                    end

                    -- PriceInRobux
                    if not string.find(pass.Contents.Buy.Contents.TextLabel.Text, 'Owned') then
                        pass.Contents.Buy.Contents.TextLabel.Text = RobuxChar .. tostring(dat.PriceInRobux)
                    end
                end
           end
        end
   end 
end