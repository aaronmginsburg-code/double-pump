local fs=require("@lune/fs")
local R=require("@lune/roblox")
local function scripts(file)
 local place=R.deserializePlace(fs.readFile(file))
 local out={}
 for _,i in place:GetDescendants() do if i:IsA("LuaSourceContainer") then out[i:GetFullName()]=i.Source:gsub("\r\n","\n") end end
 return out,place
end
local actual,place=scripts("build/DoublePump_CLOUD_DOWNLOADED.rbxl")
local expected=scripts("build/DoublePump_PRIVATE_TEST.rbxl")
local count=0
for name,source in expected do assert(actual[name]==source,"source mismatch: "..name) count+=1 end
for name in actual do assert(expected[name],"unexpected script: "..name) end
assert(place.Workspace.FallenPartsDestroyHeight==-120,"wrong destroy height")
print("Published cloud copy matches tested release:",count,"script containers; no extra test scripts")

