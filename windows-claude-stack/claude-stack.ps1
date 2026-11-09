# claude-stack.ps1 - sobe OmniRoute (20128) + Headroom (8787) e abre o Claude Code passando por eles.
# Uso:
#   claude-stack                         -> abre o claude interativo
#   claude-stack -p "pergunta"           -> qualquer argumento vai direto para o claude
#   claude-stack --set-key SUA_CHAVE     -> salva a chave do OmniRoute
#   claude-stack --status | --stop | --start-omniroute
$ErrorActionPreference = 'Stop'
$CfgDir  = Join-Path $env:USERPROFILE '.config\claude-stack'
$KeyFile = Join-Path $CfgDir 'omniroute.key'
$HrLog   = Join-Path $CfgDir 'headroom.log'
$OR = 'http://127.0.0.1:20128'; $HR = 'http://127.0.0.1:8787'
New-Item -ItemType Directory -Force -Path $CfgDir | Out-Null
foreach ($p in @("$env:USERPROFILE\.local\bin", "$env:APPDATA\npm")) { if ($env:Path -notlike "*$p*") { $env:Path += ";$p" } }

function Up($url) { try { (Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 3).StatusCode -lt 500 } catch { $false } }
function WaitUp($url, $secs, $name) {
  for ($i = 0; $i -lt $secs; $i++) { if (Up $url) { return } ; Start-Sleep 1 }
  throw "$name nao respondeu em $secs s ($url). Veja logs em $CfgDir"
}
function Start-OmniRoute {
  if (Up "$OR/api/health/ping") { return }
  Write-Host 'Iniciando OmniRoute...' -ForegroundColor DarkGray
  $env:OMNIROUTE_SERVER_HOST = '127.0.0.1'; $env:HOST = '127.0.0.1'
  omniroute serve --daemon --no-tray --no-open | Out-Null
  WaitUp "$OR/api/health/ping" 90 'OmniRoute'
}
function Start-Headroom {
  if (Up "$HR/livez") { return }
  Write-Host 'Iniciando Headroom...' -ForegroundColor DarkGray
  $exe = (Get-Command headroom -ErrorAction Stop).Source
  Start-Process -FilePath $exe -WindowStyle Hidden `
    -ArgumentList 'proxy','--port','8787','--anthropic-api-url',$OR `
    -RedirectStandardOutput $HrLog -RedirectStandardError "$HrLog.err"
  WaitUp "$HR/livez" 180 'Headroom'
}

switch ($args[0]) {
  '--set-key' {
    $k = "$($args[1])".Trim()
    if (-not $k) { throw 'Uso: claude-stack --set-key SUA_CHAVE' }
    [IO.File]::WriteAllText($KeyFile, $k)
    icacls $KeyFile /inheritance:r /grant:r "${env:USERNAME}:F" | Out-Null
    Write-Host "Chave salva em $KeyFile" -ForegroundColor Green; exit 0
  }
  '--start-omniroute' { Start-OmniRoute; Write-Host "OmniRoute OK em $OR" -ForegroundColor Green; exit 0 }
  '--status' {
    "OmniRoute : $(if (Up "$OR/api/health/ping") {'no ar'} else {'parado'})"
    "Headroom  : $(if (Up "$HR/livez") {'no ar'} else {'parado'})"
    "Chave     : $(if (Test-Path $KeyFile) {'salva'} else {'FALTANDO'})"; exit 0
  }
  '--stop' {
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'headroom.*proxy|omniroute' } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Write-Host 'Parado.'; exit 0
  }
}

if (-not (Test-Path $KeyFile)) { throw "Chave do OmniRoute nao encontrada. Rode: claude-stack --set-key SUA_CHAVE" }
Start-OmniRoute
Start-Headroom

$env:ANTHROPIC_BASE_URL   = $HR
$env:ANTHROPIC_AUTH_TOKEN = (Get-Content $KeyFile -Raw).Trim()
$env:MCP_TIMEOUT          = '90000'
Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
& claude @args
exit $LASTEXITCODE
