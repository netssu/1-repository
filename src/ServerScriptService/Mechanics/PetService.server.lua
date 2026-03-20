local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local DATA_UTILITY = require(ReplicatedStorage.Modules.Utility.DataUtility)
local DATA_PETS = require(ReplicatedStorage.Modules.Datas.PetsData)
local MultiplierUtility = require(ReplicatedStorage.Modules.Utility.MultiplierUtility)

-- CONFIG
local PET_DISTANCE = 6
local PET_SIDE_OFFSET = 4
local FLY_HEIGHT = 3

local WALK_BOB_SPEED = 8
local WALK_BOB_AMOUNT = 0.25
local WALK_TILT_AMOUNT = math.rad(6)
local WALK_FORWARD_AMOUNT = 0.6 

local ALIGN_RESPONSIVENESS = 35
local ROTATION_RESPONSIVENESS = 100
local TELEPORT_DISTANCE = 60

-- STORAGE
local activePets = {}

---------------------------------------------------
-- HOLDER
---------------------------------------------------

local function createHolder(character)
	local hrp = character:WaitForChild("HumanoidRootPart")

	local holder = Instance.new("Part")
	holder.Name = "PetHolder"
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Massless = true
	holder.Size = Vector3.new(1,1,1)
	holder.CFrame = hrp.CFrame
	holder.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = holder
	weld.Parent = holder

	return holder
end

---------------------------------------------------
-- PET CREATION
---------------------------------------------------

local function createPet(player, character, petName, slotIndex)
	local hrp = character:WaitForChild("HumanoidRootPart")
	local petData = DATA_PETS.GetPetData(petName)
	if not petData or not petData.MeshPart then return end

	local pet = petData.MeshPart:Clone()
	pet.Name = player.Name .. "_Pet_" .. slotIndex
	pet.CanCollide = false
	pet.Massless = true
	pet.CFrame = hrp.CFrame * CFrame.new(0,5,5)
	pet.Parent = character

	local holder = character:FindFirstChild("PetHolder") or createHolder(character)

	local charAttachment = Instance.new("Attachment")
	charAttachment.Parent = holder

	local petAttachment = Instance.new("Attachment")
	petAttachment.Parent = pet

	local alignPos = Instance.new("AlignPosition")
	alignPos.Mode = Enum.PositionAlignmentMode.TwoAttachment
	alignPos.Attachment0 = petAttachment
	alignPos.Attachment1 = charAttachment
	alignPos.Responsiveness = ALIGN_RESPONSIVENESS
	alignPos.MaxForce = 50000
	alignPos.Parent = pet

	local alignRot = Instance.new("AlignOrientation")
	alignRot.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignRot.Attachment0 = petAttachment
	alignRot.Responsiveness = ROTATION_RESPONSIVENESS
	alignRot.MaxTorque = 50000
	alignRot.Parent = pet

	if not activePets[player] then
		activePets[player] = {}
	end

	activePets[player][slotIndex] = {
		Pet = pet,
		Character = character,
		Holder = holder,
		Attachment = charAttachment,
		AlignRot = alignRot,
		IsFlying = petData.IsFlying or false,
		Time = 0
	}

	pet:SetNetworkOwner(player)
end

---------------------------------------------------
-- UPDATE MULTIPLIER
---------------------------------------------------

local function updateMultiplier(player)
	local equipped = DATA_UTILITY.server.get(player, "EquippedPets") or {}
	local total = 1

	for _, petName in pairs(equipped) do
		local petData = DATA_PETS.GetPetData(petName)
		if petData and petData.Multiplier then
			total += petData.Multiplier
		end
	end

	MultiplierUtility.set_base(player, total)
end

---------------------------------------------------
-- SPAWN PETS
---------------------------------------------------

local function spawnPets(player)
	if activePets[player] then
		for _, data in pairs(activePets[player]) do
			data.Pet:Destroy()
		end
	end

	activePets[player] = {}

	local character = player.Character
	if not character then return end

	local equipped = DATA_UTILITY.server.get(player, "EquippedPets") or {}

	for slotIndex, petName in pairs(equipped) do
		createPet(player, character, petName, tonumber(slotIndex))
	end

	updateMultiplier(player)
end


local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

RunService.Heartbeat:Connect(function(dt)
	for player, pets in pairs(activePets) do
		for slotIndex, data in pairs(pets) do
			local pet = data.Pet
			local character = data.Character
			if not pet or not pet.Parent or not character.Parent then continue end

			local hrp = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChild("Humanoid")
			if not hrp or not humanoid then continue end

			data.Time += dt * WALK_BOB_SPEED
			
			local isMoving = humanoid.MoveDirection.Magnitude > 0.1
			local offsetX = (slotIndex % 2 == 0 and -PET_SIDE_OFFSET or PET_SIDE_OFFSET)
			local baseOffsetZ = PET_DISTANCE + (math.floor(slotIndex/3) * 3)

			local walkForward = 0
			if isMoving and not data.IsFlying then
				walkForward = math.sin(data.Time) * WALK_FORWARD_AMOUNT
			end

			local offsetZ = baseOffsetZ + walkForward


			local targetY

			if data.IsFlying then
				targetY = FLY_HEIGHT + math.sin(data.Time) * 0.5
			else
				rayParams.FilterDescendantsInstances = { pet, character }

				local worldPos = hrp.Position
					+ hrp.CFrame.RightVector  * offsetX
					+ hrp.CFrame.LookVector   * offsetZ

				local ray = Workspace:Raycast(
					worldPos + Vector3.new(0, 10, 0),
					Vector3.new(0, -25, 0),
					rayParams
				)

				if ray then
					targetY = (ray.Position.Y - hrp.Position.Y) + (pet.Size.Y / 2)
				else
					local hip = humanoid.HipHeight > 0 and humanoid.HipHeight or 2
					targetY = -hip + (pet.Size.Y / 2)
				end

				if isMoving then
					targetY += math.abs(math.sin(data.Time)) * WALK_BOB_AMOUNT
				end
			end

			data.Attachment.Position = Vector3.new(offsetX, targetY, offsetZ)

			local lookDir = hrp.CFrame.LookVector
			local petPos = pet.Position
			local lookPoint = petPos + Vector3.new(lookDir.X,0,lookDir.Z)

			local baseRotation = CFrame.lookAt(petPos, lookPoint)

			local tilt = 0
			if isMoving and not data.IsFlying then
				tilt = math.sin(data.Time) * WALK_TILT_AMOUNT
			end

			data.AlignRot.CFrame = baseRotation * CFrame.Angles(tilt, math.rad(-90), 0)

			if (pet.Position - hrp.Position).Magnitude > TELEPORT_DISTANCE then
				pet.CFrame = hrp.CFrame
			end
		end
	end
end)

---------------------------------------------------
-- PLAYER CONNECTIONS
---------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		spawnPets(player)
	end)

	DATA_UTILITY.server.bind(player, "EquippedPets", function()
		spawnPets(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if activePets[player] then
		for _, data in pairs(activePets[player]) do
			data.Pet:Destroy()
		end
		activePets[player] = nil
	end
end)
