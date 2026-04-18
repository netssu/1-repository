--!strict

local SennaAwakenCameraUtils = {}

export type CameraConfig = {
	CamModelName: string,
	CamPartName: string,
	FrontPartName: string,
	FovPartName: string,
	FovFolderName: string,
}

local function FindCamModel(Root: Instance, CamModelName: string): Model?
	if Root:IsA("Model") and Root.Name == CamModelName then
		return Root :: Model
	end

	local Found: Instance? = Root:FindFirstChild(CamModelName, true)
	if Found and Found:IsA("Model") then
		return Found
	end

	return nil
end

local function FindNamedBasePart(Root: Instance, PartName: string): BasePart?
	local Candidate: Instance? = Root:FindFirstChild(PartName, true)
	if Candidate and Candidate:IsA("BasePart") then
		return Candidate
	end
	return nil
end

local function FindFieldOfViewValue(Root: Instance, FovFolderName: string): ValueBase?
	local FolderInstance: Instance? = Root:FindFirstChild(FovFolderName, true)
	if FolderInstance then
		local NumberValue: NumberValue? = FolderInstance:FindFirstChildWhichIsA("NumberValue", true)
		if NumberValue then
			return NumberValue
		end

		local IntValue: IntValue? = FolderInstance:FindFirstChildWhichIsA("IntValue", true)
		if IntValue then
			return IntValue
		end
	end

	return nil
end

function SennaAwakenCameraUtils.FindCamModel(Root: Instance, CamModelName: string): Model?
	return FindCamModel(Root, CamModelName)
end

function SennaAwakenCameraUtils.FindCamTargets(
	Root: Instance,
	Config: CameraConfig
): (BasePart?, BasePart?, BasePart?, AnimationController?, ValueBase?)
	local CamModel: Model? = FindCamModel(Root, Config.CamModelName)
	local CamPart: BasePart? = nil
	local FrontPart: BasePart? = nil
	local FovPart: BasePart? = nil
	local CamController: AnimationController? = nil
	local FovValue: ValueBase? = nil

	if CamModel then
		CamPart = FindNamedBasePart(CamModel, Config.CamPartName)
		FrontPart = FindNamedBasePart(CamModel, Config.FrontPartName)
		FovPart = FindNamedBasePart(CamModel, Config.FovPartName)
		CamController = CamModel:FindFirstChildWhichIsA("AnimationController", true)
		FovValue = FindFieldOfViewValue(CamModel, Config.FovFolderName)
	end

	CamPart = CamPart or FindNamedBasePart(Root, Config.CamPartName)
	FrontPart = FrontPart or FindNamedBasePart(Root, Config.FrontPartName)
	FovPart = FovPart or FindNamedBasePart(Root, Config.FovPartName)
	CamController = CamController or Root:FindFirstChildWhichIsA("AnimationController", true)
	FovValue = FovValue or FindFieldOfViewValue(Root, Config.FovFolderName)
	CamPart = CamPart or FrontPart or FovPart

	return CamPart, FrontPart, FovPart, CamController, FovValue
end

return SennaAwakenCameraUtils
