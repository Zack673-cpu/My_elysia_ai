param(
    [switch]$FrontendOnly,
    [switch]$BackendOnly,
    [switch]$SkipAnalyze,
    [switch]$UpgradeSDK
)

$ProjectRoot = $PSScriptRoot
if (-not $ProjectRoot) { $ProjectRoot = "d:\My_Elysia_ai" }
$FrontendDir = Join-Path $ProjectRoot "frontend"
$BackendDir  = Join-Path $ProjectRoot "backend"
$PythonExe   = "D:\python.exe"
$UvExe       = "D:\Scripts\uv.exe"
$FlutterBin  = "D:\flutter\bin\flutter.bat"

function Log-Step($m) { Write-Host "`n>> $m" -ForegroundColor Cyan }
function Log-Ok($m)   { Write-Host "   [OK] $m" -ForegroundColor Green }
function Log-Skip($m) { Write-Host "   [SKIP] $m" -ForegroundColor Yellow }
function Log-Fail($m) { Write-Host "   [FAIL] $m" -ForegroundColor Red }
function Log-Info($m) { Write-Host "   $m" -ForegroundColor White }

$doneF = $false
$doneB = $false
$doneSDK = $false

# === Optional: Upgrade Flutter SDK ===
if ($UpgradeSDK) {
    Log-Step "Upgrading Flutter SDK..."
    $before = (& $FlutterBin --version 2>&1 | Select-String "Flutter (\S+)").Matches.Groups[1].Value
    & $FlutterBin upgrade
    if ($LASTEXITCODE -eq 0) {
        $after = (& $FlutterBin --version 2>&1 | Select-String "Flutter (\S+)").Matches.Groups[1].Value
        $doneSDK = $true
        if ($before -ne $after) {
            Log-Ok "Flutter SDK upgraded: $before -> $after"
        } else {
            Log-Ok "Flutter SDK already at latest: $after"
        }
    } else {
        Log-Fail "Flutter SDK upgrade failed"
        exit 1
    }
}

# === Backend: uv pip install --upgrade ===
if (-not $FrontendOnly) {
    Log-Step "Updating backend Python deps..."

    if (-not (Test-Path $UvExe)) {
        Log-Fail "uv not found: $UvExe"; exit 1
    }

    $env:PYTHONPATH = "D:\Lib\site-packages"
    $reqFile = Join-Path $BackendDir "requirements.txt"
    & $UvExe pip install --python $PythonExe --upgrade --quiet -r $reqFile

    if ($LASTEXITCODE -eq 0) {
        $doneB = $true
        Log-Ok "Backend dependencies updated"
        Write-Host ""
        try {
            $out = & $UvExe pip list --python $PythonExe --quiet 2>$null
            $out | Where-Object { $_ -match "fastapi |uvicorn |openai |duckduckgo-search|pydantic-settings" } | ForEach-Object { Write-Host "   $_" }
        } catch {}
    } else {
        Log-Fail "Backend update failed"; exit 1
    }
} else {
    Log-Skip "Backend (-FrontendOnly)"
}

# === Frontend: flutter pub upgrade + analyze ===
if (-not $BackendOnly) {
    Log-Step "Updating frontend Flutter deps..."

    if (-not (Test-Path $FlutterBin)) {
        Log-Fail "flutter not found: $FlutterBin"; exit 1
    }

    Set-Location $FrontendDir
    & $FlutterBin pub upgrade

    if ($LASTEXITCODE -eq 0) {
        $doneF = $true
        Log-Ok "Flutter dependencies updated"
    } else {
        Log-Fail "flutter pub upgrade failed, trying flutter pub get..."
        & $FlutterBin pub get
        if ($LASTEXITCODE -ne 0) {
            Log-Fail "flutter pub get also failed"; exit 1
        }
        $doneF = $true
        Log-Ok "flutter pub get done (some deps may not be latest)"
    }

    if (-not $SkipAnalyze) {
        Log-Step "Running flutter analyze..."
        & $FlutterBin analyze
        if ($LASTEXITCODE -eq 0) {
            Log-Ok "flutter analyze: no issues"
        } else {
            Log-Fail "flutter analyze found issues"
        }
    } else {
        Log-Skip "flutter analyze (-SkipAnalyze)"
    }
} else {
    Log-Skip "Frontend (-BackendOnly)"
}

# === Summary ===
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Demugo AI - Update Complete!" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
if ($doneSDK) { Write-Host "  Flutter SDK upgrade    OK" -ForegroundColor Green }
if ($doneB)   { Write-Host "  Backend Python deps    OK" -ForegroundColor Green }
if ($doneF)   { Write-Host "  Frontend Flutter deps  OK" -ForegroundColor Green }
if (-not $UpgradeSDK) {
    Write-Host ""
    Log-Info "Tip: use -UpgradeSDK to also upgrade Flutter SDK"
}
Write-Host ""
