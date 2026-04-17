local CachedButtons : { [GuiButton] : () -> () } = {}
local X_CloseHandler = {}
--
function X_CloseHandler.work( X_CloseInfo : { Button : GuiButton , Callback : () -> ()? } )
	local Button = X_CloseInfo.Button
	local AlreadyExisted = CachedButtons[Button]
	CachedButtons[Button] = X_CloseInfo.Callback
	if AlreadyExisted then
		return
	end
	if not Button.Active then
		warn( Button , 'was not set to active' )
		Button.Active = true
	end
	Button.Activated:Connect(function()
		_G.CloseAll()
		local Callback : () -> ()? = CachedButtons[Button]
		if Callback then
			Callback()
		end
	end)
end
--
return X_CloseHandler