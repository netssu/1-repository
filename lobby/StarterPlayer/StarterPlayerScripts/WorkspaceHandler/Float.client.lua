local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local tagName = "Float"
local floatModels = {}
local floatSpeed = 2
local floatHeight = 0.2
local rotationSpeed = math.rad(1)

local function register(model)
	if model:IsA("Model") and model.PrimaryPart and not floatModels[model] then
		floatModels[model] = { baseCFrame = model:GetPrimaryPartCFrame(), time = 0 }
	end
end

local function unregister(model)
	floatModels[model] = nil
end

for _, model in ipairs(CollectionService:GetTagged(tagName)) do
	register(model)
end

CollectionService:GetInstanceAddedSignal(tagName):Connect(register)
CollectionService:GetInstanceRemovedSignal(tagName):Connect(unregister)

local skipStep = 5
local track = 0
local UserInputService = game:GetService("UserInputService")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

if not isMobile then -- disabled for mobile optimisation
	RunService.RenderStepped:Connect(function(dt) -- optimised by ace
		if track == skipStep then
			track = 0
		else
			track += 1
			return
		end
		
		for model, data in next, floatModels do
			local pp = model.PrimaryPart
			if pp then
				data.time += floatSpeed * dt
				local y = math.sin(data.time) * floatHeight
				local floatPos = data.baseCFrame.Position + Vector3.new(0, y, 0)
				local rot = data.baseCFrame * CFrame.Angles(0, rotationSpeed, 0)
				model:PivotTo(CFrame.new(floatPos) * (rot - rot.Position))
			else
				unregister(model)
			end
		end
	end)
end