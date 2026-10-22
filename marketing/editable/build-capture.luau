local fs=require('@lune/fs')
local R=require('@lune/roblox')
local Loader=require('../../tests/runner/Loader')
local place=R.deserializePlace(fs.readFile('build/DoublePump_CAMERA_HAND_REVISION.rbxl'))
for _,v in place:GetDescendants() do if v:IsA('BaseScript') then v.Disabled=true end end
for i,name in {'Warehouse','DustTown','Rooftops'} do
 local map=Loader.require(Loader.Server.Maps[name]); local model=map.build(); model.Name='Promo_'..name; for _,d in model:GetDescendants() do if d:IsA("BasePart") then d.CFrame=R.CFrame.new((i-1)*3000,0,0)*d.CFrame end end; model.Parent=place.Workspace
end
for _,d in place:GetDescendants() do if d:IsA("TextLabel") then d.FontFace=R.Font.new("rbxasset://fonts/families/SourceSansPro.json") end end; local s=R.Instance.new('LocalScript');s.Name='MarketingCaptureOnly';s.Source=fs.readFile('marketing/editable/capture-camera.client.luau');s.Parent=place.StarterPlayer.StarterPlayerScripts
fs.writeFile('marketing/editable/DoublePump_CAPTURE_ONLY_V2_DO_NOT_PUBLISH.rbxl',R.serializePlace(place))
print('Built separate capture-only scene, gameplay scripts disabled; original maps exact')


