------------------// SERVICES
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------// CONSTANTS
local DATA_UTILITY     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local PETS_DATA_MODULE = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PetsData"))

local COMMAND_PREFIX = "!givepet "

-- Coloque aqui o seu UserId (e de outros desenvolvedores) para evitar que players normais usem o comando
local ADMIN_USER_IDS = {
	[10386863908] = true, -- Substitua 12345678 pelo seu UserId do Roblox
}

------------------// VARIABLES
-- Nenhuma variável global necessária para este escopo

------------------// FUNCTIONS
local function givePetToPlayer(player, petName)
	-- Opcional: Verifica se o pet realmente existe na database de pets
	local allPets = PETS_DATA_MODULE.GetAllPets()
	if not allPets[petName] then
		warn("[Comando Admin] Pet não encontrado na database: " .. petName)
		return false
	end

	-- Pega a tabela atual de pets do jogador
	local ownedPets = DATA_UTILITY.server.get(player, "OwnedPets") or {}
	
	-- Adiciona o novo pet
	ownedPets[petName] = true
	
	-- Salva a tabela atualizada
	DATA_UTILITY.server.set(player, "OwnedPets", ownedPets)
	
	print("[Comando Admin] O pet '" .. petName .. "' foi entregue com sucesso para " .. player.Name)
	return true
end

local function onPlayerChatted(player, message)
	-- Verifica se o jogador tem permissão
	if not ADMIN_USER_IDS[player.UserId] then return end

	-- Verifica se a mensagem começa com o prefixo do comando
	if string.sub(message, 1, string.len(COMMAND_PREFIX)) == COMMAND_PREFIX then
		-- Extrai apenas o nome do pet da mensagem
		local petName = string.sub(message, string.len(COMMAND_PREFIX) + 1)
		
		-- Remove espaços em branco extras no início ou no fim, por garantia
		petName = string.match(petName, "^%s*(.-)%s*$")
		
		givePetToPlayer(player, petName)
	end
end

------------------// INIT
Players.PlayerAdded:Connect(function(player)
	-- Escuta todas as mensagens que o jogador envia no chat
	player.Chatted:Connect(function(message)
		onPlayerChatted(player, message)
	end)
end)