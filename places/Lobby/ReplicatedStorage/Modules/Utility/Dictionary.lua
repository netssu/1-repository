------------------//SERVICES

------------------//VARIABLES
local dictionary = {}

------------------//FUNCTIONS
local function split_path(path: string): { string }
	local parts: { string } = {}
	for part in string.gmatch(path, "[^%.]+") do
		parts[#parts + 1] = part
	end
	return parts
end

------------------//MAIN FUNCTIONS
function dictionary.get_by_path(root: any, path: string?): any
	if not path or path == "" then
		return root
	end

	local current = root
	for _, key in split_path(path) do
		if type(current) ~= "table" then
			return nil
		end
		current = current[key]
		if current == nil then
			return nil
		end
	end
	return current
end

function dictionary.set_by_path(root: any, path: string, value: any): ()
	local current = root
	local parts = split_path(path)
	for index, key in parts do
		if index < #parts then
			if type(current[key]) ~= "table" then
				current[key] = {}
			end
			current = current[key]
		else
			current[key] = value
		end
	end
end

------------------//INIT
return dictionary
