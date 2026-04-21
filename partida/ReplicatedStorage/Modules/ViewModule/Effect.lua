local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit: Knit = require(ReplicatedStorage:WaitForChild("Packages").Knit)
local Util = require(ReplicatedStorage:WaitForChild("Packages").Util)
local Effect = {}
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local FlashTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
local NewSize = UDim2.new(0.08, 40, 0.08, 40);
local Mobile = Vector2.new();
local UnitData = Knit.Get("Data", {"Towers"})
local Setupscripts = Knit.Get("Data", {"Setupscripts"})

game:GetService("UserInputService").InputBegan:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.Touch then
		Mobile = Vector2.new(Input.Position.X, Input.Position.Y + 36);
	end;
end);

function Effect.SetupUnit(Model, Unitfolder, UnitId)
	if not Model or not Unitfolder or not UnitId then return end
	local Data = UnitData[UnitId]
	if Data then
		if Data.info.Evo  ~= nil then
			if Data.info.Evo then
				if Setupscripts[UnitId.."_evolved"] then
					Setupscripts[UnitId.."_evolved"].setup(Model, Unitfolder)
				end
			else
				if Setupscripts[UnitId] then
					Setupscripts[UnitId].setup(Model, Unitfolder)
				end
			end
		else
			if Setupscripts[UnitId] then
				Setupscripts[UnitId].setup(Model, Unitfolder)
			end
		end
	end
end
function Effect.SparkleEffect(tblinfo)
	coroutine.wrap(function()
		local loop;
		while true do
			local grad : UIGradient = tblinfo.trackgrad
			if not grad or grad == nil or not tblinfo._shinyFX or not tblinfo._shinyFX:FindFirstChild("Sparkle") then break end
			local Sparkle = tblinfo._shinyFX.Sparkle;
			wait(math.random(15, 50) * 0.1 / 2);
			Sparkle.Position = UDim2.new(math.random() * 0.8 + 0.1, 0, math.random() * 0.8 + 0.1, 0);
			Sparkle.Size = UDim2.new(0, 0, 0, 0);
			local Randomtime = math.random() * 2 + 1.5;
			local Randomtime2 = math.random(-180, 180);
			local Randomtime3 = math.random(35, 50) * Randomtime * (math.random(1, 2) * 2 - 3);
			local Randomtime4 = math.random(9, 11) / 10;
			Sparkle.Rotation = Randomtime2;
			Sparkle.Visible = true;
			TweenService:Create(Sparkle, TweenInfo.new(Randomtime * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
				Size = UDim2.new(0.2 * Randomtime4, 0, 0.2 * Randomtime4, 0)
			}):Play();
			TweenService:Create(Sparkle, TweenInfo.new(Randomtime, Enum.EasingStyle.Linear), {
				Rotation = Randomtime2 + Randomtime3, 
				Position = Sparkle.Position - UDim2.new(0, 0, 0.1, 0)
			}):Play();
			wait(Randomtime);
			Sparkle.Visible = false;
			wait(math.random(15, 50) * 0.1 / 2);
		end
	end)()
