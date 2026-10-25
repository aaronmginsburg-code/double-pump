-- Conservative JSON-size accounting for bounded local v2 records (not network bytes).
local Size={}
local function quoted(s)
 local n=2
 for i=1,#s do local c=s:byte(i);n+=if c<32 then 6 elseif c==34 or c==92 or c==47 then 2 else 1 end
 return n
end
function Size.bytes(value)
 local kind=type(value)
 if kind=="string"then return quoted(value)end
 if kind=="number"then assert(value==value and math.abs(value)<math.huge);return math.max(#tostring(value),#string.format("%.17g",value))+2 end
 if kind=="boolean"then return if value then 4 else 5 end
 if kind=="nil"then return 4 end
 assert(kind=="table" and getmetatable(value)==nil,"Unsupported storage value")
 local array=true;local count=0
 for k in pairs(value)do count+=1;if type(k)~="number" or k%1~=0 or k<1 then array=false end end
 if array then for i=1,count do if value[i]==nil then array=false;break end end end
 local n=2;for k,v in pairs(value)do n+=Size.bytes(v)+(if array then 0 else quoted(tostring(k))+1)end
 return n+math.max(0,count-1)
end
return Size
