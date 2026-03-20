------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local CATEGORY_MAPPINGS = {
	["BTPets"] = "Pets",
	["BTPogos"] = "Pogos"
}

------------------//VARIABLES
local IndexController = {}
local localPlayer = Players.LocalPlayer

local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local DataPets = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PetsData"))
local DataPogos = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PogoData"))

local createdFrames = {}
local currentCategory = "Pets"
local currentSearchQuery = ""

------------------//FUNCTIONS
local function get_ui_references()
	local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
	if not playerGui then return nil end

	local indexFrame = playerGui:FindFirstChild("Index", true)
	if not indexFrame then return nil end

	local categoryFR = indexFrame:FindFirstChild("CategoryFR")
	local indexBG = indexFrame:FindFirstChild("IndexBG")

	local gridScrollingFrame = indexBG and indexBG:FindFirstChild("GridScrollingFrame")
	local template = gridScrollingFrame and gridScrollingFrame:FindFirstChild("Template")

	local searchBT = indexBG and indexBG:FindFirstChild("SearchBT")
	local textboxBG = indexBG and indexBG:FindFirstChild("TextboxBG")
	local textBox = textboxBG and textboxBG:FindFirstChild("TextBox")

	return {
		Main = indexFrame,
		CategoryFR = categoryFR,
		ScrollingFrame = gridScrollingFrame,
		Template = template,
		SearchBT = searchBT,
		TextBox = textBox
	}
end

local function clear_grid()
	for _, frame in pairs(createdFrames) do
		frame:Destroy()
	end
	table.clear(createdFrames)
end

local function create_index_frame(itemName, parent, template, category)
	local newFrame = template:Clone()
	newFrame.Name = itemName
	newFrame.Visible = true

	local itemNameTX = newFrame:FindFirstChild("ItemNameTX")
	local itemCountTX = newFrame:FindFirstChild("ItemCountTX")

	if itemCountTX then
		itemCountTX.Visible = false
	end

	if category == "Pets" then
		local petData = DataPets.GetPetData(itemName)
		if petData then
			if itemNameTX then itemNameTX.Text = petData.DisplayName end

			local viewport = DataPets.GetPetViewport(itemName)
			if viewport then
				viewport.Size = UDim2.new(1, 0, 1, 0)
				viewport.Position = UDim2.new(0.5, 0, 0.5, 0)
				viewport.AnchorPoint = Vector2.new(0.5, 0.5)
				viewport.BackgroundTransparency = 1
				viewport.ZIndex = 2
				viewport.Parent = newFrame
			end
		end
	elseif category == "Pogos" then
		local pogoData = DataPogos.Get(itemName)
		if pogoData then
			if itemNameTX then itemNameTX.Text = pogoData.Name end

			local viewport = DataPogos.GetPogoViewport(itemName)
			if viewport then
				viewport.Size = UDim2.new(1, 0, 1, 0)
				viewport.Position = UDim2.new(0.5, 0, 0.5, 0)
				viewport.AnchorPoint = Vector2.new(0.5, 0.5)
				viewport.BackgroundTransparency = 1
				viewport.ZIndex = 2
				viewport.Parent = newFrame
			end
		end
	end

	newFrame.Parent = parent
	return newFrame
end

local function matches_search(itemName, displayName)
	if currentSearchQuery == "" or currentSearchQuery == " " then
		return true
	end

	local searchLower = string.lower(currentSearchQuery)
	local nameLower = string.lower(itemName)
	local displayLower = displayName and string.lower(displayName) or ""

	if string.find(nameLower, searchLower) or string.find(displayLower, searchLower) then
		return true
	end

	return false
end

local function update_index()
	local ui = get_ui_references()
	if not ui or not ui.ScrollingFrame or not ui.Template then return end

	ui.Template.Visible = false
	clear_grid()

	if currentCategory == "Pets" then
		local ownedPets = DataUtility.client.get("OwnedPets")
		if not ownedPets then return end

		for petName, _ in pairs(ownedPets) do
			local petData = DataPets.GetPetData(petName)
			local displayName = petData and petData.DisplayName or petName

			if matches_search(petName, displayName) then
				local frame = create_index_frame(petName, ui.ScrollingFrame, ui.Template, "Pets")
				if frame then
					createdFrames[petName] = frame
				end
			end
		end
	elseif currentCategory == "Pogos" then
		local ownedPogos = DataUtility.client.get("OwnedPogos")
		if not ownedPogos then return end

		for pogoId, _ in pairs(ownedPogos) do
			local pogoData = DataPogos.Get(pogoId)
			local displayName = pogoData and pogoData.Name or pogoId

			if matches_search(pogoId, displayName) then
				local frame = create_index_frame(pogoId, ui.ScrollingFrame, ui.Template, "Pogos")
				if frame then
					createdFrames[pogoId] = frame
				end
			end
		end
	end
end

local function setup_search_events(ui)
	if not ui.SearchBT or not ui.TextBox then return end

	local function perform_search()
		currentSearchQuery = ui.TextBox.Text
		update_index()
	end

	ui.SearchBT.Activated:Connect(perform_search)

	ui.TextBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			perform_search()
		end
	end)
end

local function setup_category_buttons(ui)
	if not ui.CategoryFR then return end
	local categoryBG = ui.CategoryFR:FindFirstChild("CategoryBG")
	if not categoryBG then return end

	for _, btn in ipairs(categoryBG:GetChildren()) do
		if CATEGORY_MAPPINGS[btn.Name] then
			btn.Activated:Connect(function()
				currentCategory = CATEGORY_MAPPINGS[btn.Name]
				currentSearchQuery = ""
				if ui.TextBox then
					ui.TextBox.Text = ""
				end
				update_index()
			end)
		end
	end
end

------------------//INIT
DataUtility.client.ensure_remotes()

DataUtility.client.bind("OwnedPets", function()
	if currentCategory == "Pets" then
		update_index()
	end
end)

DataUtility.client.bind("OwnedPogos", function()
	if currentCategory == "Pogos" then
		update_index()
	end
end)

task.spawn(function()
	local ui = get_ui_references()
	if ui then
		setup_category_buttons(ui)
		setup_search_events(ui)
		update_index()
	end
end)

return IndexController