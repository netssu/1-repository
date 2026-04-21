local info


local differentPlaces = {
	MainId = {
		Lobby = 130340586645002,
		Game = 70380396628946,
		AFKChamber = 109641882079491
	},
	TestId = {
		Lobby = 117137931466956,
		Game = 77187363960578,
		AFKChamber = 74141954893736
	}
}

for _, data in differentPlaces do
	for placeName, placeId in data do
		if placeId == game.PlaceId then
			return data
		end
	end
end

