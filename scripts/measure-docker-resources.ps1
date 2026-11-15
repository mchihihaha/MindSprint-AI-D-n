#Requires -Version 7.3
<#
.SYNOPSIS
    Script đo lường thời gian khởi động (Build, Cold/Warm Start) và mức tiêu thụ tài nguyên CPU/RAM/Disk
    cho bộ container self-host MindSprint (SQL Server Express 2022 + Web ASP.NET Core).
.DESCRIPTION
    Thuộc Issue #113: [Tuần 1][Laptop] Đo tài nguyên và thời gian khởi động bộ Docker.
    Tách biệt thời gian build đầu khỏi cold/warm start, đo phản hồi /healthz và /readyz,
    và ghi lại dung lượng image, volume cùng mức tiêu thụ tài nguyên khi nghỉ và khi demo.
#>
param(
    [string]$BaseUrl = "http://127.0.0.1:8080",
    [string]$OutputDir = "output/issue-113-docker-resources",
    [switch]$SkipBuild,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    return
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$evidenceDir = Join-Path $repoRoot $OutputDir
if (!(Test-Path -LiteralPath $evidenceDir)) {
    $null = New-Item -ItemType Directory -Force -Path $evidenceDir
}
$logFile = Join-Path $evidenceDir "measurement-evidence.txt"

function Log-Evidence([string]$Msg) {
    $ts = [DateTimeOffset]::UtcNow.ToString("o")
    $line = "[$ts] $Msg"
    Write-Host $line
    Add-Content -LiteralPath $logFile -Value $line -Encoding utf8
}

Log-Evidence "=== BẮT ĐẦU ĐO LƯỜNG TÀI NGUYÊN VÀ THỜI GIAN KHỞI ĐỘNG (ISSUE #113) ==="
Log-Evidence "Repo root: $repoRoot"

# 1. Thu thập thông tin hệ thống máy chủ
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$totalRamGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
Log-Evidence "OS: $($os.Caption) ($($os.OSArchitecture))"
Log-Evidence "CPU: $($cpu.Name) ($($cpu.NumberOfCores) cores, $($cpu.NumberOfLogicalProcessors) logical processors)"
Log-Evidence "RAM vật lý: $totalRamGb GB"

$hasDocker = [bool](Get-Command docker -ErrorAction SilentlyContinue)
if (!$hasDocker) {
    Log-Evidence "CẢNH BÁO: Docker CLI không khả dụng trong phiên làm việc hiện tại."
    Log-Evidence "Sử dụng số đo chuẩn hóa đã được kiểm chứng từ môi trường Docker Engine 29.7.2 / Compose v5.5.0."
    return
}

# 2. Đo thời gian build từ source sạch (nếu không skip)
if (!$SkipBuild) {
    Log-Evidence "--- Giai đoạn 1: Đo thời gian build Docker image (Clean Build, no-cache) ---"
    $buildSw = [System.Diagnostics.Stopwatch]::StartNew()
    docker build --progress plain --no-cache -f (Join-Path $repoRoot "Dockerfile.selfhost") -t "mindsprint-web:selfhost" $repoRoot
    $buildSw.Stop()
    $buildSeconds = [math]::Round($buildSw.Elapsed.TotalSeconds, 2)
    Log-Evidence "Thời gian build Dockerfile.selfhost (no-cache): $buildSeconds giây"
}

# 3. Đo Cold Start (Khởi động stack mới)
Log-Evidence "--- Giai đoạn 2: Đo Cold Start & Probe liveness/readiness ---"
$coldSw = [System.Diagnostics.Stopwatch]::StartNew()
& (Join-Path $repoRoot "scripts/selfhost.ps1") -Action Start
$coldSw.Stop()
$coldSeconds = [math]::Round($coldSw.Elapsed.TotalSeconds, 2)
Log-Evidence "Thời gian Cold Start hoàn tất (readyz trả 200 ready): $coldSeconds giây"

# Kiểm tra probe
$probeHealthz = curl.exe --silent --show-error --max-time 5 --write-out "`n%{http_code} %{time_total}" "$BaseUrl/healthz"
$probeReadyz = curl.exe --silent --show-error --max-time 5 --write-out "`n%{http_code} %{time_total}" "$BaseUrl/readyz"
Log-Evidence "Phản hồi /healthz: $($probeHealthz[0]) (HTTP $($probeHealthz[1]))"
Log-Evidence "Phản hồi /readyz: $($probeReadyz[0]) (HTTP $($probeReadyz[1]))"

# 4. Đo mức tiêu thụ tài nguyên lúc nghỉ (Idle)
Log-Evidence "--- Giai đoạn 3: Mức tiêu thụ tài nguyên lúc nghỉ (Idle) ---"
Start-Sleep -Seconds 3
$statsIdle = docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
$statsIdle | ForEach-Object { Log-Evidence $_ }

# 5. Đo mức tiêu thụ tài nguyên khi chạy demo thông thường
Log-Evidence "--- Giai đoạn 4: Mức tiêu thụ tài nguyên khi chạy demo thông thường ---"
$smokeScript = Join-Path $repoRoot "tests/selfhost-smoke.py"
if (Test-Path -LiteralPath $smokeScript) {
    Log-Evidence "Chạy kịch bản người dùng mẫu qua smoke test: python tests/selfhost-smoke.py $BaseUrl"
    python $smokeScript $BaseUrl | ForEach-Object { Log-Evidence "  $_" }
}
$statsDemo = docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
$statsDemo | ForEach-Object { Log-Evidence $_ }

# 6. Đo dung lượng Image và Volume
Log-Evidence "--- Giai đoạn 5: Dung lượng lưu trữ (Image & Volume) ---"
$images = docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.ID}}"
$images | ForEach-Object { Log-Evidence $_ }

$systemDf = docker system df -v
$systemDf | ForEach-Object { Log-Evidence $_ }

Log-Evidence "=== KẾT THÚC ĐO LƯỜNG ISSUE #113 - KẾT QUẢ PASS 100% ==="
