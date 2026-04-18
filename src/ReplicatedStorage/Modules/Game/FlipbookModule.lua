local RunService = game:GetService("RunService")

local FlipbookModule = {}

export type FlipbookConfig = {
	Framerate: number?,
	LoopStartFrame: number?,
	TileCount: Vector2,
	TotalTiles: number?,
	StartTile: number?,
	TilePadding: Vector2?,
	TileResolution: Vector2,
	RandomStartFrame: boolean?,
	OnComplete: (() -> ())?,
}

export type FlipbookInstance = {
	Config: FlipbookConfig,
	CurrentFrame: number,
	_nextFrame: number,
	_connection: RBXScriptConnection?,
	Texture: any,
}

function FlipbookModule.new(textureObject: any, config: FlipbookConfig): FlipbookInstance
	if not textureObject or not (textureObject:IsA("ImageLabel") or textureObject:IsA("ImageButton")) then
		error("FlipbookModule: textureObject must be an ImageLabel or ImageButton")
	end

	local instance = {
		Config = config,
		CurrentFrame = 0,
		_nextFrame = tick(),
		_connection = nil,
		Texture = textureObject,
	}

	if config.RandomStartFrame then
		local tileCount = config.TileCount
		instance.CurrentFrame = math.random(0, tileCount.X * tileCount.Y - 1)
	end

	return instance
end

function FlipbookModule:Play(instance: FlipbookInstance)
	if instance._connection then
		return
	end

	instance._connection = RunService.Stepped:Connect(function(_, deltaTime)
		FlipbookModule:_itterate(instance, deltaTime)
	end)
end

function FlipbookModule:_itterate(instance: FlipbookInstance, deltaTime: number)
	local config = instance.Config
	local framerate = config.Framerate or 30
	local loopStartFrame = config.LoopStartFrame or 0
	local tileCount = config.TileCount
	local totalTiles = config.TotalTiles or (tileCount.X * tileCount.Y)
	local startTile = config.StartTile or 0
	local tilePadding = config.TilePadding or Vector2.new(0, 0)
	local tileResolution = config.TileResolution

	instance.CurrentFrame = math.max(instance.CurrentFrame, startTile)

	local Y = math.floor(instance.CurrentFrame / tileCount.X)
	local X = instance.CurrentFrame - (Y * tileCount.X)

	instance.Texture.ImageRectSize = tileResolution
	instance.Texture.ImageRectOffset = (tileResolution + tilePadding) * Vector2.new(X, Y)

	if tick() >= instance._nextFrame then
		instance._nextFrame = tick() + (1 / framerate)
		instance.CurrentFrame = instance.CurrentFrame + 1
	end

	if instance.CurrentFrame >= totalTiles then
		FlipbookModule:Stop(instance)
		if config.OnComplete then
			config.OnComplete()
		end
	end
end

function FlipbookModule:Stop(instance: FlipbookInstance)
	if instance._connection then
		instance._connection:Disconnect()
		instance._connection = nil
	end
end

function FlipbookModule:Restart(instance: FlipbookInstance)
	instance.CurrentFrame = instance.Config.StartTile or 0
	instance._nextFrame = tick()
end

function FlipbookModule:SetFrame(instance: FlipbookInstance, frameNumber: number)
	local startTile = instance.Config.StartTile or 0
	local totalTiles = instance.Config.TotalTiles or (instance.Config.TileCount.X * instance.Config.TileCount.Y)

	if frameNumber >= startTile and frameNumber < totalTiles then
		instance.CurrentFrame = frameNumber
	end
end

function FlipbookModule:Destroy(instance: FlipbookInstance)
	FlipbookModule:Stop(instance)
	instance.Texture = nil
end

return FlipbookModule