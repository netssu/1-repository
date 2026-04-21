local module = {}
local RS = game.ReplicatedStorage
local ItemsFolder = require(RS.Modules.GetItemModel)
local BossFolder = require(RS.Modules.GetBossModel)
local UnitFolder = require(RS.Modules.GetUnitModel)
local RunService = game:GetService("RunService")

-- Cache for cloned UI elements to avoid repeated cloning
local UIElementCache = {
	UICorner = nil,
	UIGradient = nil,
	AnimationPlayer = nil,
	ShinyOverlay = nil
}

-- Viewport pooling system
local ViewportPool = {}
local ActiveViewports = {}
local ViewportCount = 0

-- Performance monitoring
local LastFrameUpdate = tick()
local FRAME_BUDGET = 1/60 -- 60 FPS target
local MAX_VIEWPORTS_PER_FRAME = 5

-- Initialize cache
local function initializeCache()
	if not UIElementCache.UICorner then
		UIElementCache.UICorner = script.UICorner
		UIElementCache.UIGradient = script.UIGradient
		UIElementCache.AnimationPlayer = script.AnimationPlayer
		UIElementCache.ShinyOverlay = RS.UI_Assets.ShinyOverlay
	end
end

-- Viewport visibility management
local skipCount = 5
local track = 0

local function updateViewportVisibility()
	if track == skipCount then
		track = 0
	else
		track += 1
		return
	end
	
	local currentTime = tick()
	if currentTime - LastFrameUpdate < FRAME_BUDGET then return end

	local processed = 0
	for viewport, data in pairs(ActiveViewports) do
		if processed >= MAX_VIEWPORTS_PER_FRAME then
			break
		end

		if viewport.Parent then
			local isVisible = viewport.AbsoluteSize.X > 0 and viewport.AbsoluteSize.Y > 0
			local wasVisible = data.wasVisible

			if isVisible ~= wasVisible then
				data.wasVisible = isVisible
				if data.animationScript then
					data.animationScript.Enabled = isVisible
				end
				processed = processed + 1
			end
		else
			-- Cleanup destroyed viewports
			ActiveViewports[viewport] = nil
			ViewportCount = ViewportCount - 1
		end
	end

	LastFrameUpdate = currentTime
end

-- Pool management
local function getPooledViewport()
	if #ViewportPool > 0 then
		return table.remove(ViewportPool)
	end
	return nil
end

local function returnToPool(viewport)
	if #ViewportPool < 50 then -- Limit pool size
		-- Clean up viewport for reuse
		viewport.Parent = nil
		viewport:ClearAllChildren()
		table.insert(ViewportPool, viewport)
	else
		viewport:Destroy()
	end
end

-- Optimized model positioning
local function setModelPosition(model, customCFrame)
	if model.PrimaryPart then
		model:SetPrimaryPartCFrame(customCFrame)
	else
		local rootPart = model:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.CFrame = customCFrame
		end
	end
end

-- Batch UI element creation
local function applyUIElements(viewport, shiny, customSize)
	initializeCache()

	-- Apply size and position
	if not customSize then
		viewport.AnchorPoint = Vector2.new(0.5, 0.5)
		viewport.Position = UDim2.new(0.5, 0, 0.5, 0)
		viewport.Size = UDim2.new(1.1, 0, 1.1, 0)
		viewport.ZIndex = 2
	end

	-- Clone and apply UI elements in batch
	local corner = UIElementCache.UICorner:Clone()
	local grad = UIElementCache.UIGradient:Clone()

	corner.Parent = viewport
	grad.Parent = viewport

	if shiny then
		local shine = UIElementCache.ShinyOverlay:Clone()
		shine.Parent = viewport
		shine.ZIndex = 3
	end
end

-- Level-of-detail system for distant viewports
local function shouldUseHighDetail(viewport)
	if not viewport.Parent then return false end

	local absoluteSize = viewport.AbsoluteSize
	local screenArea = absoluteSize.X * absoluteSize.Y

	-- Use high detail for larger viewports
	return screenArea > 10000 -- Adjust threshold as needed
end

