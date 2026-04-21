local DisbledAtStartList = {"Dragify", "AnimationPlayer"}
local ContentProvider = game:GetService('ContentProvider')

local CoreUIFolder = game.ReplicatedStorage:WaitForChild("CoreUI")

local Player = game.Players.LocalPlayer
local PlayerGUI = Player:WaitForChild("PlayerGui")
repeat task.wait(1) until Player:FindFirstChild("DataLoaded")

local ImageIDs = {}

for _, main in CoreUIFolder:GetChildren() do
	local copy = main:Clone()
	copy.Parent = PlayerGUI
	
	for i,v in pairs(copy:GetDescendants()) do
		if v:IsA('ImageLabel') or v:IsA('ImageButton') then
			table.insert(ImageIDs, v.Image)
		end
	end
end

local s,e = pcall(function()
	ContentProvider:PreloadAsync(ImageIDs)
end)

for _, object in PlayerGUI:GetDescendants() do
	if object:IsA("ScreenGui") and object.Name == "Message" then object.DisplayOrder = 6 end
	if not object:IsA("LocalScript") or table.find(DisbledAtStartList, object.Name) then continue end
	if object.Name == 'Animate' then continue end 
	object.Enabled = true
end

