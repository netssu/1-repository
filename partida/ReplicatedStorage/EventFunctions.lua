local module = {}

module.EventNames = {
	"HalloweenEvent",
}

module.HalloweenEvent = function()
	game.Workspace.Info.Infinity.Value = true
	game.Workspace.Info.EventMap.Value = "ThrillerBark"
	game.Workspace.Info.PathQuantity.Value = 4
	game.Workspace.Info.MultiplePaths.Value = true
	game.Workspace.Info.PathNumber.Value = math.random(1,4)
end

return module