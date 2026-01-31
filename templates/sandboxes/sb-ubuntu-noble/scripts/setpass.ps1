$ErrorActionPreference = "Stop"
if ($IsWindows -eq $false) { Write-Error "Error: Use setpass.sh on Mac/Linux/WSL"; exit 1 }
Set-Location $PSScriptRoot
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Write-Error "Error: Docker CLI not found"; exit 1 }

if (-not (Test-Path .env)) { Copy-Item .env.example .env }
$pass = Read-Host "Enter devcontainer root password" -AsSecureString
$p = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))
$hash = (docker run --rm alpine sh -c "apk add -q openssl && openssl passwd -6 '$p'") -replace '\$', '$$'

if ($LASTEXITCODE -ne 0) { Write-Error "Error: Failed to generate hash. Is Docker running?"; exit 1 }

(Get-Content .env) | Where-Object { $_ -notmatch "^SUHASH=" } | Set-Content .env
Add-Content .env "SUHASH=$hash"

Write-Host "Password hash written to .env"
