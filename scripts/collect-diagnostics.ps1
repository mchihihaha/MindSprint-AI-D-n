param(
    [string]$OutputRoot = 'diagnostics',
    [int]$LogLines = 200,
    [string]$ComposeFile = 'compose.selfhost.yaml',
    [string]$Project = 'mindsprint-demo',
    [string]$BaseUrl = 'http://127.0.0.1:8080',
    [switch]$SelfTest
)
# Issue #115 - Thu goi chan doan cho ban self-host (Docker tren laptop) de nho nguoi khac ho tro.
#   powershell -ExecutionPolicy Bypass -File scripts/collect-diagnostics.ps1            -> diagnostics/<thoi-gian>/ + .zip
#   powershell -ExecutionPolicy Bypass -File scripts/collect-diagnostics.ps1 -SelfTest  -> them bi mat gia (canary) va kiem khong lot vao goi
# Goi gom: trang thai container, image/SHA, health, cong 8080, dung luong, /healthz + /readyz, log web/db gan nhat.
# KHONG lay bien moi truong cua container (docker inspect .Config.Env) va che mat khau/khoa/token/email trong moi tep truoc khi ghi.
# Chi doc trang thai: khong khoi dong lai, khong xoa container/volume, khong doi cau hinh may.
$ErrorActionPreference = 'Continue'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $OutputRoot $stamp
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$hints = New-Object System.Collections.Generic.List[string]

