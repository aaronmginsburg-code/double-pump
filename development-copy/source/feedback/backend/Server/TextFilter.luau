local R=if script then require(script.Parent.BroadcastRecord)else require("./BroadcastRecord")
local P=if script then require(script.Parent.Parent.Shared.Protocol)else require("../shared/Protocol")
local Filter={};Filter.__index=Filter
function Filter.new(textService,players,context,config,clock)
 local c=config or {};return setmetatable({textService=textService,players=players,context=context or Enum.TextFilterContext.PublicChat,
  experimental=R.persistent(c),clock=clock or os.time,calls=0,failures=0,persistedDisplays=0},Filter)
end
function Filter:apply(message,authorId)
 -- No identity substitution. The server supplies the connected submitting author.
 if not P.integer(authorId,1,9007199254740991)or not self.players:GetPlayerByUserId(authorId)then return nil,"OFFLINE_AUTHOR"end
 self.calls+=1
 local ok,value=pcall(function()
  local result=self.textService:FilterStringAsync(message,authorId,self.context)
  return result:GetNonChatStringForBroadcastAsync()
 end)
 if not ok or not R.text(value)then self.failures+=1;return nil,"FILTER"end
 return value
end
function Filter:submit(message,authorId)
 if not P.message(message)then return nil,"INVALID"end
 local safe,reason=self:apply(message,authorId);if not safe then return nil,reason end
 return safe,{method=R.Method,authorId=authorId,filteredAt=math.floor(self.clock())}
end
function Filter:canUseCache(note)
 if self.experimental then return R.valid(note,false)end
 return self.players:GetPlayerByUserId(note.userId)~=nil
end
function Filter:display(note)
 if self.experimental then
  -- Stored broadcast output only; service verifies the fresh authoritative gate.
  -- Cross-session policy uncertainty is documented, not represented as API certification.
  if not R.valid(note,false)then return nil,"INVALID_PROVENANCE"end
  self.persistedDisplays+=1;return note.message
 end
 -- Default conservative path remains until cross-session compliance is established.
 return self:apply(note.message,note.userId)
end
return Filter
