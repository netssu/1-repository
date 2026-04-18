--!strict

local VisualFx = {}

local DEFAULT_EMIT_COUNT: number = 1

local function ResolveEmitCount(Emitter: ParticleEmitter): number
	local EmitCountValue: any = Emitter:GetAttribute("EmitCount")
	if typeof(EmitCountValue) == "number" and EmitCountValue > 0 then
		return math.max(DEFAULT_EMIT_COUNT, math.floor(EmitCountValue + 0.5))
	end

	return DEFAULT_EMIT_COUNT
end

local function ApplyToMatchingDescendants(
	Root: Instance,
	Callback: (Item: Instance) -> (),
	IncludeBillboards: boolean?
): ()
	local function Apply(Item: Instance): ()
		if Item:IsA("ParticleEmitter")
			or Item:IsA("Beam")
			or Item:IsA("Trail")
			or Item:IsA("Light")
			or (IncludeBillboards == true and Item:IsA("BillboardGui"))
		then
			Callback(Item)
		end
	end

	Apply(Root)
	for _, Descendant: Instance in Root:GetDescendants() do
		Apply(Descendant)
	end
end

function VisualFx.EmitParticles(Root: Instance?): ()
	if not Root then
		return
	end

	ApplyToMatchingDescendants(Root, function(Item: Instance): ()
		if not Item:IsA("ParticleEmitter") then
			return
		end

		Item:Emit(ResolveEmitCount(Item))
	end)
end

function VisualFx.SetTransientEffectsEnabled(Root: Instance?, Enabled: boolean): ()
	if not Root then
		return
	end

	ApplyToMatchingDescendants(Root, function(Item: Instance): ()
		if Item:IsA("ParticleEmitter") or Item:IsA("Beam") or Item:IsA("Trail") then
			Item.Enabled = Enabled
			return
		end

		if Item:IsA("Light") then
			Item.Enabled = Enabled
		end
	end)
end

function VisualFx.SetBillboardsEnabled(Root: Instance?, Enabled: boolean): ()
	if not Root then
		return
	end

	ApplyToMatchingDescendants(Root, function(Item: Instance): ()
		if Item:IsA("BillboardGui") then
			Item.Enabled = Enabled
		end
	end, true)
end

function VisualFx.SetBillboardAdornee(Root: Instance?, Adornee: Instance?): ()
	if not Root then
		return
	end

	ApplyToMatchingDescendants(Root, function(Item: Instance): ()
		if Item:IsA("BillboardGui") then
			Item.Adornee = Adornee
		end
	end, true)
end

function VisualFx.ResolveAttachmentTemplate(Root: Instance?): Attachment?
	if not Root then
		return nil
	end

	if Root:IsA("Attachment") then
		return Root
	end

	return Root:FindFirstChildWhichIsA("Attachment", true)
end

function VisualFx.ResolveFirstBillboard(Root: Instance?): BillboardGui?
	if not Root then
		return nil
	end

	if Root:IsA("BillboardGui") then
		return Root
	end

	return Root:FindFirstChildWhichIsA("BillboardGui", true)
end

function VisualFx.PlaceAtWorldPosition(Target: Instance?, Position: Vector3): boolean
	if not Target then
		return false
	end

	if Target:IsA("Model") then
		Target:PivotTo(CFrame.new(Position))
		return true
	end

	if Target:IsA("BasePart") then
		Target.CFrame = CFrame.new(Position)
		return true
	end

	if Target:IsA("Attachment") then
		if Target.Parent == nil then
			return false
		end
		Target.WorldPosition = Position
		return true
	end

	local NestedAttachment: Attachment? = Target:FindFirstChildWhichIsA("Attachment", true)
	if NestedAttachment and NestedAttachment.Parent then
		NestedAttachment.WorldPosition = Position
		return true
	end

	local NestedModel: Model? = Target:FindFirstChildWhichIsA("Model", true)
	if NestedModel then
		NestedModel:PivotTo(CFrame.new(Position))
		return true
	end

	local NestedPart: BasePart? = Target:FindFirstChildWhichIsA("BasePart", true)
	if NestedPart then
		NestedPart.CFrame = CFrame.new(Position)
		return true
	end

	return false
end

return VisualFx
