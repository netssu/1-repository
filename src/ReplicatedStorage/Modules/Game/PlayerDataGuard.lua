--!strict

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager: any = require(ReplicatedStorage.Packages.PlayerDataManager)

local PlayerDataGuard = {}

local WARN_COOLDOWN_SECONDS: number = 5
local DEFAULT_RETRY_DELAY: number = 1

local LastWarnAt: {[string]: number} = {}

export type DisconnectHandle = {
	Disconnect: (self: DisconnectHandle) -> (),
}

export type ConnectOptions = {
	RetryDelay: number?,
	MaxAttempts: number?,
	OnConnected: (() -> ())?,
}

local function PathToString(Path: {string | number}): string
	local Parts: {string} = table.create(#Path)
	for Index, Key in ipairs(Path) do
		Parts[Index] = tostring(Key)
	end
	return table.concat(Parts, "/")
end

local function GetPlayerName(Player: Player?): string
	if Player then
		return Player.Name
	end
	return "UnknownPlayer"
end

local function WarnThrottled(MethodName: string, Player: Player?, Path: {string | number}, Message: any): ()
	local PathString: string = PathToString(Path)
	local WarnKey: string = MethodName .. ":" .. GetPlayerName(Player) .. ":" .. PathString
	local Now: number = os.clock()
	local LastWarn: number? = LastWarnAt[WarnKey]
	if LastWarn and Now - LastWarn < WARN_COOLDOWN_SECONDS then
		return
	end
	LastWarnAt[WarnKey] = Now
	warn(`[PlayerDataGuard] {MethodName} failed for {GetPlayerName(Player)} at "{PathString}": {tostring(Message)}`)
end

function PlayerDataGuard.GetOrDefault(Player: Player, Path: {string | number}, DefaultValue: any): (any, boolean)
	local Success: boolean, Result: any = pcall(function()
		return PlayerDataManager:Get(Player, Path)
	end)
	if Success then
		if Result == nil then
			return DefaultValue, true
		end
		return Result, true
	end
	WarnThrottled("Get", Player, Path, Result)
	return DefaultValue, false
end

function PlayerDataGuard.GetValueChangedSignal(Player: Player, Path: {string | number}): (any?, boolean)
	local Success: boolean, Result: any = pcall(function()
		return PlayerDataManager:GetValueChangedSignal(Player, Path)
	end)
	if Success then
		return Result, true
	end
	WarnThrottled("GetValueChangedSignal", Player, Path, Result)
	return nil, false
end

function PlayerDataGuard.ConnectValueChanged(
	Player: Player,
	Path: {string | number},
	Callback: (...any) -> (),
	Options: ConnectOptions?
): DisconnectHandle
	local RetryDelay: number = if Options and typeof(Options.RetryDelay) == "number"
		then math.max(Options.RetryDelay, 0.1)
		else DEFAULT_RETRY_DELAY
	local MaxAttempts: number? = if Options and typeof(Options.MaxAttempts) == "number"
		then math.max(1, math.floor(Options.MaxAttempts))
		else nil

	local Active: boolean = true
	local AttemptCount: number = 0
	local BoundConnection: any = nil

	task.spawn(function()
		while Active do
			if Player.Parent == nil then
				return
			end

			local Signal: any?, Success: boolean = PlayerDataGuard.GetValueChangedSignal(Player, Path)
			if Success and Signal then
				local ConnectSuccess: boolean, ConnectionOrError: any = pcall(function()
					return Signal:Connect(Callback)
				end)
				if ConnectSuccess and ConnectionOrError then
					BoundConnection = ConnectionOrError
					if Options and Options.OnConnected then
						task.spawn(Options.OnConnected)
					end
					return
				end
				WarnThrottled("ConnectValueChanged", Player, Path, ConnectionOrError)
			end

			AttemptCount += 1
			if MaxAttempts and AttemptCount >= MaxAttempts then
				return
			end

			task.wait(RetryDelay)
		end
	end)

	local Handle = {} :: DisconnectHandle
	function Handle:Disconnect(): ()
		Active = false
		if BoundConnection then
			BoundConnection:Disconnect()
			BoundConnection = nil
		end
	end

	return Handle
end

return PlayerDataGuard