module.CreateViewPort = function(Name, shiny, customSize, lowDetail)
	print('creating viewport')
	local IsItem = module.IsItem(Name)
	local ModelFolder = (IsItem and ItemsFolder) or (IsItem == nil and BossFolder) or UnitFolder

	-- Check if model exists early
	if not ModelFolder[Name] then
		return nil
	end

	-- Try to get pooled viewport first
	local ViewPort = getPooledViewport()
	if not ViewPort then
		ViewPort = Instance.new("ViewportFrame")
	end

	ViewPort.BackgroundTransparency = 1
	ViewPort.Name = Name

	local WorldModel = Instance.new("WorldModel")
	WorldModel.Parent = ViewPort

	local Model = ModelFolder[Name]:Clone()
	Model.Parent = WorldModel
	
	--if true then return Model end

	-- Optimize model positioning
	local targetCFrame
	if Model:GetAttribute("CFrame") then
		targetCFrame = Model:GetAttribute("CFrame")
	else
		targetCFrame = IsItem and 
			CFrame.new(0, -0.496, -1.442) * CFrame.Angles(0, math.rad(170), 0) or
			CFrame.new(0, -0.496, -1.442) * CFrame.Angles(0, math.rad(180), 0)
	end

	setModelPosition(Model, targetCFrame)

	-- Apply UI elements
	applyUIElements(ViewPort, shiny, customSize)

	-- Handle animations with performance consideration
	local animationScript = nil
	if not IsItem then -- and false to disable it
		animationScript = UIElementCache.AnimationPlayer:Clone()
		animationScript.Enabled = not lowDetail -- Disable for low detail
		animationScript.Parent = Model
	end

	-- Track viewport for visibility management
	ViewportCount = ViewportCount + 1
	ActiveViewports[ViewPort] = {
		animationScript = animationScript,
		wasVisible = true,
		isHighDetail = not lowDetail
	}

	return ViewPort
end

module.CreateEmptyPort = function(lowDetail)
	local ViewPort = getPooledViewport()
	if not ViewPort then
		ViewPort = Instance.new("ViewportFrame")
	end

	ViewPort.BackgroundTransparency = 1
	ViewPort.Name = "Empty_Slot"

	local WorldModel = Instance.new("WorldModel")
	WorldModel.Parent = ViewPort

	local Model = script.Empty_Slot:Clone()
	Model.Parent = WorldModel

	setModelPosition(Model, Model:GetAttribute("CFrame"))

	applyUIElements(ViewPort, false, false)

	local animationScript = UIElementCache.AnimationPlayer:Clone()
	animationScript.Enabled = not lowDetail
	animationScript.Parent = Model

	ViewportCount = ViewportCount + 1
	ActiveViewports[ViewPort] = {
		animationScript = animationScript,
		wasVisible = true,
		isHighDetail = not lowDetail
	}

	return ViewPort
end

module.IsItem = function(Name)
	if ItemsFolder[Name] then
		return true
	elseif BossFolder[Name] then
		return nil
	else
		return false
	end
end

-- Cleanup function for destroyed viewports
module.DestroyViewport = function(viewport)
	if ActiveViewports[viewport] then
		ActiveViewports[viewport] = nil
		ViewportCount = ViewportCount - 1
		returnToPool(viewport)
	end
end

-- Batch create function for multiple viewports
module.CreateViewportBatch = function(viewportData, callback)
	local createdViewports = {}
	local batchSize = 3 -- Create 3 at a time
	local currentIndex = 1

	local function createNext()
		local endIndex = math.min(currentIndex + batchSize - 1, #viewportData)

		for i = currentIndex, endIndex do
			local data = viewportData[i]
			local viewport = module.CreateViewPort(data.name, data.shiny, data.customSize, data.lowDetail)
			if viewport then
				table.insert(createdViewports, viewport)
			end
		end

		currentIndex = endIndex + 1

		if currentIndex <= #viewportData then
			RunService.Heartbeat:Wait() -- Yield for one frame
			createNext()
		else
			if callback then
				callback(createdViewports)
			end
		end
	end

	createNext()
end

-- Performance monitoring
module.GetPerformanceStats = function()
	return {
		ActiveViewports = ViewportCount,
		PooledViewports = #ViewportPool
	}
end

-- Initialize visibility management
RunService.Heartbeat:Connect(updateViewportVisibility)

return module