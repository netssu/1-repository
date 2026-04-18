--!strict

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Modules.Data.RaritiesData)

type RarityData = {
	Name: string,
	Color: Color3,
	Weight: number,
}

type PendingFlowEntry = {
	Id: string,
	Name: string,
	Description: string,
	Rarity: RarityData,
	Score: number,
	ExplicitPercentage: number?,
	AuraModelName: string,
	AnimationId: string,
}

export type FlowData = {
	Name: string,
	Description: string,
	Rarity: RarityData,
	Weight: number,
	Percentage: number,
	AuraModelName: string,
	AnimationId: string,
}

local DEFAULT_ANIMATION_ID: string = "rbxassetid://134076888722710"
local DEFAULT_RARITY_PERCENTAGES: {[string]: number} = {
	Common = 42,
	Uncommon = 28,
	Rare = 18,
	Epic = 9,
	Legendary = 3,
}

local FALLBACK_AURAS: {PendingFlowEntry} = {
	{
		Id = "GalaxyAura",
		Name = "Galaxy Aura",
		Description = "Cosmic energy flows around the user",
		Rarity = Rarities.Legendary,
		Score = DEFAULT_RARITY_PERCENTAGES.Legendary,
		ExplicitPercentage = nil,
		AuraModelName = "GalaxyAura",
		AnimationId = DEFAULT_ANIMATION_ID,
	},
	{
		Id = "WarriorAura",
		Name = "Warrior Aura",
		Description = "An aura forged through endless battles",
		Rarity = Rarities.Rare,
		Score = DEFAULT_RARITY_PERCENTAGES.Rare,
		ExplicitPercentage = nil,
		AuraModelName = "WarriorAura",
		AnimationId = DEFAULT_ANIMATION_ID,
	},
	{
		Id = "DarkMatter",
		Name = "Dark Matter",
		Description = "Pure darkness condensed into energy",
		Rarity = Rarities.Epic,
		Score = DEFAULT_RARITY_PERCENTAGES.Epic,
		ExplicitPercentage = nil,
		AuraModelName = "DarkMatter",
		AnimationId = DEFAULT_ANIMATION_ID,
	},
	{
		Id = "PhantomAura",
		Name = "Phantom Aura",
		Description = "A mysterious aura from another realm",
		Rarity = Rarities.Epic,
		Score = DEFAULT_RARITY_PERCENTAGES.Epic,
		ExplicitPercentage = nil,
		AuraModelName = "PhantomAura",
		AnimationId = DEFAULT_ANIMATION_ID,
	},
	{
		Id = "MegaAura",
		Name = "Mega Aura",
		Description = "A simple yet powerful energy flow",
		Rarity = Rarities.Common,
		Score = DEFAULT_RARITY_PERCENTAGES.Common,
		ExplicitPercentage = nil,
		AuraModelName = "MegaAura",
		AnimationId = DEFAULT_ANIMATION_ID,
	},
}

local function NormalizeName(Name: string): string
	return string.lower(string.gsub(Name, "[%s_%-%.]", ""))
end

local function HumanizeName(Id: string): string
	local Value: string = string.gsub(Id, "([a-z0-9])([A-Z])", "%1 %2")
	Value = string.gsub(Value, "[_%-%./]+", " ")
	Value = string.gsub(Value, "%s+", " ")
	Value = string.gsub(Value, "^%s+", "")
	Value = string.gsub(Value, "%s+$", "")
	if Value == "" then
		return Id
	end
	return Value
end

local function ResolveRarityData(RarityName: any): RarityData
	if typeof(RarityName) == "string" and RarityName ~= "" then
		local DirectMatch: any = (Rarities :: any)[RarityName]
		if type(DirectMatch) == "table" and type(DirectMatch.Name) == "string" then
			return DirectMatch :: RarityData
		end

		local NormalizedTarget: string = NormalizeName(RarityName)
		for _, RarityDataItem: any in pairs(Rarities) do
			if type(RarityDataItem) == "table"
				and type(RarityDataItem.Name) == "string"
				and NormalizeName(RarityDataItem.Name) == NormalizedTarget
			then
				return RarityDataItem :: RarityData
			end
		end
	end

	return Rarities.Common
end

local function ResolveAurasFolder(): Instance?
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	local EffectsFolder: Instance? = AssetsFolder and AssetsFolder:FindFirstChild("Effects") or nil
	if not EffectsFolder then
		return nil
	end
	return EffectsFolder:FindFirstChild("Auras")
end

