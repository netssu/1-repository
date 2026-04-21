
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScaleModel  = require(script.ScaleModel)
local ViewModule = {}
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Rarities = require(script.Rarities)
local UiHandler = require(game.ReplicatedStorage.Modules.Client.UIHandler)
local TraitsModule = require(game.ReplicatedStorage.Modules.Traits)
local VFXHelper = require(game.ReplicatedStorage.Modules.VFX_Helper)
local DeleteTakedownsAttribute = game.ReplicatedStorage.Events.DeleteTakedownsAttribute
local Preloader = game:GetService("ContentProvider")
local Anim = script.Evolution.Animation
Preloader:PreloadAsync({Anim})
local Debounce = false
local SoundActive = false
local hatching = false
local HATCHINGGLOBAL = nil

local function QuartOut(LT1)
	LT1 = LT1 / 1 - 1;
	return -1 * (math.pow(LT1, 4) - 1) + 0;
end;
local function ElasticOut(LT1)
	if LT1 == 0 then
		return 0;
	end;
	LT1 = LT1 / 1;
	if LT1 == 1 then
		return 1;
	end;
	local L12 = nil;
	local L13 = nil;
	local L14 = nil;
	if not L12 then
		L12 = 0.3;
	end;
	if not L13 or L13 < 1 then
		L13 = 1;
		L14 = L12 / 4;
	else
		L14 = L12 / (2 * math.pi) * math.asin(1 / L13);
	end;
	return L13 * math.pow(2, -10 * LT1) * math.sin((LT1 * 1 - L14) * (2 * math.pi) / L12) + 1 + 0;
end;
local function BackIn(LT1)
	LT1 = LT1 / 1;
	return 1 * LT1 * LT1 * (2.70158 * LT1 - 1.70158) + 0;
end;
local function QuadOut(LT1)
	LT1 = LT1 / 1;
	return -1 * LT1 * (LT1 - 2) + 0;
end;

local function replicate(v)
	if v:FindFirstChild("HumanoidRootPart") then
		for i,Part in v:GetDescendants() do
			if Part:IsA("BasePart") then
				if v then
					Part.CastShadow = false;
					Part.Anchored = false;
					Part.CanCollide = false;
					Part.CanQuery = false
					Part.CollisionGroup = "PartNotCollide";
				else
				end
			end
		end
		v.HumanoidRootPart.Anchored = true;
	end
end

