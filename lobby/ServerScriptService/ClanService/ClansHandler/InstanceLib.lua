local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

function module.DeepLoadDataToInstances(data, parentTo)
	local BasicValues = {
		["number"] = "NumberValue",
		["boolean"] = "BoolValue",
		["string"] = "StringValue"
	}

	for index, element in data do
		if BasicValues[typeof(element)] ~= nil then
			local numberVal = Instance.new(BasicValues[typeof(element)])
			numberVal.Name = index
			numberVal.Value = element
			numberVal.Parent = parentTo
		elseif typeof(element) == "table" then
			local folder = Instance.new("Folder")
			folder.Name = index
			folder.Parent = parentTo
			
			module.DeepLoadDataToInstances(element, folder)
		end
	end
end

local function isArray(tbl)
	local i = 0
	for _ in pairs(tbl) do
		i += 1
		if tbl[i] == nil then return false end
	end
	return true
end

function module.ReconcileInstancesWithData(data: table, parent: Instance)

	local BasicValues = {
		["number"] = "NumberValue",
		["boolean"] = "BoolValue",
		["string"] = "StringValue"
	}

	local keysInData = {}

	for index, value in data do
		keysInData[index] = true
		local existing = parent:FindFirstChild(index)
		local valueType = typeof(value)

		if BasicValues[valueType] then
			if existing and existing:IsA(BasicValues[valueType]) then
				if existing.Value ~= value then
					existing.Value = value
				end
			else
				if existing then existing:Destroy() end
				local newVal = Instance.new(BasicValues[valueType])
				newVal.Name = index
				newVal.Value = value
				newVal.Parent = parent
			end
		elseif valueType == "table" then
			if not existing or not existing:IsA("Folder") then
				if existing then existing:Destroy() end
				existing = Instance.new("Folder")
				existing.Name = index
				existing.Parent = parent
			end

			if isArray(value) then
				local childKeys = {}
				for i, v in ipairs(value) do
					childKeys[tostring(i)] = true
					local child = existing:FindFirstChild(tostring(i))

					if typeof(v) == "string" or typeof(v) == "number" or typeof(v) == "boolean" then
						if not child or not child:IsA(BasicValues[typeof(v)]) then
							if child then child:Destroy() end
							child = Instance.new(BasicValues[typeof(v)])
							child.Name = tostring(i)
							child.Parent = existing
						end
						child.Value = v
					elseif typeof(v) == "table" then
						if not child or not child:IsA("Folder") then
							if child then child:Destroy() end
							child = Instance.new("Folder")
							child.Name = tostring(i)
							child.Parent = existing
						end
						module.ReconcileInstancesWithData(v, child)
					else
						warn("Unhandled value type in array:", typeof(v))
					end
				end

				for _, child in existing:GetChildren() do
					if not childKeys[child.Name] then
						child:Destroy()
					end
				end
			else
				module.ReconcileInstancesWithData(value, existing)
			end
		end
	end

	for _, child in parent:GetChildren() do
		if not keysInData[child.Name] then
			child:Destroy()
		end
	end
	
	if parent.Parent == ReplicatedStorage.Clans then
		if not parent:FindFirstChild('DataLoaded') then
			Instance.new('Folder', parent).Name = 'Loaded'
		end
	end 
end


return module