--!strict

--------------------------------------------------------------------------------
-- SlowAnimage - Mass-create-then-wait approach, with optional SpriteSheet mode
--------------------------------------------------------------------------------

local Players = game:GetService("Players")

--------------------------------------------------------------------------------
-- GLOBAL STORAGE (used by multi-frame mode)
--------------------------------------------------------------------------------

local function GetGlobalStorageGui(): ScreenGui
	local player = Players.LocalPlayer
	if not player then
		error("SlowAnimage: No LocalPlayer found!")
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local storage = playerGui:FindFirstChild("SlowAnimageStorage")
	if not storage then
		storage = Instance.new("ScreenGui")
		storage.Name = "SlowAnimageStorage"
		storage.ResetOnSpawn = false
		storage.Parent = playerGui
	end
	storage.IgnoreGuiInset = true
	return storage
end

-- Global dictionary mapping "rbxassetid://12345" -> ImageLabel (cached)
local GlobalImageLabels: { [string]: ImageLabel } = {}

--------------------------------------------------------------------------------
-- UTILITY
--------------------------------------------------------------------------------

local TARGET_TYPE_READ_PROPERTIES = {
	ImageLabel = "Image",
	ImageButton = "Image",
	MeshPart   = "TextureID",
	Decal      = "Texture",
}

local function GetTextureID(child: Instance): string?
	local prop = TARGET_TYPE_READ_PROPERTIES[child.ClassName]
	if prop then
		local val = child[prop]
		if val and val ~= "" then
			return val
		end
	end
	return nil
end

local function ApplyAssetIdDirectly(targets: {Instance}, assetId: string)
	for _, target in ipairs(targets) do
		local prop = TARGET_TYPE_READ_PROPERTIES[target.ClassName]
		if prop then
			target[prop] = assetId
		end
	end
end

local function ExtractNumber(str: string): number?
	local match = string.match(str, "%d+")
	return match and tonumber(match) or nil
end

--------------------------------------------------------------------------------
-- SlowAnimage CLASS
--------------------------------------------------------------------------------

local SlowAnimage = {}
SlowAnimage.__index = SlowAnimage

