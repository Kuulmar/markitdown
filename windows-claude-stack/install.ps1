# install.ps1 - instala e configura a "claude-stack" no Windows (idempotente: pode rodar de novo sem medo).
# Uso: powershell -ExecutionPolicy Bypass -File install.ps1
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$U        = $env:USERPROFILE
$BinDir   = Join-Path $U '.local\bin'
$CfgDir   = Join-Path $U '.config\claude-stack'
$ClaudeMd = Join-Path $U '.claude\CLAUDE.md'
$Log      = Join-Path $CfgDir 'install.log'
New-Item -ItemType Directory -Force -Path $BinDir, $CfgDir, (Split-Path $ClaudeMd) | Out-Null
Start-Transcript -Path $Log -Append | Out-Null
$Fail = @()

function Say($m)  { Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "  OK  $m" -ForegroundColor Green }
function Bad($m)  { Write-Host "  ERRO $m" -ForegroundColor Red; $script:Fail += $m }
function Has($c)  { [bool](Get-Command $c -ErrorAction SilentlyContinue) }
function RefreshPath {
  $m = [Environment]::GetEnvironmentVariable('Path','Machine'); $u = [Environment]::GetEnvironmentVariable('Path','User')
  $env:Path = (@($m,$u,$BinDir,"$U\.local\bin","$env:APPDATA\npm") -join ';')
}
function AddUserPath($p) {
  $u = [Environment]::GetEnvironmentVariable('Path','User'); if (-not $u) { $u = '' }
  if (($u -split ';') -notcontains $p) { [Environment]::SetEnvironmentVariable('Path', ($u.TrimEnd(';') + ";$p").TrimStart(';'), 'User') }
}
function Run($desc, [scriptblock]$sb, $tries = 3) {
  for ($i = 1; $i -le $tries; $i++) {
    $global:LASTEXITCODE = 0
    try { & $sb; if ($LASTEXITCODE -eq 0) { Ok $desc; return $true } } catch { Write-Host "  $_" }
    Write-Host "  tentativa $i/$tries falhou ($desc), repetindo..." -ForegroundColor Yellow; Start-Sleep -Seconds (2 * $i)
  }
  Bad $desc; return $false
}
function Install-Pkg($id) {
  if (-not (Has winget)) { Bad "winget ausente: instale 'Instalador de Aplicativo' na Microsoft Store e rode de novo"; return }
  Run "winget $id" { winget.exe install -e --id $id --accept-source-agreements --accept-package-agreements --silent --scope user; if ($LASTEXITCODE -eq -1978335189) { $global:LASTEXITCODE = 0 } } 1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Run "winget $id (maquina)" { winget.exe install -e --id $id --accept-source-agreements --accept-package-agreements --silent; if ($LASTEXITCODE -eq -1978335189) { $global:LASTEXITCODE = 0 } } 1 | Out-Null }
  RefreshPath
}

try { Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force -ErrorAction Stop } catch { }
RefreshPath; AddUserPath $BinDir

# ---------- 0. Pre-requisitos: Git, Node, Claude Code ----------
Say '0/9 Pre-requisitos (Git, Node.js, Claude Code)'
if (-not (Has git)) { Install-Pkg 'Git.Git' } else { Ok 'Git ja instalado' }

function NodeOk {
  if (-not (Has node)) { return $false }
  $v = [version]((node -v) -replace '^v','')
  return (($v.Major -eq 22 -and $v -ge [version]'22.22.2') -or ($v.Major -ge 24 -and $v.Major -le 26))
}
if (-not (NodeOk)) { Install-Pkg 'OpenJS.NodeJS.LTS' }
if (NodeOk) { Ok "Node $(node -v)" } else { Bad "Node incompativel ($(if (Has node) { node -v } else { 'ausente' })). Precisa 22.22.2+ ou 24-26. Desinstale o Node antigo em Configuracoes > Aplicativos e rode de novo." }

if (-not (Has claude)) {
  Run 'Claude Code (instalador oficial)' { Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression; RefreshPath; if (Has claude) { $global:LASTEXITCODE = 0 } else { $global:LASTEXITCODE = 1 } } 2 | Out-Null
  if (-not (Has claude)) { Run 'Claude Code (npm)' { npm install -g @anthropic-ai/claude-code } | Out-Null; RefreshPath }
} else { Ok "Claude Code $(claude --version)" }
$bash = 'C:\Program Files\Git\bin\bash.exe'
if ((Test-Path $bash) -and -not [Environment]::GetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH','User')) {
  [Environment]::SetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', $bash, 'User'); $env:CLAUDE_CODE_GIT_BASH_PATH = $bash
}

