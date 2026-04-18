--!strict

local PlayersService: Players = game:GetService("Players")

local LobbyAvatars = {}

local APPLIED_USER_ID_ATTR: string = "LobbyAvatarUserId"
local DEFAULT_PLAYER_NAME: string = "Unknown"
local DEFAULT_THUMBNAIL: string = ""
local MODEL_REF_KEYS: {string} = {
	"player",
	"Player",
	"playerName",
	"username",
	"userid",
	"UserId",
	"UserID",
	"Username",
	"UserName",
	"PlayerName",
	"Owner",
	"OwnerId",
	"OwnerName",
}

local NameCache: {[number]: string} = {}
local ThumbnailCache: {[number]: string} = {}
local DescriptionCache: {[number]: HumanoidDescription} = {}
local UserIdCache: {[string]: number} = {}
local InvalidUserRefCache: {[string]: boolean} = {}

local function NormalizeUserId(Value: any): number?
	if typeof(Value) ~= "number" then
		return nil
	end

	local UserId: number = math.floor(Value)
	if UserId <= 0 then
		return nil
	end

	return UserId
end

local function ResolveHumanoid(ModelInstance: Model): Humanoid?
	local DirectHumanoid: Humanoid? = ModelInstance:FindFirstChildOfClass("Humanoid")
	if DirectHumanoid then
		return DirectHumanoid
	end

	local DescendantHumanoid: Instance? = ModelInstance:FindFirstChildWhichIsA("Humanoid", true)
	if DescendantHumanoid and DescendantHumanoid:IsA("Humanoid") then
		return DescendantHumanoid
	end

	return nil
end

local function ResolveChildUserId(Child: Instance): number?
	if Child:IsA("StringValue") then
		return LobbyAvatars.ResolveUserId(Child.Value)
	end
	if Child:IsA("IntValue") or Child:IsA("NumberValue") then
		return LobbyAvatars.ResolveUserId(Child.Value)
	end
	if Child:IsA("ObjectValue") then
		local PlayerValue: Instance? = Child.Value
		if PlayerValue and PlayerValue:IsA("Player") then
			return PlayerValue.UserId
		end
	end

	return nil
end

local function GetHumanoidDescription(UserId: number): HumanoidDescription?
	local CachedDescription: HumanoidDescription? = DescriptionCache[UserId]
	if CachedDescription then
		return CachedDescription:Clone()
	end

	local Success: boolean, Result: any = pcall(PlayersService.GetHumanoidDescriptionFromUserId, PlayersService, UserId)
	if not Success or not Result or not Result:IsA("HumanoidDescription") then
		return nil
	end

	DescriptionCache[UserId] = Result
	return Result:Clone()
end

function LobbyAvatars.ResolveUserId(Value: any): number?
	local NumericUserId: number? = NormalizeUserId(Value)
	if NumericUserId then
		return NumericUserId
	end

	if typeof(Value) ~= "string" then
		return nil
	end

	local ParsedUserId: number? = NormalizeUserId(tonumber(Value))
	if ParsedUserId then
		return ParsedUserId
	end

	local CacheKey: string = string.lower(Value)
	if InvalidUserRefCache[CacheKey] == true then
		return nil
	end

	local CachedUserId: number? = UserIdCache[CacheKey]
	if CachedUserId then
		return CachedUserId
	end

	local Success: boolean, Result: any = pcall(PlayersService.GetUserIdFromNameAsync, PlayersService, Value)
	if not Success then
		InvalidUserRefCache[CacheKey] = true
		return nil
	end

	local UserId: number? = NormalizeUserId(Result)
	if not UserId then
		InvalidUserRefCache[CacheKey] = true
		return nil
	end

	UserIdCache[CacheKey] = UserId
	return UserId
end

