------------------//SERVICES
local Players: Players = game:GetService("Players")
local TweenService: TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local MAIN_UI_NAME: string = "MainUI"
local CANVAS_NAME: string = "Canvas"
local PAGE_OPEN_DURATION: number = 0.58
local PAGE_BUTTON_DURATION: number = 0.32
local PAGE_BUTTON_STAGGER: number = 0.025
local PAGE_BUTTON_START_SCALE: number = 0.86
local PAGE_BUTTON_START_OFFSET: number = 18
local PAGE_GROUP_DURATION: number = 0.38
local PAGE_GROUP_STAGGER: number = 0.04
local PAGE_GROUP_START_SCALE: number = 0.94
local PAGE_GROUP_START_OFFSET: number = 12
local PAGE_NAMES: { string } = {
	"Home",
	"RacingPass",
	"Challenges",
	"Quests",
	"LeaderBoard",
	"Codes",
	"Stats",
	"DailyReward",
	"Shop",
	"Boosters",
	"Items",
	"Play",
	"Maps",
	"Customize",
	"Avatar",
	"Helmets",
	"Upgrade",
	"Car",
	"TireSmoke",
	"UnderGlow",
	"Settings",
}
local PAGE_ENTRY_GROUP_NAMES: { [string]: { string } } = {
	Home = { "Shop", "Play", "RacingPass", "Customize" },
	Play = { "Ranked", "Unranked", "Maps" },
	Challenges = { "QuestTopBar", "Weekly", "VIP", "Daily" },
	Quests = { "QuestTopBar", "Weekly", "Monthly", "Daily" },
	LeaderBoard = { "LeaderBoardTopBar", "Robux", "Wins", "Rank" },
	Codes = { "Codes", "FollowDevs" },
	Stats = { "statsBG" },
	DailyReward = { "Rewards", "Tittle" },
	Shop = { "ShopCard" },
	Boosters = { "ScrollingFrame" },
	Items = { "ScrollingFrame" },
	Maps = { "Mapcard", "MapInfo", "Travel" },
	Customize = { "Avatar", "Upgrade" },
	Avatar = { "Selected", "Buy", "InventoryContainer" },
	Helmets = { "Selected", "Buy", "InventoryContainer" },
	Upgrade = { "CarUpgrades", "PlayerUpgrades" },
	Car = { "Selected", "Buy", "InventoryContainer" },
	TireSmoke = { "CardOne", "InfoBox", "Showcase" },
	UnderGlow = { "CardOne", "InfoBox", "Showcase" },
	Settings = { "SettingsTopbar", "CardOne", "CardTwo", "CardThree" },
}
local PAGE_ENTRY_PAGE_ONLY: { [string]: boolean } = {
	RacingPass = true,
}

type PageState = {
	originalPosition: UDim2,
	pageTween: Tween?,
	entryTweens: { Tween },
	generation: number,
}

type EntryState = {
	originalPosition: UDim2,
	originalSize: UDim2,
	originalRotation: number,
}

type ButtonState = {
	originalPosition: UDim2,
	originalSize: UDim2,
	originalRotation: number,
	originalProperties: { [string]: number },
}

------------------//DEPENDENCIES
local modules: Folder = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local sfx = require(modules:WaitForChild("Interface"):WaitForChild("HudAnim"):WaitForChild("SFX"))

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local canvas: Frame?
local pageStates: { [GuiObject]: PageState } = {}
local entryGroupStates: { [GuiObject]: EntryState } = {}
local buttonStates: { [GuiButton]: ButtonState } = {}
local pageConnections: { RBXScriptConnection } = {}
local isEnabled: boolean = false

------------------//FUNCTIONS
local function get_canvas(): Frame?
	if canvas and canvas.Parent then
		return canvas
	end

	local mainUi = playerGui:FindFirstChild(MAIN_UI_NAME)
	local foundCanvas = mainUi and mainUi:FindFirstChild(CANVAS_NAME)
	if foundCanvas and foundCanvas:IsA("Frame") then
		canvas = foundCanvas
		return canvas
	end
	return nil
end

local function get_page_state(page: GuiObject): PageState
	local state = pageStates[page]
	if state then
		return state
	end

	state = {
		originalPosition = page.Position,
		pageTween = nil,
		entryTweens = {},
		generation = 0,
	}
	pageStates[page] = state
	return state
end

