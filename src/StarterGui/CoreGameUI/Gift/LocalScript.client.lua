

local GiftEvent = game.ReplicatedStorage.Events.Gift

local GiftFrame = script.Parent:WaitForChild("GiftFrame")
local GiftContainer = GiftFrame:WaitForChild("Frame"):WaitForChild("Main"):WaitForChild("Container")
local ExitButton = GiftFrame:WaitForChild("ExitButton")

local GiftPlayerTemplate = script.GiftPlayerTemplate

local SelectedGiftID = script.Parent:WaitForChild("SelectedGiftId")
local GiftPlayerUIList = {}


function NewGiftPlayerUI(NewPlayer)
	if GiftPlayerUIList[NewPlayer] then return end

	local clone = GiftPlayerTemplate:Clone()
	clone.PlayerNickName.Text = NewPlayer.DisplayName
	clone.Parent = GiftContainer

	GiftPlayerUIList[NewPlayer] = clone

	local userId = NewPlayer.UserId
	local thumbType = Enum.ThumbnailType.HeadShot
	local thumbSize = Enum.ThumbnailSize.Size420x420
	local content, isReady = game.Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)

	if content then
		clone.PlayerIcon.Image = content
	end

	clone.Gift.MouseButton1Down:Connect(function()
		if not SelectedGiftID.Value == 0 then return end
		
		GiftEvent:FireServer(NewPlayer, SelectedGiftID.Value)
		GiftFrame.Visible = false
	end)
	
end


ExitButton.MouseButton1Down:Connect(function()
	GiftFrame.Visible = false
end)

game.Players.PlayerAdded:Connect(NewGiftPlayerUI)

game.Players.PlayerRemoving:Connect(function(player)
	if not GiftPlayerUIList[player] then return end
	GiftPlayerUIList[player]:Destroy()
	GiftPlayerUIList[player] = nil
end)

for _, currentPlayer in game.Players:GetPlayers() do
	if currentPlayer == game.Players.LocalPlayer then continue end
	NewGiftPlayerUI(currentPlayer)
end