function Protect-Text([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $t = $Text
    # Cap khoa=gia tri co ten nhay cam (ca dang Password=...; trong chuoi ket noi va JSON "token":"...").
    $t = [regex]::Replace($t, '(?i)("?(?:[\w.:-]*?(?:password|passwd|pwd|secret|token|api[_-]?key|apikey|jwt[_-]?key|[_:.-]key|client[_-]?secret|connectionstring[s]?(?:__|:)?)\w*)"?\s*[:=]\s*"?)([^";\s,}]+)', '$1***')
    $t = [regex]::Replace($t, 'AIza[0-9A-Za-z_\-]{20,}', 'AIza***')                                   # khoa Google/Gemini
    $t = [regex]::Replace($t, 'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+', '<jwt-da-che>')    # JWT
    $t = [regex]::Replace($t, '(?i)\bbearer\s+[A-Za-z0-9\-._~+/]+=*', 'Bearer ***')
    $t = [regex]::Replace($t, '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}', '<email-da-che>')       # du lieu ca nhan
    # Chuoi dai khong ro ten -> che; tru chuoi chi gom hex thuong (SHA commit, ID image/container) vi goi can ghi SHA/image.
    $t = [regex]::Replace($t, '\b(?![0-9a-f]{40,}\b)[A-Za-z0-9+/_\-]{40,}={0,2}', '<chuoi-dai-da-che>')
    return $t
}

function Write-Safe([string]$Name, $Content, [int]$MaxLineLength = 500) {
    # Moi dong toi da 500 ky tu: log khong duoc mang ca noi dung tai lieu/nguon nguoi dung vao goi.
    $lines = @($Content | ForEach-Object { $s = Protect-Text ([string]$_); if ($s.Length -gt $MaxLineLength) { $s.Substring(0, $MaxLineLength) + ' ...[cat]' } else { $s } })
    [System.IO.File]::WriteAllLines((Join-Path $outDir $Name), [string[]]$lines, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-Capture([string]$Exe, [string[]]$Arguments) {
    try {
        $output = & $Exe @Arguments 2>&1 | ForEach-Object { "$_" }
        return @{ Ok = ($LASTEXITCODE -eq 0); Lines = @($output) }
    } catch { return @{ Ok = $false; Lines = @("Khong chay duoc $Exe : $($_.Exception.Message)") } }
}

# 1. Thong tin chung (khong co bi mat)
$git = Invoke-Capture 'git' @('rev-parse', 'HEAD')
$dirty = Invoke-Capture 'git' @('status', '--porcelain')
$dockerVersion = Invoke-Capture 'docker' @('version', '--format', 'client={{.Client.Version}} server={{.Server.Version}}')
$composeVersion = Invoke-Capture 'docker' @('compose', 'version', '--short')
$dockerUp = $dockerVersion.Ok
Write-Safe 'meta.txt' @(
    "Thoi diem: $(Get-Date -Format o)",
    "Ma nguon: $(($git.Lines | Select-Object -First 1))$(if (@($dirty.Lines | Where-Object { $_ }).Count) { ' (+ thay doi chua commit)' })",
    "May: $([Environment]::OSVersion.VersionString) | PowerShell $($PSVersionTable.PSVersion)",
    "Docker: $($dockerVersion.Lines -join ' ')",
    "Docker Compose: $($composeVersion.Lines -join ' ')",
    "Compose file: $ComposeFile | du an: $Project | URL: $BaseUrl"
)
if (-not $dockerUp) { $hints.Add('Docker Engine chua chay hoac chua cai: mo Docker Desktop, cho bieu tuong bao "Engine running", roi chay lai script.') }

# 2. Container, image/SHA, health (khong lay .Config.Env)
if ($dockerUp) {
    $ps = Invoke-Capture 'docker' @('compose', '-p', $Project, '-f', $ComposeFile, 'ps', '--all', '--format', 'table {{.Service}}\t{{.State}}\t{{.Status}}\t{{.Ports}}')
    Write-Safe 'containers.txt' $ps.Lines
    $ids = @((Invoke-Capture 'docker' @('compose', '-p', $Project, '-f', $ComposeFile, 'ps', '--all', '-q')).Lines | Where-Object { $_ -match '^[0-9a-f]{12,}$' })
    if ($ids.Count -eq 0) { $hints.Add("Chua co container nao cua du an '$Project': chay scripts/selfhost.ps1 Start (hoac docker compose -f $ComposeFile up -d).") }
    $state = @(); $images = @()
    foreach ($id in $ids) {
        $s = Invoke-Capture 'docker' @('inspect', '--format', '{{.Name}} | trang thai={{.State.Status}} | health={{if .State.Health}}{{.State.Health.Status}}{{else}}khong co{{end}} | khoi dong lai={{.RestartCount}} | bat dau={{.State.StartedAt}} | ma thoat={{.State.ExitCode}} | het RAM={{.State.OOMKilled}} | loi={{.State.Error}}', $id)
        $state += $s.Lines
        $h = Invoke-Capture 'docker' @('inspect', '--format', '{{if .State.Health}}{{range .State.Health.Log}}  {{.End}} ma={{.ExitCode}} {{.Output}}{{end}}{{end}}', $id)
        $state += @($h.Lines | Select-Object -Last 5)
        $images += (Invoke-Capture 'docker' @('inspect', '--format', '{{.Name}} | image={{.Config.Image}} | id={{.Image}}', $id)).Lines
    }
    Write-Safe 'health.txt' $state
    Write-Safe 'images.txt' $images
    Write-Safe 'disk.txt' ((Invoke-Capture 'docker' @('system', 'df')).Lines + '' + (Get-PSDrive -PSProvider FileSystem | ForEach-Object { "{0}: con trong {1:N1} GB" -f $_.Name, ($_.Free / 1GB) }))
    foreach ($svc in @('web', 'db')) {
        $log = Invoke-Capture 'docker' @('compose', '-p', $Project, '-f', $ComposeFile, 'logs', '--no-color', '--timestamps', '--tail', "$LogLines", $svc)
        Write-Safe "logs-$svc.txt" $log.Lines
        $joined = $log.Lines -join "`n"
        if ($joined -match '(?i)Login failed for user') { $hints.Add("Log $svc co 'Login failed': mat khau SQL trong .env.selfhost khong khop voi database da tao (volume cu). Xem scripts/selfhost.ps1 Configure.") }
        if ($joined -match '(?i)address already in use|port is already allocated|bind: ') { $hints.Add("Log $svc bao cong dang bi chiem: xem ports.txt de biet chuong trinh nao dang giu cong.") }
        if ($joined -match '(?i)A network-related or instance-specific error|server was not found|Connection refused') { $hints.Add("Log $svc khong ket noi duoc SQL Server: kiem container db trong health.txt (phai la healthy).") }
    }
    if (($state -join "`n") -match 'db.*health=unhealthy|db.*trang thai=exited') { $hints.Add('Container db khong khoe: xem logs-db.txt (thieu RAM, sai mat khau SA, volume hong).') }
    if (($state -join "`n") -match 'het RAM=true') { $hints.Add('Co container bi tat vi het RAM: dong bot ung dung hoac tang RAM cho Docker Desktop.') }
}

# 3. Cong 8080 va HTTP
$port = ([Uri]$BaseUrl).Port
$listeners = @(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
$portLines = foreach ($l in $listeners) {
    $p = Get-Process -Id $l.OwningProcess -ErrorAction SilentlyContinue
    "{0}:{1} <- tien trinh {2} (PID {3})" -f $l.LocalAddress, $l.LocalPort, $(if ($p) { $p.ProcessName } else { '?' }), $l.OwningProcess
}
if (-not $portLines) { $portLines = @("Khong co chuong trinh nao nghe cong $port") }
Write-Safe 'ports.txt' $portLines
$owners = @($listeners | ForEach-Object { (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName })
if ($owners.Count -gt 0 -and -not ($owners | Where-Object { $_ -match '^(com\.docker\.backend|wslrelay|vpnkit|docker.*)$' })) {
    $hints.Add("Cong $port dang bi '$($owners -join ', ')' chiem (khong phai Docker): tat chuong trinh do hoac doi cong trong compose.selfhost.yaml, roi khoi dong lai.")
}
$http = foreach ($path in @('/healthz', '/readyz')) {
    try {
        $r = Invoke-WebRequest -Uri ($BaseUrl + $path) -UseBasicParsing -TimeoutSec 5
        "$path -> $($r.StatusCode) $($r.Content)"
    } catch {
        $code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 'khong ket noi duoc' }
        "$path -> $code"
    }
}
Write-Safe 'http.txt' $http
if (($http -join ' ') -match '/healthz -> khong ket noi') { $hints.Add("Khong mo duoc $BaseUrl/healthz: web chua chay hoac sai cong.") }
elseif (($http -join ' ') -match '/readyz -> 503') { $hints.Add('Web dang chay nhung /readyz = 503: web khong ket noi duoc database (xem logs-web.txt, health.txt cua db).') }

# 4. Kiem chung che bi mat bang canary (bi mat gia, ngau nhien moi lan)
if ($SelfTest) {
    $id = [guid]::NewGuid().ToString('N').Substring(0, 12)
    # Cuoi danh sach: mat khau dang hex (nhu DB_PASSWORD cua selfhost.ps1) - khong bi quy tac chuoi dai che, phai bi che theo ten khoa.
    $canaries = @("CanaryPass-$id", "AIzaSyCANARY$id$id", "canary-jwt-$id", "canary.$id@example.com", "$id$id$id$id")
    Write-Safe 'canary-log.txt' @(
        "ConnectionStrings__Default=Server=db,1433;Database=mindsprint;User ID=sa;Password=$($canaries[0]);Encrypt=True",
        "MSSQL_SA_PASSWORD=$($canaries[0])",
        "DB_PASSWORD=$($canaries[4])",
        "Google__ClientSecretValue=$($canaries[0]) Turnstile__SecretKey=$($canaries[0])",
        "Gemini__ApiKey=$($canaries[1])  key=$($canaries[1])",
        "Jwt__Key=$($canaries[2])",
        ('{"token":"' + $canaries[2] + '","refreshToken":"' + $canaries[2] + '"}'),
        "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.$id",
        "Nguoi dung $($canaries[3]) dang nhap"
    )
    $leaks = @(Get-ChildItem $outDir -File | Select-String -SimpleMatch -Pattern $canaries)
    if ($leaks.Count) { Write-Host "SELFTEST FAIL: $($leaks.Count) dong con bi mat gia:"; $leaks | ForEach-Object { Write-Host "  $($_.Filename):$($_.LineNumber)" }; $hints.Add('SELFTEST FAIL: con bi mat gia trong goi') }
    else { Write-Host "SELFTEST PASS: $($canaries.Count) bi mat gia deu da bi che trong $(@(Get-ChildItem $outDir -File).Count) tep." }
}

Write-Safe 'summary.txt' (@('Goi chan doan MindSprint self-host. Gui ca tep .zip cho nguoi ho tro; da che mat khau/khoa/token/email.', '') +
    $(if ($hints.Count) { @('Goi y nguyen nhan:') + ($hints | ForEach-Object { " - $_" }) } else { @('Khong phat hien loi thuong gap.') }))
$zip = "$outDir.zip"
Compress-Archive -Path (Join-Path $outDir '*') -DestinationPath $zip -Force
Write-Host "Da tao: $zip"
Get-Content (Join-Path $outDir 'summary.txt') | ForEach-Object { Write-Host $_ }
if ($SelfTest -and ($hints -match 'SELFTEST FAIL')) { exit 1 }
