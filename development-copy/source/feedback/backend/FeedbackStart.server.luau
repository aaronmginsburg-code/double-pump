-- Board-only integration: Studio always uses disposable adapters; native identity is exact.
local run=game:GetService("RunService")
local root=script.Parent
local integration=require(root.IntegrationConfig)
if not run:IsStudio() then
 assert(game.GameId==10772492892 and game.PlaceId==139437092998076,"Feedback requires the authorized development target")
end
local board=workspace:WaitForChild("UniversalFeedbackBoard",30)
if not board then warn("[Feedback] Board is unavailable");return end
board:PivotTo(integration.BoardCFrame)
local options={StorageVersion=2,Schema=2,ModeratorIds=integration.ModeratorIds}
if run:IsStudio() then
 local adapters=game:GetService("ServerStorage"):FindFirstChild("FeedbackStudioAdapters")
 if not adapters then warn("[Feedback] Use the isolated review build for Studio testing");return end
 for _,child in ipairs(adapters:GetChildren())do child:Clone().Parent=root.Server end
 options.Adapter="memory"
else
 assert(integration.Mode=="persistent","Feedback runtime disabled")
 options.Adapter="roblox";options.Environment="production";options.ServiceAccessEnabled=true
 options.NativeRuntimeEnabled=true;options.TestMode=false
 options.ApprovedUniverseId=integration.UniverseId;options.ApprovedPlaceId=integration.PlaceId
 options.StoreNamespace=integration.Namespace;options.SubmissionBroadcastDisplay=integration.SubmissionBroadcastDisplay
end
local service=require(root.Server.Bootstrap).start(options)
assert(service,"Feedback backend failed")
board:SetAttribute("FeedbackMode",if run:IsStudio() then "Studio memory: resets on Stop"else "Persistent Storage V2")
