local P=if script then require(script.Parent.Parent.Shared.Protocol) else require("../shared/Protocol")
local U=if script then require(script.Parent.Util) else require("./Util")
local Guard=if script then require(script.Parent.Guard) else require("./Guard")
local Access=if script then require(script.Parent.StoreAccess) else require("./StoreAccess")
local Service={};Service.__index=Service
local function fail(code) error(code,0) end
local function catalog(old) return old or {schema=1,entries={}} end
local function author(old) return old or {schema=1,history={}} end
local function shard(old) return old or {schema=1,members={},count=0,revision=0} end
local function keyUser(id) return "u:"..tostring(id) end
local function keyNote(id) return "n:"..id end
function Service.new(deps)
	local self=setmetatable({},Service)
	self.config=deps.config;self.rawStore=deps.store;self.store=Access.new(deps.store,deps.config,deps.clock,deps.pause);self.filter=deps.filter;self.clock=deps.clock;self.id=deps.id
	self.publish=deps.publish or function() end;self.eligible=deps.eligible or function() return true end
	self.guard=Guard.new(self.config,self.clock);self.cache={};self.ranks={};self.candidates={};self.cursors={};self.dirty={};self.repairOffset=0;self.workOffset=0;self.authorCursor=nil;self.nextRecovery=0;self.nextWork=0;self.repairRunning=false
	self.metrics={requests=0,failed=0,seconds=0,repaired=0,invalidations=0,publishFailures=0,cacheHits=0}
	for _,id in ipairs(self.config.ModeratorIds) do assert(P.integer(id,1,9007199254740991),"ModeratorIds must contain positive integer UserIds") end
	return self
end
function Service:isModerator(id) return table.find(self.config.ModeratorIds,id)~=nil end
function Service:invalidate(id,revision)
	if not P.token(id,40) or not P.integer(revision,0,1e12) then return end
	self.candidates[id]=nil;self.ranks={}
	local cached=self.cache[id];if cached and revision>=cached.revision then self.cache[id]=nil end
	self.store:invalidate("catalog");self.store:invalidate("i:"..U.indexShard(id,self.config.IndexShards))
	-- No durable work depends on this hint; a round-robin repair sweep is the fallback.
	if U.size(self.dirty)<self.config.MaxActive+self.config.MaxArchive then self.dirty[id]=true end
	self.metrics.invalidations+=1
end
function Service:signal(note)
	self:invalidate(note.id,note.revision)
	local ok=pcall(self.publish,{id=note.id,revision=note.revision})
	if not ok then self.metrics.publishFailures+=1 end
end
function Service:project(note)
	local index=U.indexShard(note.id,self.config.IndexShards);local key="i:"..index
	local current=catalog(self.store:get(key));local entry=current.entries[note.id]
	if entry and entry.revision>=note.revision then return end
	self.store:update(key,function(old)
		local c=catalog(old);local e=c.entries[note.id]
		if not e or (e.revision or 0)<note.revision then
			c.entries[note.id]={id=note.id,timestamp=note.timestamp,category=note.category,supports=note.supports,
				reports=note.reportCount or 0,state=note.status,revision=note.revision}
		end
		return c
	end)
	self.ranks={};self.store:invalidate(key)
end
function Service:indexes()
	local entries={};local expires=self.clock()+self.config.IndexCacheSeconds
	for i=1,self.config.IndexShards do
		local value,untilTime=self.store:derived("i:"..i)
		expires=math.min(expires,untilTime)
		for id,entry in pairs(catalog(value).entries) do entries[id]=entry end
	end
	return entries,expires
end
function Service:reserve(pending)
	local now=self.clock()
	local result=self.store:update("catalog",function(old)
		local c=catalog(old);if c.entries[pending.id] then return c end
		local active,archived,total=0,0,0
		for _,entry in pairs(c.entries) do
			total+=1
			if entry.state=="archived" or entry.timestamp<=now-self.config.PublicSeconds then archived+=1 else active+=1 end
		end
		if active>=self.config.MaxActive or archived>=self.config.MaxArchive or total>=self.config.MaxActive+self.config.MaxArchive then return c end
		c.entries[pending.id]={id=pending.id,timestamp=now,state="pending",revision=0,supports=0,category=pending.category}
		return c
	end)
	if not result.entries[pending.id] then fail("CAPACITY") end
	return result.entries[pending.id]