function LobbyAvatars.ResolveModelUserId(ModelInstance: Model): number?
	for _, Key in MODEL_REF_KEYS do
		local UserId: number? = LobbyAvatars.ResolveUserId(ModelInstance:GetAttribute(Key))
		if UserId then
			return UserId
		end
	end

	for _, Key in MODEL_REF_KEYS do
		local Child: Instance? = ModelInstance:FindFirstChild(Key)
		if Child then
			local UserId: number? = ResolveChildUserId(Child)
			if UserId then
				return UserId
			end
		end

		local Descendant: Instance? = ModelInstance:FindFirstChild(Key, true)
		if Descendant then
			local UserId: number? = ResolveChildUserId(Descendant)
			if UserId then
				return UserId
			end
		end
	end

	return LobbyAvatars.ResolveUserId(ModelInstance.Name)
end

function LobbyAvatars.GetUserName(UserId: number): string
	local NormalizedUserId: number? = NormalizeUserId(UserId)
	if not NormalizedUserId then
		return DEFAULT_PLAYER_NAME
	end

	local CachedName: string? = NameCache[NormalizedUserId]
	if CachedName then
		return CachedName
	end

	local Success: boolean, Result: any = pcall(PlayersService.GetNameFromUserIdAsync, PlayersService, NormalizedUserId)
	if not Success or typeof(Result) ~= "string" or Result == "" then
		local FallbackName: string = DEFAULT_PLAYER_NAME .. " " .. tostring(NormalizedUserId)
		NameCache[NormalizedUserId] = FallbackName
		return FallbackName
	end

	NameCache[NormalizedUserId] = Result
	UserIdCache[string.lower(Result)] = NormalizedUserId
	return Result
end

function LobbyAvatars.GetThumbnail(UserId: number): string
	local NormalizedUserId: number? = NormalizeUserId(UserId)
	if not NormalizedUserId then
		return DEFAULT_THUMBNAIL
	end

	local CachedThumbnail: string? = ThumbnailCache[NormalizedUserId]
	if CachedThumbnail then
		return CachedThumbnail
	end

	local Success: boolean, ImageContent: any = pcall(
		PlayersService.GetUserThumbnailAsync,
		PlayersService,
		NormalizedUserId,
		Enum.ThumbnailType.HeadShot,
		Enum.ThumbnailSize.Size420x420
	)
	if not Success or typeof(ImageContent) ~= "string" then
		return DEFAULT_THUMBNAIL
	end

	ThumbnailCache[NormalizedUserId] = ImageContent
	return ImageContent
end

function LobbyAvatars.ApplyUser(ModelInstance: Model, UserId: number): boolean
	local NormalizedUserId: number? = NormalizeUserId(UserId)
	if not NormalizedUserId then
		return false
	end

	local HumanoidInstance: Humanoid? = ResolveHumanoid(ModelInstance)
	if not HumanoidInstance then
		return false
	end

	local AppliedUserId: any = ModelInstance:GetAttribute(APPLIED_USER_ID_ATTR)
	if typeof(AppliedUserId) == "number" and math.floor(AppliedUserId) == NormalizedUserId then
		return true
	end

	local Description: HumanoidDescription? = GetHumanoidDescription(NormalizedUserId)
	if not Description then
		return false
	end

	local ResetSuccess: boolean, ResetError: any = pcall(HumanoidInstance.ApplyDescriptionReset, HumanoidInstance, Description)
	if not ResetSuccess then
		local RetryDescription: HumanoidDescription = Description:Clone()
		local ApplySuccess: boolean, ApplyError: any = pcall(HumanoidInstance.ApplyDescription, HumanoidInstance, RetryDescription)
		if not ApplySuccess then
			warn(
				string.format(
					"LobbyAvatars failed to apply appearance for %s (%d): %s / %s",
					ModelInstance:GetFullName(),
					NormalizedUserId,
					tostring(ResetError),
					tostring(ApplyError)
				)
			)
			return false
		end
	end

	ModelInstance:SetAttribute(APPLIED_USER_ID_ATTR, NormalizedUserId)
	return true
end

return LobbyAvatars
