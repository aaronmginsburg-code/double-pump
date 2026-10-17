# Double Pump

A 5v5 first-person Roblox shooter built around the double pump: two pump shotguns, and swapping between them skips the pump animation.

## Setup

1. On Windows, double-click `setup-windows.bat` to install everything below in one go. Otherwise, install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder to get Rojo.
2. Run `rojo plugin install` to add the Rojo plugin to Roblox Studio.
3. Open this folder in VS Code and install the recommended extensions (Rojo, Luau Language Server).
4. Run `rojo serve`, open a Baseplate in Studio, click **Rojo > Connect**. Saved code syncs into Studio live.

## Layout

| Folder | Ends up in | Holds |
| --- | --- | --- |
| `src/shared` | ReplicatedStorage.Shared | Code and config both sides use, including `Config.luau` (all tuning numbers) |
| `src/server` | ServerScriptService.Server | Server code: damage, hit checks, rounds |
| `src/client` | StarterPlayerScripts.Client | Client code: input, swapping, effects |