end
function Service:finishSubmission(userKey,op)
	local record=author(self.store:get(userKey));local pending=record.pending
	if not pending or pending.op~=op then
		for _,receipt in ipairs(record.history) do if receipt.op==op then return {id=receipt.id,saved=true} end end
		fail("CONFLICT")
	end
	local reservation=self:reserve(pending);local acceptedAt=self.clock()
	local note=self.store:update(keyNote(pending.id),function(old)
		if old then return old end
		return {schema=self.config.Schema,id=pending.id,userId=pending.userId,author=pending.author,universe=self.config.UniverseId,
			category=pending.category,message=pending.message,timestamp=reservation.timestamp,acceptedAt=acceptedAt,status="active",revision=1,
			op=pending.op,supports=0,reportCount=0,reactionSnapshots={},reportSnapshots={}}
	end)
	assert(note.userId==pending.userId and note.op==op,"NOTE_COLLISION")
	-- If this finalization fails, durable pending intent repairs it after a restart.
	self.store:update(userKey,function(old)
		local current=author(old)
		if current.pending and current.pending.op==op then
			table.insert(current.history,{op=op,id=note.id,at=note.acceptedAt,fingerprint=pending.fingerprint,category=pending.category})
			current.pending=nil
		end
		return current
	end)
	local indexed=pcall(function() self:project(note) end)
	self:signal(note)
	return {id=note.id,saved=true,pendingListing=not indexed}
end
function Service:submit(actor,payload)
	local message=P.message(payload.message);local fingerprint=U.fingerprint(message);local now=self.clock();local userKey=keyUser(actor.id)
	local old=author(self.store:get(userKey))
	for _,receipt in ipairs(old.history) do
		if receipt.op==payload.op then
			if receipt.fingerprint~=fingerprint or receipt.category~=payload.category then fail("CONFLICT") end
			return {id=receipt.id,saved=true}
		end
	end
	if old.pending then
		if old.pending.op~=payload.op or old.pending.fingerprint~=fingerprint or old.pending.category~=payload.category then fail("BUSY") end
		return self:finishSubmission(userKey,payload.op)
	end
	-- Reject known abuse/capacity states before filtering or preparing new durable
	-- intents. The same checks run atomically below to handle competing servers.
	local today,last=0,-math.huge
	for _,receipt in ipairs(old.history) do
		last=math.max(last,receipt.at)
		if now-receipt.at<self.config.DuplicateSeconds and receipt.fingerprint==fingerprint then fail("DUPLICATE") end
		if math.floor(receipt.at/86400)==math.floor(now/86400) then today+=1 end
	end
	if now-last<self.config.Cooldown then fail("COOLDOWN") end
	if today>=self.config.DailyLimit then fail("DAILY_LIMIT") end
	if #old.history>=self.config.AuthorHistoryLimit then fail("CAPACITY") end
	local capacity=catalog(self.store:get("catalog"));local active,archived,total=0,0,0
	for _,entry in pairs(capacity.entries) do total+=1;if entry.timestamp<=now-self.config.PublicSeconds then archived+=1 else active+=1 end end
	if active>=self.config.MaxActive or archived>=self.config.MaxArchive or total>=self.config.MaxActive+self.config.MaxArchive then fail("CAPACITY") end
	local filtered=self.filter:submit(message,actor.id)
	if not filtered then fail("FILTER") end
	local candidate={id=self.id(),op=payload.op,userId=actor.id,author=actor.name,category=payload.category,message=filtered,timestamp=now,fingerprint=fingerprint}
	local record=self.store:update(userKey,function(prior)
		local a=author(prior)
		if a.pending then return a end
		local today,last=0,-math.huge
		for _,receipt in ipairs(a.history) do
			if receipt.op==payload.op then return a end
			last=math.max(last,receipt.at)
			if math.floor(receipt.at/86400)==math.floor(now/86400) then today+=1 end
			if now-receipt.at<self.config.DuplicateSeconds and receipt.fingerprint==fingerprint then return a end
		end
		if now-last<self.config.Cooldown or today>=self.config.DailyLimit or #a.history>=self.config.AuthorHistoryLimit then return a end
		a.pending=candidate;return a
	end)
	if record.pending and record.pending.op==payload.op and record.pending.fingerprint==fingerprint and record.pending.category==payload.category then
		return self:finishSubmission(userKey,payload.op)
	end
	if record.pending then fail("BUSY") end
	local today,last=0,-math.huge
	for _,receipt in ipairs(record.history) do
		if receipt.op==payload.op then
			if receipt.fingerprint~=fingerprint or receipt.category~=payload.category then fail("CONFLICT") end
			return {id=receipt.id,saved=true}
		end
		last=math.max(last,receipt.at)
		if now-receipt.at<self.config.DuplicateSeconds and receipt.fingerprint==fingerprint then fail("DUPLICATE") end
		if math.floor(receipt.at/86400)==math.floor(now/86400) then today+=1 end
	end
	if #record.history>=self.config.AuthorHistoryLimit then fail("CAPACITY") end
	if now-last<self.config.Cooldown then fail("COOLDOWN") end
	if today>=self.config.DailyLimit then fail("DAILY_LIMIT") end
	fail("CONFLICT")
