-- All reads bypass the SDK cache. Only sanitized error codes escape this adapter.
local Store={};Store.__index=Store
local Policy=if script then require(script.Parent.NativePolicy) else require("./NativePolicy")
function Store.new(config,services)
	local studio=game:GetService("RunService"):IsStudio()
 local namespace=if config.NativeRuntimeEnabled then Policy.runtime(config,game.GameId,game.PlaceId,studio)elseif config.StorageVersion==2 then Policy.v2(config,game.GameId,game.PlaceId)else Policy.namespace(config,game.GameId,game.PlaceId)
	return setmetatable({config=config,service=services.DataStoreService,http=services.HttpService,
		db=services.DataStoreService:GetDataStore(namespace),namespace=namespace,calls=0,nativeIdentity={universe=game.GameId,place=game.PlaceId,studio=studio},
		metrics={attempts=0,gets=0,updates=0,lists=0,successes=0,failures=0,budgetRejected=0,retries=0,seconds=0,transformCalls=0,encodedBytes=0}},Store)
end
function Store:halt()
 if self.config.NativeV2QAEnabled or (self.config.NativeRuntimeEnabled and self.config.Environment=="qa") then self.qaHalted=true end
end
function Store:timing(kind,elapsed,ok)
 if self.config.MeasureQALatency~=true then return end
 assert((self.config.Environment=="test" or self.config.Environment=="qa"),"Latency instrumentation is QA-only")
 self.metrics.latency=self.metrics.latency or {};local key=if kind=="gets"or kind=="updates"or kind=="lists"then kind else "other"
 local p=self.metrics.latency[key]or{count=0,failures=0,total=0,maximum=0,buckets={0,0,0,0,0,0}}
 self.metrics.latency[key]=p;p.count+=1;p.failures+=if ok then 0 else 1;p.total+=elapsed;p.maximum=math.max(p.maximum,elapsed)
 local slot=6;for i,limit in ipairs({0.05,0.1,0.25,0.5,1})do if elapsed<=limit then slot=i;break end end;p.buckets[slot]+=1
end
function Store:run(callback,budgets,kind,background)
	local m=self.metrics
	if self.qaHalted then error("QA_PROBE_STOPPED")end
	for attempt=1,self.config.StoreRetries do
		if self.backoffUntil and os.clock()<self.backoffUntil then if m then m.backpressure=(m.backpressure or 0)+1 end;error("STORE_BACKPRESSURE")end
		-- Use the current operation-specific budgets; UpdateAsync consumes both.
		for _,kind in ipairs(budgets) do
			local reserve=0
			if background or self.config.NativeV2QAEnabled or self.config.Environment=="qa" then
				local types=self.requestTypes or Enum.DataStoreRequestType
				reserve=if kind==types.StandardRead then self.config.BackgroundReadReserve elseif kind==types.StandardWrite then self.config.BackgroundWriteReserve else 1
			end
			if self.service:GetRequestBudgetForRequestType(kind)<1+reserve then if m then m.budgetRejected+=1 end;self:halt();error("STORE_BUDGET") end
		end
		if self.config.NativeRuntimeEnabled and self.config.Environment=="qa" then
   local cap=({gets=self.config.NativeRuntimeMaxGets,updates=self.config.NativeRuntimeMaxUpdates,lists=self.config.NativeRuntimeMaxLists})[kind]
   if not cap or m[kind]>=cap then self:halt();error("QA_WORKLOAD_CEILING")end
  end
  if self.config.NativeV2QAEnabled then
   local cap=({gets=self.config.NativeQAMaxGets,updates=self.config.NativeQAMaxUpdates,lists=self.config.NativeQAMaxLists})[kind]
   if not cap or m[kind]>=cap then self:halt();error("QA_WORKLOAD_CEILING")end
  end
  self.calls+=1;local started=os.clock()
		if m then m.attempts+=1;m[kind or "gets"]+=1;if attempt>1 then m.retries+=1 end end
		local ok,value=pcall(callback)
		local elapsed=os.clock()-started;self:timing(kind,elapsed,ok)
		if m then m.seconds+=elapsed;if ok then m.successes+=1 else m.failures+=1 end end
		if ok then return value end
  self:halt()
		if tostring(value):find("Throttled") then self.backoffUntil=os.clock()+10;error("STORE_THROTTLED")end
		if attempt<self.config.StoreRetries then task.wait(math.min(2,0.2*2^(attempt-1))+math.random()*0.15) end
	end
	error("STORE_UNAVAILABLE")
end
function Store:measurePayload(key,kind,value,encodedBytes)
 if self.config.MeasureQAPayloadBytes~=true then return end
 assert((self.config.Environment=="test" or self.config.Environment=="qa"),"Payload instrumentation is QA-only")
 local started=os.clock();local ok,bytes=true,encodedBytes
 if bytes==nil then
  if value==nil then bytes=0 else ok,bytes=pcall(function()return #self.http:JSONEncode(value)end)end
 end
 local m=self.metrics;m.payloadEncodingSeconds=(m.payloadEncodingSeconds or 0)+os.clock()-started
 if not ok then m.payloadEncodingFailures=(m.payloadEncodingFailures or 0)+1;self:halt();return end
 local name=({m="manifest",u="ledger",d="summary",n="note",p="projection",a="aggregate",migration="migration"})[key:match("^v2:([^:]+):")]or"other"
 m.payloads=m.payloads or {};local p=m.payloads[name]or{readCount=0,readBytes=0,readMax=0,writeTransformCount=0,writeTransformBytes=0,writeTransformMax=0};m.payloads[name]=p
 p[kind.."Count"]+=1;p[kind.."Bytes"]+=bytes;p[kind.."Max"]=math.max(p[kind.."Max"],bytes)
end
function Store:get(key,background)
	local options=Instance.new("DataStoreGetOptions");options.UseCache=false
	local value=self:run(function() return self.db:GetAsync(key,options) end,{Enum.DataStoreRequestType.StandardRead},"gets",background)
	self:measurePayload(key,"read",value);return value
end
function Store:update(key,transform,background)
	assert(#key<=50)
	return self:run(function() return self.db:UpdateAsync(key,function(old)
		self.metrics.transformCalls+=1
		local value=transform(old)
		if value~=nil then local bytes=#self.http:JSONEncode(value);self.metrics.encodedBytes+=bytes;self:measurePayload(key,"writeTransform",value,bytes);if bytes>self.config.MaxRecordBytes then error("RECORD_CAPACITY") end end
		return value
	end) end,{Enum.DataStoreRequestType.StandardRead,Enum.DataStoreRequestType.StandardWrite},"updates",background)
end
function Store:scan(prefix,cursor,limit,background)
	-- SDK continuation stays in the server worker; never accept a client token here.
	local pages=cursor
	if not pages then pages=self:run(function() return self.db:ListKeysAsync(prefix,limit) end,{Enum.DataStoreRequestType.StandardList},"lists",background)
	else self:run(function() pages:AdvanceToNextPageAsync();return true end,{Enum.DataStoreRequestType.StandardList},"lists",background) end
	local keys={};for _,entry in ipairs(pages:GetCurrentPage()) do table.insert(keys,entry.KeyName) end
	return keys,if pages.IsFinished then nil else pages
end
return Store
