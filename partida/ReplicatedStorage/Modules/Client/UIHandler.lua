--[Services]--
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIHandler = {}
local Positions = {}


if game:GetService("RunService"):IsClient() then
	local Player = Players.LocalPlayer
	local PlayerGUI = Player.PlayerGui

	local GameGUI = PlayerGUI:WaitForChild("GameGui")
	local possibleExceptions = {
		--["SlotFrame"] = {
		--	["UI"] = GameGUI:WaitForChild("Slots"):WaitForChild("Slots"),
		--	["NewProperties"] = {
		--		["Position"] = UDim2.new(0.5, 0, 1.1, 0)
		--	},
		--	["OriginalProperties"] = {
		--		["Position"] = UDim2.new(0.5, 0,0.865, 0)
		--	}
		--},
		--["Currency"] = {
		--	["UI"] = GameGUI:WaitForChild("Slots"):WaitForChild("Currency"),
		--	["NewProperties"] = {
		--		["Position"] = UDim2.new(0.5, 0, 1.1, 0)
		--	},
		--	["OriginalProperties"] = {
		--		["Position"] = UDim2.new(0.5, 0,0.794, 0)
		--	}
		--},
		--["Level"] = {
		--	["UI"] = GameGUI:WaitForChild("Slots"):WaitForChild("Level"),
		--	["NewProperties"] = {
		--		["Position"] = UDim2.new(0.5, 0, 1.1, 0)
		--	},
		--	["OriginalProperties"] = {
		--		["Position"] = UDim2.new(0.5, 0,0.958, 0)
		--	}
		--},
		--["SummonFrame"] = {
		--	["UI"] = GameGUI:WaitForChild("Summon"):WaitForChild("SummonFrame"),
		--	["NewProperties"] = {
		--		["Position"] = UDim2.new(-1, 0, 0, 0)
		--	},
		--	["OriginalProperties"] = {
		--		["Position"] = UDim2.new(0, 0,0, 0)
		--	}
		--}
	}

	function UIHandler.CreateConfetti()
		coroutine.wrap(function()
			local CurrentCamera = game.Workspace.CurrentCamera;
			local Rand = Random.new();
			local Int = Rand:NextInteger(60, 120);
			local Amount = 0;
			while true do
				local NextNum = { Rand:NextNumber(-2, 2), Rand:NextNumber(0, 2.7), Rand:NextNumber() };
				local Confe = script.Confetti:Clone();
				Confe.Color = Color3.fromHSV(Rand:NextNumber(), 1, 1);
				Confe.CFrame = CurrentCamera.CFrame * CFrame.new(0, 1.5 + NextNum[2], -1);
				Confe.CastShadow = false;
				Confe.Parent = CurrentCamera;
				coroutine.wrap(function()
					local Clock = os.clock();
					local iron = Rand:NextNumber(4, 9);
					while true do
						local Clamp = math.clamp((os.clock() - Clock) / iron, 0.001, 1);
						Confe.CFrame = CurrentCamera.CFrame * CFrame.new(NextNum[1], 1.5 + NextNum[2] - Clamp * 10, -1) * CFrame.Angles(NextNum[3] * (Clamp * 125), 0, 0);
						game:GetService("RunService").RenderStepped:Wait();
						if Clamp >= 1 then
							break;
						end;
					end;
					Confe:Destroy();
				end)();
				if not (Amount < Int) then
					break;
				end;
				Amount = Amount + 1;
			end;
		end)();
	end

	local function createTransitionSquares(ParentFrame)

		local list = {}
		local indexCounter = 0
		local elementCounter = 1

		--Cloning the necessary squares ui
		for i = 1,400 do

			if i % 20 == 1  then
				indexCounter += 1
				elementCounter = 1
				list[indexCounter] = {}
				--list[indexCounter][elementCounter] = tostring(i)
			end

			local clone = script.Template:Clone()
			clone.LayoutOrder = i
			clone.Name = tostring(i)
			clone.Parent = ParentFrame
			list[indexCounter][elementCounter] = clone
			elementCounter += 1

		end

		--Adjusting the list for easy looping of animation
		local newList = {}
		for a = 1,20 do
			newList[a] = {}
			for b = 1,a do
				local copy1,copy2 = list[a][b],list[b][a]
				if copy1 ~= copy2 then
					table.insert(newList[a],copy1)
				end
				table.insert(newList[a],copy2)
			end


		end

		return newList
	end

	local function waitForSummon(_callback)
		task.spawn(function()
			repeat task.wait() until _G.canSummon
			_callback()
		end)
	end

	function UIHandler.PlaySound(Name  : string)
		local Found = script.Sounds:FindFirstChild(Name)
		if not Found then
			return
		end
		
		local Clone : Sound = Found:Clone() do
			Clone.Parent = workspace
			Clone:Play()
		end
		
		task.delay(Clone.TimeLength, function()
			Clone:Destroy()
		end)
		
	end
	
	function UIHandler.DisableAllButtons(exceptions)
		--task.spawn(function()
		--	local Player = Players.LocalPlayer
		--	local PlayerGUI = Player.PlayerGui
		--	task.wait(0.5)
		--	PlayerGUI.GameGui.EndScreen.VictoryFrame.Visible = false
		--end)
		
		--local GameGUI = PlayerGUI.GameGui
		--local SlotFrame = GameGUI.Slots.Slots
		--local InventoryFrame = GameGUI.Inventory.InventoryFrame
		--local ItemFrame = GameGUI.Items.ItemsFrame
		--Positions[SlotFrame.Name] = UDim2.new(0.5, 0,0.865, 0)  --SlotFrame.Position


		--for name,info in possibleExceptions do
		--	if exceptions and table.find(exceptions,name) then continue end
		--	for propertyName,newProperty in info.NewProperties do
		--		TweenService:Create(info.UI, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {[propertyName] = newProperty}):Play()
		--	end

		--end



		--TweenService:Create(InventoryFrame, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {AnchorPoint = Vector2.new(0,0)}):Play()
		--TweenService:Create(ItemFrame, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {AnchorPoint = Vector2.new(0,0)}):Play()

		--for i, v in GameGUI.Buttons:GetChildren() do
		--	if v:IsA("ImageButton") then
		--		Positions[v.Name] = v.Position
		--		if v.Name ~= "SettingsButton" then
		--			TweenService:Create(v, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {Position = UDim2.new(-0.1, 0, v.Position.Y.Scale, 0)}):Play()
		--		elseif v.Name == "SettingsButton" then
		--			TweenService:Create(v, TweenInfo.new(0.15, Enum.EasingStyle.Sine), {Position = UDim2.new(4.239, 0,1.228, 0)}):Play()
		--		end
		--	end
		--end
		--TweenService:Create(GameGUI.Buttons.Buttons,TweenInfo.new(0.15, Enum.EasingStyle.Sine), {AnchorPoint = Vector2.new(1,0.5)}):Play()
	end

	function UIHandler.EnableAllButtons()
		--if not _G.canSummon then
		--	waitForSummon(UIHandler.EnableAllButtons)
		--	return
		--end
		
		
		local Player = Players.LocalPlayer
		local PlayerGUI = Player.PlayerGui
		
		PlayerGUI.GameGui.EndScreen.VictoryFrame.Visible = true
		
		--local GameGUI = PlayerGUI.GameGui
		--local SlotFrame = GameGUI.Slots.Slots
		--local InventoryFrame = GameGUI.Inventory.InventoryFrame
		--local ItemFrame = GameGUI.Items.ItemsFrame

		--for name,info in possibleExceptions do
		--	--if exceptions and table.find(exceptions,name) then continue end
		--	for propertyName,newProperty in info.OriginalProperties do
		--		TweenService:Create(info.UI, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {[propertyName] = newProperty}):Play()
		--	end
		--end

		--TweenService:Create(InventoryFrame, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {AnchorPoint = Vector2.new(0,1)}):Play()
		--TweenService:Create(ItemFrame, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {AnchorPoint = Vector2.new(0,1)}):Play()
		----TweenService:Create(SlotFrame, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {Position = Positions[SlotFrame.Name]}):Play()
		----TweenService:Create(GameGUI.Slots.Level, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {Position = UDim2.new(0.5, 0,0.958, 0)}):Play()
		----TweenService:Create(GameGUI.Slots.Currecny, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {Position = UDim2.new(0.5, 0,0.794, 0)}):Play()
		--for i, v in GameGUI.Buttons:GetChildren() do
		--	if v:IsA("ImageButton") then
		--		TweenService:Create(v, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {Position = Positions[v.Name]}):Play()
		--	end
		--end
		--TweenService:Create(GameGUI.Buttons.Buttons,TweenInfo.new(0.15, Enum.EasingStyle.Sine), {AnchorPoint = Vector2.new(0,0.5)}):Play()
		--GameGUI.Buttons.Buttons.SettingsButton.Visible = true
	end

	function UIHandler.Transition()
		local Player = Players.LocalPlayer
		local PlayerGUI = Player:WaitForChild("PlayerGui")
		local GameGUI = PlayerGUI:WaitForChild("GameGui")

		local parentFrame = script.Main:Clone()
		parentFrame.Parent = GameGUI.Transition

		local uiList = createTransitionSquares(parentFrame)

		for delayTimer,list in uiList do
			for _,ui in list do
				local tweenInfo = TweenInfo.new(0.3,Enum.EasingStyle.Linear,Enum.EasingDirection.Out)
				local open = TweenService:Create(
					ui.Background,
					tweenInfo,
					{Size = UDim2.new(1,0,1,0)}
				)

				local close = TweenService:Create(
					ui.Background,
					tweenInfo,
					{Size = UDim2.new(0,0,0,0)}
				)

				task.delay(delayTimer * 0.03,function()
					open:Play()
					task.wait(2)
					close:Play()
				end)

			end
		end


	end

end

return UIHandler
