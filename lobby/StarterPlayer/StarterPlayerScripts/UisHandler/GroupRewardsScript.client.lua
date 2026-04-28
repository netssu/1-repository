-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TS = game:GetService("TweenService")

-- CONSTANTS
local GROUP_ID = 35339513

-- VARIABLES
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Referências da UI (Caminho absoluto via PlayerGui)
local NewUI = PlayerGui:WaitForChild("NewUI")
local OpenFrame = NewUI:WaitForChild("GroupRewardsFrame")
local GroupRewardsFrame = OpenFrame:WaitForChild("Frame")
local RewardsFrame = GroupRewardsFrame:WaitForChild("RewardsFrame")
local ExitButton = OpenFrame:WaitForChild("ExitButton")
local ClaimButton = GroupRewardsFrame:WaitForChild("ClaimButton")

-- Referências de Módulos e Eventos
local UIHandlerModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIHandler"))
local Event = ReplicatedStorage:WaitForChild("Events"):WaitForChild("GroupRewards")
local Zone = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Zone"))
local Container = Zone.new(workspace:WaitForChild("GroupRewardsBox"):WaitForChild("JoinGroupandLikeHitbox"))

local open = false

-- FUNCTIONS
local function UpdUi()
	-- Aguarda a ClaimedGroupReward carregar no jogador para evitar erros
	local claimedReward = Player:WaitForChild("ClaimedGroupReward")

	if claimedReward.Value then
		ClaimButton.Interactable = false
		ClaimButton.TextLabel.Text = "Claimed"
		OpenFrame.Claimed.Visible = true
		ClaimButton.Image = ClaimButton.ClaimedTexture.Value
		ClaimButton.TextLabel.Visible = false
		RewardsFrame.GroupFrame.Frame.ImageButton.UIGradient.Enabled = true
		RewardsFrame.LikeFrame.Frame.ImageButton.UIGradient.Enabled = true
		RewardsFrame.GroupFrame.Frame.ImageButton.TextLabel.Text = "1/1"
		RewardsFrame.LikeFrame.Frame.ImageButton.TextLabel.Text = "1/1"
	else
		if Player:IsInGroup(GROUP_ID) then
			OpenFrame.Claimed.Visible = false
			ClaimButton.Image = ClaimButton.NotClaimedTexture.Value
			ClaimButton.TextLabel.Visible = true
			ClaimButton.Interactable = true
			ClaimButton.TextLabel.Text = "Claim"
			RewardsFrame.GroupFrame.Frame.ImageButton.UIGradient.Enabled = true
			RewardsFrame.LikeFrame.Frame.ImageButton.UIGradient.Enabled = true
			RewardsFrame.GroupFrame.Frame.ImageButton.TextLabel.Text = "1/1"
			RewardsFrame.LikeFrame.Frame.ImageButton.TextLabel.Text = "1/1"
		else
			OpenFrame.Claimed.Visible = false
			ClaimButton.Image = ClaimButton.NotClaimedTexture.Value
			ClaimButton.TextLabel.Visible = true
			ClaimButton.Interactable = true
			ClaimButton.TextLabel.Text = "Claim"
			RewardsFrame.GroupFrame.Frame.ImageButton.UIGradient.Enabled = false
			RewardsFrame.LikeFrame.Frame.ImageButton.UIGradient.Enabled = false
			RewardsFrame.GroupFrame.Frame.ImageButton.TextLabel.Text = "0/1"
			RewardsFrame.LikeFrame.Frame.ImageButton.TextLabel.Text = "0/1"
		end
	end
end

-- INIT
ClaimButton.MouseButton1Up:Connect(function()
	UpdUi()
	if Player:IsInGroup(GROUP_ID) then
		Event:FireServer(Player)
		_G.Message("Successfully", Color3.new(1, 0.666667, 0), nil, "Success")
	else
		_G.Message("You need join in group and like the Game", Color3.new(1, 0, 0), nil, "Error")
	end
end)

ExitButton.Activated:Connect(function()
	if open then
		UIHandlerModule.EnableAllButtons()
		local unitsGui = PlayerGui:WaitForChild("UnitsGui", 3)
		if unitsGui then
			unitsGui.Inventory.Units.Visible = false
		end
	end
	OpenFrame.Visible = false
	open = false
end)
Container.playerEntered:Connect(function(plr)
	if plr == Player then
		UpdUi()

		if UIHandlerModule and type(UIHandlerModule.DisableAllButtons) == "function" then
			UIHandlerModule.DisableAllButtons()
		else
			warn("Aviso: UIHandlerModule.DisableAllButtons ainda não carregou ou não existe.")
		end

		if type(_G.CloseAll) == "function" then
			_G.CloseAll('GroupRewards')
		else
			warn("Aviso: _G.CloseAll ainda não foi definida em nenhum script!")
		end
	end
end)

Container.playerExited:Connect(function(plr)
	if plr == Player then

		if UIHandlerModule and type(UIHandlerModule.EnableAllButtons) == "function" then
			UIHandlerModule.EnableAllButtons()
		end

		if type(_G.CloseAll) == "function" then
			_G.CloseAll()
		end
	end
end)