function SlowAnimage.new(
	targetOrTargets: Instance | {Instance},
	framesHolder: Instance?
)
	local self = setmetatable({}, SlowAnimage)

	----------------------------------------------------------------
	-- Convert single target to table
	----------------------------------------------------------------
	if typeof(targetOrTargets) == "Instance" then
		self.Targets = { targetOrTargets }
	else
		self.Targets = targetOrTargets
	end

	self.FramesHolder = framesHolder

	-- Playback flags:
	self.Playing = false
	self.Paused = false
	self.CurrentFrame = 1
	self.FPS = 1
	self.Loops = true
	self.Reverses = false

	self.AnimationThread = nil
	self.FramesData = {} -- will store { AssetId = "rbxassetid://...", ... }

	-- Sprite-sheet fields
	self.SpriteSheet = false
	self.SpriteSheetColumns = 0
	self.SpriteSheetRows = 0
	self.SpriteSheetTotalFrames = 0

	----------------------------------------------------------------
	-- DETECT IF WE SHOULD USE SPRITE-SHEET MODE
	----------------------------------------------------------------
	do
		local firstTarget = self.Targets[1]
		if firstTarget 
			and (firstTarget.ClassName == "ImageLabel" or firstTarget.ClassName == "ImageButton")
		then
			local spriteSheetVec = firstTarget:GetAttribute("SpriteSheet")
			if typeof(spriteSheetVec) == "Vector2" then
				self.SpriteSheet = true
				self.SpriteSheetColumns = spriteSheetVec.X
				self.SpriteSheetRows = spriteSheetVec.Y
				self.SpriteSheetTotalFrames = self.SpriteSheetColumns * self.SpriteSheetRows
				self.Name = firstTarget:GetFullName()
			end
		end
	end

	----------------------------------------------------------------
	-- SPRITE-SHEET MODE
	----------------------------------------------------------------
	if self.SpriteSheet then
		-- We do NOT use framesHolder. We rely on the existing .Image being set.
		-- We'll just ensure we re-apply whatever .Image the first target has to all targets
		local firstTarget = self.Targets[1]
		local firstAssetId = GetTextureID(firstTarget)
		if firstAssetId then
			ApplyAssetIdDirectly(self.Targets, firstAssetId)
		end
	else
		----------------------------------------------------------------
		-- MULTI-FRAME MODE
		----------------------------------------------------------------
		if not self.FramesHolder then
			--warn("SlowAnimage: No framesHolder provided and no SpriteSheet attribute found.")
			return self
		end

		-- 1) Sort frames by numeric name, fallback to alphabetical
		local children = self.FramesHolder:GetChildren()
		table.sort(children, function(a, b)
			local aNum = ExtractNumber(a.Name)
			local bNum = ExtractNumber(b.Name)
			if aNum and bNum then
				return aNum < bNum
			elseif aNum and not bNum then
				return true
			elseif bNum and not aNum then
				return false
			else
				return a.Name < b.Name
			end
		end)

		-- 2) Gather all valid assetIds
		local assetIdList = {}
		for _, child in ipairs(children) do
			local assetId = GetTextureID(child)
			if assetId then
				table.insert(assetIdList, assetId)
			end
		end

		-- 3) Mass-create hidden labels, track them for a final "wait until loaded" step
		local labelList = {}
		for _, assetId in ipairs(assetIdList) do
			-- Reuse or create new label
			local label = GlobalImageLabels[assetId]
			if not label then
				local storage = GetGlobalStorageGui()
				label = Instance.new("ImageLabel")
				label.Name = "SlowAnimage_" .. assetId
				label.Position = UDim2.fromOffset(0, 0)
				label.Size = UDim2.fromOffset(1, 1)
				label.BackgroundTransparency = 1
				label.ImageTransparency = 0.999
				label.Visible = true
				label.Parent = storage

				GlobalImageLabels[assetId] = label
			end

			-- Re-set the .Image in case something changed
			label.Image = assetId
			table.insert(labelList, label)

			-- Also store for playback
			table.insert(self.FramesData, { AssetId = assetId })
		end

		-- 4) Wait until all are loaded
		local totalCount = #labelList
		local loadedCount = 0
		for _, label in ipairs(labelList) do
			task.spawn(function()
				if label.IsLoaded then
					loadedCount += 1
				else
					repeat task.wait() until label.IsLoaded
					loadedCount += 1
				end
			end)
		end

		while loadedCount < totalCount do
			task.wait()
		end

		-- 5) If we have frames, set the first frame's asset ID right away
		if #self.FramesData > 0 then
			ApplyAssetIdDirectly(self.Targets, self.FramesData[1].AssetId)
		end
	end

	return self
end

--------------------------------------------------------------------------------
-- Playback
--------------------------------------------------------------------------------