local function get_entry_state(instance: GuiObject): EntryState
	local state = entryGroupStates[instance]
	if state then
		return state
	end

	state = {
		originalPosition = instance.Position,
		originalSize = instance.Size,
		originalRotation = instance.Rotation,
	}
	entryGroupStates[instance] = state
	return state
end

local function get_button_properties(button: GuiButton): { [string]: number }
	local properties: { [string]: number } = {
		BackgroundTransparency = button.BackgroundTransparency,
	}
	if button:IsA("ImageButton") then
		properties.ImageTransparency = button.ImageTransparency
	end
	if button:IsA("TextButton") then
		properties.TextTransparency = button.TextTransparency
		properties.TextStrokeTransparency = button.TextStrokeTransparency
	end
	return properties
end

local function get_button_state(button: GuiButton): ButtonState
	local state = buttonStates[button]
	if state then
		return state
	end

	state = {
		originalPosition = button.Position,
		originalSize = button.Size,
		originalRotation = button.Rotation,
		originalProperties = get_button_properties(button),
	}
	buttonStates[button] = state
	return state
end

local function is_visible_in_hierarchy(instance: GuiObject): boolean
	local current: Instance? = instance
	while current and current:IsA("GuiObject") do
		if not current.Visible then
			return false
		end
		current = current.Parent
	end
	return true
end

local function scale_udim2(size: UDim2, scaleFactor: number): UDim2
	return UDim2.new(
		size.X.Scale * scaleFactor,
		size.X.Offset * scaleFactor,
		size.Y.Scale * scaleFactor,
		size.Y.Offset * scaleFactor
	)
end

local function add_entry_tween(page: GuiObject, tween: Tween): ()
	local pageState = pageStates[page]
	if pageState then
		table.insert(pageState.entryTweens, tween)
	end
end

local function get_configured_entry_groups(page: GuiObject): { GuiObject }
	local groups: { GuiObject } = {}
	for _, child in page:GetChildren() do
		if child:IsA("GuiObject") and child:GetAttribute("UIAnimEntryGroup") == true and child.Visible then
			table.insert(groups, child)
		end
	end
	if #groups > 0 then
		return groups
	end

	local groupNames = PAGE_ENTRY_GROUP_NAMES[page.Name]
	if not groupNames then
		return groups
	end

	for _, groupName in groupNames do
		local group = page:FindFirstChild(groupName)
		if group and group:IsA("GuiObject") and group.Visible then
			table.insert(groups, group)
		end
	end
	return groups
end

