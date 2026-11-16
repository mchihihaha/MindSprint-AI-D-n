#Requires -Version 7.3
<#
.SYNOPSIS
Measures build, cold/warm startup, and resources for the laptop SQL Server stack.
.DESCRIPTION
Builds an archived Git revision and uses a new Compose project, loopback port,
and test volume. Evidence is retained in a per-run directory.
#>
param(
    [string]$Revision = 'HEAD',
    [string]$OutputDir = 'output/issue-113-docker-resources',
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Help) {
    Get-Help $PSCommandPath -Detailed
    return
}

function Invoke-Checked([string]$Executable) {
    $PSNativeCommandUseErrorActionPreference = $false
    & $Executable @args
    if ($LASTEXITCODE -ne 0) {
        throw "$Executable $($args[0]) failed with exit code $LASTEXITCODE."
    }
}

function Write-Evidence([string]$Message) {
    $line = "[$([DateTimeOffset]::UtcNow.ToString('o'))] $Message"
    Add-Content -LiteralPath $evidence -Value $line -Encoding utf8
    Write-Host $line
}

function Measure-Startup([string]$Phase) {
    $watch = [Diagnostics.Stopwatch]::new()
    $probe = Start-ThreadJob -ArgumentList $base, $watch, $startupTimeout -ScriptBlock {
        param($Base, $Watch, $Timeout)
        $pending = [ordered]@{ '/healthz' = 'ok'; '/readyz' = 'ready' }
        $lastStatus = @{}
        $handler = [Net.Http.HttpClientHandler]::new()
        $handler.UseProxy = $false
        $handler.AllowAutoRedirect = $false
        $client = [Net.Http.HttpClient]::new($handler)
        $client.Timeout = [TimeSpan]::FromSeconds(1)
        try {
            while (!$Watch.IsRunning) { Start-Sleep -Milliseconds 10 }
            while ($pending.Count -and $Watch.Elapsed.TotalSeconds -lt $Timeout) {
                foreach ($path in @($pending.Keys)) {
                    try {
                        $response = $client.GetAsync("$Base$path").GetAwaiter().GetResult()
                        try {
                            $lastStatus[$path] = "HTTP $([int]$response.StatusCode)"
                            if ($response.StatusCode -ne [Net.HttpStatusCode]::OK) { continue }
                            $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json
                            if ($body.status -ne $pending[$path]) {
                                $lastStatus[$path] = 'HTTP 200 with an unexpected body'
                                continue
                            }
                            [pscustomobject]@{
                                Path = $path
                                Status = $body.status
                                Seconds = [math]::Round($Watch.Elapsed.TotalSeconds, 3)
                                ObservedAt = [DateTimeOffset]::UtcNow.ToString('o')
                            }
                            $pending.Remove($path)
                        } finally {
                            $response.Dispose()
                        }
                    } catch [Net.Http.HttpRequestException], [OperationCanceledException] {
                        $lastStatus[$path] = 'no HTTP response'
                    }
                }
                if ($pending.Count) { Start-Sleep -Milliseconds 200 }
            }
            if ($pending.Count) {
                $details = foreach ($path in $pending.Keys) { "$path ($($lastStatus[$path]))" }
                throw "No successful probe within $Timeout seconds for $($details -join ', ')."
            }
        } finally {
            $client.Dispose()
        }
    }

    try {
        Write-Evidence "$Phase start | docker compose -p $project up -d --no-build --pull never --wait --wait-timeout $startupTimeout db web"
        $watch.Start()
        Invoke-Checked docker @compose up -d --no-build --pull never --wait --wait-timeout $startupTimeout db web 2>&1 |
            ForEach-Object { Write-Evidence "$Phase compose | $_" }
        $observations = @(Receive-Job -Job $probe -Wait -ErrorAction Stop)
        if ($observations.Count -ne 2) { throw "Missing HTTP observations for $Phase start." }
        foreach ($observation in $observations) {
            Write-Evidence "$Phase $($observation.Path) HTTP 200 status=$($observation.Status) elapsed_seconds=$($observation.Seconds) observed_at=$($observation.ObservedAt)"
        }
    } finally {
        Remove-Job -Job $probe -Force
    }
}

function Get-ResourceSample {
    $records = @(Invoke-Checked docker stats --no-stream --format '{{json .}}' $web $db)
    if ($records.Count -ne 2) { throw 'Expected a resource sample for each of the two test containers.' }
    $records
}

