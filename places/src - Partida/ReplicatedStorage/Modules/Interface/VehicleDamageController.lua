------------------//VARIABLES
local activePanel: GuiObject?

------------------//MAIN FUNCTIONS
local vehicleDamageController = {}

function vehicleDamageController.Enable(player: Player, _vehicle: Model): ()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local racingHud = playerGui and playerGui:FindFirstChild("RacingHud")
	local canvas = racingHud and racingHud:FindFirstChild("Canvas")
	local damagePanel = canvas and canvas:FindFirstChild("VehicleDamage")
	if damagePanel and damagePanel:IsA("GuiObject") then
		activePanel = damagePanel
		activePanel.Visible = true
	end
end

function vehicleDamageController.Disable(): ()
	if activePanel then
		activePanel.Visible = false
		activePanel = nil
	end
end

------------------//INIT
return vehicleDamageController
