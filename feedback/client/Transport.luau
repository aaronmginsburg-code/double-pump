local Transport={}
function Transport.new(network)
	local http=game:GetService("HttpService");local pending={};local count=0
	network.Response.OnClientEvent:Connect(function(sequence,result)
		local entry=pending[sequence]
		if entry and type(result)=="table" then entry.result=result;entry.done=true end
	end)
	return function(action,payload)
		if count>=2 then return {ok=false,code="BUSY",message="Please wait for the current request."} end
		local sequence=http:GenerateGUID(false);local entry={done=false};pending[sequence]=entry;count+=1
		network.Request:FireServer(sequence,action,payload)
		local deadline=os.clock()+8
		while not entry.done and os.clock()<deadline do task.wait(0.05) end
		pending[sequence]=nil;count-=1
		return entry.result or {ok=false,code="UNAVAILABLE",message="The server did not confirm the result. Keep your draft and retry."}
	end
end
return Transport
