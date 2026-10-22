local U=game:GetService('UserInputService')
local L=game:GetService('Lighting')
local camera=workspace.CurrentCamera
local shots={
 {Vector3.new(-46,11,-33),Vector3.new(5,7,0),10,1.6},
 {Vector3.new(2962,6,0),Vector3.new(3012,4,0),17.4,2.6},
 {Vector3.new(5967,13,24),Vector3.new(6015,7,-2),0,2.5},
 {Vector3.new(-50,25,-38),Vector3.new(0,4,0),10,1.6},
 {Vector3.new(2960,34,-46),Vector3.new(3000,2,0),17.4,2.6},
 {Vector3.new(5952,32,-50),Vector3.new(6000,0,0),0,2.5},
}
local cf=CFrame.new()
local function shot(i)
 local t=shots[i];cf=CFrame.lookAt(t[1],t[2]);L.ClockTime=t[3];L.Brightness=t[4];L.Ambient=Color3.fromRGB(95,95,108); L.OutdoorAmbient=Color3.fromRGB(125,125,140)
end
shot(2)
U.InputBegan:Connect(function(i) local n=({[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,[Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5,[Enum.KeyCode.Six]=6})[i.KeyCode];if n then shot(n) end end)
game:GetService('RunService').RenderStepped:Connect(function() camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=cf;camera.FieldOfView=70; U.MouseBehavior=Enum.MouseBehavior.Default end)

task.spawn(function()
 local P=game:GetService('Players')
 local ok,rig=pcall(function() return P:CreateHumanoidModelFromUserIdAsync(11808586604) end)
 if not ok then return end
 for _,desc in rig:GetDescendants() do if desc:IsA('BasePart') then desc.Anchored=true;desc.CanCollide=false end end
 for j,at in {Vector3.new(-5,3,-20),Vector3.new(3010,3,3),Vector3.new(6010,5,5)} do
  local clone=rig:Clone();clone.Name='StagedAvatarReference';clone.Parent=workspace;clone:PivotTo(CFrame.new(at))
 end
 rig:Destroy()
end)
