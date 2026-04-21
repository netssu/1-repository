script.Parent.Touched:Connect(function(h)
 local hum = h.Parent:FindFirstChild("Humanoid")
 if hum ~= nil then
  h.parent.HumanoidRootPart.CFrame = CFrame.new(workspace["TelePart1"].Position)
 end
end)