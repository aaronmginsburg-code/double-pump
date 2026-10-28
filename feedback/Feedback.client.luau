local modules=game:GetService("ReplicatedStorage"):WaitForChild("FeedbackClient")
local network=game:GetService("ReplicatedStorage"):WaitForChild("FeedbackNetwork",5)
local prompt=workspace:WaitForChild("UniversalFeedbackBoard",30)
if not prompt then return end
prompt=prompt:FindFirstChild("FeedbackPrompt",true)
local http=game:GetService("HttpService")
local request=if network then require(modules.Transport).new(network) else function()
 return {ok=false,code="UNAVAILABLE",message="Feedback is awaiting release approval. Please try again later."}
end
local state=require(modules.BackendState).new(request,os.clock,function()return http:GenerateGUID(false)end)
local player=game:GetService("Players").LocalPlayer
local client=player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local flow=require(client.Controllers.GameFlow)
local closeFeedback
local function canOpen()
 local c=player.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
 return player:GetAttribute("Mode")=="Practice" and c~=nil and c:GetAttribute("CombatContext")=="Lobby" and h~=nil and h.Health>0
end
local function closeIfNeeded() if closeFeedback and not canOpen() then closeFeedback() end end
player:GetAttributeChangedSignal("Mode"):Connect(closeIfNeeded)
local function watchCharacter(c)
 c:GetAttributeChangedSignal("CombatContext"):Connect(closeIfNeeded)
 c:GetAttributeChangedSignal("SpawnRevision"):Connect(function()if closeFeedback then closeFeedback()end end)
 local h=c:WaitForChild("Humanoid",10)
 if h then h.Died:Connect(function()if closeFeedback then closeFeedback()end end)end
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then task.spawn(watchCharacter,player.Character) end
player.OnTeleport:Connect(function()if closeFeedback then closeFeedback()end end)
local hidden={}
local playerGui=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local function suppress(other)
 if other:IsA("ScreenGui") and other.Name~="FeedbackUI" and hidden[other]==nil then hidden[other]=other.Enabled;other.Enabled=false end
end
local added
local function open()
 flow.feedbackOpen=true;player:SetAttribute("FeedbackOpen",true)
 for _,other in ipairs(playerGui:GetChildren())do suppress(other)end
 added=playerGui.ChildAdded:Connect(suppress)
 flow.refresh()
end
local function close()
 flow.feedbackOpen=false;player:SetAttribute("FeedbackOpen",false)
 if added then added:Disconnect();added=nil end
 for other,enabled in pairs(hidden)do if other.Parent then other.Enabled=enabled end end
 table.clear(hidden)
 flow.refresh()
end
require(modules.FeedbackUI)(state,{shared=modules,network=network,prompt=prompt,hudEnabled=false,onOpen=open,onClose=close,canOpen=canOpen,bindClose=function(fn)closeFeedback=fn end,
 banner=if not network then "Feedback is temporarily unavailable" elseif network:GetAttribute("StorageMode")=="memory" then "STUDIO REVIEW · Temporary test storage · Resets when Play stops" else "Community feedback · Saved across visits",
 footer="Share an idea · Report a problem",hudText="Player feedback · Read and share ideas"})
