local CurrentCamera = workspace.Camera
local XDivisor = 1278
local MultiplyBy = CurrentCamera.ViewportSize.X / XDivisor

local ThicknessCache = {}
local OnUIStroke = function( UIStroke : UIStroke )
	if not UIStroke:IsA('UIStroke') then
		return
	end
	local OriginalThickness = ThicknessCache[UIStroke]
	if not OriginalThickness then
		ThicknessCache[UIStroke] = UIStroke.Thickness
		OriginalThickness = UIStroke.Thickness
	end
	UIStroke.Thickness = OriginalThickness * MultiplyBy
end

local CollectionService : CollectionService = game:GetService('CollectionService')
CollectionService:GetInstanceAddedSignal('UIStroke'):Connect( OnUIStroke )

local tspawn = task.spawn
local ScaleAll = function()
	for __ , UIStroke : UIStroke in CollectionService:GetTagged('UIStroke') do
		tspawn( OnUIStroke , UIStroke )
	end
end ; ScaleAll()
CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
	MultiplyBy = CurrentCamera.ViewportSize.X / XDivisor
	ScaleAll()
end)

--local CurrentCamera = workspace.CurrentCamera

--local uiStrokes: { UIStroke } = {}
--local thicknessCache = {}

--local xDivisor = 1278

--local function scaleStrokes()
--	for _, uiStroke in uiStrokes do
--		local originalThickness = thicknessCache[uiStroke]
		
--		if not originalThickness then
--			thicknessCache[uiStroke] = uiStroke.Thickness
			
--			originalThickness = uiStroke.Thickness
--		end
			
--		uiStroke.Thickness = originalThickness * (CurrentCamera.ViewportSize.X / xDivisor)
--	end
--end

--local function strokeAdded(uiStroke: UIStroke)
--	table.insert(uiStrokes, uiStroke)
--end

--do
--	for _, descendant in script.Parent:GetDescendants() do
--		if descendant:IsA("UIStroke") then
--			task.spawn(strokeAdded, descendant)
--		end
--	end

--	script.Parent.DescendantAdded:Connect(function(descendant: Instance) 
--		if descendant:IsA("UIStroke") then
--			strokeAdded(descendant)	
--		end	
--	end)
--end

--do
--	CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(scaleStrokes)

--	task.spawn(scaleStrokes)
--end