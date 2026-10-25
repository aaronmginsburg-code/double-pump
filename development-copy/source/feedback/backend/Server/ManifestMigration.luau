-- Explicit LOCAL migration rehearsal. Source adapter exposes reads only.
local U=if script then require(script.Parent.Util) else require("./Util")
local Migration={};Migration.__index=Migration
function Migration.new(service,legacy)
 assert(service.config.TestMode and service.config.LegacyFrozen,"Legacy writers must be drained/frozen before migration rehearsal")
 return setmetatable({service=service,legacy={get=function(_,key)return legacy:get(key)end}},Migration)
end
function Migration:snapshot(id)
 local s=self.service;local n=self.legacy:get("n:"..id)
 assert(n and n.schema==1 and n.universe==s.config.UniverseId,"LEGACY_SCHEMA_CONFLICT")
 assert(n.status=="active"or n.status=="hidden"or n.status=="archived","LEGACY_STATE_CONFLICT")
 local work=self.legacy:get("work")
 for _,job in pairs(work and work.entries or{})do assert(not job.payload or job.payload.id~=id,"LEGACY_WORK_PENDING")end
 local users={};local revisions={}
 local function user(who)users[who]=users[who]or{supported=false,supportRevision=0,revision=1,dirty=true,origin="v1:"..id};return users[who]end
 for i=1,s.config.Shards do
  local a=self.legacy:get("s:"..id..":"..i)or{revision=0,members={}}
  local b=self.legacy:get("r:"..id..":"..i)or{revision=0,members={}}
  revisions[i]={support=a.revision,report=b.revision}
  for who,e in pairs(a.members)do local v=user(who);v.supported=e.active;v.supportRevision=e.revision;v.supportOp=e.op end
  for who,e in pairs(b.members)do local v=user(who);v.reported=true;v.reason=e.reason;v.reportAt=e.at end
 end
 assert(U.size(users)<=s.config.MigrationMaxUsers,"MIGRATION_BATCH_CAPACITY")
 local author=self.legacy:get("u:"..n.userId)or{history={}}
 assert(not author.pending,"LEGACY_AUTHOR_PENDING")
 return n,users,revisions,author.history
end
function Migration:stage(id)
 local s=self.service;local n,users,revisions,history=self:snapshot(id)
 local order={};for who in pairs(users)do table.insert(order,who)end;table.sort(order)
 local record=s.store:update("v2:migration:"..id,function(old)
  if old then assert(old.sourceRevision==n.revision,"MIGRATION_SOURCE_CHANGED");return old end
  return {schema=2,id=id,sourceRevision=n.revision,sourceState=n.status,sourceAudit=U.copy(n.audit),sourceUser=n.userId,sourceMessage=n.message,sourceCategory=n.category,sourceTimestamp=n.timestamp,
   users=users,order=order,revisions=revisions,history=history,cursor=0,status="staged"}
 end)
 assert(record.status~="rolledBack","MIGRATION_WITHDRAWN");self:verify(record)
 local note={schema=2,id=n.id,op=n.op,userId=n.userId,author=n.author,universe=n.universe,category=n.category,message=n.message,
  timestamp=n.timestamp,contentRevision=1,fingerprint="migrated",origin="v1:"..id}
 local m=s.store:update(s:manifestKey(id),function(old)
  local current=old or{schema=2,revision=0,entries={}};assert(current.schema==2)
  if current.entries[id]then assert(current.entries[id].origin==note.origin,"MIGRATION_TARGET_CONFLICT");return current end
  local active,archive=0,0;for _,g in pairs(current.entries)do if s.clock()-g.timestamp>=s.config.PublicSeconds then archive+=1 else active+=1 end end
  if active>=s.config.ManifestActiveLimit or archive>=s.config.ManifestArchiveLimit then return current end
  current.entries[id]={state="migration",revision=1,contentRevision=1,userId=n.userId,universe=n.universe,op=n.op,timestamp=n.timestamp,category=n.category,origin=note.origin}
  current.revision+=1;return current
 end)
 assert(m.entries[id],"MIGRATION_CAPACITY")
 local stored=s.store:update("v2:n:"..id,function(old)if old then assert(old.origin==note.origin,"MIGRATION_TARGET_CONFLICT");return old end;return note end)
 s:putSummary(stored);return record
