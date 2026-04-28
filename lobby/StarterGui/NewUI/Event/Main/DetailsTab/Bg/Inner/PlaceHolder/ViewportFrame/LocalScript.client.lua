local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)

local newVP = ViewPortModule.CreateViewPort("Fawn")
if not newVP then
	--warn("Anikannn Amor couldn't load ")
	return
end
newVP.Parent = script.Parent