local function NormalizeAnimationId(Value: any): string?
	if typeof(Value) == "number" then
		Value = tostring(math.floor(Value + 0.5))
	end
	if typeof(Value) ~= "string" then
		return nil
	end

	local TrimmedValue: string = string.gsub(string.gsub(Value, "^%s+", ""), "%s+$", "")
	if TrimmedValue == "" then
		return ""
	end

	if string.sub(TrimmedValue, 1, #"rbxassetid://") == "rbxassetid://" then
		return TrimmedValue
	end

	if string.match(TrimmedValue, "^%d+$") then
		return "rbxassetid://" .. TrimmedValue
	end

	return TrimmedValue
end

local function BuildFlowDataMap(Entries: {PendingFlowEntry}): {[string]: FlowData}?
	if #Entries == 0 then
		return nil
	end

	local ExplicitTotal: number = 0
	local MissingScoreTotal: number = 0
	for _, Entry: PendingFlowEntry in Entries do
		if type(Entry.ExplicitPercentage) == "number" and Entry.ExplicitPercentage > 0 then
			ExplicitTotal += Entry.ExplicitPercentage
		else
			MissingScoreTotal += math.max(Entry.Score, 0)
		end
	end

	local ExplicitScale: number = 1
	local RemainingPercentage: number = 100
	if ExplicitTotal > 100 then
		ExplicitScale = 100 / ExplicitTotal
		RemainingPercentage = 0
	elseif ExplicitTotal > 0 and MissingScoreTotal <= 0 then
		ExplicitScale = 100 / ExplicitTotal
		RemainingPercentage = 0
	else
		RemainingPercentage = math.max(0, 100 - ExplicitTotal)
	end

	if RemainingPercentage > 0 and MissingScoreTotal <= 0 then
		MissingScoreTotal = 0
		for _, Entry: PendingFlowEntry in Entries do
			if type(Entry.ExplicitPercentage) ~= "number" or Entry.ExplicitPercentage <= 0 then
				MissingScoreTotal += 1
			end
		end
	end

	local Data: {[string]: FlowData} = {}
	for _, Entry: PendingFlowEntry in Entries do
		local Percentage: number
		if type(Entry.ExplicitPercentage) == "number" and Entry.ExplicitPercentage > 0 then
			Percentage = Entry.ExplicitPercentage * ExplicitScale
		else
			local ResolvedScore: number = math.max(Entry.Score, 0)
			if ResolvedScore <= 0 then
				ResolvedScore = 1
			end
			if MissingScoreTotal <= 0 then
				Percentage = 0
			else
				Percentage = (ResolvedScore / MissingScoreTotal) * RemainingPercentage
			end
		end
		Data[Entry.Id] = {
			Name = Entry.Name,
			Description = Entry.Description,
			Rarity = Entry.Rarity,
			Weight = Percentage,
			Percentage = Percentage,
			AuraModelName = Entry.AuraModelName,
			AnimationId = Entry.AnimationId,
		}
	end

	return Data
end

local function BuildDynamicFlowsData(): {[string]: FlowData}?
	local AurasFolder: Instance? = ResolveAurasFolder()
	if not AurasFolder then
		return nil
	end

	local Entries: {PendingFlowEntry} = {}
	for _, AuraTemplate: Instance in ipairs(AurasFolder:GetChildren()) do
		if not AuraTemplate:IsA("Model") and not AuraTemplate:IsA("Folder") and not AuraTemplate:IsA("BasePart") then
			continue
		end

		local RarityData: RarityData = ResolveRarityData(AuraTemplate:GetAttribute("Rarity"))
		local PercentageAttribute: any = AuraTemplate:GetAttribute("Percentage")
		local Score: number
		local ExplicitPercentage: number? = nil
		if typeof(PercentageAttribute) == "number" and PercentageAttribute > 0 then
			Score = PercentageAttribute
			ExplicitPercentage = PercentageAttribute
		else
			Score = DEFAULT_RARITY_PERCENTAGES[RarityData.Name] or RarityData.Weight or 1
		end

		local Id: string = AuraTemplate.Name
		table.insert(Entries, {
			Id = Id,
			Name = HumanizeName(Id),
			Description = HumanizeName(Id) .. " aura",
			Rarity = RarityData,
			Score = Score,
			ExplicitPercentage = ExplicitPercentage,
			AuraModelName = Id,
			AnimationId = NormalizeAnimationId(AuraTemplate:GetAttribute("AnimationId")) or DEFAULT_ANIMATION_ID,
		})
	end

	return BuildFlowDataMap(Entries)
end

local FlowsData: {[string]: FlowData} = BuildDynamicFlowsData() or (BuildFlowDataMap(FALLBACK_AURAS) or {})

return FlowsData