local function tween_group_to_original(group: GuiObject, state: EntryState, delayTime: number, generation: number, page: GuiObject): ()
	task.delay(delayTime, function()
		local pageState = pageStates[page]
		if not pageState or pageState.generation ~= generation or not page.Visible or not group.Parent or not is_visible_in_hierarchy(group) then
			return
		end

		local tween = TweenService:Create(
			group,
			TweenInfo.new(PAGE_GROUP_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{
				Position = state.originalPosition,
				Size = state.originalSize,
				Rotation = state.originalRotation,
			}
		)
		add_entry_tween(page, tween)
		tween:Play()
	end)
end

local function animate_entry_groups(page: GuiObject, generation: number, groups: { GuiObject }): ()
	for index, group in groups do
		local state = get_entry_state(group)
		group.Position = UDim2.new(
			state.originalPosition.X.Scale,
			state.originalPosition.X.Offset,
			state.originalPosition.Y.Scale,
			state.originalPosition.Y.Offset + PAGE_GROUP_START_OFFSET
		)
		group.Size = scale_udim2(state.originalSize, PAGE_GROUP_START_SCALE)
		group.Rotation = state.originalRotation
		tween_group_to_original(group, state, (index - 1) * PAGE_GROUP_STAGGER, generation, page)
	end
end

local function tween_button_to_original(button: GuiButton, state: ButtonState, delayTime: number, generation: number, page: GuiObject): ()
	task.delay(delayTime, function()
		local pageState = pageStates[page]
		if not pageState or pageState.generation ~= generation or not page.Visible or not button.Parent or not is_visible_in_hierarchy(button) then
			return
		end

		local properties: { [string]: any } = {
			Position = state.originalPosition,
			Size = state.originalSize,
			Rotation = state.originalRotation,
		}
		for property, value in state.originalProperties do
			properties[property] = value
		end

		local tween = TweenService:Create(
			button,
			TweenInfo.new(PAGE_BUTTON_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			properties
		)
		add_entry_tween(page, tween)
		tween:Play()
	end)
end

local function animate_buttons(page: GuiObject, generation: number): ()
	local buttonIndex: number = 0
	for _, descendant in page:GetDescendants() do
		if not descendant:IsA("GuiButton") or descendant:GetAttribute("UIAnimEntryIgnore") == true or not descendant.Visible or not is_visible_in_hierarchy(descendant) then
			continue
		end

		local state = get_button_state(descendant)
		buttonIndex += 1
		local startProperties: { [string]: any } = {
			Position = state.originalPosition + UDim2.fromOffset(0, PAGE_BUTTON_START_OFFSET),
			Size = scale_udim2(state.originalSize, PAGE_BUTTON_START_SCALE),
			Rotation = state.originalRotation,
		}

		for property, value in state.originalProperties do
			startProperties[property] = if value < 1 then 1 else value
		end

		for property, value in startProperties do
			descendant[property] = value
		end
		tween_button_to_original(descendant, state, (buttonIndex - 1) * PAGE_BUTTON_STAGGER, generation, page)
	end
end

local function animate_entry(page: GuiObject, generation: number): ()
	local groups = get_configured_entry_groups(page)
	if #groups > 0 then
		animate_entry_groups(page, generation, groups)
		return
	end
	if page:GetAttribute("UIAnimEntryPageOnly") == true or PAGE_ENTRY_PAGE_ONLY[page.Name] then
		return
	end
	animate_buttons(page, generation)
end

local function get_slide_distance(page: GuiObject): number
	local camera = workspace.CurrentCamera
	local viewportHeight = if camera then camera.ViewportSize.Y else 720
	return math.max(page.AbsoluteSize.Y + 80, viewportHeight * 0.65)
end

local function cancel_page_tween(page: GuiObject): PageState
	local state = get_page_state(page)
	state.generation += 1
	if state.pageTween then
		state.pageTween:Cancel()
		state.pageTween = nil
	end
	for _, tween in state.entryTweens do
		tween:Cancel()
	end
	state.entryTweens = {}
	return state
end

local function animate_page_open(page: GuiObject): ()
	local state = cancel_page_tween(page)
	local generation = state.generation
	local originalPosition = state.originalPosition
	local slideDistance = get_slide_distance(page)
	page.Position = UDim2.new(
		originalPosition.X.Scale,
		originalPosition.X.Offset,
		originalPosition.Y.Scale,
		originalPosition.Y.Offset + slideDistance
	)

	local pageTween = TweenService:Create(
		page,
		TweenInfo.new(PAGE_OPEN_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = originalPosition }
	)
	state.pageTween = pageTween
	pageTween.Completed:Connect(function()
		if state.generation == generation then
			state.pageTween = nil
			page.Position = originalPosition
		end
	end)
	pageTween:Play()
	animate_entry(page, generation)
	sfx.play_for(page, "sfx_open")
end

local function handle_page_visibility(page: GuiObject): ()
	if page.Visible then
		animate_page_open(page)
	else
		cancel_page_tween(page)
	end
end

local function bind_pages(): ()
	local currentCanvas = get_canvas()
	if not currentCanvas then
		return
	end

	for _, pageName in PAGE_NAMES do
		local page = currentCanvas:FindFirstChild(pageName)
		if page and page:IsA("GuiObject") then
			get_page_state(page)
			table.insert(pageConnections, page:GetPropertyChangedSignal("Visible"):Connect(function()
				handle_page_visibility(page)
			end))
			if page.Visible then
				task.defer(function()
					if page.Parent and page.Visible then
						handle_page_visibility(page)
					end
				end)
			end
		end
	end
end

local function disconnect_pages(): ()
	for _, connection in pageConnections do
		connection:Disconnect()
	end
	pageConnections = {}
	pageStates = {}
	entryGroupStates = {}
	buttonStates = {}
end

------------------//MAIN FUNCTIONS
local function interface_page_animation_controller_enable(): boolean
	if isEnabled then
		return true
	end
	if not get_canvas() then
		warn("[InterfacePageAnimationController] MainUI.Canvas not found")
		return false
	end

	isEnabled = true
	bind_pages()
	return true
end

local function interface_page_animation_controller_disable(): ()
	if not isEnabled then
		return
	end

	isEnabled = false
	disconnect_pages()
	canvas = nil
end

------------------//INIT
return {
	enable = interface_page_animation_controller_enable,
	disable = interface_page_animation_controller_disable,
}
