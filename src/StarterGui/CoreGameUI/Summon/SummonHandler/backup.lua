function summon(amount, HolocronSummon, isLucky)
	if not _G.canSummon then return end
	if not SummonFrame.Visible then return end 

	_G.canSummon = false

	local result = game.ReplicatedStorage.Functions.SummonBannerEvent:InvokeServer(amount,HolocronSummon, isLucky)

	if typeof(result) ~= "table" then
		task.spawn(function()
			_G.canSummon = true
			UiHandler.PlaySound("Error")
			_G.Message(result,Color3.fromRGB(221, 0, 0))
		end)

		return
	end

	local Skip = nil

	if not isLucky then
		Skip = player:WaitForChild("Settings"):WaitForChild("SummonSkip").Value
		SummonFrame.Visible = false
		if Skip then
			local SkipUIScale = SkipFrame.UIScale
			SkipUIScale.Scale = 0
			SkipFrame.Visible = true
			local Tween = TweenService:Create(SkipUIScale,TweenInfo.new(.5,Enum.EasingStyle.Exponential),{Scale = 1})
			Tween:Play()
			Tween.Completed:Wait()
		end
	end

	for towerindex, Data in result do
		if Skip then
			if Data.Tower ~= nil then
				SummonFrame.Visible = false
				local Unit = Data.Tower
				local UnitStats = Upgrades[Unit.Name]

				if Unit and UnitStats then
					MedalLib.triggerClip(
						'UNIT_SUMMON', 
						'{' .. UnitStats.Rarity .. '} {' .. Unit.Name .. '}',
						{player}, 
						{'SaveClip'},
						{duration = 30}
					)

					if UnitStats.Rarity == "Mythical" then
						UiHandler.CreateConfetti()
					end

					local Template = SkipFrame.Frame.TemplateButton:Clone()
					local UIScale = Template.UIScale

					if UIScale then
						UIScale.Scale = 0
					end

					local GradTable = {
						Template.Image,
						Template.GlowEffect,
					}

					Template.Name = Unit.Name
					Template.LayoutOrder = towerindex
					Template.Parent = SkipFrame.Frame
					Template.Visible = true

					if Unit:GetAttribute("Trait") ~= "" then
						local TraitScale = Template.TraitIcon.UIScale
						TraitScale.Scale = 0
						TweenService:Create(TraitScale,TweenInfo.new(.5,Enum.EasingStyle.Elastic),{Scale = 1}):Play()
						Template.TraitIcon.Visible = true
						Template.TraitIcon.Image = TraitsModule.Traits[Unit:GetAttribute("Trait")].ImageID
						Template.TraitIcon.UIGradient.Color = TraitsModule.TraitColors[TraitsModule.Traits[Unit:GetAttribute("Trait")].Rarity].Gradient
						Template.TraitIcon.UIGradient.Rotation = TraitsModule.TraitColors[TraitsModule.Traits[Unit:GetAttribute("Trait")].Rarity].GradientAngle
					end

					if Unit:GetAttribute("Shiny") then
						Template.Shiny.Visible = true
					end


					local isShiney = Unit and Unit:GetAttribute("Shiny") or false
					local raritiesGrade = {
						Rare = 1,
						Epic = 2,
						Legendary = 3,
						Mythical = 4,
						Unique = 5
					}

					local hasTrait = Unit and Unit:GetAttribute("Trait") ~= "" and Unit:GetAttribute("Trait") or false
					local traitRarity = hasTrait and TraitsModule.Traits[hasTrait] and TraitsModule.Traits[hasTrait].Rarity
					local isTraitMythical = (hasTrait and raritiesGrade[traitRarity] ~= nil and raritiesGrade[traitRarity] >= raritiesGrade.Mythical) or false



					if Data.AutoSell and not Unit:GetAttribute("Shiny") and not isTraitMythical then
						task.spawn(function()
							local SoldScale = Template.Sold.UIScale
							SoldScale.Scale = 0
							Template.Sold.Visible = true
							TweenService:Create(SoldScale,TweenInfo.new(.5,Enum.EasingStyle.Elastic),{Scale = 1}):Play()
						end)
					end

					local ViewPort = ViewPortModule.CreateViewPort(Unit.Name)
					ViewPort.Parent = Template
					ViewPort.ZIndex = 7

					GradientsModule.addRarityGradient(GradTable,UnitStats.Rarity)

					if #result ~= 1 then
						local UnitTween = TweenService:Create(UIScale,TweenInfo.new(.2,Enum.EasingStyle.Elastic),{Scale = 1})
						UnitTween:Play()
						UnitTween.Completed:Wait()
					else
						local UnitTween = TweenService:Create(UIScale,TweenInfo.new(.4,Enum.EasingStyle.Elastic),{Scale = 1})
						UnitTween:Play()
						UnitTween.Completed:Wait()
					end

					--ViewModule.Hatch(statsTower, tower,function () nextUnit = true end)

				end

			else
				warn("wtf")
				_G.Message("You Got WillPower Point!",Color3.fromRGB(212, 28, 236))
				local item = Data.Item
				local itemStats = itemStatsModule.Star


				UiHandler.CreateConfetti()

				local Template = SkipFrame.Frame.TemplateButton:Clone()
				local UIScale = Template.UIScale

				if UIScale then
					UIScale.Scale = 0
				end

				local GradTable = {
					Template.Image,
					Template.GlowEffect,
				}

				Template.Name = item.Name
				Template.LayoutOrder = towerindex
				Template.Parent = SkipFrame.Frame
				Template.Visible = true

				local ViewPort = ViewPortModule.CreateViewPort("Star")
				ViewPort.Parent = Template
				GradientsModule.addRarityGradient(GradTable,itemStats.Rarity)

				if #result ~= 1 then
					local UnitTween = TweenService:Create(UIScale,TweenInfo.new(.2,Enum.EasingStyle.Elastic),{Scale = 1})
					UnitTween:Play()
					UnitTween.Completed:Wait()
				else
					local UnitTween = TweenService:Create(UIScale,TweenInfo.new(.4,Enum.EasingStyle.Elastic),{Scale = 1})
					UnitTween:Play()
					UnitTween.Completed:Wait()
				end

			end
		else
			if Data.Tower ~= nil then
				local tower = Data.Tower
				UiHandler.PlaySound("Redeem")
				SummonFrame.Visible = false
				local Tower = GetUnitModel[tower.Name]
				local statsTower = Upgrades[tower.Name]

				local isShiney = Tower and Tower:GetAttribute("Shiny") or false
				local raritiesGrade = {
					Rare = 1,
					Epic = 2,
					Legendary = 3,
					Mythical = 4,
					Unique = 5
				}

				local hasTrait = tower and tower:GetAttribute("Trait") ~= "" and tower:GetAttribute("Trait") or false
				local traitRarity = hasTrait and TraitsModule.Traits[hasTrait] and TraitsModule.Traits[hasTrait].Rarity
				local isTraitMythical = (hasTrait and raritiesGrade[traitRarity] ~= nil and raritiesGrade[traitRarity] >= raritiesGrade.Mythical) or false

				if Data.AutoSell and not tower:GetAttribute("Shiny") and not isTraitMythical  then
					_G.Message("Unit Sold", Color3.fromRGB(255, 170, 0), true)
				end
				if Tower and statsTower then
					--print('MEDAL_CLIP_TRIGGER:{' .. statsTower.Rarity .. '} {' .. Tower.Name .. '} ')

					MedalLib.triggerClip(
						'UNIT_SUMMON', 
						'{' .. statsTower.Rarity .. '} {' .. Tower.Name .. '}',
						{player}, 
						{'SaveClip'},
						{duration = 30}
					)


					local nextUnit = false

					--ViewModule.Hatch(statsTower, tower,function () nextUnit = true end)

					if statsTower.Rarity == "Mythical" then
						UiHandler.CreateConfetti()
					end


					ViewModule.Hatch({
						statsTower,
						tower,
						function () 
							nextUnit = true 
						end,
						true,
						AutoSummon
					})

					repeat task.wait() until nextUnit

					nextUnit = true
				end
			else
				_G.Message("You Got WillPower Point!",Color3.fromRGB(212, 28, 236))
				local nextItem = false
				local item = Data.Item
				local itemStats = itemStatsModule.Star
				UiHandler.PlaySound("Redeem")
				SummonFrame.Visible = false
				UiHandler.CreateConfetti()
				ViewModule.Item({
					itemStats,
					item,
					function () 
						nextItem = true 
					end,
					"1",
					AutoSummon
				})
				repeat task.wait() until nextItem
			end
		end
	end

	if Skip then
		local SkipUIScale = SkipFrame.UIScale
		SkipFrame.Visible = true
		local Tween = TweenService:Create(SkipUIScale,TweenInfo.new(.25,Enum.EasingStyle.Exponential),{Scale = 0})
		Tween:Play()
		Tween.Completed:Wait()
	end

	for _, v in SkipFrame.Frame:GetChildren() do
		if v:IsA("TextButton") and v.Name ~= "TemplateButton" then
			v:Destroy()
		end
	end

	_G.canSummon = true
	SummonFrame.Visible = true

	if AutoSummon then
		summon(1, HolocronSummon)
		return
	end

	--_G.CloseAll("SummonFrame")
	--UiHandler.DisableAllButtons({'Exp_Frame','Units_Bar',"Currency","Level","SummonFrame"})
end