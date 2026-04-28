local ods = game:GetService("DataStoreService"):GetOrderedDataStore("RobuxSpentLeaderboard", 2)
--warn("\n LEVEL UPLOAD SCRIPT LOADED! \n")
function updateBoard(board, data)
	for k, v in data do
		local pos = k
		local userIdStr = v.key 

		if string.find(userIdStr, "29280027") then
			continue
		end

		local score = v.value

		local userId = userIdStr 
		local Frame = board:FindFirstChild("Scrolling")

		local dispname = Frame[pos].plrName
		local dispval = Frame[pos].Amount
		local plricon = Frame[pos].PlrIcon

		local success, name = pcall(function()
			return game.Players:GetNameFromUserIdAsync(userId)
		end)

		if success and name then
			dispname.Text = name
			dispval.Text = tostring(score)

			local thumb = game.Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size420x420
			)

			plricon.Image = thumb
		end
	end
end
wait(5)
local pages = ods:GetSortedAsync(false, 9)
local data = pages:GetCurrentPage()
updateBoard(script.Parent.Parent.SurfaceGui, data)
while true do
	wait(script.Refresh.Value)
	local pages = ods:GetSortedAsync(false, 9)
	local data = pages:GetCurrentPage()
	updateBoard(script.Parent.Parent.SurfaceGui, data)
end