local Alphabet = {"a", "b", "c", "d", "e", "f", "g", "h", "i","j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"}

local GlobalFunctions = {}

function GlobalFunctions.CopyDictionary(Table)
	--Create a completely separate table so that the path arent connected
	local newTable = {}
	for index, element in Table do
		if typeof(element) == "table" then
			newTable[index] = GlobalFunctions.CopyDictionary(element)
		else
			newTable[index] = element
		end
	end

	return newTable
end

function GlobalFunctions.GenerateID()
	local newId = ""
	for i = 1, 10 do
		local newValue
		if math.random(1,2) == 1 then	--take a number
			newValue = math.random(0,9)
		else --take a letter
			newValue = Alphabet[ math.random(1,#Alphabet) ]
			if math.random(1,2) == 2 then --uppercase
				newValue = string.upper(newValue)
			end
		end
		newId = `{newId}{newValue}`
	end

	return newId

end
function GlobalFunctions.GetDictionaryIndexLength(dictionary, countTotalLayer)

	local count = 0
	local countedLayer = 0
	local function count(dict)
		countedLayer += 1
		local currentLayer = countTotalLayer
		for index,element in dictionary do
			if typeof(element) == "table" and (countTotalLayer and currentLayer < countTotalLayer ) then
				count(element)
			else
				count += 1
			end
		end

	end

	count(dictionary)

	return count

end

function GlobalFunctions.FindIndex(dict, findElement)
	for _, element in dict do
		if element == findElement then
			return element
		end
	end
	return nil
end

return GlobalFunctions
