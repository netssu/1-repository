local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local Reward = require(script.Parent.Reward)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local NotificationController = require(ReplicatedStorage.Controllers.NotificationController)

local BLUR_SIZE: number = 22
local ANIMATION_SPEED_MULTIPLIER: number = 1.5
local ANIMATION_RESET_SPEED: number = 1
local OPEN_ANIMATION_DURATION: number = 3.6
local SUMMON_RESULT_WAIT_TIMEOUT: number = 0.75
local SUMMON_RESULT_WAIT_INTERVAL: number = 0.05
local EXIT_DELAY: number = 1
local EXIT_DROP_DISTANCE: number = -3

local PACK_COSTS = {
	["Cosmetics"] = 100,
	["Emotes"] = 500,
	["Player"] = 250,
}

local _isOpening = false

local Packs = {}

function Packs.Start(): () end

local function getNetworkErrorPayload(): string
	return HttpService:JSONEncode({ Success = false, Reason = "NetworkError" })
end

local function decodeRewardPayload(itemDataJson: string): (boolean, any?)
	local success, decodedData = pcall(function()
		return HttpService:JSONDecode(itemDataJson)
	end)

	if not success then
		warn("Failed to decode item JSON")
		return false, nil
	end

	return true, decodedData
end

local function handleRewardFailure(packContainer: GuiObject, reason: string?): ()
	packContainer.Visible = false

	if reason == "InsufficientFunds" then
		NotificationController.NotifyError("Error", "Insufficient funds.", 3)
	elseif reason == "PurchaseInProgress" then
		NotificationController.NotifyWarning("Please wait", "A purchase is already in progress.", 3)
	else
		NotificationController.NotifyError("Error", "An error occurred while opening the pack.", 3)
	end
end

local function waitForAnimationToFinish(animation: AnimationTrack, timeout: number): ()
	local finished = false
	local connection = animation.Stopped:Connect(function()
		finished = true
	end)

	local deadline = os.clock() + math.max(timeout, 0.1)
	while not finished and os.clock() < deadline do
		task.wait()
	end

	connection:Disconnect()
end

function Packs.PlaySummonAnimation(cardType: string, itemDataJson: string?, fromPurchase: boolean?): ()
	if _isOpening then
		return
	end
	_isOpening = true

	local cost = PACK_COSTS[cardType]
	if cost then
		local currentYen = PlayerDataManager:Get(LocalPlayer, { "Yen" })
		if currentYen < cost then
			NotificationController.NotifyError(
				"Insufficient Balance",
				"You need " .. cost .. " Yen to open this pack!",
				3
			)
			_isOpening = false
			return
		end
	end

	TweenService:Create(
		game.Lighting.Blur,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Size = BLUR_SIZE }
	):Play()

	local resolvedItemDataJson = itemDataJson
	local summonResolved = itemDataJson ~= nil
	local rewardShown = false
	local animationFinished = false

	if not resolvedItemDataJson then
		task.spawn(function()
			local success, jsonResult = pcall(function()
				return Packets.Summon:Fire(cardType)
			end)

			if summonResolved then
				return
			end

			if success and typeof(jsonResult) == "string" and jsonResult ~= "" then
				resolvedItemDataJson = jsonResult
			else
				warn("Failed to receive item from server or packet error:", jsonResult)
				resolvedItemDataJson = getNetworkErrorPayload()
			end

			summonResolved = true
		end)
	end

	local PackGui = LocalPlayer.PlayerGui:FindFirstChild("Pack")
	local PackContainer = PackGui and PackGui.Pack
	local PackInside = PackContainer and PackContainer:FindFirstChild("Inside")

	if not PackContainer then
		_isOpening = false
		return
	end

	PackContainer.Visible = true

	if not PackInside then
		_isOpening = false
		return
	end

	local function showRewardIfReady(): ()
		if rewardShown or not animationFinished or not summonResolved or not resolvedItemDataJson then
			return
		end

		rewardShown = true

		local success, decodedData = decodeRewardPayload(resolvedItemDataJson)
		if not success or not decodedData then
			PackContainer.Visible = false
			_isOpening = false
			return
		end

		if decodedData.Success == false then
			handleRewardFailure(PackContainer, decodedData.Reason)
			_isOpening = false
			return
		end

		PackContainer.Visible = false
		Reward.ShowRewards({ decodedData }, cardType)
		_isOpening = false
	end

	for _, child in ipairs(PackInside:GetChildren()) do
		if child:IsA("Model") then
			child:Destroy()
		end
	end

	local cardModel
	local cardAssetName = cardType .. "Cards"
	local cardAssets = ReplicatedStorage:FindFirstChild("Assets")
	local miscAssets = cardAssets and cardAssets:FindFirstChild("Cards")

	if miscAssets then
		local cardAsset = miscAssets:FindFirstChild(cardAssetName)
		if cardAsset then
			cardModel = cardAsset:Clone()
		end
	end

	if cardModel then
		cardModel.Parent = PackInside

		local animationController = cardModel:FindFirstChild("AnimationController")
		local animator = animationController and animationController:FindFirstChild("Animator")

		if not animator then
			_isOpening = false
			return
		end

		local openAnimation = ReplicatedStorage.Assets.ReplicatedAnims.OpenCard
		if not openAnimation then
			_isOpening = false
			return
		end

		local animation = animator:LoadAnimation(openAnimation)
		animation:Play()
		animation:AdjustSpeed(ANIMATION_SPEED_MULTIPLIER)

		waitForAnimationToFinish(animation, OPEN_ANIMATION_DURATION)

		animation:AdjustSpeed(ANIMATION_RESET_SPEED)

		task.delay(EXIT_DELAY, function()
			if cardModel and cardModel:FindFirstChild("RootPart") then
				TweenService:Create(
					cardModel.RootPart,
					TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
					{ Position = cardModel.RootPart.Position + Vector3.new(0, EXIT_DROP_DISTANCE, 0) }
				):Play()
			end
		end)
	end

	animationFinished = true

	if not summonResolved then
		local deadline = os.clock() + SUMMON_RESULT_WAIT_TIMEOUT
		while not summonResolved and os.clock() < deadline do
			task.wait(SUMMON_RESULT_WAIT_INTERVAL)
		end

		if not summonResolved then
			resolvedItemDataJson = getNetworkErrorPayload()
			summonResolved = true
		end
	end

	showRewardIfReady()

	task.delay(3, function()
		TweenService
			:Create(game.Lighting.Blur, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Size = 0 })
			:Play()
	end)
end

return Packs
