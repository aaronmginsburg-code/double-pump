-- Starts only the standalone sandbox or an explicitly authorized isolated service test.
local Bootstrap={}
function Bootstrap.start(overrides)
	local root=script.Parent.Parent
	local config=table.clone(require(script.Parent.Config))
	for k,v in pairs(overrides or {}) do config[k]=v end
	local run=game:GetService("RunService")
	require(script.Parent.BroadcastRecord).persistent(config)
	if not config.Adapter or config.Adapter=="disabled" then warn("[Feedback] Disabled: configure an isolated test adapter first.");return nil end
	assert(config.Environment=="test" or config.NativeRuntimeEnabled==true,"Native runtime disabled")
	-- Reject V2 before constructing any native store/service adapter.
	if config.StorageVersion==2 then
  if config.Adapter=="memory"then assert(run:IsStudio(),"Memory sandbox is Studio-only")
  else
   if config.NativeRuntimeEnabled then
    require(script.Parent.NativePolicy).runtime(config,game.GameId,game.PlaceId,run:IsStudio())
    assert(not config.NativeRuntimeManualOnly,"QA runtime requires manual probe")
   else
    require(script.Parent.NativePolicy).v2(config,game.GameId,game.PlaceId)
    assert(not config.NativeV2ManualOnly,"Native V2 candidate must use the manual probe, not automatic Bootstrap")
   end
  end
 end
	local players=game:GetService("Players");local http=game:GetService("HttpService")
	local store,filter
	if config.Adapter=="memory" then
		assert(run:IsStudio(),"Memory sandbox is Studio-only")
		store=require(script.Parent.MemoryStore).new();filter=require(script.Parent.TestFilter).new();config.TestMode=true
	else
		assert(config.Adapter=="roblox","Unknown adapter")
		store=require(script.Parent.RobloxStore).new(config,{DataStoreService=game:GetService("DataStoreService"),HttpService=http})
		filter=require(script.Parent.TextFilter).new(game:GetService("TextService"),players,nil,config);config.TestMode=false
	end
	config.UniverseId=if game.GameId>0 then game.GameId else 1
	local messaging=game:GetService("MessagingService");local topic=if config.TestMode then "UFeedback_memory" else store.namespace
	local remotes=game:GetService("ReplicatedStorage"):FindFirstChild("FeedbackNetwork")
	assert(not remotes,"Feedback backend already started")
	remotes=Instance.new("Folder");remotes.Name="FeedbackNetwork"
	remotes:SetAttribute("StorageMode",if config.TestMode then "memory" else config.Environment)
	local request=Instance.new("RemoteEvent");request.Name="Request";request.Parent=remotes
	local response=Instance.new("RemoteEvent");response.Name="Response";response.Parent=remotes
	local notice=Instance.new("RemoteEvent");notice.Name="Invalidation";notice.Parent=remotes
	local Service=require(if config.StorageVersion==2 then script.Parent.ManifestService else script.Parent.FeedbackService)
	local P=require(root.Shared.Protocol)
	local service=Service.new({config=config,store=store,filter=filter,clock=os.time,id=function()return http:GenerateGUID(false) end,
		publish=function(message)
			-- Clients receive only revision hints, never content or reporter identities.
			notice:FireAllClients(message)
			if not config.TestMode then messaging:PublishAsync(topic,message) end
		end,
		eligible=function(actor,action)
			local player=actor.player
			if not player or player.Parent~=players then return false end
			if action=="Capabilities" or action=="ModerateList" or action=="Hide" or action=="ReviewReports" then return true end
			local character=player.Character;local pivot=character and character:FindFirstChild("HumanoidRootPart")
			local anchor=workspace:FindFirstChild("FeedbackPrompt",true)
			return pivot~=nil and anchor~=nil and anchor.Parent:IsA("BasePart") and (pivot.Position-anchor.Parent.Position).Magnitude<=32
		end})
	if not config.TestMode then
		local ok,connection=pcall(function() return messaging:SubscribeAsync(topic,function(packet)
			local value=packet.Data
			if type(value)=="table" and P.token(value.id,40) and P.integer(value.revision,0,1e12) then service:invalidate(value.id,value.revision);notice:FireAllClients({id=value.id,revision=value.revision}) end
		end) end)
		if ok then Bootstrap.connection=connection else warn("[Feedback] Invalidation subscription unavailable; bounded sweep remains active.") end
	end
	local function actor(player)
		-- Studio multi-client simulation uses negative engine UserIds. Synthetic IDs
		-- exist ONLY with the non-durable Studio adapter, never with real services.
		local id=player.UserId
		if config.TestMode and id<=0 then id=1000000000+math.abs(id) end
		return {id=id,name=player.Name,player=player}
	end
	request.OnServerEvent:Connect(function(player,sequence,action,payload)
		if not P.token(sequence,40) or type(action)~="string" or #action>24 then return end
		local result=service:request(actor(player),action,payload)
		if player.Parent==players then response:FireClient(player,sequence,result) end
	end)
	players.PlayerRemoving:Connect(function(player) service.guard:forget(actor(player).id) end)
	remotes.Parent=game:GetService("ReplicatedStorage")
	task.spawn(function()
		while remotes.Parent do
			task.wait(config.RepairSeconds)
			local ok=pcall(function() service:repair() end)
			if not ok then warn("[Feedback] Repair deferred: storage unavailable or budget exhausted.") end
		end
	end)
	print("[Feedback] Backend ready: "..(if config.TestMode then "STUDIO MEMORY / FIXED SAFE TEST TEXT" else "ROBLOX STORAGE V2").."; "..config.Environment)
	Bootstrap.service=service
	return service
end
return Bootstrap
