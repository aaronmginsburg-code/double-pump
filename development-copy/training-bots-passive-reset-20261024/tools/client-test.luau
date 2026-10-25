-- Disposable genuine WeaponController calls; no validation bypass.
assert(game.RunService:IsStudio())
local p=game.Players.LocalPlayer;local C=p.PlayerScripts:WaitForChild('Client'):WaitForChild('Controllers')
local W=require(C.WeaponController);local Cam=require(C.CameraController)
local Menu=require(p.PlayerScripts.Client.UI.MainMenu)
task.wait(6);Menu.close();require(C.GameFlow).refresh();local release=Cam.requestCursor()
local last=0
game.RunService:BindToRenderStep('TemporaryBotPassiveCamera',Enum.RenderPriority.Camera.Value+2,function()
 local phase=workspace:GetAttribute('PassiveResetPhase')
 if phase=='Complete'then game.RunService:UnbindFromRenderStep('TemporaryBotPassiveCamera');Menu.open();release();return end
 local char=p.Character;local h=char and char:FindFirstChildOfClass('Humanoid');if not h or h.Health<=0 then return end
 local folder=workspace:FindFirstChild('TrainingBots');local b=folder and folder:FindFirstChild(if phase=='ProvokeAgain'then 'Training Bot 2'else'Training Bot 1')
 local torso=b and b:FindFirstChild('UpperTorso');if not torso then return end
 local eye=workspace.CurrentCamera.CFrame.Position;local delta=torso.Position-eye
 if delta.Magnitude<.1 then return end
 local look=delta.Unit;Cam.yaw=math.atan2(-look.X,-look.Z);Cam.pitch=math.asin(look.Y)
 workspace.CurrentCamera.CFrame=CFrame.lookAt(eye,torso.Position)
 if (phase=='Provoke'or phase=='ProvokeAgain')and os.clock()-last>.7 then
  last=os.clock();W.tryFire();W.equip(if W.state.equipped==1 then 2 else 1)
 end
end)