end
function Service:visible(note,archived)
	if not note or note.schema~=self.config.Schema or note.universe~=self.config.UniverseId then return false end
	if archived then return note.status=="archived" or (note.status=="active" and self.clock()-note.timestamp>=self.config.PublicSeconds) end
	return note.status=="active" and self.clock()-note.timestamp<self.config.PublicSeconds
end
function Service:candidate(id)
	local cached=self.candidates[id]
	if cached and cached.expires>self.clock()then local p=self.store:path(keyNote(id));p.hits+=1;self.store.metrics.hits+=1;return U.copy(cached.value)end
	local note=self.store:get(keyNote(id))
	if U.size(self.candidates)>=self.config.CacheLimit then self.candidates={}end
	self.candidates[id]={value=U.copy(note),expires=self.clock()+self.config.IndexCacheSeconds}
	return note
end
function Service:publicNote(note,viewer,moderator,archived)
	if not moderator and not self:visible(note,false) then return nil end
	if moderator and not note then return nil end
	local cached=self.cache[note.id];local now=self.clock();local message
	-- The adapter still decides author eligibility on every retrieval. No cached text
	-- is used if it can no longer safely produce a display result.
	if cached and cached.revision==note.revision and cached.untilTime>now and self.filter.canUseCache and self.filter:canUseCache(note) then
		message=cached.message;self.metrics.cacheHits+=1
	else
		message=self.filter:display(note)
		if message then
			if U.size(self.cache)>=self.config.CacheLimit then self.cache={} end
			self.cache[note.id]={message=message,revision=note.revision,untilTime=now+self.config.FilterCacheSeconds}
		end
	end
	if not message then return nil end
	local s=shard(self.store:get("s:"..note.id..":"..U.shard(viewer,self.config.Shards)))
	local membership=s.members[tostring(viewer)] or {active=false,revision=0}
	local reports=shard(self.store:get("r:"..note.id..":"..U.shard(viewer,self.config.Shards)))
	-- Filtering AND membership reads yield. Visibility is the final storage check.
	local fresh=self.store:visibility(keyNote(note.id))
	if not fresh or fresh.revision~=note.revision or (not moderator and not self:visible(fresh,false)) then self.candidates[note.id]=nil;return nil end
	return {id=note.id,author=note.author,category=note.category,title=note.category,message=message,timestamp=note.timestamp,
		supports=note.supports,supported=membership.active,supportRevision=membership.revision,revision=note.revision,
		reported=reports.members[tostring(viewer)]~=nil,status=if moderator then note.status else nil,
		reportCount=if moderator then note.reportCount else nil,audit=if moderator then note.audit else nil}