end
function Effect.ShineEffect(tblinfo)
	local Shine = tblinfo._shinyFX.Shine;
	local speedmul = tblinfo.speed_mul and tblinfo.speed_mul or 1;
	local width_scale = tblinfo.width_scale and tblinfo.width_scale or 1;
	wait((math.random(20, 45) * 0.1 + 1) / 2 / speedmul);
	Shine.Position = UDim2.new(0.5, 0, 0.5, 0);
	Shine.Visible = true;

	local grad = Shine:FindFirstChild("gradient");
	local Parent = tblinfo._shinyFX.Parent;
	if grad and Parent then
		local Border = Parent:FindFirstChild("Border");
		if tblinfo and tblinfo.additional_params and tblinfo.additional_params.topframe_grad then
			Border = tblinfo.additional_params.topframe_grad;
		end;
		if not Border then
			Border = Parent.UIStroke:FindFirstChild("Border");
		end;
		local DivSpeedMul = 2 / speedmul;
		local UpdSpeed = 0;
		while Shine ~= nil and grad ~= nil and Border ~= nil do
			if DivSpeedMul < UpdSpeed then
				return;
			end;
			local Tween = -0.3 + 1.3 * TweenService:GetValue(UpdSpeed / DivSpeedMul, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut);
			local MathClamp1 = math.clamp(Tween + 0.1 * width_scale, 0.002, 0.997);
			local MathClamp2 = math.clamp(Tween + 0.2 * width_scale, 0.003, 0.998);
			grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(math.clamp(Tween, 0.001, 0.996), 1), NumberSequenceKeypoint.new(MathClamp1, 0.25), NumberSequenceKeypoint.new(MathClamp2, 0.25), NumberSequenceKeypoint.new(math.clamp(Tween + 0.3 * width_scale, 0.004, 0.999), 1), NumberSequenceKeypoint.new(1, 1) });
			local AddedNumbers = (MathClamp2 + MathClamp1) / 2;
			local NewColor = Border.Color;
			local IMPKEY = nil;
			if AddedNumbers < 0.01 then
				IMPKEY = NewColor.Keypoints[1].Value;
			end;
			if AddedNumbers > 0.99 then
				IMPKEY = NewColor.Keypoints[#NewColor.Keypoints].Value;
			end;
			if IMPKEY == nil then
				for i = 1, #NewColor.Keypoints - 1 do
					if IMPKEY ~= nil then
						break;
					end;
					local KeyPointspoint1 = NewColor.Keypoints[i];
					local KeyPointspoint1Add = NewColor.Keypoints[i + 1];
					if KeyPointspoint1.Time <= AddedNumbers and AddedNumbers <= KeyPointspoint1Add.Time then
						local Form = (AddedNumbers - KeyPointspoint1.Time) / (KeyPointspoint1Add.Time - KeyPointspoint1.Time);
						IMPKEY = Color3.new((KeyPointspoint1Add.Value.R - KeyPointspoint1.Value.R) * Form + KeyPointspoint1.Value.R, (KeyPointspoint1Add.Value.G - KeyPointspoint1.Value.G) * Form + KeyPointspoint1.Value.G, (KeyPointspoint1Add.Value.B - KeyPointspoint1.Value.B) * Form + KeyPointspoint1.Value.B);
					end;
				end;
			end;
			local H1, H2, H3 = IMPKEY:ToHSV();
			local colo3fromb = Color3.fromHSV(H1, H2 / 4, H3);
			local Tbl = {};
			local NewTime = 0;
			for _, Poin in NewColor.Keypoints do
				local SetTime = Poin.Time;
				local P1, P2, P3 = Poin.Value:ToHSV();
				if NewTime < AddedNumbers and AddedNumbers <= SetTime then
					table.insert(Tbl, ColorSequenceKeypoint.new(AddedNumbers, colo3fromb));
				end;
				table.insert(Tbl, ColorSequenceKeypoint.new(SetTime, (Color3.fromHSV(P1, P2 / 1.5, P3))));
				NewTime = SetTime;
			end;
			grad.Color = ColorSequence.new(Tbl);
			UpdSpeed = UpdSpeed + RunService.Heartbeat:Wait();			
		end;
	end;
	Shine.Visible = false;
	wait((math.random(20, 45) * 0.1 + 1) / 2);
end
function Effect.flashbutton(Pos)
	local FlashClone = script.EffectThing:Clone();
	FlashClone.Parent = game.Players.LocalPlayer.PlayerGui.SideBar;
	FlashClone.Visible = true;
	FlashClone.Position = UDim2.new(0, Pos.X, 0, Pos.Y);
	FlashClone.Size = UDim2.new(0, 0, 0, 0);
	local Tween = TweenService:Create(FlashClone, FlashTweenInfo, {
		Size = NewSize, 
		ImageTransparency = 1
	});
	Tween:Play();
	Tween.Completed:Wait();
	Tween:Destroy();
	FlashClone:Destroy();
end;
function Effect.Start(Gradient)
	--coroutine.wrap(function()
	--	local Deltatime =  RunService.Heartbeat:Wait()
	--	while Gradient ~= nil and Gradient.Parent ~= nil do
	--		if Gradient == nil then
	--			return;
	--		end;
	--		if Gradient.Parent == nil then
	--			return;
	--		end;
	--		Gradient.Offset = Vector2.new(Gradient.Offset.X + (1 * Deltatime), 0)

	--		if Gradient.Offset.X >= 1 then
	--			local isRotated = (Gradient.Rotation == 180)
	--			Gradient.Rotation = isRotated and 0 or 180; Gradient.Offset = Vector2.new(-1, 0) --isRotated and -0.5 or -1
	--		end
	--		Deltatime = RunService.Heartbeat:Wait();		
	--	end;
	--end)()
end

function Effect.Click(Button : GuiButton)
	if Button:FindFirstChildWhichIsA("UIScale") == nil then
		local UiScale = Instance.new("UIScale");
		UiScale.Scale = 1;
		UiScale.Parent = Button;
	end;
	local buttonMetatable = {
		__index = {
			AnimateButton = function(self, scale)
				if self.Object then
					if not self.Object:FindFirstChild("UIScale") then return end
					local UIObject = self.Object.UIScale
					if UIObject and UIObject:IsA("UIScale") then
						TweenService:Create(UIObject, TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false), {
							Scale = scale
						}):Play();
					end
				end
			end
		},
	}

	local function createButtonWrapper(button)
		local buttonWrapper = {
			Object = button,
			WaitForChild = function(self, childName)
				return self.Object:WaitForChild(childName)
			end
		}
		setmetatable(buttonWrapper, buttonMetatable)
		return buttonWrapper
	end

	if Button:IsA("ImageButton") or Button:IsA("TextButton") then
		local buttonWrapper = createButtonWrapper(Button)

		Button.MouseLeave:Connect(function()
			buttonWrapper:AnimateButton(1)
		end)
		Button.MouseButton1Down:Connect(function()
			buttonWrapper:AnimateButton(0.85)
		end)
		Button.MouseButton1Up:Connect(function()
			if Button:HasTag("NORMALCLICK") then
				Util.PlaySound(16015456044,0.7, 1.5)
			end
			Effect.flashbutton(Button.AbsolutePosition + Button.AbsoluteSize * 0.5 + Vector2.new(0, 36))
			Button:SetAttribute("ButtonSize", Button.AbsoluteSize.X)
			buttonWrapper:AnimateButton(1)
		end)
	end

