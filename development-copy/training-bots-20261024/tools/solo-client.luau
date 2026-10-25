-- Disposable client camera/input staging; real WeaponController/remote validation.
assert(game.RunService:IsStudio())
local p=game.Players.LocalPlayer;local c=p.PlayerScripts:WaitForChild('Client'):WaitForChild('Controllers')
local W=require(c.WeaponController);local Cam=require(c.CameraController);local Input=require(c.InputController)
local Menu=require(p.PlayerScripts.Client.UI.MainMenu);local Panel=require(p.PlayerScripts.Client.UI.DeveloperPanel)
local Net=require(game.ReplicatedStorage.Shared.Net)
task.wait(8);Menu.close();require(c.GameFlow).refresh();if Panel.setOpen then Panel.setOpen(false)end
local fired=false;local last=0;local phase='';local voted=''
game.RunService:BindToRenderStep('TemporaryBotCamera',Enum.RenderPriority.Camera.Value+2,function()
 local current=workspace:GetAttribute('BotsTestPhase')or''
 if current~=phase then phase=current;print('BOT_TEST_CLIENT_PHASE',phase)end
 if phase=='Complete'then game.RunService:UnbindFromRenderStep('TemporaryBotCamera');Menu.open();return end
 if game.ReplicatedStorage.MatchState:GetAttribute('State')=='Voting' then
  local map=workspace:GetAttribute('BotsTestVote');if map and voted~=map then Net.event('PlayerAction'):FireServer('Vote',map);voted=map end
 end
 if phase=='QueueCancel' or phase=='QueueMatch'then
  local q=workspace.Range.MatchQueue.QueueFloor.Position
  local eye=workspace.CurrentCamera.CFrame.Position;local look=(q+Vector3.new(0,3,0)-eye).Unit
  Cam.yaw=math.atan2(-look.X,-look.Z);Cam.pitch=math.asin(look.Y)
  return
 end
 if phase~='Provoke' and phase~='EliminateBot' and phase~='MatchCombat'then return end
 local folder=workspace:FindFirstChild('TrainingBots');local target=folder and folder:FindFirstChild('Training Bot 1')
 if not target or not target:FindFirstChild('UpperTorso')or not target:FindFirstChildOfClass('Humanoid') or target.Humanoid.Health<=0 or not p.Character or not p.Character:FindFirstChildOfClass('Humanoid') or p.Character.Humanoid.Health<=0 then return end
 local eye=workspace.CurrentCamera.CFrame.Position;local look=(target.UpperTorso.Position-eye).Unit
 Cam.yaw=math.atan2(-look.X,-look.Z);Cam.pitch=math.asin(look.Y)
 workspace.CurrentCamera.CFrame=CFrame.lookAt(eye,target.UpperTorso.Position)
 if os.clock()-last>.65 and (phase~='Provoke'or not fired)then
  last=os.clock();fired=true
  W.tryFire();W.equip(if W.state.equipped==1 then 2 else 1)
 end
end)