$repo = Split-Path -Parent $PSScriptRoot
$project = 'mindsprint-issue113-' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
$run = Join-Path ([IO.Path]::GetFullPath($OutputDir, $repo)) $project
$source = Join-Path $run 'source'
$evidence = Join-Path $run 'measurement-evidence.txt'
$archive = Join-Path $run 'source.tar'
$smokePath = Join-Path $repo 'tests/selfhost-smoke.py'
$image = "$($project):test"
$startupTimeout = 240
$imageBuilt = $false
$stackStarted = $false
$previousEnvironment = @{}
$result = 'Blocked'
$null = New-Item -ItemType Directory -Path $run -Force

try {
    try {
        Write-Evidence "Run | project=$project"
        foreach ($command in 'git', 'tar', 'docker', 'python') {
            if (!(Get-Command $command -ErrorAction SilentlyContinue)) { throw "Missing command $command." }
        }
        try {
            $dockerVersion = Invoke-Checked docker version --format '{{.Client.Version}} / {{.Server.Version}}' 2>$null
        } catch {
            throw 'Cannot reach the Docker Engine. Start Docker Desktop and verify access before retrying.'
        }
        $composeVersion = Invoke-Checked docker compose version --short
        Write-Evidence "Docker client / engine | $dockerVersion"
        Write-Evidence "Docker Compose | $composeVersion"
        Write-Evidence (Invoke-Checked docker info --format 'Engine | os={{.OperatingSystem}} kernel={{.KernelVersion}} cpu={{.NCPU}} memory_bytes={{.MemTotal}}')
        Write-Evidence (Invoke-Checked python --version)

        $result = 'Fail'
        $sha = Invoke-Checked git -C $repo rev-parse --verify --end-of-options "$Revision^{commit}"
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        Write-Evidence "Host | $($os.Caption) build=$($os.BuildNumber) cpu=$($cpu.Name) cores=$($cpu.NumberOfCores) threads=$($cpu.NumberOfLogicalProcessors) memory_gib=$ram"
        Write-Evidence "Source | git archive $sha"
        Write-Evidence "Tool SHA-256 | measure-docker-resources.ps1=$((Get-FileHash -LiteralPath $PSCommandPath).Hash) selfhost-smoke.py=$((Get-FileHash -LiteralPath $smokePath).Hash)"
        $null = New-Item -ItemType Directory -Path $source
        Invoke-Checked git -C $repo archive --format=tar "--output=$archive" $sha
        Invoke-Checked tar -xf $archive -C $source
        Remove-Item -LiteralPath $archive

        Write-Evidence "Build | docker build --progress plain --no-cache --label org.opencontainers.image.revision=$sha -t $image -f Dockerfile.selfhost <archive>"
        $buildArgs = @('build', '--progress', 'plain', '--no-cache', '--label', "org.opencontainers.image.revision=$sha",
            '-t', $image, '-f', (Join-Path $source 'Dockerfile.selfhost'), $source)
        $build = [Diagnostics.Stopwatch]::StartNew()
        Invoke-Checked docker @buildArgs 2>&1 | Out-File -LiteralPath (Join-Path $run 'build.log') -Encoding utf8
        $imageBuilt = $true
        Write-Evidence "Build complete | elapsed_seconds=$([math]::Round($build.Elapsed.TotalSeconds, 3))"

        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listener.Start()
        try { $port = $listener.LocalEndpoint.Port } finally { $listener.Stop() }
        $base = "http://127.0.0.1:$port"
        $envFile = Join-Path $source '.env.benchmark'
        $null = New-Item -ItemType File -Path $envFile
        $secretDirectory = Join-Path $source '.secrets.selfhost'
        $null = New-Item -ItemType Directory -Path $secretDirectory
        $null = New-Item -ItemType File -Path (Join-Path $secretDirectory 'gemini-api-key')
        $settings = @{
            DB_PASSWORD = [Guid]::NewGuid().ToString('N')
            JWT_KEY = [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N')
            DATABASE_NAME = 'mindsprint_benchmark'
            GOOGLE_CLIENT_ID = $null
            PUBLIC_ORIGIN = $null
            PUBLIC_ALIAS_ORIGIN = $null
        }
        foreach ($key in $settings.Keys) {
            $previousEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
            [Environment]::SetEnvironmentVariable($key, $settings[$key], 'Process')
        }
        $override = Join-Path $source 'compose.benchmark.yaml'
        @"
services:
  web:
    image: $image
    ports: !override
      - "127.0.0.1:$($port):8080"
"@ | Set-Content -LiteralPath $override -Encoding ascii
        $compose = @('compose', '--progress', 'plain', '-p', $project, '--project-directory', $source,
            '--env-file', $envFile, '-f', (Join-Path $source 'compose.selfhost.yaml'), '-f', $override)

        Write-Evidence "Stack | $base Production SQL Server Express 2022 | isolated project and volume, AI and Google disabled"
        Invoke-Checked docker @compose config --quiet
        Invoke-Checked docker @compose pull --policy missing db 2>&1 |
            ForEach-Object { Write-Evidence "DB image preparation | $_" }
        $stackStarted = $true
        Measure-Startup 'Cold'
        Write-Evidence "Warm preparation | docker compose -p $project stop web db (volume retained)"
        Invoke-Checked docker @compose stop web db 2>&1 |
            ForEach-Object { Write-Evidence "Warm preparation | $_" }
        Measure-Startup 'Warm'

        $web = Invoke-Checked docker @compose ps -q web
        $db = Invoke-Checked docker @compose ps -q db
        $webId = Invoke-Checked docker inspect --format '{{.Image}}' $web
        $dbId = Invoke-Checked docker inspect --format '{{.Image}}' $db
        $imageRevision = Invoke-Checked docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' $webId
        if ($imageRevision -ne $sha) { throw 'The running web image revision differs from the archived revision.' }
        Write-Evidence ("Web image | " + (Invoke-Checked docker image inspect --format 'id={{.Id}} size_bytes={{.Size}}' $webId))
        Write-Evidence ("DB image | " + (Invoke-Checked docker image inspect --format 'id={{.Id}} size_bytes={{.Size}}' $dbId))
        $volume = Invoke-Checked docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/opt/mssql"}}{{.Name}}{{end}}{{end}}' $db
        if ($volume -ne "$($project)_sqlserver-data") { throw 'Unexpected SQL Server test volume.' }
        $usage = Invoke-Checked docker @compose exec -T --user 0 db du -sk /var/opt/mssql
        if ($usage -notmatch '^(\d+)\s+/var/opt/mssql$') { throw 'Could not measure SQL Server volume usage.' }
        Write-Evidence "DB volume | $volume allocated_kib=$($Matches[1])"

        Write-Evidence 'Resource sampling | docker stats --no-stream --format "{{json .}}" <test web and DB>'
        Start-Sleep -Seconds 3
        foreach ($sample in 1..3) {
            Get-ResourceSample | ForEach-Object { Write-Evidence "Idle sample $sample | $_" }
        }
        Write-Evidence "Demo | python -E tests/selfhost-smoke.py $base --pace"
        $demo = Start-ThreadJob -ArgumentList $smokePath, $base -ScriptBlock {
            param($SmokePath, $Base)
            $PSNativeCommandUseErrorActionPreference = $false
            python -E $SmokePath $Base --pace
            if ($LASTEXITCODE -ne 0) { throw "Smoke test failed with exit code $LASTEXITCODE." }
        }
        try {
            $sample = 0
            while ($demo.State -in 'NotStarted', 'Running') {
                if ($demo.State -eq 'NotStarted') { Start-Sleep -Milliseconds 50; continue }
                $records = @(Get-ResourceSample)
                if ($demo.State -ne 'Running') { break }
                $sample++
                $records | ForEach-Object { Write-Evidence "Demo sample $sample | $_" }
            }
            Receive-Job -Job $demo -Wait -ErrorAction Stop | ForEach-Object { Write-Evidence "Smoke | $_" }
            if ($sample -eq 0) { throw 'No resource sample was captured while the smoke test was running.' }
        } finally {
            Remove-Job -Job $demo -Force
        }
    } finally {
        try {
            if ($stackStarted) {
                Invoke-Checked docker @compose down --volumes 2>&1 |
                    ForEach-Object { Write-Evidence "Cleanup | $_" }
            }
            if ($imageBuilt) {
                Invoke-Checked docker image rm $image | Out-Null
            }
        } finally {
            foreach ($key in $previousEnvironment.Keys) {
                [Environment]::SetEnvironmentVariable($key, $previousEnvironment[$key], 'Process')
            }
            if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive }
            if (Test-Path -LiteralPath $source) {
                $resolvedSource = Get-Item -LiteralPath $source
                $expectedSource = Join-Path (Resolve-Path -LiteralPath $run).ProviderPath 'source'
                if ($resolvedSource.FullName -ne $expectedSource -or
                    $resolvedSource.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                    throw 'Unexpected source directory during cleanup.'
                }
                Remove-Item -LiteralPath $resolvedSource.FullName -Recurse -Force
            }
        }
    }
} catch {
    Write-Evidence "Result | $result | $($_.Exception.Message)"
    throw
}

Write-Evidence 'Result | Pass'
