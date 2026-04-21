local module = {}

function module.factorial(n)
	local n2 = n
	for i = 1,n do
		if n-i ~= 0 then
			n2 = n2 * (n-i)
		end
	end
	return n2
end
function module.tostandard(n)
	local dec = ""
	local places = ""
	local record = "dec"
	for i in string.gmatch(n,".") do
		if i == "e" then
			record = "none"
		end
		if record == "dec" then
			dec = dec .. i
		end
		if record == "place" then
			places = places .. i
		end
		if i == "+" then
			record = "place"
		end
	end
	for i = 1,tonumber(places) do
		dec = dec .. "0"
	end
	local dec2 = ""
	for i in string.gmatch(dec,"%d") do
		dec2 = dec2 .. i
	end
	return dec2
end
function module.ShortenNum(Number)
	local Len = 0
	local Num = ""
	local SNum = Number
	for i in string.gmatch(Number,"%d") do
		Num = Num .. i
	end
	local Len = string.len(Num)
	local function Dec()
		local S = (math.ceil(Len/3)) - 1
		local S2 = S*3
		local SN = ""
		local Record = true
		local i = 0
		for v in string.gmatch(string.reverse(Num),"%d") do
			i = i + 1
			if i <= S2 then
				Record = true
			else
				Record = false
			end
			if Record then
				SN = SN .. v
			end
		end
		return string.sub(string.reverse(SN),1,1)
	end
	if Len == 4 or Len == 5 or Len == 6 then
		SNum = string.sub(Num,1,-4) ..".".. Dec() .."K"
	elseif Len == 7 or Len == 8 or Len == 9 then
		SNum = string.sub(Num,1,-7) ..".".. Dec() .."M"
	elseif Len == 10 or Len == 11 or Len == 12 then
		SNum = string.sub(Num,1,-10) ..".".. Dec() .."B"
	elseif Len == 13 or Len == 14 or Len == 15 then
		SNum = string.sub(Num,1,-13) ..".".. Dec() .."T"
	elseif Len == 16 or Len == 17 or Len == 18 then
		SNum = string.sub(Num,1,-16) ..".".. Dec() .."Qd"
	elseif Len == 19 or Len == 20 or Len == 21 then
		SNum = string.sub(Num,1,-19) ..".".. Dec() .."Qn"
	elseif Len == 22 or Len == 23 or Len == 24 then
		SNum = string.sub(Num,1,-22) ..".".. Dec() .."Sx"
	elseif Len == 25 or Len == 26 or Len == 27 then
		SNum = string.sub(Num,1,-25) ..".".. Dec() .."Sp"
	elseif Len == 28 or Len == 29 or Len == 30 then
		SNum = string.sub(Num,1,-28) ..".".. Dec() .."O"
	elseif Len == 31 or Len == 32 or Len == 33 then
		SNum = string.sub(Num,1,-31) ..".".. Dec() .."N"
	elseif Len == 34 or Len == 35 or Len >= 36 then
		SNum = string.sub(Num,1,-34) ..".".. Dec() .."D"
	end
	return SNum
end
function module.InsertCommas(Number)
	local Decimal = false
	for Char in string.gmatch(Number,".") do
		if Char == "." then
			Decimal = true
		end
	end
	local Count1 = 0
	local Count2 = 0
	local Text = ""
	local Record = false
	if Decimal then
		Record = false
	end
	for Char in string.gmatch(string.reverse(Number),".") do
		Text = Text .. Char
		Count1 = Count1 + 1
		if not Decimal and not Record then
			Record = true
		end
		if Record then
			Count2 = Count2 + 1
			if Count2 >= 3 then
				Count2 = 0
				if Count1 ~= string.len(Number) then
					Text = Text ..","
				end
			end
		end
		if Decimal and not Record then
			if Char == "." then
				Record = true
			end
		end
	end
	return string.reverse(Text)
end
function fib(n)
	if n == 1 or n == 0 then
		return n
	else
		return fib(n-1) + fib(n-2)
	end
end
function module.fib(n)
	--0, 1, 1, 2, 3, 5, 8, 13, 21, 34, ...
	return fib(n-1)
end

return module