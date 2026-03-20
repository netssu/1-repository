------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService: TweenService = game:GetService("TweenService")
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local HIDE_LOCAL_TRANSPARENCY: number = 1

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local remotesFolder: Folder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local ringEvent: RemoteEvent = remotesFolder:WaitForChild("RingEvent")
local hiddenRings: { [Instance]: {
	localT: number,
	color: Color3,
	size: Vector3,
} } = {}

local currentLabelTween: Tween? = nil

local SoundUtility = require(ReplicatedStorage.Modules.Utility.SoundUtility)
local SoundData = require(ReplicatedStorage.Modules.Datas.SoundData)

------------------//FUNCTIONS
local function get_label(): TextLabel?
	local pGui = player:FindFirstChild("PlayerGui")
	if not pGui then
		return nil
	end

	local hud = pGui:FindFirstChild("UI")
	if not hud then
		return nil
	end

	local holder = hud:FindFirstChild("GameHUD")
	if not holder then
		return nil
	end
	
	local container = holder:FindFirstChild("MultiplierContainer")
	if not container then
		return nil
	end

	return container:FindFirstChild("ValueLabel")
end

local function update_hud(amount: number, first : boolean)
	local label = get_label()
	if not label then
		return
	end

	if not label:GetAttribute("BaseSize") then
		label:SetAttribute("BaseSize", label.TextSize)
		label:SetAttribute("OriginalPos", label.Position)
	end

	local baseSize = label:GetAttribute("BaseSize")
	local originalPos = label:GetAttribute("OriginalPos")

	if currentLabelTween then
		currentLabelTween:Cancel()
	end

	if amount > 0 then
		label.Visible = true
		label.Text = string.format("x%.2f", amount)

		label.TextSize = baseSize * 1.8
		label.Rotation = math.random(-15, 15)
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0

		currentLabelTween =
			TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				TextSize = baseSize,
				Rotation = 0,
			})
		currentLabelTween:Play()

		task.spawn(function()
			for i = 1, 6 do
				local offset = UDim2.new(0, math.random(-3, 3), 0, math.random(-3, 3))
				label.Position = originalPos + offset
				task.wait(0.04)
			end
			label.Position = originalPos
		end)
	else
		currentLabelTween =
			TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				TextSize = baseSize * 0.2,
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
		currentLabelTween.Completed:Connect(function()
			if amount <= 0 then
				label.Visible = false
			end
		end)
		currentLabelTween:Play()
	end
end

local function hide_ring(ring: BasePart): ()
	if not ring or not ring.Parent then
		return
	end
	if hiddenRings[ring] then
		return
	end

	hiddenRings[ring] = {
		localT = ring.LocalTransparencyModifier,
		color = ring.Color,
		size = ring.Size,
	}

	TweenService:Create(ring, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		LocalTransparencyModifier = HIDE_LOCAL_TRANSPARENCY,
		Size = Vector3.new(0, 0, 0),
	}):Play()
end

local function restore_all(): ()
	for ring, original in hiddenRings do
		if ring and ring.Parent then
			TweenService:Create(ring, TweenInfo.new(0.2), {
				LocalTransparencyModifier = original.localT,
				Color = original.color,
				Size = original.size,
			}):Play()
		end
	end
	table.clear(hiddenRings)
end

------------------//INIT
player.CharacterAdded:Connect(function()
	restore_all()
	update_hud(player:GetAttribute("Multiplier") or 0, true)
end)

player:GetAttributeChangedSignal("Multiplier"):Connect(function()
	update_hud(player:GetAttribute("Multiplier") or 0)
end)

ringEvent.OnClientEvent:Connect(function(action: string, sum: number?, ring: BasePart?, ringValue: number?)
	if action == "Restore" then
		restore_all()
		return
	end

	if action == "Collect" then
		if ring then
			hide_ring(ring)
		end

		if sum then
			update_hud(sum)
		end
	end
end)
