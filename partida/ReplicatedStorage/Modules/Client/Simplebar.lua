-- Made with <3 by Ace

local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local TweenLib = require(script.TweenLib)
local MouseOverModule = require(script.MouseOverModule)

export type TopbarButton = {
	name: string,
	instance: TextButton,
	bindEvent: (self: TopbarButton, fn: () -> ()) -> TopbarButton,
	clearEvents: (self: TopbarButton) -> TopbarButton,
	setState: (self: TopbarButton) -> TopbarButton,
	setSide: (self: TopbarButton) -> TopbarButton,
	setColor: (self: TopbarButton) -> TopbarButton,
	setLayoutOrder: (self: TopbarButton) -> TopbarButton,
	singleBind: (self: TopbarButton) -> TopbarButton,
	setImage: (self: TopbarButton) -> TopbarButton,
	bindToFrame: (self: TopbarButton) -> TopbarButton,
	setSize: (self: TopbarButton) -> TopbarButton,
	setUrgent: (self: TopbarButton) -> TopbarButton,
	setCustomXSize: (self: TopbarButton) -> TopbarButton,
	setHoverText: (self: TopbarButton) -> TopbarButton,
	singleAction: (self: singleAction) -> TopbarButton
}


local disabledColor = Color3.fromRGB(18, 18, 21)
local enabledColor = Color3.fromRGB(255,255,255)

local module = {}
module.__index = module

module.LayoutOrder = 1 -- automatically adjust layout order depending on number called
module.buttons = {}
module.events = {}
module.GUIHolder = nil :: ScreenGui
module.activated = {}

-- Create the topbar GUI

if not module.GUIHolder or not module.GUIHolder.Parent then
	local Simplebar = script.Simplebar:Clone()
	module.GUIHolder = Simplebar
	Simplebar.Name = HttpService:GenerateGUID(false)
	Simplebar.Parent = PlayerGui
end

local DefaultY = 44
local DefaultX = 100

function module.getRef(name)
	return name and module.buttons[string.upper(name)]
end

function module.getEventsRef(name)
	return name and module.events[string.upper(name)]
end

function module.toggleSimplebar(state)
	module.GUIHolder.Enabled = state
end

function module.createButton(name) : TopbarButton
	if module.getRef(name) then
		warn(`Button {string.upper(name)} already exists`)
		warn(debug.traceback('', 2))
		return
	end
	
	local self = setmetatable({}, module) :: TopbarButton
	self.name = string.upper(name)
	-- we can create the button
	local Template = script.Template:Clone()
	
	Template.Name = self.name
	self.instance = Template
	
	Template.Activated:Connect(function()
		local attrib = Template:GetAttribute('Activated')
		Template:SetAttribute('Activated', not attrib)
		self:setState(not attrib)
	end)

	Template.Selectable = true --@Colton: Added for controller support.
	Template.LayoutOrder = module.LayoutOrder
	Template.ZIndex = module.LayoutOrder -- idk why im doing this since ZIndex is just whether or not if it overlaps but eh

	module.LayoutOrder += 1
	
	Template.Parent = module.GUIHolder.MainContainer.Right -- right side by default
	
	module.buttons[self.name] = self.instance -- pass instance reference
	module.events[self.name] = {}
	
	return self
end

function module:setCustomXSize(num: number) : TopbarButton -- 44 is the Y height
	self.instance.Size = UDim2.fromOffset(num, DefaultY)
	return self
end

function module:bindEvent(State, fn: () -> ()) : TopbarButton
	local foundRef = module.getRef(self.name) :: TextButton
	local tableRef = module.getEventsRef(self.name) :: {}
	
	
	if State then
		-- Only for activating
		local conn = foundRef:GetAttributeChangedSignal('Activated'):Connect(function()
			local attrib = foundRef:GetAttribute('Activated')
			
			if attrib or self.singleAction then
				-- Main logic here
				self:setUrgent(false)
				fn()
			end
		end)
		
		table.insert(tableRef, conn)
	else
		-- Only for deactivating
		local conn = foundRef:GetAttributeChangedSignal('Activated'):Connect(function()
			local attrib = foundRef:GetAttribute('Activated')

			if not attrib then
				-- Main logic here
				if not foundRef:GetAttribute('IgnoreSignal') then
					fn()
				else
					foundRef:SetAttribute('IgnoreSignal', false)
				end
			end
		end)

		table.insert(tableRef, conn)
	end
	
	
	return self
