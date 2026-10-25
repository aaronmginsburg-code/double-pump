local U={}
function U.copy(value)
	if type(value)~="table" then return value end
	local result={};for k,v in pairs(value) do result[k]=U.copy(v) end;return result
end
function U.size(t) local n=0;for _ in pairs(t) do n+=1 end;return n end
-- Bounded duplicate fingerprint, not a security credential or reversible text.
function U.fingerprint(message)
	local normalized=message:lower():gsub("%s+"," ")
	local a,b=2166136261,5381
	for i=1,#normalized do local c=normalized:byte(i);a=bit32.bxor(a,c);a=(a*65599)%4294967296;b=(b*33+c)%4294967296 end
	return string.format("%08x%08x:%d",a,b,#normalized)
end
function U.shard(userId,count) return userId%count+1 end
function U.indexShard(id,count) local n=0;for i=1,#id do n=(n*33+id:byte(i))%count end;return n+1 end
return U
