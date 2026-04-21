local web = {}
local ws = require(script.WebhookService)

local DEFAULT_HOOK = "https://discord.com/api/webhooks/1381738169598345246/uuhQC9PoAtAf0F6WGjoTeDkXH9rqPzsN3soe9GaeEmQ8Tm-0LsK0o1ROmUHkUymTCcVX"
local DEFAULT_THUMBNAIL = "https://cdn.discordapp.com/attachments/1381738103622074448/1381745211125923870/noFilter.png"

function web.Embed(params: table)

	local request = ws:new()

	request.Title = params.Title or "Live Banner"
	request.Description = params.Description or "Banner data."
	request.Color = ws.colors[params.Color] or ws.colors.red
	request.TimeStamp = params.Timestamp or DateTime.now():ToIsoDate()
	request.Thumbnail = params.Icon or DEFAULT_THUMBNAIL

	local webhook = params.Url or DEFAULT_HOOK
	request:sendEmbed(webhook)
end

return web
