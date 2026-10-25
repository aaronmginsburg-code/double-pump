-- Server-local read sharing. Authority/membership reads have NO completed cache.
local U=if script then require(script.Parent.Util) else require("./Util")
local Access={};Access.__index=Access
local function family(key)
	if key:sub(1,3)=="v2:"then return ({m="manifest",u="ledger",d="summary",n="note",p="projection",a="aggregate",migration="migration"})[key:match("^v2:([^:]+)")] or "other"end
	local prefix=key:match("^([^:]+):") or key
	return ({n="note",u="author",s="support",r="report",i="index",catalog="catalog",work="work"})[prefix] or "other"
end
function Access.new(db,c,clock,pause)
	return setmetatable({db=db,config=c,clock=clock,pause=pause or function()task.wait()end,cache={},flights={},pending={},flightCount=0,generation=0,
		scopes=setmetatable({},{__mode="k"}),metrics={reads=0,updates=0,lists=0,hits=0,coalesced=0,deferred=0,paths={}}},Access)
end
function Access:scope(name,background)
	local allowed={List=true,ModerateList=true,Submit=true,Support=true,Report=true,Hide=true,ReviewReports=true,Capabilities=true,repair=true}
	self.scopes[coroutine.running()]={name=if allowed[name]then name else "other",background=background,reads=0,updates=0,lists=0}
end
function Access:unscope()self.scopes[coroutine.running()]=nil end
function Access:path(key)
	local scope=self.scopes[coroutine.running()];local name=(if scope then scope.name else "direct").."/"..family(key)
	local p=self.metrics.paths[name]
	if not p then p={reads=0,updates=0,lists=0,hits=0,coalesced=0};self.metrics.paths[name]=p end
	return p,scope
end
function Access:permit(kind,scope)
	if not scope or not scope.background then return end
	local cap=({reads=self.config.BackgroundMaxReads,updates=self.config.BackgroundMaxUpdates,lists=1})[kind]
	if scope[kind]>=cap or (kind=="updates" and scope.reads>=self.config.BackgroundMaxReads)then self.metrics.deferred+=1;error("MAINTENANCE_LIMIT",0)end
	scope[kind]+=1
	if kind=="updates"then scope.reads+=1 end -- UpdateAsync also consumes read capacity.
end
function Access:derived(key)
	assert(key=="catalog" or key:match("^i:%d+$") or key:match("^v2:d:%d+$"),"Only derived discovery data may be cached")
	return self:read(key,self.config.IndexCacheSeconds)
end
function Access:get(key)return self:read(key,0)end
function Access:visibility(key)
	-- Each response needs a read begun AFTER its yielding filter/membership work.
	-- Joining an older in-flight read here could extend that read's display lease.
	local p,scope=self:path(key);self:permit("reads",scope);self.metrics.reads+=1;p.reads+=1
	return self.db:get(key,scope and scope.background)
end
function Access:read(key,ttl)
	local p,scope=self:path(key)
	for _=1,3 do
		local cached=self.cache[key]
		if ttl>0 and cached and cached.expires>self.clock()then self.metrics.hits+=1;p.hits+=1;return U.copy(cached.value),cached.expires end
		local flight=self.flights[key]
		if flight then
			flight.refs+=1;self.metrics.coalesced+=1;p.coalesced+=1
			while not flight.done do self.pause()end
		else
			if self.flightCount>=self.config.ReadFlightLimit then error("BUSY",0)end
			self:permit("reads",scope)
			flight={refs=1};self.flights[key]=flight;self.flightCount+=1
			self.pending[key]=self.pending[key]or{};self.pending[key][flight]=true
			self.metrics.reads+=1;p.reads+=1
			flight.ok,flight.value=pcall(function()return self.db:get(key,scope and scope.background)end)
			flight.done=true
			if self.flights[key]==flight then self.flights[key]=nil end
		end
		flight.refs-=1
		if flight.refs==0 then self.pending[key][flight]=nil;self.flightCount-=1;if next(self.pending[key])==nil then self.pending[key]=nil end end
		if not flight.ok then error(flight.value,0)end
		if not flight.invalid then
			if ttl>0 then
				if U.size(self.cache)>=self.config.CacheLimit then self.cache={}end
				self.cache[key]={value=U.copy(flight.value),expires=self.clock()+ttl}
			end
			return U.copy(flight.value),if ttl>0 then self.cache[key].expires else nil
		end
	end
	error("BUSY",0)
end
function Access:invalidate(key)
	self.cache[key]=nil
	-- Key-local fencing includes completed leaders with waiting consumers.
	for flight in pairs(self.pending[key]or{})do flight.invalid=true end
	self.generation+=1
end
function Access:update(key,transform)
	if self.writeGuard then self.writeGuard(key)end
	local p,scope=self:path(key);self:permit("updates",scope);self.metrics.updates+=1;p.updates+=1
	self:invalidate(key)
	local ok,value=pcall(function()return self.db:update(key,function(old)local value=transform(old);if self.validate then self.validate(value)end;return value end,scope and scope.background)end)
	self:invalidate(key) -- Also invalidate after an ambiguous committed error.
	if not ok then error(value,0)end
	return value
end
function Access:scan(prefix,cursor,limit)
	local p,scope=self:path(prefix);self:permit("lists",scope);self.metrics.lists+=1;p.lists+=1
	return self.db:scan(prefix,cursor,limit,scope and scope.background)
end
return Access
