local Guard={};Guard.__index=Guard
local rates={List={6,0.4},Submit={2,0.1},Support={5,1},Report={3,0.1},ModerateList={4,0.2},Hide={3,0.2},ReviewReports={3,0.2},Capabilities={2,0.1}}
function Guard.new(config,clock) return setmetatable({config=config,clock=clock,players={},running=0},Guard) end
function Guard:enter(id,action)
	local now=self.clock();local state=self.players[id]
	if not state then state={running=0,buckets={}};self.players[id]=state end
	local rate=rates[action];if not rate then return false end
	local b=state.buckets[action] or {tokens=rate[1],at=now};state.buckets[action]=b
	b.tokens=math.min(rate[1],b.tokens+math.max(0,now-b.at)*rate[2]);b.at=now
	if b.tokens<1 or state.running>=self.config.PerPlayerConcurrent or self.running>=self.config.MaxConcurrent then return false end
	b.tokens-=1;state.running+=1;self.running+=1;return true
end
function Guard:leave(id) local s=self.players[id];if s then s.running-=1;if s.retired and s.running==0 then self.players[id]=nil end end;self.running-=1 end
function Guard:forget(id) local s=self.players[id];if s then if s.running==0 then self.players[id]=nil else s.retired=true end end end
return Guard