end
function Service:list(actor,payload,moderator)
	local now=self.clock();local c=catalog(self.store:get("catalog"));local projected,rankExpires=self:indexes();local entries={}
 local rankKey=table.concat({payload.sort,payload.category or "all",tostring(moderator),tostring(payload.archived),tostring(payload.reportedOnly)},"|")
 local ranked=self.ranks[rankKey]
 if ranked and ranked.expires>now then entries=ranked.entries;self.metrics.rankHits=(self.metrics.rankHits or 0)+1
 else

	for id,reservation in pairs(c.entries) do
		local e=projected[id] or reservation
		local expired=now-e.timestamp>=self.config.PublicSeconds
		local eligible=if moderator then true else (e.state=="active" or e.state=="pending") and not expired
		if moderator and payload.archived then eligible=eligible and (expired or e.state=="archived") end
		if moderator and not payload.archived then eligible=eligible and not expired and e.state~="archived" end
		if eligible and (not payload.category or e.category==payload.category) and (not payload.reportedOnly or (e.reports or 0)>0) then table.insert(entries,{id=id,timestamp=e.timestamp,supports=e.supports or 0}) end
	end
	table.sort(entries,function(a,b)
		if payload.sort=="Most supported" and a.supports~=b.supports then return a.supports>b.supports end
		if a.timestamp==b.timestamp then return a.id>b.id end
		return if payload.sort=="Oldest" then a.timestamp<b.timestamp else a.timestamp>b.timestamp
	end)
  if U.size(self.ranks)>=self.config.CacheLimit then self.ranks={}end
  self.ranks[rankKey]={entries=entries,expires=rankExpires}
 end
	local offset=0
	if payload.cursor then
		local cursor=self.cursors[payload.cursor]
		if not cursor or cursor.user~=actor.id or cursor.expires<=now or cursor.sort~=payload.sort or cursor.category~=payload.category
			or cursor.moderator~=moderator or cursor.reportedOnly~=payload.reportedOnly or cursor.archived~=payload.archived then fail("INVALID") end
		offset=cursor.offset
	end
	local notes,scanned={},0
	while offset<#entries and #notes<self.config.PageSize and scanned<self.config.CandidateLimit do
		offset+=1;scanned+=1;local note=self:candidate(entries[offset].id)
		if note and (not payload.category or note.category==payload.category) then
			local public=self:publicNote(note,actor.id,moderator,payload.archived)
			if public then table.insert(notes,public)
			elseif moderator then
				-- Staff can still hide/report-review an offline author's note without
				-- receiving its text or any stale cached text.
				table.insert(notes,{id=note.id,author=note.author,category=note.category,title=note.category,
					message="Content withheld: filtering or visibility could not be verified.",timestamp=note.timestamp,
					supports=note.supports,revision=note.revision,status=note.status,reportCount=note.reportCount,withheld=true})
			end
		end
	end
	local nextCursor
	if offset<#entries then
		if U.size(self.cursors)>=self.config.CursorLimit then self.cursors={} end
		nextCursor=self.id();self.cursors[nextCursor]={user=actor.id,expires=now+self.config.CursorSeconds,sort=payload.sort,
			category=payload.category,moderator=moderator,reportedOnly=payload.reportedOnly,archived=payload.archived,offset=offset}
	end
	local stats
	if moderator then
		stats={active=0,archived=0,hidden=0,reported=0,pending=0}
		for id,reservation in pairs(c.entries) do
			local e=projected[id] or reservation
			local status=if e.state=="active" and now-e.timestamp>=self.config.PublicSeconds then "archived" else e.state
			if stats[status]~=nil then stats[status]+=1 end
			if (e.reports or 0)>0 then stats.reported+=1 end
		end
	end
	return {notes=notes,cursor=nextCursor,withheld=scanned-#notes,stats=stats,leaseSeconds=self.config.RevalidateSeconds,
		testMode=self.config.TestMode==true,publicReleaseBlocked=self.config.NativeRuntimeEnabled~=true}
end
function Service:reconcile(id,known)
	local note=self.store:get(keyNote(id));if not note then return end
	local reactions,reports={},{}
	if known then
		(if known.kind=="Support" then reactions else reports)[tostring(known.index)]={revision=known.value.revision,count=known.value.count}
	elseif note.status~="hidden" then
	for i=1,self.config.Shards do
		local s=shard(self.store:get("s:"..id..":"..i));reactions[tostring(i)]={revision=s.revision,count=s.count}
		local r=shard(self.store:get("r:"..id..":"..i));reports[tostring(i)]={revision=r.revision,count=r.count}
	end
	end
	local now=self.clock()
	local needsUpdate=note.status=="active" and now-note.timestamp>=self.config.PublicSeconds
	for _,pair in ipairs({{note.reactionSnapshots,reactions},{note.reportSnapshots,reports}})do
		for index,snapshot in pairs(pair[2])do local previous=pair[1][index];if not previous or snapshot.revision>previous.revision then needsUpdate=true end end
	end
	local updated=if not needsUpdate then note else self.store:update(keyNote(id),function(old)
		if not old then return nil end
		local changed=false
		for _,pair in ipairs({{old.reactionSnapshots,reactions},{old.reportSnapshots,reports}}) do
			for index,snapshot in pairs(pair[2]) do
				local previous=pair[1][index]
				if not previous or snapshot.revision>previous.revision then pair[1][index]=snapshot;changed=true end
			end
		end
		if old.status=="active" and now-old.timestamp>=self.config.PublicSeconds then old.status="archived";changed=true end
		if changed then
			old.supports=0;old.reportCount=0
			for _,s in pairs(old.reactionSnapshots) do old.supports+=s.count end
			for _,r in pairs(old.reportSnapshots) do old.reportCount+=r.count end
			old.revision+=1
		end
		return old
	end)
	self:project(updated)
	if updated.revision~=note.revision then self:signal(updated) end
	self.dirty[id]=nil;self.metrics.repaired+=1