end
function Migration:verify(record)
 local n,_,revisions,history=self:snapshot(record.id)
 assert(n.revision==record.sourceRevision and n.status==record.sourceState and n.message==record.sourceMessage and n.userId==record.sourceUser
  and n.category==record.sourceCategory and n.timestamp==record.sourceTimestamp,"MIGRATION_SOURCE_CHANGED")
 assert(#history==#record.history,"MIGRATION_HISTORY_CHANGED")
 for i,r in ipairs(history)do local old=record.history[i];assert(r.op==old.op and r.id==old.id and r.fingerprint==old.fingerprint and r.at==old.at,"MIGRATION_HISTORY_CHANGED")end
 for i,v in ipairs(revisions)do assert(v.support==record.revisions[i].support and v.report==record.revisions[i].report,"MIGRATION_MEMBERS_CHANGED")end
end
function Migration:step(id,limit)
 local s=self.service;assert(limit>=1 and limit<=s.config.RepairBatch)
 local key="v2:migration:"..id;local r=s.store:get(key);assert(r and r.status~="rolledBack","MIGRATION_NOT_STAGED")
 self:verify(r)
 local authorKey="v2:u:"..r.sourceUser
 s.store:update(authorKey,function(old)
  local a=old or{schema=2,revision=0,notes={},history={}};assert(a.schema==2)
  for _,receipt in ipairs(r.history)do
   local found=false;for _,existing in ipairs(a.history)do if existing.op==receipt.op then assert(existing.id==receipt.id and existing.fingerprint==receipt.fingerprint,"MIGRATION_RECEIPT_CONFLICT");found=true end end
   if not found then assert(#a.history<s.config.AuthorHistoryLimit,"MIGRATION_HISTORY_CAPACITY");table.insert(a.history,U.copy(receipt))end
  end
  return a
 end)
 local untilIndex=math.min(#r.order,r.cursor+limit)
 for i=r.cursor+1,untilIndex do
  local who=r.order[i];local entry=r.users[who]
  local a=s.store:update("v2:u:"..who,function(old)
   local l=old or{schema=2,revision=0,notes={},history={}};assert(l.schema==2)
   if l.notes[id]then assert(l.notes[id].origin==entry.origin and l.notes[id].revision==entry.revision,"MIGRATION_LEDGER_CONFLICT")
   else assert(U.size(l.notes)<s.config.LedgerLimit,"MIGRATION_LEDGER_CAPACITY");l.notes[id]=U.copy(entry);l.revision+=1 end
   return l
  end)
  s:projectEntry(tonumber(who),id,a.notes[id])
  s.store:update(key,function(old)old.cursor=math.max(old.cursor,i);return old end)
 end
 r=s.store:get(key)
 if r.cursor==#r.order then
  self:verify(r)
  local m=s.store:update(s:manifestKey(id),function(old)
   local g=old.entries[id];assert(g and g.origin=="v1:"..id,"MIGRATION_GATE_CONFLICT")
   if g.state=="migration"then
    g.state=if r.sourceState=="hidden"then "hidden"elseif r.sourceState=="archived"then "archived"else "active"
    if r.sourceState=="hidden"then g.audit=U.copy(r.sourceAudit)end
    g.revision+=1;old.revision+=1
   end
   return old
  end)
  s.store:update(key,function(old)old.status="complete";return old end);s:signal({id=id,revision=m.entries[id].revision})
  return true
 end
 return false
end
function Migration:withdraw(id)
 local s=self.service
 s.store:update(s:manifestKey(id),function(old)
  local g=old and old.entries[id];if g and g.state~="hidden"then g.state="quarantined";g.revision+=1;old.revision+=1 end;return old
 end)
 s.store:update("v2:migration:"..id,function(old)assert(old);old.status="rolledBack";return old end)
 s:signal({id=id,revision=1})
end
return Migration
