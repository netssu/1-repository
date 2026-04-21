-- Written by Ace
for i,v in script:GetChildren() do
	task.defer(require, v)
end