end

function module:clearEvents() : TopbarButton
	local foundRef = module.getRef(self.name)
	if foundRef then
		for i,v in foundRef do
			v:Disconnect()
			v = nil
		end
		
		module.events[self.name] = {}
	else
		warn('No events table was created for name reference')
	end
	
	return self
end

function module:setSide(side: string) : TopbarButton
	if side ~= 'Left' and side ~= 'Right' then return self end
	self.instance.Parent = module.GUIHolder.MainContainer[side]
	return self
end

function module:setColor(color) : TopbarButton
	if color then
		local foundGradient = self.instance.Icon:FindFirstChildOfClass('UIGradient')
		if foundGradient then foundGradient:Destroy() end
		
		if typeof(color) == 'Color3' then
			self.instance.Icon.ImageColor3 = color
			self.OriginalColor = color
		elseif typeof(color) == 'Instance' and color:IsA('UIGradient') then -- for gradients, i recommend creating the UIGradient urself
			color:Clone().Parent = self.instance.Icon -- technically this supports scripts too!
		elseif typeof(color) == 'ColorSequence' then -- just incase u specified colorsequence instead
			local Gradient = Instance.new('UIGradient', self.instance.Icon)
			Gradient.Color = color
		end
	end
	
	return self
end

function module:setImage(ID) : TopbarButton
	self.instance.Icon.Image = ID
	
	return self
end

local ttime = 0.1
function module:setState(state: boolean) : TopbarButton
	if state then
		-- enabled
		--self.instance.Icon.ImageColor3
		if not self.singleAction then
			TweenLib.tween(self.instance.Icon, ttime, {ImageColor3 = Color3.fromRGB(0,0,0)})
			TweenLib.tween(self.instance, ttime, {BackgroundColor3 = enabledColor})
			module.activated[self] = true
		
			if self.instance:GetAttribute('SingleBound') then
				for i,v: TextButton in module.activated do
					if i == self then continue end
					i.instance:SetAttribute('IgnoreSignal', true)
					i.instance:SetAttribute('Activated', false)
					i:setState(false)
					
					module.activated[i] = nil
				end
			end
		end
	else
		if not self.singleAction then
			module.activated[self] = nil
			-- inactive/disabled
			TweenLib.tween(self.instance.Icon, ttime, {ImageColor3 = self.OriginalColor or Color3.fromRGB(255,255,255)})
			TweenLib.tween(self.instance, ttime, {BackgroundColor3 = disabledColor})
		end
	end
	
	return self
end

function module:setLayoutOrder(num: number) : TopbarButton
	self.instance.LayoutOrder = num
	return self
end

function module:singleBind(state: boolean) : TopbarButton
	self.instance:SetAttribute('SingleBound', state)
	return self
end

function module:bindToFrame(frame: Frame) : TopbarButton
	if self.boundFrame then
		self.boundFrame = nil
		self.boundConnection:Disconnect()
		self.boundConnection = nil
	end
	
	self.boundFrame = frame
	self.boundConnection = frame:GetPropertyChangedSignal('Visible'):Connect(function()
		if not frame.Visible and module.activated[self] then
			self.instance:SetAttribute('IgnoreSignal', true)
			self.instance:SetAttribute('Activated', false)
			self:setState(false)
		end
	end)
	
	
	return self
end

function module:setSize(num: number) : TopbarButton
	self.instance.Icon.Size = UDim2.fromScale(num, num)
	
	return self
end

function module:setUrgent(state: boolean) : TopbarButton
	self.instance.Urgent.Visible = state
	return self
end

function module:setHoverText(text: string) : TopbarButton
	if not self.hoverTextSet then
		local mouseEnter, mouseLeave = MouseOverModule.MouseEnterLeaveEvent(self.instance)
		
		self.instance.Tooltip.TextLabel.Text = text
		
		mouseEnter:Connect(function()
			TweenLib.tween(self.instance.UIStroke, 0.3, {Transparency = 0})
			self.instance.Tooltip.Visible = true
		end)
		
		mouseLeave:Connect(function()
			TweenLib.tween(self.instance.UIStroke, 0.3, {Transparency = 1})
			self.instance.Tooltip.Visible = false
		end)
		
		self.hoverTextSet = true
	end
	
	
	return self
end

function module:singleAction(state) : TopbarButton
	self.singleAction = state
	
	return self
end

return module