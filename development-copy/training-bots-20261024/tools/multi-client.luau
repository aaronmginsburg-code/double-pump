-- Disposable genuine client controller calls and capture framing.
assert(game.RunService:IsStudio())
local p=game.Players.LocalPlayer;local C=p.PlayerScripts:WaitForChild('Client'):WaitForChild('Controllers')
local Cam=require(C.CameraController);local W=require(C.WeaponController);local Menu=require(p.PlayerScripts.Client.UI.MainMenu)
local Panel=require(p.PlayerScripts.Client.UI.DeveloperPanel)
task.wait(5);Menu.close();require(C.GameFlow).refresh();if Panel.setOpen then Panel.setOpen(false)end
local release=Cam.requestCursor() -- prevent automated test windows capturing the owner's mouse
local last=0;local phase='';local shotPhases={}
game.RunService:BindToRenderStep('TemporaryBotMultiCamera',Enum.RenderPriority.Camera.Value+2,function()
 local current=workspace:GetAttribute('BotsMultiPhase')or''
 if current~=phase then phase=current;print('BOT_MULTI_CLIENT_PHASE',p.UserId,phase)end
 if phase=='Complete'then game.RunService:UnbindFromRenderStep('TemporaryBotMultiCamera');release();Menu.open();return end
 local char=p.Character;local hum=char and char:FindFirstChildOfClass('Humanoid')
 if not hum or hum.Health<=0 then return end
 local folder=workspace:FindFirstChild('TrainingBots');local bot=folder and folder:FindFirstChild('Training Bot 1')
 if phase=='PhotoPassive' or phase=='Returned'then
  local eye=workspace.CurrentCamera.CFrame.Position
  local look=(Vector3.new(-1249,3.7,0)-eye).Unit;Cam.yaw=math.atan2(-look.X,-look.Z);Cam.pitch=math.asin(look.Y);return
 end
 if phase=='Queue'or phase=='QueueBoth'then
  local eye=workspace.CurrentCamera.CFrame.Position;local look=(Vector3.new(-1252,4,20)-eye).Unit
  Cam.yaw=math.atan2(-look.X,-look.Z);Cam.pitch=math.asin(look.Y);return
 end
 if p.UserId~=-1 then return end
 local target
 if phase=='HumanPractice'then for _,other in game.Players:GetPlayers()do if other.UserId==-2 then target=other.Character end end
 elseif phase=='Provoke'or phase=='Match'then target=bot else return end
 local torso=target and target:FindFirstChild('UpperTorso');local th=target and target:FindFirstChildOfClass('Humanoid')
 if not torso or not th or th.Health<=0 then return end
 local eye=workspace.CurrentCamera.CFrame.Position;local look=(torso.Position-eye).Unit
 Cam.yaw=math.atan2(-look.X,-look.Z);Cam.pitch=math.asin(look.Y);workspace.CurrentCamera.CFrame=CFrame.lookAt(eye,torso.Position)
 if os.clock()-last>.7 and (phase=='Match'or phase=='HumanPractice'or phase=='Provoke')then
  shotPhases[phase]=true;last=os.clock();W.tryFire();W.equip(if W.state.equipped==1 then 2 else 1)
 end
end)
