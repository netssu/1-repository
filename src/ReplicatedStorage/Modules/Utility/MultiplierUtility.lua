local MultiplierUtility = {}

local states = {}

local function sanitize_number(value: any, defaultValue: number): number
	if type(value) ~= "number" then
		return defaultValue
	end
	if value ~= value then
		return defaultValue
	end
	return value
end

local function get_state(player: Player)
	local state = states[player.UserId]
	if state then
		return state
	end

	local current = sanitize_number(player:GetAttribute("Multiplier"), 1)
	if current < 1 then
		current = 1
	end

	state = {
		base = current,
		additives = {},
		factors = {},
	}

	states[player.UserId] = state
	return state
end

local function compute_factor_product(state): number
	local product = 1
	for _, factor in pairs(state.factors) do
		product *= factor
	end
	return math.max(0, product)
end

local function recalc(player: Player): number
	local state = get_state(player)

	local additive = 0
	for _, value in pairs(state.additives) do
		additive += value
	end

	local factorProduct = compute_factor_product(state)
	local final = math.max(1, (state.base + additive) * factorProduct)
	player:SetAttribute("Multiplier", final)
	return final
end

function MultiplierUtility.init(player: Player): number
	return recalc(player)
end

function MultiplierUtility.set_base(player: Player, baseValue: number): number
	local state = get_state(player)
	state.base = math.max(1, sanitize_number(baseValue, 1))
	return recalc(player)
end

function MultiplierUtility.get_base(player: Player): number
	local state = get_state(player)
	return state.base
end

function MultiplierUtility.set_additive(player: Player, key: string, value: number): number
	local state = get_state(player)
	state.additives[key] = sanitize_number(value, 0)
	return recalc(player)
end

function MultiplierUtility.get_additive(player: Player, key: string): number
	local state = get_state(player)
	return sanitize_number(state.additives[key], 0)
end

function MultiplierUtility.set_factor(player: Player, key: string, factor: number): number
	local state = get_state(player)
	state.factors[key] = math.max(0, sanitize_number(factor, 1))
	return recalc(player)
end

function MultiplierUtility.get_factor(player: Player, key: string): number
	local state = get_state(player)
	return sanitize_number(state.factors[key], 1)
end

function MultiplierUtility.get_factor_product(player: Player): number
	local state = get_state(player)
	return compute_factor_product(state)
end

function MultiplierUtility.get(player: Player): number
	return recalc(player)
end

function MultiplierUtility.clear(player: Player)
	states[player.UserId] = nil
end

return MultiplierUtility