function ViewModule.EvolveHatch(Info) --UnitInfo, PlayerUnit, _resumeCallback

	local UnitInfo = Info[1]
	local PlayerUnit = Info[2]
	local _resumeCallback = Info[3]
	local isFromSummon = Info[4]
	local GetUnitModel = require(game.ReplicatedStorage.Modules.GetUnitModel)
	local Unit = if PlayerUnit:GetAttribute("Shiny") then GetUnitModel[PlayerUnit.Name] else GetUnitModel[PlayerUnit.Name]
	local HatchUi : ScreenGui = script.HatchInfo:Clone() --Point to the ui here--Knit.Get("Module", "GuiUtil").GetUI("HatchInfo"):Clone()
	local HatchCenter = HatchUi:WaitForChild("Center")
	local HatchBottom = HatchUi:WaitForChild("Bottom")
	local HatchTakedowns = HatchUi:WaitForChild("Takedowns")
	local UnitsTakedowns = PlayerUnit:GetAttribute("Takedowns")
	local HatchShiny = HatchUi:WaitForChild("Shiny")
	HatchUi.Parent = 	game.Players.LocalPlayer.PlayerGui

	UiHandler.DisableAllButtons()

	local WaitTime = 1.5
	local WaitTimer = os.clock()
	HatchCenter.Visible = false
	task.delay(WaitTime,function()
		HatchCenter.Visible = true
	end)

	game.Players.LocalPlayer.CameraMinZoomDistance = 10;
	if game.Lighting.UIBlur.Size > 0 then
		TweenService:Create(game.Lighting.UIBlur, TweenInfo.new(.3), {Size = 4}):Play()
	end
	local Info = nil;
	local ItemInfo = nil;
	local Rarity  = nil;
	local Trait = PlayerUnit:GetAttribute("Trait")
	local TimeObtained = PlayerUnit:GetAttribute("TimeObtained")
	local Shiny = PlayerUnit:GetAttribute("Shiny")
	local UnitData = nil;
	local Anchor = true;
	if Unit then
		Rarity = UnitInfo.Rarity;
		UnitData = UnitInfo
	else
		UnitData = UnitInfo
		Rarity = UnitInfo.Rarity;
	end;
	UnitData.OffSet = CFrame.new(0,0,0)
	local CurrentCamera = game.Workspace.CurrentCamera;
	local Rand = Random.new();
	local DepthOfFieldEffect = Instance.new("DepthOfFieldEffect");
	DepthOfFieldEffect.InFocusRadius = 2.3;
	DepthOfFieldEffect.FarIntensity = 0;
	DepthOfFieldEffect.Parent = game.Lighting;
	--if FarIntensity then
	DepthOfFieldEffect.FarIntensity = 1;
	--end;
	if HATCHINGGLOBAL then
		HATCHINGGLOBAL:Disconnect()
		HATCHINGGLOBAL = nil
	end

	local light = Instance.new("Part")
	light.Transparency = 1
	light.Anchored = true
	light.CanCollide = false
	local spotlight = Instance.new("SpotLight")
	spotlight.Range = 6
	spotlight.Brightness = .5
	spotlight.Parent = light
	light.Parent = CurrentCamera

	if UnitsTakedowns then

		if UnitInfo.Takedowns then

			HatchTakedowns.Visible = true
			HatchTakedowns.Quantity.Text = UnitsTakedowns .. "/" .. UnitInfo.Takedowns
			if UnitsTakedowns < UnitInfo.Takedowns then
				HatchTakedowns.Quantity.NotComplete.Enabled = true
				HatchTakedowns.Quantity.Complete.Enabled = false
			else
				HatchTakedowns.Quantity.NotComplete.Enabled = false
				HatchTakedowns.Quantity.Complete.Enabled = true
			end
		else
			DeleteTakedownsAttribute:FireServer(PlayerUnit,"Takedowns")
		end
	end

	local Model
	local Rand4 = {};
	local Rand5 = {};
	local Rand6 = 1;

	while Rand6 <= 1 do
		local Rand7 = UnitInfo;
		if Unit then
			local UnitModel = Unit:Clone()
			UiHandler.PlaySound("Evo")
			if Trait then
				TraitsModule.AddVisualAura(UnitModel, Trait)
			end
			task.spawn(function()
				local Wrap
				Wrap = RunService.RenderStepped:Connect(function()
					light.CFrame = CurrentCamera.CFrame
					if UnitModel == nil or  UnitModel.Parent == nil then Wrap:Disconnect() light:Destroy() end
					for _, Part in (UnitModel:GetDescendants()) do
						if Part:IsA("BasePart") then
							if Part.Name == "HumanoidRootPart" and Anchor then
								Part.Anchored = true;
							else
								Part.Anchored = false;
							end;
							Part.CastShadow = false;
							Part.CanCollide = false;
							Part.CanQuery = false
						end;
					end;
				end)
			end)
			--Util.create_cell_shading(UnitModel, UnitData, nil, nil)
			UnitModel.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None;
			Model = UnitModel;

		end;

		if Rand6 == 1 then
			local PointLight = Instance.new("PointLight");
			PointLight.Range = 5;
			PointLight.Brightness = 5;
			PointLight.Parent = Model.PrimaryPart;
		end;

		local StarRelease = nil;
		if Unit and Model:FindFirstChild("HumanoidRootPart") then
			Model.HumanoidRootPart.Anchored = true;
			StarRelease = script.LevelParticle:Clone();
			StarRelease.LockedToPart = true;
			StarRelease.Parent = Model.HumanoidRootPart;
		end;
		if Unit then
			ScaleModel(Model, 0.6666666666666666 / Model.HumanoidRootPart.Size.X);
		end;


		--Model:PivotTo(CurrentCamera.CFrame);


		if Unit or ItemInfo  then
			Model.Parent = workspace.Ignore;--game.Players.LocalPlayer.Character;
		else
			Model.Parent = workspace.Ignore;
		end;
		if StarRelease then
			StarRelease:Emit(StarRelease.Rate);
		end;
		if Unit then
			--local track = Model.Humanoid:LoadAnimation(Model.Animations.Idle)
			task.spawn(function()
				local track = Model.Humanoid:LoadAnimation(Anim)
				track:Play()
				track:AdjustSpeed(.85)
				track.Stopped:Wait()
				track:Destroy()
				local track2 = Model.Humanoid:LoadAnimation(Model.Animations.Idle)
				track2:Play()
				track2:Destroy()
			end)
		end
		local CF1
		local CF2
		if Rand6 == 2 then
			CF1 = 1.9;
		elseif Rand6 == 3 then
			CF1 = -1.9;
		else
			CF1 = 0;
		end;
		if Rand6 > 1 then
			CF2 = -0.2;
		else
			CF2 = 0;
		end;
		Rand4[Rand6] = Model;
		Rand5[Rand6] = CFrame.new(CF1, 0,  CF2);
		Rand6 = Rand6 + 1;	
		RunService.RenderStepped:Wait();		
	end;


	local CFOF = nil;
	local Name
	if Unit then
		Name = 	UnitInfo.name;
		CFOF = UnitData.OffSet;
	else
		Name = UnitInfo.name .. " (x" .. tostring(UnitInfo.amount or 1) .. ")";
	end;
	if UnitInfo and PlayerUnit then
		HatchCenter.UnitName.Text = UnitInfo.Name
		HatchCenter.Rarity.Text = UnitInfo.Rarity
		HatchCenter.Rarity.UIGradient.Color = TraitsModule["TraitColors"][UnitInfo.Rarity].Gradient
		task.spawn(function()
			local gradients = {
				HatchCenter.Rarity.UIGradient
			}
			local valid = false
			repeat
				valid = false
				for _,grad in gradients do
					if Rarity == "Mythical" then
						local t = 2.8
						local range = 7
						grad.Rotation = 0
						local loop = tick() % t / t
						local colors = {}
						for i = 1, range + 1, 1 do
							local z = Color3.fromHSV(loop - ((i - 1)/range), 1, 1)
							if loop - ((i - 1) / range) < 0 then
								z = Color3.fromHSV((loop - ((i - 1) / range)) + 1, 1, 1)
							end
							local d = ColorSequenceKeypoint.new((i - 1) / range, z)
							table.insert(colors, d)
						end
						grad.Color = ColorSequence.new(colors)
						valid = true
					else
						grad.Rotation = (grad.Rotation+2)%360
						valid = true
					end
				end
				task.wait()
			until not valid
		end)
		if Shiny then
			task.delay(WaitTime,function()
				HatchShiny.Visible = true
			end)

			--HatchCenter.Shiny.Visible = true
		end
		if TimeObtained ~= nil then
			task.delay(WaitTime,function()
				HatchCenter.Limited.Visible = true
			end)

			if TimeObtained == "???" then
				HatchCenter.Limited.Text = `[Limited] - Obtained: ???`

			else
				HatchCenter.Limited.Text = `[Limited] - Obtained: {os.date(nil,TimeObtained)}`
			end
		end
		if Trait ~= "" and Trait ~= nil then
			task.delay(WaitTime,function()
				HatchCenter.Trait.Visible = true
			end)

			HatchCenter.Trait.Text = Trait
			if string.find(Trait, "I") or Trait == "Berserker" or Trait == "Expertion" or Trait == "Godspeed" then
				HatchCenter.Trait.Icon.Position = UDim2.new(0.5 - (0.02 * #Trait),0,0.5,0)
			else
				HatchCenter.Trait.Icon.Position = UDim2.new(0.5 - (0.025 * #Trait),0,0.5,0)
			end

			HatchCenter.Trait.UIGradient.Color = TraitsModule["TraitColors"][TraitsModule["Traits"][Trait].Rarity].Gradient
			HatchCenter.Trait.Icon.Image = TraitsModule["Traits"][Trait].ImageID
			HatchCenter.Trait.Icon.UIGradient.Color = TraitsModule["TraitColors"][TraitsModule["Traits"][Trait].Rarity].Gradient

			task.spawn(function()
				local gradients = {
					HatchCenter.Trait.UIGradient,
					HatchCenter.Trait.Icon.UIGradient,
				}
				local valid = false
				repeat
					valid = false
					for _,grad in gradients do
						if HatchCenter:FindFirstChild("Trait") then
							if HatchCenter.Trait.Text == "Cosmic Crusader" or HatchCenter.Trait.Text == "Waders Will" then
								local t = 2.8
								local range = 7
								grad.Rotation = 0
								local loop = tick() % t / t
								local colors = {}
								for i = 1, range + 1, 1 do
									local z = Color3.fromHSV(loop - ((i - 1)/range), 1, 1)
									if loop - ((i - 1) / range) < 0 then
										z = Color3.fromHSV((loop - ((i - 1) / range)) + 1, 1, 1)
									end
									local d = ColorSequenceKeypoint.new((i - 1) / range, z)
									table.insert(colors, d)
								end
								grad.Color = ColorSequence.new(colors)
								valid = true
							else
								grad.Rotation = (grad.Rotation+2)%360
								valid = true
							end
						end
					end
					task.wait()
				until not valid
			end)

		end

		--Check for trait

		local Text : UIGradient = HatchCenter.Rarity
		--	Knit.Get("Module", "GuiUtil").Destroy_OldGradient(Text)
		if Rarity == "Mythical" then
			Text.UIGradient.Rotation = 90
			Text.UIGradient.Color = Rarities[UnitInfo.Rarity].Color
		else
			Text.UIGradient.Color = Rarities[UnitInfo.Rarity].Color
			--	Knit.Get("Module", "Effect").Start(Text.UIGradient)
		end;
		HatchUi.Enabled = true
	end

	if UnitData then

		task.delay(WaitTime,function()


			if ViewModule.infotween_in then
				ViewModule.infotween_in:Cancel();
			end;
			if ViewModule.infotween_in2 then
				ViewModule.infotween_in2:Cancel();
			end;
			if ViewModule.infotween_in3 then
				ViewModule.infotween_in3:Cancel();
			end;
			HatchUi.Enabled = true;
			HatchCenter.Size = UDim2.new(0.25, 0, 0.25, 0)-- UDim2.new(0, 0, 0, 0);
			HatchCenter.Position = UDim2.new(0.5, 0, 0.9, 0);
			ViewModule.infotween_in = TweenService:Create(HatchCenter, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, 0, 0.3, 0)
			});
			ViewModule.infotween_out = TweenService:Create(HatchCenter, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 0, 0, 0)
			});
			ViewModule.infotween_in:Play();
			ViewModule.infotween_in2 = TweenService:Create(HatchShiny, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Size = UDim2.new(0.254, 0, 0.275, 0)
			});
			ViewModule.infotween_out2 = TweenService:Create(HatchShiny, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 0, 0, 0)
			});
			ViewModule.infotween_in2:Play();
			ViewModule.infotween_in3 = TweenService:Create(HatchTakedowns, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Size = UDim2.new(0.168, 0, 0.121, 0)
			});
			ViewModule.infotween_out3 = TweenService:Create(HatchTakedowns, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 0, 0, 0)
			});
			ViewModule.infotween_in3:Play();
			if ViewModule.holder_ui_scale_tween then
				ViewModule.holder_ui_scale_tween:Cancel();
			end;
			HatchCenter.UIScale.Scale = 0;
			ViewModule.holder_ui_scale_tween = TweenService:Create(HatchCenter.UIScale, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Scale = 1
			});
			ViewModule.holder_ui_scale_tween:Play();
			if ViewModule.small_info_scale_tween then
				ViewModule.small_info_scale_tween:Cancel();
			end;
			--HatchBottom.Position = UDim2.new(1.5, -10, 1, -80);
			ViewModule.small_info_scale_tween = TweenService:Create(HatchBottom, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.67, 0,0.92, 0)
			});
			ViewModule.small_info_scale_tween:Play();
		end)
	end

	if CFOF == nil then
		CFOF = CFrame.new();
	end;

	local MainParticle = script.Inspect:Clone();
	replicate(MainParticle)

	task.delay(WaitTime,function()
		MainParticle.Parent = workspace.Ignore;
	end)
	
	local EvolveEmit = nil
	
	for _, Particle in MainParticle:GetDescendants() do
		if Particle:IsA("ParticleEmitter") then
			if Rarity ~= nil then
				Particle.Color = Rarities[UnitInfo.Rarity].Color
			end;
			Particle:Emit(math.max(1, Particle.Rate / 2));
		end;
	end;
	local LoopTrue = true;
	local LoopTrue2 = true;
	local LoopTrue3 = false;
	local FinalTimer = nil
	coroutine.wrap(function()

		if LoopTrue == false or LoopTrue2 == false then
			return;
		end;

		replicate(Model)
		LoopTrue3 = true;
		EvolveEmit = script.Evolution.EvolveEmit:Clone()
		EvolveEmit.Parent = game.Workspace.Ignore
		VFXHelper.EmitWithDelay(EvolveEmit)
		local originalCameraCFrame = CurrentCamera.CFrame
		local OCSLOCK = os.clock();
		
		while LoopTrue2 do
			FinalTimer = os.clock() - WaitTimer
			for Index, PartThing in Rand4 do
				Model:PivotTo(CurrentCamera.CFrame * CFrame.new(0, 0, -3.35) * CFrame.Angles(0, 3.141592653589793, 0));
				EvolveEmit.CFrame = CurrentCamera.CFrame * CFrame.new(0, 0, -3.35) * CFrame.Angles(0, 3.141592653589793, 0);
				MainParticle.CFrame = CurrentCamera.CFrame * CFrame.new(0, 0, -3.35) * CFrame.Angles(0, 3.141592653589793, 0);
			end;
			RunService.RenderStepped:Wait();			
		end;
	end)();

	repeat 
		task.wait() 
	until FinalTimer and FinalTimer > WaitTime
	local ClickLoop = nil;
	ClickLoop = UserInputService.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then

			ClickLoop:Disconnect();
			ClickLoop = nil;
			LoopTrue2 = false;
			LoopTrue = false;
			local OSCLOCK = os.clock();
			ViewModule.infotween_out:Play()
			ViewModule.infotween_out2:Play()
			ViewModule.infotween_out3:Play()
			while true do
				local Clock = math.clamp((os.clock() - OSCLOCK) / 0.5, 0, 1);
				local Easing3 = BackIn(Clock);
				for Index, PartFound in Rand4 do
					local CFOFFS = CurrentCamera.CFrame * CFrame.new(0, 0, -3.35) * Rand5[Rand6 - 1] * CFrame.new(0, Easing3 * -5, 0) * CFrame.Angles(0, 3.141592653589793, 0);
					PartFound:PivotTo(CFOFFS * CFOF);
					for _, ExtraPaer in MainParticle:GetDescendants() do
						if ExtraPaer:IsA("ParticleEmitter") then
							ExtraPaer.Enabled = false;
						end;
					end;
					MainParticle.CFrame = CFOFFS * CFrame.new(-1.52587891E-05, -0.00043296814, 0.265960693, 1, 8.98941107E-06, 4.2619572E-06, -8.98976123E-06, 1, 8.23723967E-05, -4.26121642E-06, -8.23724331E-05, 1);
				end;
				DepthOfFieldEffect.FarIntensity = 1 - Clock;
				RunService.RenderStepped:Wait();
				if Clock >= 1 then

					break;
				end;				
			end;
			--if sound then
			--	sound:Pause()
			--	sound:Destroy()
			--	end
			if ViewModule.infotween_out.PlaybackState == Enum.PlaybackState.Completed then
				HatchUi:Destroy()
			else
				local outTween; outTween = ViewModule.infotween_out.Completed:Connect(function()
					HatchUi:Destroy()
					outTween:Disconnect()
				end)
			end

			if ViewModule.infotween_out2.PlaybackState == Enum.PlaybackState.Completed then
				HatchUi:Destroy()
			else
				local outTween; outTween = ViewModule.infotween_out2.Completed:Connect(function()
					HatchUi:Destroy()
					outTween:Disconnect()
				end)
			end

			DepthOfFieldEffect:Destroy();
			MainParticle:Destroy();
			EvolveEmit:Destroy()
			for _, tHING in Rand4 do
				tHING:Destroy();
			end;
			game.Players.LocalPlayer.CameraMinZoomDistance = 0.5;
			for _, Object in Rand4 do
				Object:Destroy();
			end;

			if not isFromSummon then
				task.spawn(UiHandler.EnableAllButtons)
				--ENALBE THE UI HERE--Knit.Get("Module", "GuiUtil"):RenableAllWindows()
			end
			if _resumeCallback then
				_resumeCallback()
			end
		end;
	end);

