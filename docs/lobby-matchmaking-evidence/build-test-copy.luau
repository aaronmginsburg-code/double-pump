local fs=require("@lune/fs")
local R=require("@lune/roblox")
local place=R.deserializePlace(fs.readFile("build/DoublePump_LOBBY_MATCHMAKING.rbxl"))
local remote=R.Instance.new("RemoteEvent")
remote.Name="LobbyTestProbe"
remote.Parent=place.ReplicatedStorage
local server=R.Instance.new("Script")
server.Name="LobbyTestProbe_DO_NOT_PUBLISH"
server.Source=fs.readFile("docs/lobby-matchmaking-evidence/server-probe.luau")
server.Parent=place.ServerScriptService
local client=R.Instance.new("LocalScript")
client.Name="LobbyTestProbe_DO_NOT_PUBLISH"
client.Source=fs.readFile("docs/lobby-matchmaking-evidence/client-probe.luau")
client.Parent=place.StarterPlayer.StarterPlayerScripts
fs.writeFile("build/DoublePump_LOBBY_TEST_ONLY_DO_NOT_PUBLISH.rbxl",R.serializePlace(place))
print("Instrumented local test copy created; production candidate unchanged")