end
-- Durable bounded write-ahead jobs make an ambiguous shard commit discoverable
-- without repeatedly scanning every shard. Workers replay the SAME desired state.
function Service:enqueue(kind,actor,payload)
 local token=kind..":"..payload.id..":"..tostring(actor.id)..":"..payload.op
 local job={kind=kind,userId=actor.id,payload=U.copy(payload),at=self.clock()}
 local queued=self.store:update("work",function(old)
  local q=old or {schema=1,entries={}}
  if not q.entries[token] and U.size(q.entries)<self.config.WorkLimit then q.entries[token]=job end
  return q
 end)
 local saved=queued.entries[token];if not saved then fail("CAPACITY")end
 if saved.payload.expected~=payload.expected or saved.payload.desired~=payload.desired or saved.payload.reason~=payload.reason then fail("CONFLICT")end
 return token,saved
end
function Service:ack(token)
 self.store:update("work",function(old)
  if old and old.entries[token]then old.entries[token]=nil end
  return old
 end)
end
function Service:runWork(token,job)
 local payload=job.payload;local id=payload.id
 local note=self.store:get(keyNote(id))
 if not self:visible(note,false)then self:ack(token);return nil end
 local index=U.shard(job.userId,self.config.Shards);local who=tostring(job.userId)
 local key=(if job.kind=="Support" then "s:" else "r:")..id..":"..index
 local result=self.store:update(key,function(old)
  local value=shard(old)
  if job.kind=="Support" then
   local m=value.members[who]
   if m and m.op==payload.op then return value end
   if (if m then m.revision else 0)~=payload.expected then return value end
   if not m and U.size(value.members)>=self.config.MembersPerShard then return value end
   local previous=if m then m.active else false
   value.members[who]={active=payload.desired,revision=payload.expected+1,op=payload.op}
   if previous~=payload.desired then value.count+=if payload.desired then 1 else -1 end
   value.revision+=1
  elseif not value.members[who] and U.size(value.members)<self.config.ReportsPerShard then
   value.members[who]={reason=payload.reason,at=job.at};value.count+=1;value.revision+=1
  end
  return value
 end)
 self.dirty[id]=true
 local aggregated=pcall(function()self:reconcile(id,{kind=job.kind,index=index,value=result});self:ack(token)end)
 return result.members[who],aggregated
end
function Service:support(actor,payload)
 local note=self.store:get(keyNote(payload.id));if not self:visible(note,false)then fail("WITHHELD")end
 local confirmed=shard(self.store:get("s:"..payload.id..":"..U.shard(actor.id,self.config.Shards))).members[tostring(actor.id)]
 if confirmed and confirmed.op==payload.op and confirmed.active==payload.desired then
  return {supported=confirmed.active,supportRevision=confirmed.revision,countsPending=true}
 end
 local token,job=self:enqueue("Support",actor,payload)
 local membership,aggregated=self:runWork(token,job)
 if not membership then fail("CAPACITY")end
 if membership.op~=payload.op or membership.active~=payload.desired then fail("CONFLICT")end
 return {supported=membership.active,supportRevision=membership.revision,countsPending=not aggregated}
end
function Service:report(actor,payload)
 local note=self.store:get(keyNote(payload.id));if not self:visible(note,false)then fail("WITHHELD")end
 local confirmed=shard(self.store:get("r:"..payload.id..":"..U.shard(actor.id,self.config.Shards))).members[tostring(actor.id)]
 if confirmed then return {reported=true}end
 local token,job=self:enqueue("Report",actor,payload)
 local membership=self:runWork(token,job)
 if not membership then fail("CAPACITY")end
 return {reported=true}
end
function Service:reviewReports(payload)
	local note=self.store:get(keyNote(payload.id));if not note then fail("WITHHELD") end
	local reasons={};for _,reason in ipairs(P.Reasons) do reasons[reason]=0 end
	for i=1,self.config.Shards do
		local r=shard(self.store:get("r:"..payload.id..":"..i))
		for _,entry in pairs(r.members) do reasons[entry.reason]=(reasons[entry.reason] or 0)+1 end
	end
	return {id=note.id,reasons=reasons,status=note.status,audit=note.audit}
