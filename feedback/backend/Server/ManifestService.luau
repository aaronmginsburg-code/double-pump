-- V2 authority. Native use requires isolated manual QA policy; legacy keys are never written.
local Legacy=if script then require(script.Parent.FeedbackService) else require("./FeedbackService")
local P=if script then require(script.Parent.Parent.Shared.Protocol) else require("../shared/Protocol")
local U=if script then require(script.Parent.Util) else require("./Util")
local Size=if script then require(script.Parent.RecordSize) else require("./RecordSize")
local Policy=if script then require(script.Parent.NativePolicy)else require("./NativePolicy")
local R=if script then require(script.Parent.BroadcastRecord)else require("./BroadcastRecord")
local Service={};Service.__index=Service;setmetatable(Service,{__index=Legacy})
local function fail(code)error(code,0)end
local function ledger(old)return old or {schema=2,revision=0,notes={},history={}}end
local function manifest(old)return old or {schema=2,revision=0,entries={}}end
local function summary(old)return old or {schema=2,entries={}}end
local function bucket(old)return old or {schema=2,revision=0,count=0,reports=0,members={}}end
local function userKey(id)return "v2:u:"..string.format("%.0f",id)end
function Service.new(deps)
 if deps.config.TestMode==true then assert(deps.config.Adapter~="roblox","Native V2 cannot pretend to be TestMode")
 else
  local identity=deps.store.nativeIdentity;assert(identity,"V2 native startup is not authorized")
  local namespace=(if deps.config.NativeRuntimeEnabled then Policy.runtime(deps.config,identity.universe,identity.place,identity.studio)else Policy.v2(deps.config,identity.universe,identity.place))
  assert(namespace==deps.store.namespace,"Native V2 namespace mismatch")
 end
 R.persistent(deps.config)
 local self=Legacy.new(deps);setmetatable(self,Service)
 self.store.writeGuard=function(key)assert(key:sub(1,3)=="v2:","V2_LEGACY_WRITE_FORBIDDEN")end
 self.store.validate=function(value)if value~=nil then local bytes=Size.bytes(value);self.metrics.maxRecordBytes=math.max(self.metrics.maxRecordBytes or 0,bytes);if bytes>self.config.MaxRecordBytes then fail("CAPACITY")end end end
 self.summaryCache={};self.visibilityEpoch=0;self.recoveryCursor=nil;self.repairRunning=false;self.userOffset=0;self.nextScan=0
 self.metrics.v2Repairs=0;self.metrics.projectionFailures=0;self.metrics.queueOverflow=0
 return self
end
function Service:manifestKey(id)return "v2:m:"..U.indexShard(id,self.config.ManifestShards)end
function Service:summaryKey(id)return "v2:d:"..U.indexShard(id,self.config.SummaryShards)end
function Service:invalidate(id,_revision)
 self.visibilityEpoch+=1;self.cache[id]=nil;self.store:invalidate(self:summaryKey(id))
end
function Service:signal(note)
 self:invalidate(note.id,note.revision or 1)
 local ok=pcall(self.publish,{id=note.id,revision=note.revision or 1});if not ok then self.metrics.publishFailures+=1 end
end
function Service:validateManifest(value)
 if value==nil then return manifest(nil)end
 assert(value.schema==2 and type(value.entries)=="table","V2_MANIFEST_UNAVAILABLE")
 return value
end
function Service:gate(id)
 local m=self:validateManifest(self.store:get(self:manifestKey(id)));return m.entries[id]
end
function Service:publicGate(g)
 return g and g.state=="active" and g.universe==self.config.UniverseId and self.clock()-g.timestamp<self.config.PublicSeconds
