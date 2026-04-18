------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local Assets = ReplicatedStorage:WaitForChild("Assets")
local CosmeticsFolder = Assets:WaitForChild("Cosmetics")

------------------//VARIABLES
local CosmeticsModule = {}

CosmeticsModule.Items = {
    ["Arm Band"] = {
        Name = "Arm Band",
        Model = CosmeticsFolder:WaitForChild("Arm Band"),
        Rarity = "Common",
        Price = 100,
        Weight = 1000,
        AnimationId = nil,
        BodyPart = "Arms",
    },
    ["Black Gloves"] = {
        Name = "Black Gloves",
        Model = CosmeticsFolder:WaitForChild("Black Gloves"),
        Rarity = "Common",
        Price = 150,
        Weight = 1000,
        AnimationId = nil,
        BodyPart = "Hands",
         MotorOffsets = {
            ["Left Arm"]  = CFrame.new(0, -0.65, 0),
            ["Right Arm"] = CFrame.new(0, -0.65, 0),
        },
    },
    ["Navy"] = {
        Name = "Navy",
        Model = CosmeticsFolder:WaitForChild("Navy"),
        Rarity = "Common",
        Price = 120,
        Weight = 1000,
        AnimationId = nil,
        BodyPart = "Head",
        MotorOffsets = {
            ["Head"] = CFrame.new(0, 0.1, 0)
        },
    },
    ["Ball Boy Bag"] = {
        Name = "Ball Boy Bag",
        Model = CosmeticsFolder:WaitForChild("Ball Boy Bag"),
        Rarity = "Uncommon",
        Price = 250,
        Weight = 500,
        AnimationId = nil,
        BodyPart = "Torso",
    },
    ["Chain"] = {
        Name = "Chain",
        Model = CosmeticsFolder:WaitForChild("Chain"),
        Rarity = "Rare",
        Price = 500,
        Weight = 200,
        AnimationId = nil,
        BodyPart = "Torso",
    },
    ["Ski Mask"] = {
        Name = "Ski Mask",
        Model = CosmeticsFolder:WaitForChild("Ski Mask"),
        Rarity = "Rare",
        Price = 300,
        Weight = 200,
        AnimationId = nil,
        BodyPart = "Head",
    },
    ["Super Cape"] = {
        Name = "Super Cape",
        Model = CosmeticsFolder:WaitForChild("Super Cape"),
        Rarity = "Epic",
        Price = 1000,
        Weight = 50,
        AnimationId = nil,
        BodyPart = "Back",
    },
    ["Batman Cape"] = {
        Name = "Batman Cape",
        Model = CosmeticsFolder:WaitForChild("Batman Cape"),
        Rarity = "Epic",
        Price = 2500,
        Weight = 50,
        AnimationId = "rbxassetid://89494237526043",
        BodyPart = "Back",
    },
    ["Vampiric Wings"] = {
        Name = "Vampiric Wings",
        Model = CosmeticsFolder:WaitForChild("Vampiric Wings"),
        Rarity = "Legendary",
        Price = 2500,
        Weight = 10,
        AnimationId = nil,
        BodyPart = "Back",
    },
    ["Purple Wings"] = {
        Name = "Purple Wings",
        Model = CosmeticsFolder:WaitForChild("Purple Wings"),
        Rarity = "Legendary",
        Price = 2500,
        Weight = 10,
        AnimationId = "rbxassetid://94751515839319",
        BodyPart = "Back",
    }
}

------------------//FUNCTIONS
function CosmeticsModule.GetItemViewport(itemName)
    local itemData = CosmeticsModule.Items[itemName]
    if not itemData then
        warn("CosmeticsModule: Item not found - " .. tostring(itemName))
        return nil
    end

    local viewport = Instance.new("ViewportFrame")
    viewport.BackgroundTransparency = 1
    viewport.Size = UDim2.fromScale(1, 1)
    viewport.Name = "Viewport_" .. itemName

    local modelClone = itemData.Model:Clone()
    local cf, size = modelClone:GetBoundingBox()

    modelClone:PivotTo(CFrame.new(Vector3.new(0,0,0)) * cf.Rotation)
    modelClone.Parent = viewport

    local camera = Instance.new("Camera")
    viewport.CurrentCamera = camera
    camera.Parent = viewport
    camera.FieldOfView = 25

    local newCf, newSize = modelClone:GetBoundingBox()
    local maxDimension = math.max(newSize.X, newSize.Y, newSize.Z)
    local fitDistance = (maxDimension / 2) / math.tan(math.rad(camera.FieldOfView) / 2)
    local finalDistance = fitDistance * 1.7
    local cameraDirection = Vector3.new(1, 0.5, 2).Unit
    local cameraPosition = newCf.Position + (cameraDirection * finalDistance)

    camera.CFrame = CFrame.new(cameraPosition, newCf.Position)
    return viewport
end

------------------//INIT
return CosmeticsModule
