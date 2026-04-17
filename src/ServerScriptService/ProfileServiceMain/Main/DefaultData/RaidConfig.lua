local RaidConfig = {
	["Credits"] = 0,
	['Raids'] = {
		['Raid1'] = {
			['Shop'] = {
				['Willpower'] = {
					['ItemType'] = 'Currency',
					['Price'] = 20, -- original 10
					['Amount'] = 1,
					['CurrentLimit'] = 0,
					['Limit'] = 25, -- maximum 25 willpower
				},
				['Gems'] = {
					['ItemType'] = 'Currency',
					['Price'] = 20, -- original 10
					['Amount'] = 300,
					['CurrentLimit'] = 0,
					['Limit'] = 10,
				},
				['Palpotin'] = {
					['ItemType'] = 'Tower',
					['Price'] = 50, -- original 25
					['Amount'] = 1,
					['CurrentLimit'] = 0,
					['Limit'] = 1,
				}
			}
		}
	}
}



return RaidConfig
