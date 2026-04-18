--!strict

-- Based on the provided WaveTransition snippet: generates a grid of squares that animate in a wave.
local WaveTransition = {}
WaveTransition.__index = WaveTransition

local TYPEDEF_ONLY = {} -- Roblox typing workaround

export type WaveTransitionParams = {
	color: Color3?,
	width: number?,
	waveDirection: Vector2?,
	waveFunction: ((x: number, t: number) -> number)?,
}

-- Default easing curve: https://www.desmos.com/calculator/linp7zw3sa
local function DefaultWaveFunction(x: number, t: number): number
	local l = 0.5
	local edge = t * (1 + l)
	if x < edge - l then
		return 1
	elseif x > edge then
		return 0
	else
		return 0.5 + 0.5 * math.cos(math.pi / l * (x - edge + l))
	end
end

function WaveTransition.new(container: GuiBase2d, params: WaveTransitionParams?)
	local width = (params and params.width) or 10

	-- calculate the number of rows to cover the screen
	local size = container.AbsoluteSize.X / width
	local height = math.ceil(container.AbsoluteSize.Y / size)

	local self = {
		squares = table.create(width * height) :: {GuiObject},
		percents = table.create(width * height) :: {number},
		color = (params and params.color) or Color3.new(1, 1, 1),
		width = width,
		height = height,
		size = size,
		waveDirection = (params and params.waveDirection) or Vector2.new(1, 1),
		waveFunction = (params and params.waveFunction) or DefaultWaveFunction,
	}

	if container ~= TYPEDEF_ONLY then
		local shortest = math.huge
		local longest = -math.huge

		for r = 1, self.height do
			for c = 1, self.width do
				local pos = Vector2.new((c - 1) * self.size, (r - 1) * self.size)
				local f = Instance.new("Frame")
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.Size = UDim2.fromOffset(self.size + 1, self.size + 1) -- +1 to overlap edges
				f.Position = UDim2.fromOffset(pos.X + self.size / 2, pos.Y + self.size / 2)
				f.BackgroundColor3 = self.color
				f.BorderSizePixel = 0
				f.Parent = container

				local percent = self.waveDirection:Dot(pos)
				if percent < shortest then
					shortest = percent
				end
				if percent > longest then
					longest = percent
				end

				local idx = (r - 1) * self.width + c
				self.squares[idx] = f
				self.percents[idx] = percent
			end
		end

		for i, s in ipairs(self.squares) do
			self.percents[i] = (self.percents[i] - shortest) / (longest - shortest)
		end
	end

	setmetatable(self, WaveTransition)
	return self
end

function WaveTransition:_UpdateOne(square: GuiObject, percent: number, alpha: number)
	local t = self.waveFunction(percent, alpha)
	square.Size = UDim2.fromOffset(t * (self.size + 1), t * (self.size + 1))
end

function WaveTransition:Update(alpha: number)
	for i, square in ipairs(self.squares) do
		self:_UpdateOne(square, self.percents[i], alpha)
	end
end

function WaveTransition:Destroy()
	for _, s in ipairs(self.squares) do
		s:Destroy()
	end
	self.squares = nil :: any
	self.percents = nil :: any
end

export type WaveTransition = typeof(WaveTransition.new(TYPEDEF_ONLY :: any))

return WaveTransition
