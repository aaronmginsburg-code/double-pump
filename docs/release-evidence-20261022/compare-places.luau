local fs=require('@lune/fs')
local R=require('@lune/roblox')
local proc=require('@lune/process')
local serde=require('@lune/serde')
local function inventory(path)
 local p=R.deserializePlace(fs.readFile(path));local r={}
 for _,i in p:GetDescendants() do
  if i:IsA('LuaSourceContainer') then r[i:GetFullName()]={class=i.ClassName,source=i.Source:gsub('\r\n','\n')} end
 end
 return r
end
local a=inventory(proc.args[1]);local b=inventory(proc.args[2]);local diffs={};local n=0
for k,v in a do
 n+=1
 if not b[k] then table.insert(diffs,'missing '..k) elseif v.source~=b[k].source or v.class~=b[k].class then table.insert(diffs,'changed '..k) end
end
for k in b do if not a[k] then table.insert(diffs,'extra '..k) end end
print(serde.encode('json',{expectedScripts=n,differences=diffs},true))
assert(#diffs==0,'Source mismatch')
