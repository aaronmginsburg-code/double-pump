-- Pure client state. Server data is authoritative; no optimistic reactions/success.
local State={};State.__index=State
function State.new(request,clock,id)
	return setmetatable({request=request,clock=clock,id=id,notes={},sort="Newest",leaseUntil=0,generation=0,
		pageCursor=nil,nextCursor=nil,moderator=false,staff=false,status="Loading feedback…",backend=true,onChanged=function()end},State)
end
function State:changed() self.onChanged() end
function State:capabilities()
	local out=self.request("Capabilities",{})
	if out.ok then self.moderator=out.data.moderator;self.testMode=out.data.testMode end
end
function State:clear(message)
	self.notes={};self.leaseUntil=0;self.status=message;self:changed()
end
function State:refresh(reset)
	if self.refreshing then return end
	if reset then self.pageCursor=nil end
	self.refreshing=true;local generation=self.generation;local started=self.clock()
	local out=self.request(if self.staff then "ModerateList" else "List",{sort=self.sort,category=self.category,cursor=self.pageCursor,reportedOnly=self.reportedOnly,archived=self.archived})
	self.refreshing=false
	if generation~=self.generation then return end
	if not out.ok then
		if out.code=="INVALID" then self.pageCursor=nil end
		self:clear(out.message or "Feedback unavailable.");return
	end
	-- Lease begins when the request began, not after a delayed response arrived.
	if self.clock()>=started+5 then self:clear("Feedback verification expired. Refreshing…");return end
	self.notes=out.data.notes;self.nextCursor=out.data.cursor;self.stats=out.data.stats
	self.leaseUntil=started+math.min(5,out.data.leaseSeconds or 5)
	self.status=if #self.notes==0 then (if (out.data.withheld or 0)>0 then "Notes withheld until filtering and visibility can be verified." else "No feedback on this page yet.") else ""
	self:changed()
end
function State:expire()
	if self.leaseUntil>0 and self.clock()>=self.leaseUntil then self:clear("Revalidating feedback…");return true end
	return false
end
function State:setSort(sort)
	self.sort=sort;self.generation+=1;self.pageCursor=nil;self.nextCursor=nil;self:clear("Loading feedback…")
end
function State:nextPage()
	if not self.nextCursor then return end
	self.generation+=1;self.pageCursor=self.nextCursor;self.nextCursor=nil;self:clear("Loading next page…")
end
function State:list(_mode) return self.notes end
function State:submit(category,message,_author,_timestamp)
	if self.mutating then return nil,"Please wait for the current request." end
	if not self.pendingSubmit or self.pendingSubmit.category~=category or self.pendingSubmit.message~=message then
		self.pendingSubmit={op=self.id(),category=category,message=message}
	end
	self.mutating=true;local result=self.request("Submit",self.pendingSubmit);self.mutating=false
	if not result.ok then return nil,result.message or "The server could not confirm storage. Retry this draft." end
	self.pendingSubmit=nil;self:setSort("Newest")
	return {id=result.data.id,pendingListing=result.data.pendingListing},nil
end
function State:toggle(note)
	if self.mutating then return false,"Please wait for the current request." end
	local pending=note.pendingSupport
	if not pending then pending={id=note.id,op=self.id(),desired=not note.supported,expected=note.supportRevision};note.pendingSupport=pending end
	self.mutating=true;local result=self.request("Support",pending);self.mutating=false
	if not result.ok then
		if result.code=="CONFLICT" then note.pendingSupport=nil;self:clear("Reaction changed. Refreshing…") end
		return false,result.message or "Reaction not confirmed."
	end
	self.generation+=1;note.supported=result.data.supported;note.supportRevision=result.data.supportRevision;note.pendingSupport=nil
	return true
end
function State:report(note,reason)
	if self.mutating then return false,"Please wait for the current request." end
	self.mutating=true;local out=self.request("Report",{id=note.id,op=self.id(),reason=reason});self.mutating=false
	if not out.ok then return false,out.message or "Report not confirmed." end
	self.generation+=1;note.reported=true;return true
end
function State:hide(note,reason)
	if self.mutating then return false,"Please wait for the current request." end
	self.mutating=true;local out=self.request("Hide",{id=note.id,op=self.id(),reason=reason});self.mutating=false
	if not out.ok then return false,out.message or "Hide not confirmed." end
	self.generation+=1;self:clear("Note hidden. Refreshing…");return true
end
return State
