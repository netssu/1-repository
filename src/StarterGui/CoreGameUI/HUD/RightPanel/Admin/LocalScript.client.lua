local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local whitelist = {
	794444736,
	2309402771,
	546957599,
	864876417,
	5365172226
}

if table.find(whitelist, Player.UserId) then
	script.Parent.Visible = true
end