-- New signature: :Play(fps: number?, loops: bool?, reverses: bool?)
function SlowAnimage:Play(fps: number?, loops: boolean?, reverses: boolean?)
	if fps then
		self.FPS = fps
	end
	if loops ~= nil then
		self.Loops = loops
	end
	if reverses ~= nil then
		self.Reverses = reverses
	end

	-- If already playing, just unpause if we were paused
	if self.Playing then
		self.Paused = false
		return
	end

	self.Playing = true
	self.Paused = false

	-- SPRITE-SHEET MODE
	if self.SpriteSheet then
		-- If no frames or invalid
		if self.SpriteSheetTotalFrames < 1 then
			warn("SlowAnimage: SpriteSheet has 0 frames or is invalid.")
			self.Playing = false
			return
		end

		self.AnimationThread = task.spawn(function()
			while self.Playing do
				debug.profilebegin(`Animage Sprite-Sheet: {self.Name}`)
				if not self.Paused then
					self:SetFrame(self.CurrentFrame)
					debug.profileend()
					task.wait(1 / self.FPS)

					-- Step
					if self.Reverses then
						self.CurrentFrame -= 1
						if self.CurrentFrame < 1 then
							if self.Loops then
								self.CurrentFrame = self.SpriteSheetTotalFrames
							else
								self.CurrentFrame = 1
								self.Playing = false
							end
						end
					else
						self.CurrentFrame += 1
						if self.CurrentFrame > self.SpriteSheetTotalFrames then
							if self.Loops then
								self.CurrentFrame = 1
							else
								self.CurrentFrame = self.SpriteSheetTotalFrames
								self.Playing = false
							end
						end
					end
				else
					debug.profileend()
					task.wait()
				end
			end
		end)

	else
		-- MULTI-FRAME MODE
		if #self.FramesData == 0 then
			--warn("SlowAnimage: No frames to play in multi-frame mode.")
			self.Playing = false
			return
		end

		self.AnimationThread = task.spawn(function()
			local total = #self.FramesData
			while self.Playing do
				debug.profilebegin(`Animage Mutli-Frame: {self.FramesHolder.Name}`)
				if not self.Paused then
					self:SetFrame(self.CurrentFrame)
					debug.profileend()
					task.wait(1 / self.FPS)

					-- Step
					if self.Reverses then
						self.CurrentFrame -= 1
						if self.CurrentFrame < 1 then
							if self.Loops then
								self.CurrentFrame = total
							else
								self.CurrentFrame = 1
								self.Playing = false
							end
						end
					else
						self.CurrentFrame += 1
						if self.CurrentFrame > total then
							if self.Loops then
								self.CurrentFrame = 1
							else
								self.CurrentFrame = total
								self.Playing = false
							end
						end
					end
				else
					debug.profileend()
					task.wait()
				end
			end
		end)
	end
end

function SlowAnimage:Pause()
	if self.Playing then
		self.Paused = true
	end
end

function SlowAnimage:Cancel()
	self.Playing = false
	self.Paused = false
	self.CurrentFrame = 1

	if self.SpriteSheet then
		-- Show the first cell
		self:SetFrame(1)
	else
		-- Show first multi-frame if we have one
		if #self.FramesData > 0 then
			ApplyAssetIdDirectly(self.Targets, self.FramesData[1].AssetId)
		end
	end
end

-- Toggle the direction of playback (forward <-> reverse)
function SlowAnimage:Reverse()
	self.Reverses = not self.Reverses
	
end

function SlowAnimage:SetFrame(index: number)
	-- SPRITE-SHEET MODE
	if self.SpriteSheet then
		if self.SpriteSheetTotalFrames < 1 then
			return
		end
		index = math.clamp(index, 1, self.SpriteSheetTotalFrames)
		self.CurrentFrame = index

		-- For each GUI target, shift .ImageRectOffset by the size of one cell
		for _, target in ipairs(self.Targets) do
			if target:IsA("ImageLabel") or target:IsA("ImageButton") then
				local cols = self.SpriteSheetColumns
				if cols <= 0 then
					warn("SlowAnimage: SpriteSheet columns <= 0?")
					return
				end
				-- The user is expected to have set .ImageRectSize to the size of one cell
				local cellSize = target.ImageRectSize

				local idx = index - 1
				local offsetX = (idx % cols) * cellSize.X
				local offsetY = math.floor(idx / cols) * cellSize.Y
				target.ImageRectOffset = Vector2.new(offsetX, offsetY)
			end
		end

		return
	end

	-- MULTI-FRAME MODE
	if #self.FramesData == 0 then
		return
	end
	index = math.clamp(index, 1, #self.FramesData)
	self.CurrentFrame = index

	local frameData = self.FramesData[index]
	ApplyAssetIdDirectly(self.Targets, frameData.AssetId)
end

function SlowAnimage:Destroy()
	self:Cancel()
	self.FramesData = {}
	self.Targets = {}
	self.FramesHolder = nil
end

return SlowAnimage