-- Server-generated provenance/binding, not a Roblox certificate or cryptographic signature.
local P=if script then require(script.Parent.Parent.Shared.Protocol)else require("../shared/Protocol")
local R={}
R.Method="TextService.FilterStringAsync/GetNonChatStringForBroadcastAsync"
R.MockMethod="TestFilter.fixed-authored"
function R.experimental(c)
 if c.ExperimentalQAPersistedBroadcastDisplay~=true then return false end
 assert(c.Environment=="test" and c.StorageVersion==2,"Experimental persistent display is QA Storage V2 only")
 return true
end
function R.persistent(c)
 local experimental=R.experimental(c)
 if c.SubmissionBroadcastDisplay~=true then return experimental end
 assert(not experimental and c.NativeRuntimeEnabled==true and c.TestMode==false and c.StorageVersion==2
  and (c.Environment=="production" or c.Environment=="qa"),"Invalid submission broadcast display profile")
 return true
end
function R.text(value)
 return type(value)=="string" and #value>0 and #value<=4800 and utf8.len(value)~=nil and not value:find("[%z\1-\8\11\12\14-\31\127]")
end
function R.digest(message,author)
 -- Exact-byte accidental-corruption check. Trusted server writes remain the security boundary.
 local bytes=#message..":"..message..#author..":"..author;local a,b=2166136261,5381
 for i=1,#bytes do local c=bytes:byte(i);a=bit32.bxor(a,c);a=(a*65599)%4294967296;b=(b*33+c)%4294967296 end
 return string.format("%08x%08x:%d",a,b,#bytes)
end
function R.stamp(note,proof,allowMock)
 assert(type(proof)=="table" and proof.authorId==note.userId and P.integer(proof.filteredAt,0,9007199254740991),"FILTER_PROVENANCE")
 assert(proof.method==R.Method or (allowMock and proof.method==R.MockMethod),"FILTER_METHOD")
 assert(R.text(note.message),"FILTER_REPRESENTATION")
 note.filtering={schema=1,method=proof.method,authorId=note.userId,filteredAt=proof.filteredAt,contentRevision=note.contentRevision,
  noteId=note.id,universe=note.universe,digest=R.digest(note.message,note.author)}
end
function R.valid(note,allowMock)
 if type(note)~="table" or note.schema~=2 or not P.token(note.id,40)or not P.token(note.op,40)
  or not P.integer(note.userId,1,9007199254740991)or not P.integer(note.universe,1,9007199254740991)
  or not P.integer(note.contentRevision,1,1000000000)or not P.integer(note.timestamp,0,9007199254740991)
  or type(note.author)~="string"or #note.author<1 or #note.author>64 or not R.text(note.author)
  or not table.find(P.Categories,note.category)or not R.text(note.message)then return false end
 local p=note.filtering
 return type(p)=="table" and p.schema==1 and (p.method==R.Method or (allowMock and p.method==R.MockMethod))
  and p.authorId==note.userId and p.noteId==note.id and p.universe==note.universe and p.contentRevision==note.contentRevision
  and P.integer(p.filteredAt,0,9007199254740991)and p.digest==R.digest(note.message,note.author)
end
function R.bound(note,gate,allowMock)
 if not R.valid(note,allowMock)or type(gate)~="table"or type(gate.filtering)~="table"then return false end
 for _,field in ipairs({"schema","method","authorId","filteredAt","contentRevision","noteId","universe","digest"})do
  if note.filtering[field]~=gate.filtering[field]then return false end
 end
 return true
end
return R
