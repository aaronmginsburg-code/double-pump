# One-time setup for Double Pump on Windows: installs Rokit, Rojo, the Rojo Studio plugin
# and the recommended VS Code extensions. Safe to run again.
$ErrorActionPreference = "Stop"
$ProjectDir = $PSScriptRoot
$RokitBin = Join-Path $env:USERPROFILE ".rokit\bin"

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }

if (-not (Test-Path (Join-Path $RokitBin "rokit.exe"))) {
    Step "Downloading Rokit"
    $release = Invoke-RestMethod "https://api.github.com/repos/rojo-rbx/rokit/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like "*windows-x86_64.zip" } | Select-Object -First 1
    if (-not $asset) { throw "Couldn't find a Windows download for Rokit $($release.tag_name)." }
    $zip = Join-Path $env:TEMP $asset.name
    $unzipDir = Join-Path $env:TEMP "rokit-download"
    Invoke-WebRequest $asset.browser_download_url -OutFile $zip
    if (Test-Path $unzipDir) { Remove-Item $unzipDir -Recurse -Force }
    Expand-Archive $zip -DestinationPath $unzipDir
    $exe = Get-ChildItem $unzipDir -Recurse -Filter "rokit.exe" | Select-Object -First 1

    Step "Installing Rokit $($release.tag_name)"
    & $exe.FullName self-install
} else {
    Step "Rokit is already installed"
}
$env:Path = "$RokitBin;$env:Path"

Step "Installing Rojo for this project"
Set-Location $ProjectDir
& rokit install --no-trust-check
if ($LASTEXITCODE -ne 0) { & rokit install }
& rojo --version

Step "Installing the Rojo plugin into Roblox Studio"
& rojo plugin install

Step "Installing VS Code extensions"
$code = Get-Command code -ErrorAction SilentlyContinue
if (-not $code) {
    $guess = Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin\code.cmd"
    if (Test-Path $guess) { $code = Get-Item $guess }
}
if ($code) {
    & $code.Source --install-extension evaera.vscode-rojo --force
    & $code.Source --install-extension johnnymorganz.luau-lsp --force
} else {
    Write-Host "Couldn't find VS Code's 'code' command. Install the Rojo and Luau Language Server extensions from VS Code's Extensions panel." -ForegroundColor Yellow
}

Step "All done"
Write-Host "Next: open this folder in VS Code, run 'rojo serve' in its terminal, then in Studio click Rojo > Connect." -ForegroundColor Green