end;

function ViewModule.Hatch(Info) --UnitInfo, PlayerUnit, _resumeCallback
	warn(Info)
	local UnitInfo = Info[1]
	local PlayerUnit = Info[2]
	local _resumeCallback = Info[3]
	local isFromSummon = Info[4]
	local GetUnitModel = require(game.ReplicatedStorage.Modules.GetUnitModel)
	local Unit = if PlayerUnit:GetAttribute("Shiny") then GetUnitModel[PlayerUnit.Name] else GetUnitModel[PlayerUnit.Name]
	local HatchUi : ScreenGui = script.HatchInfo:Clone() --Point to the ui here--Knit.Get("Module", "GuiUtil").GetUI("HatchInfo"):Clone()
	local HatchCenter = HatchUi:WaitForChild("Center")
	local HatchBottom = HatchUi:WaitForChild("Bottom")
	local HatchTakedowns = HatchUi:WaitForChild("Takedowns")
	local UnitsTakedowns = PlayerUnit:GetAttribute("Takedowns")
	local HatchShiny = HatchUi:WaitForChild("Shiny")
	HatchUi.Parent = 	game.Players.LocalPlayer.PlayerGui

	-- CLOSE ALL OF THE UI HERE --Knit.Get("Module", "GuiUtil"):CloseAllWindows(" ", true)
	
	UiHandler.DisableAllButtons()
	
	game.Players.LocalPlayer.CameraMinZoomDistance = 10;
	--if game.Lighting.UIBlur.Size > 0 then
	--	TweenService:Create(game.Lighting.UIBlur, TweenInfo.new(.3), {Size = 4}):Play()
	--end
	local Info = nil;
	local ItemInfo = nil;
	local Rarity  = nil;
	local Trait = PlayerUnit:GetAttribute("Trait")
	local TimeObtained = PlayerUnit:GetAttribute("TimeObtained")
	local Shiny = PlayerUnit:GetAttribute("Shiny")
	local UnitData = nil;
	local Anchor = true;
	if Unit then
		Rarity = UnitInfo.Rarity;
		UnitData = UnitInfo
	else
		UnitData = UnitInfo
		Rarity = UnitInfo.Rarity;
	end;
	UnitData.OffSet = CFrame.new(0,0,0)

	local CurrentCamera = game.Workspace.CurrentCamera;
	local Rand = Random.new();
	local DepthOfFieldEffect = Instance.new("DepthOfFieldEffect");
	DepthOfFieldEffect.InFocusRadius = 2.3;
	DepthOfFieldEffect.FarIntensity = 0;
	DepthOfFieldEffect.Parent = game.Lighting;
	--if FarIntensity then
	DepthOfFieldEffect.FarIntensity = 1;
	--end;
	if HATCHINGGLOBAL then
		HATCHINGGLOBAL:Disconnect()
		HATCHINGGLOBAL = nil
	end

	local light = Instance.new("Part")
	light.Transparency = 1
	light.Anchored = true
	light.CanCollide = false
	local spotlight = Instance.new("SpotLight")
	spotlight.Range = 6
	spotlight.Brightness = .5
	spotlight.Parent = light
	light.Parent = CurrentCamera

	if UnitsTakedowns then

		if UnitInfo.Takedowns then

			HatchTakedowns.Visible = true
			HatchTakedowns.Quantity.Text = UnitsTakedowns .. "/" .. UnitInfo.Takedowns
			if UnitsTakedowns < UnitInfo.Takedowns then
				HatchTakedowns.Quantity.NotComplete.Enabled = true
				HatchTakedowns.Quantity.Complete.Enabled = false
			else
				HatchTakedowns.Quantity.NotComplete.Enabled = false
				HatchTakedowns.Quantity.Complete.Enabled = true
			end
		else
			DeleteTakedownsAttribute:FireServer(PlayerUnit,"Takedowns")
		end
	end

	local Model
	local Rand4 = {};
	local Rand5 = {};
	local Rand6 = 1;
	if typeof(Hatching) ~= "table" then
		while Rand6 <= 1 do
			local Rand7 = UnitInfo;
			if Unit then
				local UnitModel = Unit:Clone()

				if Trait then
					TraitsModule.AddVisualAura(UnitModel, Trait)
				end
				--[=[
				
				local auraFolder = game.ReplicatedStorage.AuraTraits:FindFirstChild(Trait)
				if auraFolder then

					local newAuraFolder = Instance.new("Folder")
					newAuraFolder.Name = "Aura"
					newAuraFolder.Parent = UnitModel

					for _,bodyPart in auraFolder:GetChildren() do
						local weldToPart = UnitModel:FindFirstChild(bodyPart.Name)
						if weldToPart == nil then continue end

						local partClone = bodyPart:Clone()

						local weld = Instance.new("Weld")
						weld.Part0 = partClone
						weld.Part1 = weldToPart
						weld.Parent = partClone

						partClone.Parent = newAuraFolder
						
						
						if partClone.Name == "Torso" and Trait == "King" then
							task.spawn(function()
								local SpinPart = partClone:FindFirstChild("Spin")

								if not SpinPart then
									return
								end
								
								local Goal = {Orientation = SpinPart.Orientation + Vector3.new(0, 360, 0)}
								local Information = TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 0, false, 0)

								local Rotation = TweenService:Create(SpinPart, Information, Goal)

								local function Play()
									if not SpinPart then
										return
									end

									Rotation:Play()

									Rotation.Completed:Once(function()
										if not SpinPart then
											return
										end

										Play()
									end)
								end

								Rotation:Play()

								Rotation.Completed:Once(function()
									if not SpinPart then
										return
									end

									Play()
								end)
								
								--local SpinPart = partClone:FindFirstChild("Spin")

								----// Spinning
								--	HATCHINGGLOBAL = RunService.PostSimulation:Connect(function()
								--	if not SpinPart then
								--		if HATCHINGGLOBAL then
								--			HATCHINGGLOBAL:Disconnect()
								--			HATCHINGGLOBAL = nil		
								--		end
								--	end

								--	if SpinPart then
								--		SpinPart.Orientation += Vector3.new(0, 1.5, 0)
								--	end
								--end)
							end)
						end
					end

				end
]=]

				task.spawn(function()
					local Wrap
					Wrap = RunService.RenderStepped:Connect(function()
						light.CFrame = CurrentCamera.CFrame
						if UnitModel == nil or  UnitModel.Parent == nil then Wrap:Disconnect() light:Destroy() end
						for _, Part in (UnitModel:GetDescendants()) do
							if Part:IsA("BasePart") then
								if Part.Name == "HumanoidRootPart" and Anchor then
									Part.Anchored = true;
								else
									Part.Anchored = false;
								end;
								Part.CastShadow = false;
								Part.CanCollide = false;
								Part.CanQuery = false
							end;
						end;
					end)
				end)
				--Util.create_cell_shading(UnitModel, UnitData, nil, nil)
				UnitModel.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None;
				Model = UnitModel;
			else
				Model = ReplicatedStorage.Assets.Items:FindFirstChild(UnitInfo.item_id):Clone() do
					for _,object in Model:GetDescendants() do
						if object:IsA("BasePart") then
							object.CanQuery = false
						end
					end
				end
			end;

			local pf, pf2, pf3 = Model:GetDescendants();
			if Rand6 == 1 then
				local PointLight = Instance.new("PointLight");
				PointLight.Range = 5;
				PointLight.Brightness = 5;
				PointLight.Parent = Model.PrimaryPart;
			end;

			local StarRelease = nil;
			if Unit and Model:FindFirstChild("HumanoidRootPart") then
				Model.HumanoidRootPart.Anchored = true;
				StarRelease = script.LevelParticle:Clone();
				StarRelease.LockedToPart = true;
				StarRelease.Parent = Model.HumanoidRootPart;
			end;
			if Unit then
				ScaleModel(Model, 0.6666666666666666 / Model.HumanoidRootPart.Size.X);
			end;


			Model:PivotTo(CurrentCamera.CFrame);
			if Unit or ItemInfo  then
				Model.Parent = workspace.Ignore;--game.Players.LocalPlayer.Character;
			else
				Model.Parent = workspace.Ignore;
			end;
			if StarRelease then
				StarRelease:Emit(StarRelease.Rate);
			end;
			if Unit then
				local track = Model.Humanoid:LoadAnimation(Model.Animations.Idle)
				track:Play()
				track:Destroy()
				-- REPLACE WITH IDLE ANIMATON SYSTEM HERE --Knit.Get("Module", "Animate").Idle(Model, UnitInfo.UnitId, nil, true);
				if Model:FindFirstChild("_standref") then
					--	if Stan-ds:FindFirstChild(UnitData.stand):FindFirstChild("idle") then
					--	Model._standref.Value._standanimationref.Value:LoadAnimation(Stands:FindFirstChild(UnitData.stand).idle):Play();
					--end
				end;
			end
			local CF1
			local CF2
			if Rand6 == 2 then
				CF1 = 1.9;
			elseif Rand6 == 3 then
				CF1 = -1.9;
			else
				CF1 = 0;
			end;
			if Rand6 > 1 then
				CF2 = -0.2;
			else
				CF2 = 0;
			end;
			Rand4[Rand6] = Model;
			Rand5[Rand6] = CFrame.new(CF1, 0,  CF2);
			Rand6 = Rand6 + 1;	
			RunService.RenderStepped:Wait();		
		end;


		local OSCLOCK = os.clock();
		local CFOF = nil;
		local Name
		if Unit then
			Name = 	UnitInfo.name;
			CFOF = UnitData.OffSet;
		else
			Name = UnitInfo.name .. " (x" .. tostring(UnitInfo.amount or 1) .. ")";
		end;
		if UnitInfo and PlayerUnit then
			HatchCenter.UnitName.Text = UnitInfo.Name
			HatchCenter.Rarity.Text = UnitInfo.Rarity
			HatchCenter.Rarity.UIGradient.Color = TraitsModule["TraitColors"][UnitInfo.Rarity].Gradient
			task.spawn(function()
				local gradients = {
					HatchCenter.Rarity.UIGradient
				}
				local valid = false
				repeat
					valid = false
					for _,grad in gradients do
						if Rarity == "Mythical" then
							local t = 2.8
							local range = 7
							grad.Rotation = 0
							local loop = tick() % t / t
							local colors = {}
							for i = 1, range + 1, 1 do
								local z = Color3.fromHSV(loop - ((i - 1)/range), 1, 1)
								if loop - ((i - 1) / range) < 0 then
									z = Color3.fromHSV((loop - ((i - 1) / range)) + 1, 1, 1)
								end
								local d = ColorSequenceKeypoint.new((i - 1) / range, z)
								table.insert(colors, d)
							end
							grad.Color = ColorSequence.new(colors)
							valid = true
						else
							grad.Rotation = (grad.Rotation+2)%360
							valid = true
						end
					end
					task.wait()
				until not valid
			end)
			if Shiny then
				HatchShiny.Visible = true
				--HatchCenter.Shiny.Visible = true
			end
			if TimeObtained ~= nil then
				if TimeObtained == "???" then
					HatchCenter.Limited.Text = `[Limited] - Obtained: ???`
					HatchCenter.Limited.Visible = true
				else
					HatchCenter.Limited.Text = `[Limited] - Obtained: {os.date(nil,TimeObtained)}`
					HatchCenter.Limited.Visible = true
				end
			end
			if Trait ~= "" and Trait ~= nil then
				HatchCenter.Trait.Visible = true
				HatchCenter.Trait.Text = Trait
				if string.find(Trait, "I") or Trait == "Berserker" or Trait == "Expertion" or Trait == "Godspeed" then
					HatchCenter.Trait.Icon.Position = UDim2.new(0.5 - (0.02 * #Trait),0,0.5,0)
				else
					HatchCenter.Trait.Icon.Position = UDim2.new(0.5 - (0.025 * #Trait),0,0.5,0)
				end

				HatchCenter.Trait.UIGradient.Color = TraitsModule["TraitColors"][TraitsModule["Traits"][Trait].Rarity].Gradient
				HatchCenter.Trait.Icon.Image = TraitsModule["Traits"][Trait].ImageID
				HatchCenter.Trait.Icon.UIGradient.Color = TraitsModule["TraitColors"][TraitsModule["Traits"][Trait].Rarity].Gradient

				task.spawn(function()
					local gradients = {
						HatchCenter.Trait.UIGradient,
						HatchCenter.Trait.Icon.UIGradient,
					}
					local valid = false
					repeat
						valid = false
						for _,grad in gradients do
							if HatchCenter:FindFirstChild("Trait") then
								if HatchCenter.Trait.Text == "Immortal" then
									local t = 2.8
									local range = 7
									grad.Rotation = 0
									local loop = tick() % t / t
									local colors = {}
									for i = 1, range + 1, 1 do
										local z = Color3.fromHSV(loop - ((i - 1)/range), 1, 1)
										if loop - ((i - 1) / range) < 0 then
											z = Color3.fromHSV((loop - ((i - 1) / range)) + 1, 1, 1)
										end
										local d = ColorSequenceKeypoint.new((i - 1) / range, z)
										table.insert(colors, d)
									end
									grad.Color = ColorSequence.new(colors)
									valid = true
								else
									grad.Rotation = (grad.Rotation+2)%360
									valid = true
								end
							end
						end
						task.wait()
					until not valid
				end)

			end

			--Check for trait

			local Text : UIGradient = HatchCenter.Rarity
			--	Knit.Get("Module", "GuiUtil").Destroy_OldGradient(Text)
			if Rarity == "Mythical" then
				Text.UIGradient.Rotation = 90
				Text.UIGradient.Color = Rarities[UnitInfo.Rarity].Color
			else
				Text.UIGradient.Color = Rarities[UnitInfo.Rarity].Color
				--	Knit.Get("Module", "Effect").Start(Text.UIGradient)
			end;
			HatchUi.Enabled = true
		end

		if UnitData then

			--			HatchCenter.UnitName.Text = Name
			--HatchCenter.Rarity.Text = UnitInfo.Rarity
			--local Text = HatchCenter.Rarity
			--Knit.Get("Module", "GuiUtil").Destroy_OldGradient(Text)
			if Rarity == "Mythical" then
				--	Text.UIGradient.Rotation = 90
				--	Text.UIGradient.Color = Rarities[UnitInfo.Rarity].Color
			else
				--	Text.UIGradient.Color = Rarities[UnitInfo.Rarity].Color
				--	Knit.Get("Module", "Effect").Start(Text.UIGradient)
			end;
			if ViewModule.infotween_in then
				ViewModule.infotween_in:Cancel();
			end;
			if ViewModule.infotween_in2 then
				ViewModule.infotween_in2:Cancel();
			end;
			if ViewModule.infotween_in3 then
				ViewModule.infotween_in3:Cancel();
			end;
			HatchUi.Enabled = true;
			HatchCenter.Size = UDim2.new(0.25, 0, 0.25, 0)-- UDim2.new(0, 0, 0, 0);
			HatchCenter.Position = UDim2.new(0.5, 0, 0.9, 0);
			ViewModule.infotween_in = TweenService:Create(HatchCenter, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, 0, 0.3, 0)
			});
			ViewModule.infotween_out = TweenService:Create(HatchCenter, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 0, 0, 0)
			});
			ViewModule.infotween_in:Play();
			ViewModule.infotween_in2 = TweenService:Create(HatchShiny, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Size = UDim2.new(0.254, 0, 0.275, 0)
			});
			ViewModule.infotween_out2 = TweenService:Create(HatchShiny, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 0, 0, 0)
			});
			ViewModule.infotween_in2:Play();
			ViewModule.infotween_in3 = TweenService:Create(HatchTakedowns, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Size = UDim2.new(0.168, 0, 0.121, 0)
			});
			ViewModule.infotween_out3 = TweenService:Create(HatchTakedowns, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 0, 0, 0)
			});
			ViewModule.infotween_in3:Play();
			if ViewModule.holder_ui_scale_tween then
				ViewModule.holder_ui_scale_tween:Cancel();
			end;
			HatchCenter.UIScale.Scale = 0;
			ViewModule.holder_ui_scale_tween = TweenService:Create(HatchCenter.UIScale, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Scale = 1
			});
			ViewModule.holder_ui_scale_tween:Play();
			if ViewModule.small_info_scale_tween then
				ViewModule.small_info_scale_tween:Cancel();
			end;
			--HatchBottom.Position = UDim2.new(1.5, -10, 1, -80);
			ViewModule.small_info_scale_tween = TweenService:Create(HatchBottom, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.67, 0,0.92, 0)
			});
			ViewModule.small_info_scale_tween:Play();
		end
		--Knit.Get("Module", "Effect").SetupUnit(Model, UnitInfo.FolderData, UnitInfo.UnitId)
		if UnitInfo.FolderData then
			local Data = UnitInfo.FolderData.Data
			local StatData = Data.statBoosts
			--for i,Range in StatData:GetChildren() do
			--	local StatText : TextLabel = HatchBottom.Stats:FindFirstChild(Range.Name)
			--	if StatText then
			--		HatchBottom.Visible = true
			--		local StatCalcuation = Util.CalcStats({UnitId = UnitInfo.UnitId}, Range.Name, Range.Value)
			--		StatText.Visible = true
			--		StatText.Text = StatCalcuation[1]
			--		StatText.TextColor3 = StatCalcuation[2]
			--		if StatCalcuation[1] == "SSS" then
			--			--Knit.Get("Module", "GuiUtil").Destroy_OldGradient(StatText)
			--			--Knit.Get("Module", "Effect").StartRainbow(StatText.UIGradient)
			--		end
			--	end
			--end
			for _,Trait in UnitInfo.FolderData.traits:GetChildren() do
				--	Util.ApplyTraitEffect(Model, Trait.Id.Value)
				--local TraitInfo = TraitsData[Trait.Id.Value]
				local TraitGuiClone = script.Trait:Clone()
				--local placeholdertrait: ImageLabel = Knit.Get("Module", "GuiUtil").Clone(Trait.Id.Value)
				--placeholdertrait.Parent = TraitGuiClone
				--TraitGuiClone.TraitName.Text = TraitInfo.name
				--placeholdertrait.AnchorPoint = Vector2.new(1, .1)
				--placeholdertrait.Position = UDim2.fromScale(0.45, 0,0.413, 0)
				--local SetRarity = TraitInfo.Rarity
				--if TraitInfo.singular then
				--	DownloadGrad(TraitGuiClone.TraitName, TraitInfo.Rarity)
				--	DownloadGrad(placeholdertrait, SetRarity)
				--else
				--	local TraitMainData = TraitInfo.tiers[Trait.Tier.Value]
				--	TraitGuiClone.TraitName.Text = TraitInfo.name .. " " .. Util.Convertoroman(Trait.Tier.Value)
				--	if TraitMainData.override_rarity then
				--		SetRarity = TraitMainData.override_rarity
				--	end;
				--	DownloadGrad(placeholdertrait, SetRarity)
				--	DownloadGrad(TraitGuiClone.TraitName, SetRarity)
				--end;

				--TraitGuiClone.Parent = HatchCenter
			end
			if UnitInfo.FolderData:FindFirstChild("OriginalOwner") then
				HatchBottom.Owner.Text = "Original Owner: ".. UnitInfo.FolderData:FindFirstChild("OriginalOwner").Value
			else
				--warn("Unable to find owner for uuid: ".. UnitInfo.FolderData.Name)
				HatchBottom.Owner.Text = "Original Owner: "..  game.Players.LocalPlayer.Name
			end
		end
		if CFOF == nil then
			CFOF = CFrame.new();
		end;
		--local sound = Util.PlaySound(3120909354,0.15, 2)
		local MainParticle = script.Inspect:Clone();
		replicate(MainParticle)
		--task.spawn(function()

		--	local function updateColors()
		--		local t = 2.8
		--		local range = 7
		--		local loop = tick() % t / t
		--		local colors = {}

		--		for i = 1, range + 1 do
		--			local z = Color3.fromHSV(loop - ((i - 1) / range), 1, 1)
		--			if loop - ((i - 1) / range) < 0 then
		--				z = Color3.fromHSV((loop - ((i - 1) / range)) + 1, 1, 1)
		--			end
		--			local d = ColorSequenceKeypoint.new((i - 1) / range, z)
		--			table.insert(colors, d)
		--		end
		--		table.sort(colors, function(a, b) return a.Time < b.Time end)  -- Ensure keypoints are ordered by time
		--		return ColorSequence.new(colors)
		--	end

		--	local valid = true

		--	repeat
		--		valid = false
		--		warn("WOR")

		--		if Rarity == "Mythical" then
		--			local colorSequence = updateColors()

		--			for _, attachment in MainParticle.Attachment:GetChildren() do
		--				if attachment:IsA("ParticleEmitter") then
		--					attachment.Color = colorSequence
		--				end
		--			end

		--			valid = true
		--		else
		--			valid = true
		--		end

		--		task.wait(0.1)  -- Control update frequency to reduce lag
		--	until not valid
		--end)

		MainParticle.Parent = workspace.Ignore;
		for _, Particle in MainParticle:GetDescendants() do
			if Particle:IsA("ParticleEmitter") then
				if Rarity ~= nil then
					Particle.Color = Rarities[UnitInfo.Rarity].Color
					if Rarity == "Mythical" then
						--	Knit.Get("Module", "Effect").StartRainbow(Particle)
					end;
				end;
				Particle:Emit(math.max(1, Particle.Rate / 2));
			end;
		end;
		coroutine.wrap(function()
			if NewUnit then
				if Rarity == "Legendary" or Rarity == "Mythical" or Rarity == "Secret"  then
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
								RunService.RenderStepped:Wait();
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
				end
			end
		end)();
		local LoopTrue = true;
		local LoopTrue2 = true;
		local LoopTrue3 = false;

		coroutine.wrap(function()


			local num = 0
			while LoopTrue do
				replicate(Model)
				local Clamp = math.clamp((os.clock() - OSCLOCK) / 1, 0, 1);
				local Easing1 = QuartOut(Clamp, "Quart", "Out");
				local Easing2 = ElasticOut(math.clamp((os.clock() - OSCLOCK) / 1, 0, 1), "Elastic", "Out");
				for Index, OBJJ in Rand4 do
					local Camoffset = CurrentCamera.CFrame * CFrame.new(0, 0, -7.35 + 3.9999999999999996 * Easing2) * Rand5[Index] * CFrame.Angles(0, math.rad(Easing1 * 360), 0) * CFrame.Angles(0, 3.141592653589793, 0);
					OBJJ:PivotTo(Camoffset * CFOF);
					if num == 0 then
						num += 1
						--OBJJ.Parent = game.ReplicatedStorage

					end
					MainParticle.CFrame = Camoffset* CFrame.new(-1.52587891E-05, -0.00043296814, 0.265960693, 1, 8.98941107E-06, 4.2619572E-06, -8.98976123E-06, 1, 8.23723967E-05, -4.26121642E-06, -8.23724331E-05, 1);
				end;
				RunService.RenderStepped:Wait();
				if Clamp >= 1 then
					break;
				end;			
			end;
			if LoopTrue == false or LoopTrue2 == false then
				return;
			end;
			LoopTrue3 = true;
			local OCSLOCK = os.clock();
			local DIVIDENUM = 1.5;
			while LoopTrue2 do
				replicate(Model)
				for Index, PartThing in Rand4 do
					local NewCamOff = CurrentCamera.CFrame * CFrame.new(0, 0, -3.35) * Rand5[Index] * CFrame.Angles(0, 3.141592653589793, 0);
					PartThing:PivotTo(NewCamOff * CFOF);
					MainParticle.CFrame = NewCamOff * CFrame.new(-1.52587891E-05, -0.00043296814, 0.265960693, 1, 8.98941107E-06, 4.2619572E-06, -8.98976123E-06, 1, 8.23723967E-05, -4.26121642E-06, -8.23724331E-05, 1);
				end;
				RunService.RenderStepped:Wait();			
			end;


		end)();

		local ClickLoop = nil;
		ClickLoop = UserInputService.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				ClickLoop:Disconnect();
				ClickLoop = nil;
				LoopTrue2 = false;
				LoopTrue = false;
				local OSCLOCK = os.clock();
				ViewModule.infotween_out:Play()
				ViewModule.infotween_out2:Play()
				ViewModule.infotween_out3:Play()
				while true do
					local Clock = math.clamp((os.clock() - OSCLOCK) / 0.5, 0, 1);
					local Easing3 = BackIn(Clock);
					for Index, PartFound in Rand4 do
						local CFOFFS = CurrentCamera.CFrame * CFrame.new(0, 0, -3.35) * Rand5[Rand6 - 1] * CFrame.new(0, Easing3 * -5, 0) * CFrame.Angles(0, 3.141592653589793, 0);
						PartFound:PivotTo(CFOFFS * CFOF);
						for _, ExtraPaer in MainParticle:GetDescendants() do
							if ExtraPaer:IsA("ParticleEmitter") then
								ExtraPaer.Enabled = false;
							end;
						end;
						MainParticle.CFrame = CFOFFS * CFrame.new(-1.52587891E-05, -0.00043296814, 0.265960693, 1, 8.98941107E-06, 4.2619572E-06, -8.98976123E-06, 1, 8.23723967E-05, -4.26121642E-06, -8.23724331E-05, 1);
					end;
					DepthOfFieldEffect.FarIntensity = 1 - Clock;
					RunService.RenderStepped:Wait();
					if Clock >= 1 then

						break;
					end;				
				end;
				--if sound then
				--	sound:Pause()
				--	sound:Destroy()
				--	end
				if ViewModule.infotween_out.PlaybackState == Enum.PlaybackState.Completed then
					HatchUi:Destroy()
				else
					local outTween; outTween = ViewModule.infotween_out.Completed:Connect(function()
						HatchUi:Destroy()
						outTween:Disconnect()
					end)
				end

				if ViewModule.infotween_out2.PlaybackState == Enum.PlaybackState.Completed then
					HatchUi:Destroy()
				else
					local outTween; outTween = ViewModule.infotween_out2.Completed:Connect(function()
						HatchUi:Destroy()
						outTween:Disconnect()
					end)
				end

				DepthOfFieldEffect:Destroy();
				MainParticle:Destroy();
				for _, tHING in Rand4 do
					tHING:Destroy();
				end;
				game.Players.LocalPlayer.CameraMinZoomDistance = 0.5;
				for _, Object in Rand4 do
					Object:Destroy();
				end;

				if not isFromSummon then
					task.spawn(UiHandler.EnableAllButtons)
					--ENALBE THE UI HERE--Knit.Get("Module", "GuiUtil"):RenableAllWindows()
				end
				if _resumeCallback then
					_resumeCallback()
				end
			end;
		end);
	elseif Hatching.Hatching then
		local CustomColor = Hatching.HatchColor
		local StarPar
		local LevelParticle
		--	Util.PlaySound(4612383453,0.5, 5)
		--	local sound = Util.PlaySound(16050117895,0.15, 5)
		while Rand6 <= 1 do
			local Star = script.Stars.Star:Clone();
			if CustomColor ~= nil then
				Star.StarForcefield.Color = CustomColor;
				Star.StarTemplate.Color = CustomColor;
			end;
			StarPar = script.star_particles:Clone();
			LevelParticle = script.LevelParticle:Clone();
			Star.PrimaryPart.Size = Star.PrimaryPart.Size / 5;
			Star.StarForcefield.Size = Star.StarForcefield.Size / 4.2;
			StarPar.Size = Star.PrimaryPart.Size;
			for _, parpart in StarPar:GetDescendants() do
				if parpart:IsA("ParticleEmitter") then
					parpart.LockedToPart = true;
				end;
			end;
			for _, Des in Star:GetDescendants() do
				if Des:IsA("ParticleEmitter") then
					Des.LockedToPart = true;
				end;
			end;
			Star.Parent = CurrentCamera;
			StarPar.Parent = CurrentCamera;
			LevelParticle.Parent = CurrentCamera;
			if Rand6 == 1 then
				local PointLight = Instance.new("PointLight");
				PointLight.Range = 5;
				PointLight.Brightness = 5;
				PointLight.Parent = Star.PrimaryPart;
			end;
			local RandNum
			if Rand6 == 2 then
				RandNum = 1.8;
			elseif Rand6 == 3 then
				RandNum = -1.8;
			else
				RandNum = 0;
			end;
			local F1
			if Rand6 > 1 then
				F1 = -1;
			else
				F1 = 0;
			end;
			Rand4[Rand6] = Star.PrimaryPart;
			Rand5[Rand6] = CFrame.new(RandNum, 0, F1) * CFrame.Angles(0, 1.5707963267948966, 0);
			Rand6 = Rand6 + 1;			
		end;
		local OsClock1 = os.clock();
		while true do
			local clamp = math.clamp((os.clock() - OsClock1) / 0.85, 0, 1);
			local Ease = ElasticOut(clamp, "Elastic", "Out");
			for Indx, Par in Rand4 do
				Par.CFrame = CurrentCamera.CFrame * CFrame.new(0, 5 - Ease * 5, -7.5 + Ease * 5) * Rand5[Indx];
				StarPar.CFrame = Par.CFrame;
			end;
			DepthOfFieldEffect.FarIntensity = clamp;
			RunService.RenderStepped:Wait();
			if clamp >= 1 then
				break;
			end;			
		end;
		local CFIMP = CFrame.new(0, 0, -2.5);
		local Size1 = Rand4[1].Size;
		local Size2 = Rand4[1].Parent.StarForcefield.Size;
		local Num = 0;
		while true do
			local NextInt = Num % 2 == 0 and Rand:NextNumber(-45, -25) or Rand:NextNumber(25, 45);
			local clomosrf = os.clock();
			local matmaxr = 0.1 / math.max(Num * 0.6, 1);
			Rand4[1].Particles.Core:Emit(1);
			StarPar.Particles.Core:Emit(10);
			LevelParticle:Emit(LevelParticle.Rate);
			while true do
				local Clam = math.clamp((os.clock() - clomosrf) / (matmaxr / 1), 0, 1);
				local EaseM = ElasticOut(Clam);
				for iNDEX, CfOBJ in Rand4 do
					CfOBJ.CFrame = CurrentCamera.CFrame * CFIMP * Rand5[iNDEX] * CFrame.new(0.1 * EaseM, 0, 0) * CFrame.Angles(math.rad(NextInt * EaseM), 0, 0);
					StarPar.CFrame = CurrentCamera.CFrame * CFIMP * Rand5[iNDEX] * CFrame.new(0.1 * EaseM, 0, 0);
				end;
				RunService.RenderStepped:Wait();
				if Clam >= 1 then
					break;
				end;				
			end;
			local Cloos = os.clock();
			local MathMax = 0.4 / math.max(Num * 0.7, 1);
			Rand4[1].Particles.Core:Emit(1);
			StarPar.Particles.Core:Emit(10);
			while true do
				local NewEase = math.clamp((os.clock() - Cloos) / (MathMax / 1), 0, 1);
				local EasinQuad = QuadOut(NewEase);
				for Indx, Obj in Rand4 do
					Obj.CFrame = CurrentCamera.CFrame * CFIMP * Rand5[Indx] * CFrame.new(0.1 - 0.1 * EasinQuad, 0, 0) * CFrame.Angles(math.rad(NextInt - EasinQuad * NextInt), 0, 0);
					--Obj.Pare.StarForcefield.CFrame = CurrentCamera.CFrame * CFIMP * Rand5[Indx] * CFrame.new(0.1 - 0.1 * EasinQuad, 0, 0);
					StarPar.CFrame = CurrentCamera.CFrame * CFIMP * Rand5[Indx] * CFrame.new(0.1 - 0.1 * EasinQuad, 0, 0);
				end;
				RunService.RenderStepped:Wait();
				if NewEase >= 1 then
					break;
				end;				
			end;
			if not (Num < 3) then
				break;
			end;
			Num = Num + 1;			
		end;
		local Ovbloc = os.clock();
		while true do
			local Clam = math.clamp((os.clock() - Ovbloc) / 0.4, 0, 1);
			local EaseOut = QuartOut(Clam, "Quart", "Out");
			for Indx, Obj in Rand4 do
				Obj.Size = Size1 * (1 - EaseOut * 0.75);
				Obj.Parent.StarForcefield.Size = Size2 * (1 - EaseOut * 0.75);
				--Obj.Parent.StarForcefield.CFrame = CurrentCamera.CFrame * CFIMP * Rand5[Indx];
				Obj.CFrame = CurrentCamera.CFrame * CFIMP * Rand5[Indx];
				StarPar.CFrame = Obj.CFrame;
			end;
			RunService.RenderStepped:Wait();
			if Clam >= 1 then
				break;
			end;			
		end;
		game.Debris:AddItem(StarPar, 2);
		game.Debris:AddItem(LevelParticle, 2);
		local Size4 = Rand4[1].Size;
		local Size5 = Rand4[1].Parent.StarForcefield.Size;

		local Oscl = os.clock();
		while true do
			local clamp = math.clamp((os.clock() - Oscl) / 0.075, 0, 1);
			local Easeout = ElasticOut(clamp, "Sine", "Out");
			for Indx, Star in Rand4 do
				Star.Size = Size4 * (Easeout * 5);
				Star.Parent.StarForcefield.Size = Size5 * (Easeout * 5);
				Star.CFrame = CurrentCamera.CFrame * CFIMP * Rand5[Indx];
			end;
			RunService.RenderStepped:Wait();
			if clamp >= 1 then
				break;
			end;			
		end;
		for _, obj in Rand4 do
			obj.Parent:Destroy();
		end;
		DepthOfFieldEffect:Destroy()

		UiHandler.EnableAllButtons()
	end;