# ---------- 1-2. Plugins ----------
Say '1-2/9 Plugins claude-mem e claude-code-setup'
Run 'marketplace thedotmack/claude-mem'                 { claude plugin marketplace add thedotmack/claude-mem; if ($LASTEXITCODE) { $global:LASTEXITCODE = [int](-not ((claude plugin marketplace list) -match 'thedotmack')) } } | Out-Null
Run 'plugin claude-mem'                                 { claude plugin install claude-mem@thedotmack } | Out-Null
Run 'marketplace anthropics/claude-plugins-official'    { claude plugin marketplace add anthropics/claude-plugins-official; if ($LASTEXITCODE) { $global:LASTEXITCODE = [int](-not ((claude plugin marketplace list) -match 'claude-plugins-official')) } } | Out-Null
Run 'plugin claude-code-setup'                          { claude plugin install claude-code-setup@claude-plugins-official } | Out-Null

# ---------- 3. Skill task-observer ----------
Say '3/9 Skill task-observer'
Run 'skill task-observer' { npx -y skills add https://github.com/rebelytics/one-skill-to-rule-them-all --skill task-observer -g -a claude-code -y } | Out-Null

# ---------- 4. OmniRoute ----------
Say '4/9 OmniRoute'
Run 'npm install -g omniroute' { npm install -g omniroute } | Out-Null
RefreshPath

# ---------- 5-6. uv, Headroom, MarkItDown ----------
Say '5-6/9 uv, Headroom, MarkItDown'
if (-not (Has uv)) {
  Run 'uv' { Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression; RefreshPath; $global:LASTEXITCODE = [int](-not (Has uv)) } 2 | Out-Null
  if (-not (Has uv)) { Install-Pkg 'astral-sh.uv' }
} else { Ok "uv $(uv --version)" }
Run 'headroom-ai[all] (Python 3.13)' { uv tool install --python 3.13 'headroom-ai[all]' } 2 | Out-Null
Run 'markitdown[all]'                { uv tool install 'markitdown[all]' } 2 | Out-Null
Run 'markitdown-mcp'                 { uv tool install markitdown-mcp } 2 | Out-Null
uv tool update-shell 2>$null | Out-Null
RefreshPath
claude mcp remove -s user markitdown 2>$null | Out-Null
Run 'MCP markitdown (escopo user)' { claude mcp add -s user markitdown -- markitdown-mcp } | Out-Null

# ---------- 7. CLAUDE.md ----------
Say '7/9 ~/.claude/CLAUDE.md'
$begin = '<!-- claude-stack:begin -->'; $end = '<!-- claude-stack:end -->'
$block = @"
$begin
## Regras permanentes (claude-stack)
- Usar sempre a skill **ponytail** no modo **full**.
- Converter todo arquivo (PDF, DOCX, XLSX, PPTX, HTML, imagens etc.) com **markitdown** (MCP ``markitdown`` ou CLI ``markitdown``) antes de ler.
- Consultar o **claude-mem** antes de refazer qualquer trabalho ja feito.
- Rodar a skill **task-observer** em tarefas longas.
$end
"@
$cur = if (Test-Path $ClaudeMd) { Get-Content $ClaudeMd -Raw -Encoding UTF8 } else { '' }
if ($cur -match [regex]::Escape($begin)) { $cur = [regex]::Replace($cur, "(?s)$([regex]::Escape($begin)).*?$([regex]::Escape($end))", $block.Trim()) }
else { $cur = ($cur.TrimEnd() + "`r`n`r`n" + $block).TrimStart() }
[IO.File]::WriteAllText($ClaudeMd, $cur, (New-Object Text.UTF8Encoding $false)); Ok $ClaudeMd

# ---------- 8. Comando claude-stack ----------
Say '8/9 Comando claude-stack'
$src = Join-Path $PSScriptRoot 'claude-stack.ps1'
if ($PSScriptRoot -and (Test-Path $src)) { Copy-Item $src (Join-Path $BinDir 'claude-stack.ps1') -Force }
else { Invoke-WebRequest 'https://raw.githubusercontent.com/kuulmar/markitdown/claude/bold-faraday-d6jlgb/windows-claude-stack/claude-stack.ps1' -OutFile (Join-Path $BinDir 'claude-stack.ps1') -UseBasicParsing }
Set-Content -Path (Join-Path $BinDir 'claude-stack.cmd') -Encoding ASCII -Value "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0claude-stack.ps1`" %*`r`nexit /b %ERRORLEVEL%"
if (Test-Path (Join-Path $BinDir 'claude-stack.ps1')) { Ok "$BinDir\claude-stack.cmd" } else { Bad 'claude-stack.ps1 nao copiado' }

# ---------- 9. Sobe OmniRoute e abre o painel ----------
Say '9/9 Subindo OmniRoute (porta 20128)'
& (Join-Path $BinDir 'claude-stack.ps1') --start-omniroute
Start-Process 'http://localhost:20128/dashboard/api-manager'

Say 'RESUMO'
if ($Fail.Count) { Write-Host "Falhas:" -ForegroundColor Red; $Fail | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }; Write-Host "Log completo: $Log" }
else { Write-Host 'Tudo instalado. Feche esta janela, abra um PowerShell NOVO e siga o passo do navegador.' -ForegroundColor Green }
Stop-Transcript | Out-Null