end

function Effect.GradGlow(Grad, TblInfo)
	--coroutine.wrap(function()
	--	while true do
	--		local IntColor = Color3.fromRGB(0, 0, 0);
	--		if TblInfo.initial_color then
	--			IntColor = TblInfo.initial_color;
	--		end;
	--		local Value1 = nil;
	--		local Value2 = nil;
	--		local Value3 = nil;
	--		local BaseColor = TblInfo.base_color;
	--		local TickFixed = tick() * 0.1 * 1 / 0.6666666666666666 % 1;
	--		local TweenValue 
	--		if TickFixed < 0.5 then
	--			TweenValue = TweenService:GetValue(TickFixed * 2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut);
	--		else
	--			TweenValue = 1 - TweenService:GetValue((TickFixed - 0.5) * 2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut);
	--		end;
	--		local newSequenc = {};
	--		if TblInfo.rainbow == true then
	--			BaseColor = Color3.fromHSV(TickFixed, 1, 1);
	--		end;
	--		if BaseColor then
	--			local Upd1, Upd2, Upd3 = BaseColor:ToHSV();
	--			Value1 = Upd1;
	--			Value2 = Upd2;
	--			Value3 = Upd3;
	--		end;
	--		table.insert(newSequenc, ColorSequenceKeypoint.new(0, IntColor));
	--		table.insert(newSequenc, ColorSequenceKeypoint.new(0.8, Color3.fromHSV(Value1, Value2, Value3 / 2)));
	--		table.insert(newSequenc, ColorSequenceKeypoint.new(1, Color3.fromHSV(Value1, Value2, TweenValue * Value3)));
	--		Grad.Color = ColorSequence.new(newSequenc);
	--		RunService.Heartbeat:Wait();
	--	end
	--end)();
end
function Effect.StartRainbow(Gradient)
	coroutine.wrap(function()
		while Gradient ~= nil and Gradient.Parent ~= nil do
			if Gradient == nil then
				return;
			end;
			if Gradient.Parent == nil then
				return;
			end;
			local TickThing = tick() * 0.1 * 1 % 1;
			local Table = {};
			for i = 0, 1, 0.1 do
				table.insert(Table, ColorSequenceKeypoint.new(i, (Color3.fromHSV((CurrentTick + i * 0.6) % 1, 0.8, 1))));
			end;
			Gradient.Color = ColorSequence.new(Table);
			RunService.Heartbeat:Wait();			
		end;
	end)();
end
function Effect.SpinObject(Object)
	local Loop = nil;
	Loop = RunService.Heartbeat:Connect(function(DelaTime)
		if Object then
			if not Object.Parent then
				Loop:Disconnect();
				Loop = nil;
				return;
			end;
		else
			Loop:Disconnect();
			Loop = nil;
			return;
		end;
		Object.CFrame = Object.CFrame * CFrame.Angles(0, math.rad(DelaTime * 360 / 4), 0);
	end);
end
return Effect