end
function Service:boundLedger(value)
 assert(value.schema==2 and U.size(value.notes)<=self.config.LedgerLimit and #value.history<=self.config.AuthorHistoryLimit,"V2_LEDGER_CAPACITY")
 return value
end
function Service:putSummary(note,counts)
 if note.filtering or R.persistent(self.config)then assert(R.valid(note,self.config.TestMode==true),"FILTER_PROVENANCE")end
 self.store:update(self:summaryKey(note.id),function(old)
  local d=summary(old);assert(d.schema==2)
  if not d.entries[note.id] and U.size(d.entries)>=self.config.SummariesPerShard then return d end
  local existing=d.entries[note.id]
  if existing then assert(existing.contentRevision==note.contentRevision and existing.userId==note.userId,"V2_SUMMARY_CONFLICT")end
  if not existing or (counts and (counts.revision or 0)>=(existing.aggregateRevision or 0))then
   local entry=U.copy(note);entry.supports=if counts then counts.supports else 0;entry.reportCount=if counts then counts.reports else 0
   entry.aggregateRevision=if counts then counts.revision else 0;d.entries[note.id]=entry
  end
  return d
 end)
 local d=summary(self.store:get(self:summaryKey(note.id)));if not d.entries[note.id]then fail("CAPACITY")end
 self:signal({id=note.id,revision=counts and counts.revision or 1})
end
function Service:checkSubmission(a,payload,fingerprint,now)
 for _,r in ipairs(a.history)do
  if r.op==payload.op then if r.fingerprint~=fingerprint or r.category~=payload.category then fail("CONFLICT")end;return r end
 end
 if a.pending then if a.pending.op~=payload.op or a.pending.fingerprint~=fingerprint or a.pending.category~=payload.category then fail("BUSY")end;return nil end
 local last=-math.huge;local today=0
 for _,r in ipairs(a.history)do
  last=math.max(last,r.at);if now-r.at<self.config.DuplicateSeconds and r.fingerprint==fingerprint then fail("DUPLICATE")end
  if math.floor(r.at/86400)==math.floor(now/86400)then today+=1 end
 end
 if now-last<self.config.Cooldown then fail("COOLDOWN")end
 if today>=self.config.DailyLimit then fail("DAILY_LIMIT")end
 if #a.history>=self.config.AuthorHistoryLimit then fail("CAPACITY")end
 return nil
end
function Service:submit(actor,payload)
 local message=P.message(payload.message);if not message then fail("INVALID")end
 local fingerprint=U.fingerprint(message);local a=self:boundLedger(ledger(self.store:get(userKey(actor.id))))
 local receipt=self:checkSubmission(a,payload,fingerprint,self.clock());if receipt then return {id=receipt.id,saved=true}end
 if not a.pending then
  local safe,proof=self.filter:submit(message,actor.id);if not safe then fail("FILTER")end
  local candidate={schema=2,id=self.id(),op=payload.op,userId=actor.id,author=actor.name,universe=self.config.UniverseId,
   category=payload.category,message=safe,timestamp=math.floor(self.clock()),contentRevision=1,fingerprint=fingerprint}
  R.stamp(candidate,proof,self.config.TestMode==true)
  self.store:update(userKey(actor.id),function(old)
   local current=self:boundLedger(ledger(old));local r=self:checkSubmission(current,payload,fingerprint,self.clock())
   if not r and not current.pending then current.pending=candidate;current.revision+=1 end
   return current
  end)
 end
 self:markUser(actor.id)
 return self:finishSubmissionV2(actor.id,payload.op)
end
function Service:finishSubmissionV2(userId,op)
 local a=self:boundLedger(ledger(self.store:get(userKey(userId))))
 if not a.pending or a.pending.op~=op then
  for _,r in ipairs(a.history)do if r.op==op then return {id=r.id,saved=true}end end;fail("CONFLICT")
 end
 local note=a.pending
 if note.filtering or R.persistent(self.config)then assert(R.valid(note,self.config.TestMode==true),"FILTER_PROVENANCE")end
 local key=self:manifestKey(note.id)
 local m=self.store:update(key,function(old)
  local current=manifest(old);assert(current.schema==2)
  if current.entries[note.id]then assert(current.entries[note.id].op==op and current.entries[note.id].userId==userId,"V2_ID_COLLISION");return current end
  local active,archived=0,0
  for _,g in pairs(current.entries)do if self.clock()-g.timestamp>=self.config.PublicSeconds then archived+=1 else active+=1 end end
  if active>=self.config.ManifestActiveLimit or archived>=self.config.ManifestArchiveLimit or U.size(current.entries)>=self.config.ManifestActiveLimit+self.config.ManifestArchiveLimit then return current end
  current.entries[note.id]={state="pending",revision=1,contentRevision=note.contentRevision,userId=userId,universe=note.universe,op=op,timestamp=note.timestamp,category=note.category,filtering=U.copy(note.filtering)}
  current.revision+=1;return current
 end)
 if not m.entries[note.id]then fail("CAPACITY")end
 local stored=self.store:update("v2:n:"..note.id,function(old)
  if old then assert(old.op==op and old.userId==userId and old.contentRevision==note.contentRevision and (not note.filtering or R.bound(old,note,self.config.TestMode==true)),"V2_IMMUTABLE_CONFLICT");return old end
  return U.copy(note)
 end)
 self:putSummary(stored)
 m=self.store:update(key,function(old)
  local g=old and old.entries[note.id];assert(g and g.contentRevision==note.contentRevision and g.op==op,"V2_GATE_CONFLICT")
  if g.state=="pending"then g.state="active";g.acceptedAt=self.clock();g.revision+=1;old.revision+=1 end
  assert(g.state=="active" or g.state=="hidden","V2_GATE_CONFLICT");return old
 end)
 local acceptedAt=m.entries[note.id].acceptedAt or m.entries[note.id].timestamp
 local finalized=self.store:update(userKey(userId),function(old)
  if old.pending and old.pending.op==op then
   table.insert(old.history,{op=op,id=note.id,at=acceptedAt,fingerprint=note.fingerprint,category=note.category});old.pending=nil;old.revision+=1
  end
  return old
 end)
 self:unmarkIfClean(userId,finalized)
 self:signal({id=note.id,revision=m.entries[note.id].revision});return {id=note.id,saved=true}
end
function Service:markUser(userId,revision)
 if self.dirty[userId] or U.size(self.dirty)<self.config.CacheLimit then self.dirty[userId]=math.max(self.dirty[userId]or 0,revision or 0)else self.metrics.queueOverflow+=1 end
end
function Service:unmarkIfClean(userId,a)
 if a.pending then return false end
 for _,entry in pairs(a.notes)do if entry.dirty then return false end end
 if (self.dirty[userId]or 0)<=a.revision then self.dirty[userId]=nil end
 return true
end
function Service:mutate(actor,action,payload)
 local g=self:gate(payload.id);if not self:publicGate(g)then fail("WITHHELD")end
 local who=tostring(actor.id)
 local a=self.store:update(userKey(actor.id),function(old)
  local l=self:boundLedger(ledger(old));local e=l.notes[payload.id]
  if not e and U.size(l.notes)>=self.config.LedgerLimit then return l end
  e=e or {revision=0,supportRevision=0,supported=false}
  if action=="Support"then
   if e.supportOp==payload.op then return l end
   if e.supportRevision~=payload.expected then return l end
  elseif e.reported then return l end
  local pending=0;for _,v in pairs(l.notes)do if v.dirty then pending+=1 end end
  if not e.dirty and pending>=self.config.PendingPerUser then return l end
  e=U.copy(e);e.revision+=1;e.dirty=true
  if action=="Support"then e.supportRevision+=1;e.supportOp=payload.op;e.supported=payload.desired
  else e.reported=true;e.reason=payload.reason;e.reportAt=self.clock();e.reportOp=payload.op end
  l.notes[payload.id]=e;l.revision+=1;return l
 end)
 local e=a.notes[payload.id];if not e then fail(if U.size(a.notes)>=self.config.LedgerLimit then "CAPACITY"else "BUSY")end
 if action=="Support" and (e.supportOp~=payload.op or e.supported~=payload.desired)then fail(if e.supportRevision~=payload.expected then "CONFLICT" else "BUSY")end
 if action=="Report" and not e.reported then fail("BUSY")end
 self:markUser(actor.id,a.revision)
 local projected=true
 if e.dirty then projected=pcall(function()self:projectEntry(actor.id,payload.id,e)end)end
 if not projected then self.metrics.projectionFailures+=1 end
 if action=="Support"then return {supported=e.supported,supportRevision=e.supportRevision,countsPending=not projected}end
 return {reported=true}
end
function Service:support(actor,payload)return self:mutate(actor,"Support",payload)end
function Service:report(actor,payload)return self:mutate(actor,"Report",payload)end
function Service:projectEntry(userId,id,entry)
 local index=U.shard(userId,self.config.Shards);local who=string.format("%.0f",userId)
 local b=self.store:update("v2:p:"..id..":"..index,function(old)
  local current=bucket(old);local prior=current.members[who]
  if prior and prior.revision>=entry.revision then return current end
  if not prior and U.size(current.members)>=self.config.MembersPerShard then fail("CAPACITY")end
  current.count+=(if entry.supported then 1 else 0)-(if prior and prior.supported then 1 else 0)
  current.reports+=(if entry.reported then 1 else 0)-(if prior and prior.reported then 1 else 0)
  current.members[who]=U.copy(entry);current.members[who].dirty=nil;current.revision+=1;return current
 end)
 local a=self.store:update("v2:a:"..id,function(old)
  local current=old or {schema=2,revision=0,snapshots={},supports=0,reports=0};local prior=current.snapshots[tostring(index)]
  if not prior or b.revision>prior.revision then
   current.snapshots[tostring(index)]={revision=b.revision,count=b.count,reports=b.reports};current.supports=0;current.reports=0
   for _,snapshot in pairs(current.snapshots)do current.supports+=snapshot.count;current.reports+=snapshot.reports end
   current.revision+=1
  end
  return current
 end)
 local note=self.store:get("v2:n:"..id);assert(note,"V2_NOTE_MISSING");self:putSummary(note,a)
 local finalized=self.store:update(userKey(userId),function(old)
  local current=old and old.notes[id];if current and current.revision==entry.revision then current.dirty=nil end;return old
 end)
 self:unmarkIfClean(userId,finalized)
 self.metrics.v2Repairs+=1
end
function Service:hide(actor,payload)
 local m=self.store:update(self:manifestKey(payload.id),function(old)
  local g=old and old.entries[payload.id];if not g then return old end
  if g.state~="hidden"then
   g.state="hidden";g.revision+=1;old.revision+=1
   g.audit={userId=actor.id,at=self.clock(),reason=payload.reason,op=payload.op,reviewAfter=self.clock()+self.config.AuditSeconds}
  end
  return old
 end)
 local g=m and m.entries[payload.id];if not g then fail("WITHHELD")end
 self:signal({id=payload.id,revision=g.revision});return {hidden=true,revision=g.revision}
end
function Service:reviewReports(payload)
 local g=self:gate(payload.id);if not g then fail("WITHHELD")end
 local reasons={};for _,reason in ipairs(P.Reasons)do reasons[reason]=0 end
 for i=1,self.config.Shards do
  local b=bucket(self.store:get("v2:p:"..payload.id..":"..i))
  for _,e in pairs(b.members)do if e.reported then reasons[e.reason]=(reasons[e.reason] or 0)+1 end end
 end
 return {id=payload.id,status=g.state,audit=g.audit,reasons=reasons,countsMayBePending=true}
end
function Service:text(note)
 if (note.filtering or R.persistent(self.config))and not R.valid(note,self.config.TestMode==true)then return nil end
 local c=self.cache[note.id];local now=self.clock()
 if c and c.contentRevision==note.contentRevision and c.expires>now and self.filter.canUseCache and self.filter:canUseCache(note)then self.metrics.cacheHits+=1;return c.message end
 local safe=self.filter:display(note)
 if safe then if U.size(self.cache)>=self.config.CacheLimit then self.cache={}end;self.cache[note.id]={message=safe,contentRevision=note.contentRevision,expires=now+self.config.FilterCacheSeconds}end
 return safe
end
function Service:list(actor,payload,moderator)
 local notes={};local reportHints={};local now=self.clock()
 for i=1,self.config.SummaryShards do
  local d=self.store:derived("v2:d:"..i);if d then assert(d.schema==2);for _,note in pairs(d.entries)do
   if (note.reportCount or 0)>0 then reportHints[note.id]=true end
   if (not payload.category or note.category==payload.category)and(not payload.reportedOnly or note.reportCount>0)then table.insert(notes,note)end
  end end
 end
 table.sort(notes,function(a,b)
  if payload.sort=="Most supported" and a.supports~=b.supports then return a.supports>b.supports end
  if a.timestamp==b.timestamp then return a.id>b.id end
  return if payload.sort=="Oldest"then a.timestamp<b.timestamp else a.timestamp>b.timestamp
 end)
 local offset=0
 if payload.cursor then
  local cursor=self.cursors[payload.cursor]
  if not cursor or cursor.user~=actor.id or cursor.expires<=now or cursor.sort~=payload.sort or cursor.category~=payload.category or cursor.moderator~=moderator or cursor.archived~=payload.archived or cursor.reportedOnly~=payload.reportedOnly then fail("INVALID")end
  offset=cursor.offset
 end
 -- Filter at most CandidateLimit hints before ALL authoritative gate reads.
 local candidates={};local scanned=0
 while offset<#notes and #candidates<math.min(self.config.CandidateLimit,self.config.PageSize) do
  offset+=1;scanned+=1;local n=notes[offset];local safe=self:text(n)
  table.insert(candidates,{note=n,message=safe})
 end
 local a=self:boundLedger(ledger(self.store:get(userKey(actor.id))))
 local epoch=self.visibilityEpoch;local gates={}
 for i=1,self.config.ManifestShards do gates[i]=self:validateManifest(self.store:visibility("v2:m:"..i))end
 if epoch~=self.visibilityEpoch then fail("WITHHELD")end
 local out={};local consumed=0;local stats={active=0,hidden=0,pending=0,archived=0,reported=0}
 for _,m in ipairs(gates)do for id,g in pairs(m.entries)do
  local status=if now-g.timestamp>=self.config.PublicSeconds and g.state=="active"then "archived"else g.state
  if status=="migration"or status=="quarantined"then status="pending"end
  if stats[status]~=nil then stats[status]+=1 end
  if reportHints[id]then stats.reported+=1 end
 end end
 for _,c in ipairs(candidates)do
  consumed+=1;local n=c.note;local g=gates[U.indexShard(n.id,self.config.ManifestShards)].entries[n.id]
  local matches=g and n.schema==2 and n.universe==self.config.UniverseId and g.universe==n.universe and g.userId==n.userId and g.contentRevision==n.contentRevision and g.category==n.category and g.timestamp==n.timestamp and g.op==n.op
  if n.filtering or R.persistent(self.config)then matches=matches and R.bound(n,g,self.config.TestMode==true)end
  local expired=g and self.clock()-g.timestamp>=self.config.PublicSeconds
  local eligible=matches and (if moderator then (if payload.archived then expired else not expired)else self:publicGate(g))
  if eligible and (c.message or moderator)then
   local e=a.notes[n.id]or{supported=false,supportRevision=0}
   table.insert(out,{id=n.id,author=n.author,category=n.category,title=n.category,message=c.message or "Content withheld: filtering could not be verified.",
    withheld=c.message==nil,timestamp=n.timestamp,supports=n.supports,supported=e.supported,supportRevision=e.supportRevision,reported=e.reported==true,
    revision=g.revision,status=if moderator then g.state else nil,audit=if moderator then g.audit else nil,reportCount=if moderator then n.reportCount else nil})
   if #out>=self.config.PageSize then break end
  end
 end
 offset=offset-#candidates+consumed;local nextCursor
 if offset<#notes then
  if U.size(self.cursors)>=self.config.CursorLimit then self.cursors={}end
  nextCursor=self.id();self.cursors[nextCursor]={user=actor.id,expires=now+self.config.CursorSeconds,sort=payload.sort,category=payload.category,moderator=moderator,archived=payload.archived,reportedOnly=payload.reportedOnly,offset=offset}
 end
 return {notes=out,cursor=nextCursor,withheld=consumed-#out,stats=if moderator then stats else nil,leaseSeconds=5,testMode=self.config.TestMode==true,publicReleaseBlocked=self.config.NativeRuntimeEnabled~=true}
end
function Service:repairUser(userId)
 local a=self:boundLedger(ledger(self.store:get(userKey(userId))))
 if a.pending then self:finishSubmissionV2(userId,a.pending.op)end
 local done=0
 for id,e in pairs(a.notes)do if e.dirty then self:projectEntry(userId,id,e);done+=1;if done>=self.config.RepairBatch then return false end end end
 return self:unmarkIfClean(userId,a)
end
function Service:repair()
 if self.repairRunning then return false end
 self.repairRunning=true;self.store:scope("repair",true)
 local ok,result=pcall(function()
  local users={};for userId in pairs(self.dirty)do table.insert(users,userId)end;table.sort(users)
  for _=1,math.min(#users,self.config.RepairBatch)do
   self.userOffset=self.userOffset%#users+1;local userId=users[self.userOffset]
   local completed,clean=pcall(function()return self:repairUser(userId)end)
   -- repairUser clears only the observed ledger generation; never erase a newer hint.
  end
  if self.clock()>=self.nextScan then
   local keys,cursor=self.store:scan("v2:u:",self.recoveryCursor,self.config.RepairBatch)
   for _,key in ipairs(keys)do local id=tonumber(key:match("^v2:u:(%d+)$"));if id then local completed,clean=pcall(function()return self:repairUser(id)end);if not completed or not clean then self:markUser(id)end end end
   self.recoveryCursor=cursor;self.nextScan=self.clock()+self.config.RecoverySeconds
  end
  return true
 end)
 self.store:unscope();self.repairRunning=false
 if not ok then self.store.metrics.deferred+=1;return false end
 return result
end
return Service
