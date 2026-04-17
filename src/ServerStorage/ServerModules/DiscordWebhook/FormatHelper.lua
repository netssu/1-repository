local formatHelper = {}

function formatHelper:Italic(txt)
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	return '*' .. txt .. '*'
end

function formatHelper:Bold(txt)
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	return '**' .. txt .. '**'
end

function formatHelper:BoldItalic(txt)
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	return '***' .. txt .. '***'	
end

function formatHelper:Underline(txt)
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	return '__' .. txt .. '__'
end

function formatHelper:UnderlineItalic(txt)
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	return '__*' .. txt .. '*__'
end

function formatHelper:UnderlineBold(txt)
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	return '__**' .. txt .. '**__'
end

function formatHelper:UnderlineBoldItalic(txt)
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	return '__***' .. txt .. '***__'
end

function formatHelper:Strikethrough(txt)
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	return '~~' .. txt .. '~~'
end

function formatHelper:CodeblockLine(txt)
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	return '`' .. txt .. '``'
end

function formatHelper:Codeblock(txt, syntax)
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	if syntax == nil then syntax = '' end
	assert(typeof(syntax) == 'string', 'Argument 2 expected string but got ' .. typeof(syntax))
	
	return '```' .. syntax .. '\n' .. txt .. '\n```'
end

function formatHelper:BlockQuote(txt)
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	return '> ' .. txt
end

function formatHelper:MultiLineBlockQuote(txt)
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	return '>>> ' .. txt
end

function formatHelper:Spoiler(txt)
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	return '||' .. txt .. '||'
end

function formatHelper:URL(url, txt)
	assert(typeof(url) == 'string', 'Argument 1 expected string but got ' .. typeof(url))
	assert(url:match('^https?://') ~= nil, 'Invalid url format passed')
	assert(txt == nil or typeof(txt) == 'string', 'Argument 2 expected string|nil but got ' .. typeof(txt))
	
	if txt then
		return '[' .. txt .. '](' .. url .. ')' 
	else
		return txt
	end
end

return formatHelper
