-- Public protocol only. No permissions or storage configuration belong here.
local P = {}
P.Categories = {"Bug Report", "Feature Suggestion", "Gameplay Feedback", "Balance Issue", "General Feedback"}
P.Reasons = {"Inappropriate", "Personal information", "Spam", "Other"}
P.Sorts = {"Newest", "Oldest", "Most supported"}
P.Messages = {
	INVALID="That request is invalid.", UNAVAILABLE="Feedback is temporarily unavailable. Please try again.",
	CAPACITY="New submissions are temporarily unavailable: storage capacity has been reached.",
	COOLDOWN="Please wait 60 seconds between successful submissions.", DAILY_LIMIT="You can submit five notes per UTC day.",
	DUPLICATE="You already submitted this message in the last 24 hours.", BUSY="Please wait before trying again.",
	FORBIDDEN="You do not have permission for that action.", FILTER="Text could not be safely filtered. Your draft was not submitted.",
	WITHHELD="This note cannot currently be displayed.", CONFLICT="This note changed. Refresh and try again.",
}
local function token(value,maximum)
	return type(value)=="string" and #value>=1 and #value<=maximum and value:match("^[%w_%-]+$")~=nil
end
P.token=token
function P.integer(n,minimum,maximum)
	return type(n)=="number" and n==n and n%1==0 and n>=minimum and n<=maximum
end
function P.message(value)
	if type(value)~="string" or #value>1200 then return nil end
	local length=utf8.len(value)
	if not length or length>300 or value:find("[%z\1-\8\11\12\14-\31\127]") then return nil end
	local clean=value:match("^%s*(.-)%s*$")
	if clean=="" or not clean:find("[^%s]") then return nil end
	return clean
end
local fields={
	List={sort=true,category=true,cursor=true}, Submit={op=true,category=true,message=true},
	Support={op=true,id=true,desired=true,expected=true}, Report={op=true,id=true,reason=true},
	ModerateList={sort=true,category=true,cursor=true,reportedOnly=true,archived=true},
	Hide={op=true,id=true,reason=true}, ReviewReports={id=true}, Capabilities={},
}
function P.validate(action,payload)
	local allowed=fields[action]
	if not allowed or type(payload)~="table" or getmetatable(payload)~=nil then return false end
	local count=0
	for k in pairs(payload) do count+=1;if count>6 or not allowed[k] then return false end end
	if action=="Submit" then return token(payload.op,40) and table.find(P.Categories,payload.category)~=nil and P.message(payload.message)~=nil end
	if action=="Support" then return token(payload.op,40) and token(payload.id,40) and type(payload.desired)=="boolean" and P.integer(payload.expected,0,1e9) end
	if action=="Report" or action=="Hide" then return token(payload.op,40) and token(payload.id,40) and table.find(P.Reasons,payload.reason)~=nil end
	if action=="ReviewReports" then return token(payload.id,40) end
	if action=="List" or action=="ModerateList" then
		return table.find(P.Sorts,payload.sort)~=nil and (payload.category==nil or table.find(P.Categories,payload.category)~=nil)
			and (payload.cursor==nil or token(payload.cursor,40)) and (payload.reportedOnly==nil or type(payload.reportedOnly)=="boolean")
			and (payload.archived==nil or type(payload.archived)=="boolean")
	end
	return true
end
return P
