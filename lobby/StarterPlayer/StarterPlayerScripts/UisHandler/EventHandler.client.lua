-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CONSTANTS
local LocalPlayer = Players.LocalPlayer
local EasterEvent = workspace:WaitForChild("EventMain")
local JoinEvent = EasterEvent:WaitForChild("Main"):WaitForChild("Join")
local LeaveEvent = EasterEvent:WaitForChild("Main"):WaitForChild("Leave")
local PlayersFolder = EasterEvent:WaitForChild("Players")
local Countdown = EasterEvent.Main:WaitForChild("Countdown")
local Zone = require(ReplicatedStorage.Modules.Zone)
local EventHitbox = workspace:WaitForChild("EventMain"):WaitForChild("EasterMainHitbox")

-- VARIABLES
repeat task.wait() until LocalPlayer:FindFirstChild("DataLoaded")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local NewUI = PlayerGui:WaitForChild("NewUI")
local EventUI = NewUI:WaitForChild("Event")

local JoinBtn = EventUI.Main.Buttons.Join.Btn
local ExitBtn = EventUI.Main.Buttons.Exit.Btn

-- Referências do Header
local HeaderTitle = EventUI.Header.Title

local DetailsTab = EventUI.Main.DetailsTab
local AttemptsTextLabel = DetailsTab.Attempt.Attemps 
local BossViewport = DetailsTab.Bg.Inner.PlaceHolder.ViewportFrame
local BossIcon = DetailsTab.Bg.Inner.PlaceHolder.Icon
local RewardsSlots = DetailsTab.Slots
local ActText = DetailsTab.Act
local StageText = DetailsTab.Stage

local StartTab = EventUI.Main.StartTab
local PlayersContainer = StartTab.Contents.Players.Bg
local PlayerTemplate = PlayersContainer:WaitForChild("PlayerFrame")
local PlayerCountLabel = StartTab.PlayersAmount
local CountdownTextLabel = StartTab.GameStartsTime

local LocationFrame = StartTab.Contents.Location.Bg:WaitForChild("Death Star")
local LocationImage = LocationFrame.Contents.Bg.Location_Image

-- Dados do Jogador
local Attempts = LocalPlayer:WaitForChild("FawnEventAttempts")
local HighestWave = LocalPlayer:WaitForChild("EventData").Easter.HighestWave
local EventWins = LocalPlayer:WaitForChild("EventWins")

local ContainerZone = Zone.new(EventHitbox)

-- Oculta o template base para não aparecer vazio na lista
PlayerTemplate.Visible = false

-- FUNCTIONS
local function UpdateAttempts()
	-- Atualiza o texto de tentativas usando RichText
	AttemptsTextLabel.Text = `Total Attempts: <font color="#51E851">{Attempts.Value}</font>`
end

local function UpdateEventInfo(eventName, stageInfo)
	-- Função extra criada para você atualizar os textos baseados no evento facilmente
	HeaderTitle.Text = eventName
	ActText.Text = eventName
	StageText.Text = stageInfo
end

local function UpdatePlayerList()
	-- Atualiza a label de quantidade
	local currentPlayers = #PlayersFolder:GetChildren()
	PlayerCountLabel.Text = `Players ({currentPlayers}/4)`
end

local function AddPlayerToUI(obj)
	UpdatePlayerList()

	local foundPlr = Players:FindFirstChild(obj.Name)
	if not foundPlr then return end

	-- Clona o template do PlayerFrame
	local newPlayerEntry = PlayerTemplate:Clone()
	newPlayerEntry.Name = foundPlr.Name
	newPlayerEntry.Visible = true

	-- Configura os dados do jogador no frame
	local textContainer = newPlayerEntry.Contents.Text_Container
	textContainer.PlayerName.Text = "@" .. foundPlr.Name

	-- Obtém a foto de perfil
	local success, icon = pcall(function()
		return Players:GetUserThumbnailAsync(foundPlr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size352x352)
	end)

	if success and icon then
		textContainer.PlayerIcon.Image = icon
	end

	newPlayerEntry.Parent = PlayersContainer
end

local function RemovePlayerFromUI(obj)
	UpdatePlayerList()
	local existingFrame = PlayersContainer:FindFirstChild(obj.Name)
	if existingFrame then
		existingFrame:Destroy()
	end
end

-- INIT
-- Configuração inicial dos dados
UpdateAttempts()
UpdateEventInfo("Galactic Tower Defense", "Defeat the Empire") -- Exemplo de uso para atualizar os títulos

-- Conexões de Botões
JoinBtn.Activated:Connect(function()
	JoinEvent:FireServer()
end)

ExitBtn.Activated:Connect(function()
	LeaveEvent:FireServer()
end)

-- Conexões de Dados do Jogador
Attempts.Changed:Connect(UpdateAttempts)

-- Conexões de Players na Sala (Folder)
PlayersFolder.ChildAdded:Connect(AddPlayerToUI)
PlayersFolder.ChildRemoved:Connect(RemovePlayerFromUI)

-- Verifica jogadores que já podem estar na pasta antes do script carregar
for _, playerObj in ipairs(PlayersFolder:GetChildren()) do
	AddPlayerToUI(playerObj)
end

-- Conexão de Tempo
Countdown.Changed:Connect(function()
	CountdownTextLabel.Text = `Game Starts in {Countdown.Value}s`
end)

-- Conexões de Zona (ZonePlus)
ContainerZone.playerEntered:Connect(function(player)
	if player == LocalPlayer then
		warn("Opening Event Frame")
		-- Se estiver usando o _G.CloseAll do seu sistema anterior
		if _G.CloseAll then
			_G.CloseAll('Event')
		end
		-- Caso não use o _G, basta habilitar a UI aqui:
		-- EventUI.Visible = true
	end
end)

ContainerZone.playerExited:Connect(function(player)
	if player == LocalPlayer then
		if _G.CloseAll then
			_G.CloseAll()
		end
		-- EventUI.Visible = false
	end
end)