end;


local function ColorMove(Part)

	local colors = {
		Color3.fromRGB(255, 0, 0),  
		Color3.fromRGB(255, 165, 0), 
		Color3.fromRGB(255, 255, 0), 
		Color3.fromRGB(0, 255, 0),  
		Color3.fromRGB(0, 255, 255), 
		Color3.fromRGB(0, 0, 255), 
		Color3.fromRGB(128, 0, 128)
	}

	local tweenInfo = TweenInfo.new(
		.5,
		Enum.EasingStyle.Linear
	)
	while true do
		for _, color in colors do
			local tween = TweenService:Create(Part, tweenInfo, {Color = color})
			tween:Play()
			tween.Completed:Wait()
			tween:Destroy()
		end
	end
end
function ViewModule.Item(Info)

	local ItemInfo = Info[1] --{Name}
	local PlayerItem = Info[2]
	local _resumeCallback = Info[3]
	local isFromSummon = Info[4]
	local GetItemModel = require(game.ReplicatedStorage.Modules.GetItemModel)
	local Item = GetItemModel[ItemInfo.Name]
	local HatchUi : ScreenGui = script.HatchInfo:Clone() --Point to the ui here--Knit.Get("Module", "GuiUtil").GetUI("HatchInfo"):Clone()
	local HatchCenter = HatchUi:WaitForChild("Center")
	local HatchBottom = HatchUi:WaitForChild("Bottom")
	HatchUi.Parent = 	game.Players.LocalPlayer.PlayerGui

	-- CLOSE ALL OF THE UI HERE --Knit.Get("Module", "GuiUtil"):CloseAllWindows(" ", true)
	--UiHandler.DisableAllButtons()
	--_G.CloseAll()

	game.Players.LocalPlayer.CameraMinZoomDistance = 10;
	local Info = nil;
	local Rarity  = nil;
	local Trait = PlayerItem and PlayerItem:GetAttribute("Trait") or nil
	local UnitData = nil;
	local Anchor = true;
	if Item then
		Rarity = ItemInfo.Rarity;
		UnitData = ItemInfo
	else
		UnitData = ItemInfo
		Rarity = ItemInfo.Rarity;
	end;
	UnitData.OffSet = CFrame.new(0,0,0)

	local CurrentCamera = game.Workspace.CurrentCamera;
	local Rand = Random.new();
	local DepthOfFieldEffect = Instance.new("DepthOfFieldEffect");
	DepthOfFieldEffect.InFocusRadius = 2.3;
	DepthOfFieldEffect.FarIntensity = 0;
	DepthOfFieldEffect.Parent = game.Lighting;
	--if FarIntensity then
	DepthOfFieldEffect.FarIntensity = 1;
	--end;
	local Model
	local Rand4 = {};
	local Rand5 = {};
	local Rand6 = 1;

	while Rand6 <= 1 do
		local Rand7 = ItemInfo;
		if Item then
			local UnitModel = Item:Clone()
			if UnitModel.Name == "Crystal (Celestial)" then
				UnitModel["Rainboy.001"].SurfaceAppearance:Destroy()
				UnitModel["Rainboy.001"].Transparency = 0.55
				task.spawn(function()
					ColorMove(UnitModel["Rainboy.001"])

				end)
			end
			task.spawn(function()
				local Wrap
				Wrap = RunService.RenderStepped:Connect(function()
					if UnitModel == nil or  UnitModel.Parent == nil then Wrap:Disconnect() end
					for _, Part in (UnitModel:GetDescendants()) do
						if Part:IsA("BasePart") then
							if Part.Name == "HumanoidRootPart" and Anchor then
								Part.Anchored = true;
							else
								Part.Anchored = false;
							end;
							Part.CastShadow = false;
							Part.CanCollide = false;
							Part.CanQuery = false
						end;
					end;
				end)
			end)
			--Util.create_cell_shading(UnitModel, UnitData, nil, nil)
			--UnitModel.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None;
			Model = UnitModel;
		else
			Model = ReplicatedStorage.Assets.Items:FindFirstChild(ItemInfo.item_id):Clone() do
				for _,object in Model:GetDescendants() do
					if object:IsA("BasePart") then
						object.CanQuery = false
					end
				end
			end
		end;

		local pf, pf2, pf3 = Model:GetDescendants();
		if Rand6 == 1 then
			local PointLight = Instance.new("PointLight");
			PointLight.Range = 5;
			PointLight.Brightness = 5;
			PointLight.Parent = Model.PrimaryPart;
		end;

		local StarRelease = nil;
		if Item and Model:FindFirstChild("HumanoidRootPart") then
			Model.HumanoidRootPart.Anchored = true;
			StarRelease = script.LevelParticle:Clone();
			StarRelease.LockedToPart = true;
			StarRelease.Parent = Model.HumanoidRootPart;
		end;
		if Item then
			ScaleModel(Model, 0.6666666666666666 / Model.HumanoidRootPart.Size.X);
		end;


		Model:PivotTo(CurrentCamera.CFrame);
		if Item or ItemInfo  then
			Model.Parent = workspace.Ignore;--game.Players.LocalPlayer.Character;
		else
			Model.Parent = workspace.Ignore;
		end;
		if StarRelease then
			StarRelease:Emit(StarRelease.Rate);
		end;
		--if Item then
		--	local track = Model.Humanoid:LoadAnimation(Model.Animations.Idle)
		--	track:Play()
		--	track:Destroy()
		--	-- REPLACE WITH IDLE ANIMATON SYSTEM HERE --Knit.Get("Module", "Animate").Idle(Model, UnitInfo.UnitId, nil, true);
		--	if Model:FindFirstChild("_standref") then
		--		--	if Stan-ds:FindFirstChild(UnitData.stand):FindFirstChild("idle") then
		--		--	Model._standref.Value._standanimationref.Value:LoadAnimation(Stands:FindFirstChild(UnitData.stand).idle):Play();
		--		--end
		--	end;
		--end
		local CF1
		local CF2
		if Rand6 == 2 then
			CF1 = 1.9;
		elseif Rand6 == 3 then
			CF1 = -1.9;
		else
			CF1 = 0;
		end;
		if Rand6 > 1 then
			CF2 = -0.2;
		else
			CF2 = 0;
		end;
		Rand4[Rand6] = Model;
		Rand5[Rand6] = CFrame.new(CF1, 0,  CF2);
		Rand6 = Rand6 + 1;	
		RunService.RenderStepped:Wait();		
	end;


	local OSCLOCK = os.clock();
	local CFOF = nil;
	local Name
	if Item then
		Name = 	ItemInfo.name;
		CFOF = UnitData.OffSet;
	else
		Name = ItemInfo.name .. " (x" .. tostring(ItemInfo.amount or 1) .. ")";
	end;
	if ItemInfo then
		HatchCenter.UnitName.Text = ItemInfo.Name
		HatchCenter.Rarity.Text = ItemInfo.Rarity
		HatchCenter.Rarity.UIGradient.Color = TraitsModule["TraitColors"][ItemInfo.Rarity].Gradient
		task.spawn(function()
			local gradients = {
				HatchCenter.Rarity.UIGradient
			}
			local valid = false
			repeat
				valid = false
				for _,grad in gradients do
					if Rarity == "Mythical" then
						local t = 2.8
						local range = 7
						grad.Rotation = -83
						local loop = tick() % t / t
						local colors = {}
						for i = 1, range + 1, 1 do
							local z = Color3.fromHSV(loop - ((i - 1)/range), 1, 1)
							if loop - ((i - 1) / range) < 0 then
								z = Color3.fromHSV((loop - ((i - 1) / range)) + 1, 1, 1)
							end
							local d = ColorSequenceKeypoint.new((i - 1) / range, z)
							table.insert(colors, d)
						end
						grad.Color = ColorSequence.new(colors)
						valid = true
					else
						grad.Rotation = (grad.Rotation+2)%360
						valid = true
					end
				end
				task.wait()
			until not valid
		end)
		if Trait ~= "" and Trait ~= nil then
			HatchCenter.Trait.Visible = true
			HatchCenter.Trait.Text = Trait
			HatchCenter.Trait.UIGradient.Color = TraitsModule["TraitColors"][  TraitsModule["Traits"][Trait].Rarity  ].Gradient
			HatchCenter.Trait.Icon.Image = TraitsModule["Traits"][Trait].ImageID
			HatchCenter.Trait.Icon.UIGradient.Color = TraitsModule["TraitColors"][  TraitsModule["Traits"][Trait].Rarity  ].Gradient


		end

		--	--Check for trait



		local Text : UIGradient = HatchCenter.Rarity
		--	Knit.Get("Module", "GuiUtil").Destroy_OldGradient(Text)
		if Rarity == "Mythical" then
			Text.UIGradient.Rotation = 90
			Text.UIGradient.Color = Rarities[ItemInfo.Rarity].Color
		else
			Text.UIGradient.Color = Rarities[ItemInfo.Rarity].Color
			--	Knit.Get("Module", "Effect").Start(Text.UIGradient)
		end;
		HatchUi.Enabled = true
	end

	if UnitData then

		--			HatchCenter.UnitName.Text = Name
		--HatchCenter.Rarity.Text = UnitInfo.Rarity
		--local Text = HatchCenter.Rarity
		--Knit.Get("Module", "GuiUtil").Destroy_OldGradient(Text)
		if Rarity == "Mythical" then
			--	Text.UIGradient.Rotation = 90
			--	Text.UIGradient.Color = Rarities[UnitInfo.Rarity].Color
		else
			--	Text.UIGradient.Color = Rarities[UnitInfo.Rarity].Color
			--	Knit.Get("Module", "Effect").Start(Text.UIGradient)
		end;
		if ViewModule.infotween_in then
			ViewModule.infotween_in:Cancel();
		end;
		HatchUi.Enabled = true;
		HatchCenter.Size = UDim2.new(0.25, 0, 0.25, 0)-- UDim2.new(0, 0, 0, 0);
		HatchCenter.Position = UDim2.new(0.5, 0, 0.9, 0);
		ViewModule.infotween_in = TweenService:Create(HatchCenter, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 0.3, 0)
		});
		ViewModule.infotween_out = TweenService:Create(HatchCenter, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 0)
		});
		ViewModule.infotween_in:Play();
		if ViewModule.holder_ui_scale_tween then
			ViewModule.holder_ui_scale_tween:Cancel();
		end;
		HatchCenter.UIScale.Scale = 0;
		ViewModule.holder_ui_scale_tween = TweenService:Create(HatchCenter.UIScale, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Scale = 1
		});
		ViewModule.holder_ui_scale_tween:Play();
		if ViewModule.small_info_scale_tween then
			ViewModule.small_info_scale_tween:Cancel();
		end;
		--HatchBottom.Position = UDim2.new(1.5, -10, 1, -80);
		ViewModule.small_info_scale_tween = TweenService:Create(HatchBottom, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.67, 0,0.92, 0)
		});
		ViewModule.small_info_scale_tween:Play();
	end
	--Knit.Get("Module", "Effect").SetupUnit(Model, UnitInfo.FolderData, UnitInfo.UnitId)
	if ItemInfo.FolderData then
		local Data = ItemInfo.FolderData.Data
		local StatData = Data.statBoosts
		--for i,Range in StatData:GetChildren() do
		--	local StatText : TextLabel = HatchBottom.Stats:FindFirstChild(Range.Name)
		--	if StatText then
		--		HatchBottom.Visible = true
		--		local StatCalcuation = Util.CalcStats({UnitId = UnitInfo.UnitId}, Range.Name, Range.Value)
		--		StatText.Visible = true
		--		StatText.Text = StatCalcuation[1]
		--		StatText.TextColor3 = StatCalcuation[2]
		--		if StatCalcuation[1] == "SSS" then
		--			--Knit.Get("Module", "GuiUtil").Destroy_OldGradient(StatText)
		--			--Knit.Get("Module", "Effect").StartRainbow(StatText.UIGradient)
		--		end
		--	end
		--end

		if ItemInfo.FolderData:FindFirstChild("OriginalOwner") then
			HatchBottom.Owner.Text = "Original Owner: ".. ItemInfo.FolderData:FindFirstChild("OriginalOwner").Value
		else
			--warn("Unable to find owner for uuid: ".. UnitInfo.FolderData.Name)
			HatchBottom.Owner.Text = "Original Owner: "..  game.Players.LocalPlayer.Name
		end
	end
	if CFOF == nil then
		CFOF = CFrame.new();
	end;
	--local sound = Util.PlaySound(3120909354,0.15, 2)
	local MainParticle = script.Inspect:Clone();
	replicate(MainParticle)

	MainParticle.Parent = workspace.Ignore;
	for _, Particle in MainParticle:GetDescendants() do
		if Particle:IsA("ParticleEmitter") then
			if Rarity ~= nil then
				Particle.Color = Rarities[ItemInfo.Rarity].Color
				if Rarity == "Mythical" then
					--	Knit.Get("Module", "Effect").StartRainbow(Particle)
				end;
			end;
			Particle:Emit(math.max(1, Particle.Rate / 2));
		end;
	end;
	coroutine.wrap(function()
		if NewUnit then
			if Rarity == "Legendary" or Rarity == "Mythical" or Rarity == "Secret"  then
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
							RunService.RenderStepped:Wait();
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
			end
		end
	end)();
	local LoopTrue = true;
	local LoopTrue2 = true;
	local LoopTrue3 = false;

	coroutine.wrap(function()


		local num = 0
		while LoopTrue do
			replicate(Model)
			local Clamp = math.clamp((os.clock() - OSCLOCK) / 1, 0, 1);
			local Easing1 = QuartOut(Clamp, "Quart", "Out");
			local Easing2 = ElasticOut(math.clamp((os.clock() - OSCLOCK) / 1, 0, 1), "Elastic", "Out");
			for Index, OBJJ in Rand4 do
				local Camoffset = CurrentCamera.CFrame * CFrame.new(0, 0, -7.35 + 3.9999999999999996 * Easing2) * Rand5[Index] * CFrame.Angles(0, math.rad(Easing1 * 360), 0) * CFrame.Angles(0, 3.141592653589793, 0);
				OBJJ:PivotTo(Camoffset * CFOF);
				if num == 0 then
					num += 1
					--OBJJ.Parent = game.ReplicatedStorage

				end
				MainParticle.CFrame = Camoffset* CFrame.new(-1.52587891E-05, -0.00043296814, 0.265960693, 1, 8.98941107E-06, 4.2619572E-06, -8.98976123E-06, 1, 8.23723967E-05, -4.26121642E-06, -8.23724331E-05, 1);
			end;
			RunService.RenderStepped:Wait();
			if Clamp >= 1 then
				break;
			end;			
		end;
		if LoopTrue == false or LoopTrue2 == false then
			return;
		end;
		LoopTrue3 = true;
		local OCSLOCK = os.clock();
		local DIVIDENUM = 1.5;
		while LoopTrue2 do
			replicate(Model)
			for Index, PartThing in Rand4 do
				local NewCamOff = CurrentCamera.CFrame * CFrame.new(0, 0, -3.35) * Rand5[Index] * CFrame.Angles(0, 3.141592653589793, 0);
				PartThing:PivotTo(NewCamOff * CFOF);
				MainParticle.CFrame = NewCamOff * CFrame.new(-1.52587891E-05, -0.00043296814, 0.265960693, 1, 8.98941107E-06, 4.2619572E-06, -8.98976123E-06, 1, 8.23723967E-05, -4.26121642E-06, -8.23724331E-05, 1);
			end;
			RunService.RenderStepped:Wait();			
		end;


	end)();

	local ClickLoop = nil;
	ClickLoop = UserInputService.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			ClickLoop:Disconnect();
			ClickLoop = nil;
			LoopTrue2 = false;
			LoopTrue = false;
			local OSCLOCK = os.clock();
			ViewModule.infotween_out:Play()
			while true do
				local Clock = math.clamp((os.clock() - OSCLOCK) / 0.5, 0, 1);
				local Easing3 = BackIn(Clock);
				for Index, PartFound in Rand4 do
					local CFOFFS = CurrentCamera.CFrame * CFrame.new(0, 0, -3.35) * Rand5[Rand6 - 1] * CFrame.new(0, Easing3 * -5, 0) * CFrame.Angles(0, 3.141592653589793, 0);
					PartFound:PivotTo(CFOFFS * CFOF);
					for _, ExtraPaer in MainParticle:GetDescendants() do
						if ExtraPaer:IsA("ParticleEmitter") then
							ExtraPaer.Enabled = false;
						end;
					end;
					MainParticle.CFrame = CFOFFS * CFrame.new(-1.52587891E-05, -0.00043296814, 0.265960693, 1, 8.98941107E-06, 4.2619572E-06, -8.98976123E-06, 1, 8.23723967E-05, -4.26121642E-06, -8.23724331E-05, 1);
				end;
				DepthOfFieldEffect.FarIntensity = 1 - Clock;
				RunService.RenderStepped:Wait();
				if Clock >= 1 then

					break;
				end;				
			end;
			--if sound then
			--	sound:Pause()
			--	sound:Destroy()
			--	end
			if ViewModule.infotween_out.PlaybackState == Enum.PlaybackState.Completed then
				HatchUi:Destroy()
			else
				local outTween; outTween = ViewModule.infotween_out.Completed:Connect(function()
					HatchUi:Destroy()
					outTween:Disconnect()
				end)
			end



			DepthOfFieldEffect:Destroy();
			MainParticle:Destroy();
			for _, tHING in Rand4 do
				tHING:Destroy();
			end;
			game.Players.LocalPlayer.CameraMinZoomDistance = 0.5;
			for _, Object in Rand4 do
				Object:Destroy();
			end;

			if not isFromSummon then
				task.spawn(UiHandler.EnableAllButtons)
				--ENALBE THE UI HERE--Knit.Get("Module", "GuiUtil"):RenableAllWindows()
			end
			if _resumeCallback then
				_resumeCallback()
			end
		end;
	end);
end

return ViewModule