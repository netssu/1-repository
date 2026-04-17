local TextService = game:GetService("TextService")
local xorKey = 88
local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local WordList = require(script.WordList)

local module = {}

function module.encryptWord(word)
	local bytes = {}
	for i = 1, #word do
		local char = string.byte(word, i)
		local xor = bit32.bxor(char, xorKey)
		table.insert(bytes, xor)
	end
	local encoded = ""
	for _, byte in ipairs(bytes) do
		local hi = math.floor(byte / 64) + 1
		local lo = (byte % 64) + 1
		encoded = encoded .. b64chars:sub(hi, hi) .. b64chars:sub(lo, lo)
	end
	return encoded
end

function module.decryptWord(encoded)
	local bytes = {}
	for i = 1, #encoded, 2 do
		local hiChar = encoded:sub(i, i)
		local loChar = encoded:sub(i + 1, i + 1)
		local hi = b64chars:find(hiChar) - 1
		local lo = b64chars:find(loChar) - 1
		local byte = (hi * 64) + lo
		local original = bit32.bxor(byte, xorKey)
		table.insert(bytes, string.char(original))
	end
	return table.concat(bytes)
end

--local encrypted = module.encryptWord("FUCK")
--local decrypted = module.decryptWord(encrypted)

--print("Encrypted:", encrypted)
--print("Decrypted:", decrypted)



function module.checkIfFilteredAsync(str, UserId)
	local isBanned = false
	
	for i,v in WordList.Banned do
		if string.find(str, module.decryptWord(v)) then
			return true
		end
	end

	-- use roblox to check if filtered
	local originalInput = str

	local s, e = pcall(function()
		str = TextService:FilterStringAsync(str, UserId):GetNonChatStringForBroadcastAsync()
	end)

	if not s then warn(e) end
	if not s or str ~= originalInput then -- it got filtered or unknown error
		return true
	end
end

return module