end
function Service:hide(actor,payload)
	local now=self.clock()
	local note=self.store:update(keyNote(payload.id),function(old)
		if not old then return nil end
		if old.status~="hidden" then
			old.status="hidden";old.revision+=1
			-- Hide-only moderation needs at most one immutable audit record/note.
			old.audit={userId=actor.id,at=now,reason=payload.reason,op=payload.op,reviewAfter=now+self.config.AuditSeconds}
		end
		return old
	end)
	if not note then fail("WITHHELD") end
	pcall(function() self:project(note) end);self:signal(note);return {hidden=true,revision=note.revision}
end
function Service:repair()
 if self.repairRunning then return end
 self.repairRunning=true;self.store:scope("repair",true)
 local ok,err=pcall(function()
  local now=self.clock()
  if now>=self.nextWork then
   -- Poll the bounded durable queue, not all note shards. Never clear unprocessed work.
   local queue=self.store:get("work") or {entries={}};local tokens={}
   for token in pairs(queue.entries)do table.insert(tokens,token)end;table.sort(tokens)
   for _=1,math.min(#tokens,self.config.RepairBatch)do
    self.workOffset=self.workOffset%#tokens+1;local token=tokens[self.workOffset]
    local completed,_,aggregated=pcall(function()return self:runWork(token,queue.entries[token])end)
    if not completed or aggregated==false then self.metrics.workFailures=(self.metrics.workFailures or 0)+1 end
   end
   self.nextWork=now+self.config.RepairSeconds
  end
  if now>=self.nextRecovery then
   -- Slow bounded legacy/pending-author discovery, with the cursor committed only
   -- after successful processing. Restart starts discovery again; no data deletion.
   local keys,nextCursor=self.store:scan("u:",self.authorCursor,self.config.RepairBatch)
   for _,key in ipairs(keys)do local a=self.store:get(key);if a and a.pending then self:finishSubmission(key,a.pending.op)end end
   local c=catalog(self.store:get("catalog"));local ids={};for id in pairs(c.entries)do table.insert(ids,id)end;table.sort(ids)
   -- One legacy note per recovery interval, not two unconditional full reductions/tick.
   if #ids>0 then local offset=self.repairOffset%#ids+1;self:reconcile(ids[offset]);self.repairOffset=offset end
   self.authorCursor=nextCursor;self.nextRecovery=now+self.config.RecoverySeconds
  end
 end)
 self.store:unscope();self.repairRunning=false
 if not ok then
  self.store.metrics.deferred+=1
  if err=="MAINTENANCE_LIMIT" or tostring(err):find("STORE_BUDGET") or tostring(err):find("STORE_BACKPRESSURE")then return false end
  error(err,0)
 end
 return true
end
function Service:request(actor,action,payload)
	self.metrics.requests+=1;local started=os.clock()
	if not P.integer(actor.id,1,9007199254740991) or type(actor.name)~="string" or #actor.name>32 then return {ok=false,code="INVALID"} end
	if not self.guard:enter(actor.id,action) then return {ok=false,code="BUSY"} end
	self.store:scope(action,false)
	local ok,result=pcall(function()
		if not P.validate(action,payload) then fail("INVALID") end
		local moderator=self:isModerator(actor.id)
		if (action=="ModerateList" or action=="Hide" or action=="ReviewReports") and not moderator then fail("FORBIDDEN") end
		if not self.eligible(actor,action) then fail("FORBIDDEN") end
		if action=="Capabilities" then return {moderator=moderator,testMode=self.config.TestMode==true,publicReleaseBlocked=self.config.NativeRuntimeEnabled~=true} end
		if action=="Submit" then return self:submit(actor,payload) end
		if action=="List" or action=="ModerateList" then return self:list(actor,payload,action=="ModerateList") end
		if action=="Support" then return self:support(actor,payload) end
		if action=="Report" then return self:report(actor,payload) end
		if action=="Hide" then return self:hide(actor,payload) end
		if action=="ReviewReports" then return self:reviewReports(payload) end
		fail("INVALID")
	end)
	self.store:unscope();self.guard:leave(actor.id);self.metrics.seconds+=os.clock()-started
	if not ok then self.metrics.failed+=1;local code=if P.Messages[result] then result else "UNAVAILABLE";return {ok=false,code=code,message=P.Messages[code]} end
	return {ok=true,data=result}
end
return Service
