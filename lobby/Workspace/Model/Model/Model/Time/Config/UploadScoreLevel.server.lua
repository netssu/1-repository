local ods = game:GetService("DataStoreService"):GetOrderedDataStore("TimeSpentLeaderboard", 2)
--warn("\n LEVEL UPLOAD SCRIPT LOADED! \n")

local function numbertotime(number)
	local Hours = math.floor(number / 60 / 60)
	local Mintus = math.floor(number / 60) %60
	local Seconds = math.floor(number % 60)

	if Mintus < 10 and Hours > 0 then
		Mintus = "0"..Mintus
	end

	if Seconds < 10 then
		Seconds = "0"..Seconds
	end

	if Hours > 0 then
		return `{Hours}:{Mintus}:{Seconds}`
	else
		return `{Mintus}:{Seconds}`
	end
end

function updateBoard(board, data)	
	for k, v in data do
		local pos = k
		local userIdStr = v.key 
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
			dispval.Text = numbertotime(score)

			local thumb = game.Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size420x420
			)

			plricon.Image = thumb
		end
	end
end
task.wait(5)

local pages = ods:GetSortedAsync(false, 9)
local data = pages:GetCurrentPage()
updateBoard(script.Leaderboard.Value.SurfaceGui, data)
while true do
	wait(script.Refresh.Value)
	local pages = ods:GetSortedAsync(false, 9)
	local data = pages:GetCurrentPage()
	updateBoard(script.Leaderboard.Value.SurfaceGui, data)
end