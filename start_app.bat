@echo off
setlocal EnableExtensions

rem ================================================================
rem My Elysia AI unified launcher
rem   1. Start backend silently if it is not running (pythonw,
rem      log goes to %%LOCALAPPDATA%%\MyElysiaAI\backend.log)
rem   2. Launch frontend and wait until it exits
rem   3. Close backend after frontend exits
rem ================================================================

set "ROOT=%~dp0"
set "PORT=8000"
set "BACKEND_DIR=%ROOT%backend"
set "LOG_DIR=%LOCALAPPDATA%\MyElysiaAI"
set "LOG_FILE=%LOG_DIR%\backend.log"
set "PY=%BACKEND_DIR%\.venv\Scripts\python.exe"
if exist "%BACKEND_DIR%\.venv\Scripts\pythonw.exe" set "PY=%BACKEND_DIR%\.venv\Scripts\pythonw.exe"

rem --- 1. Backend already running? Skip straight to frontend ---
curl.exe -s -o nul --max-time 3 "http://127.0.0.1:%PORT%/api/health"
if not errorlevel 1 goto launch_frontend

rem --- 2. Start backend silently, then wait for it (max ~65s) ---
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
start /b "" cmd /c "cd /d "%BACKEND_DIR%" && "%PY%" -m uvicorn app.main:app --host 127.0.0.1 --port %PORT% >> "%LOG_FILE%" 2>&1"
rem Give boot-time network stack a moment to settle
timeout /t 5 /nobreak >nul
set /a TRIES=0

:wait_backend
set /a TRIES+=1
if %TRIES% gtr 30 goto backend_failed
timeout /t 2 /nobreak >nul
curl.exe -s -o nul --max-time 3 "http://127.0.0.1:%PORT%/api/health"
if errorlevel 1 goto wait_backend

rem --- 3. Launch frontend (prefer Release build) and wait for exit ---
:launch_frontend
set "FRONTEND_EXE=%ROOT%frontend\build\windows\x64\runner\Release\elysia_ai.exe"
if not exist "%FRONTEND_EXE%" set "FRONTEND_EXE=%ROOT%frontend\build\windows\x64\runner\Debug\elysia_ai.exe"
if not exist "%FRONTEND_EXE%" goto frontend_missing
start "" /wait "%FRONTEND_EXE%"

rem --- 4. Frontend exited: close backend (process listening on port) ---
for /f "tokens=5" %%a in ('netstat -ano ^| findstr "LISTENING" ^| findstr ":%PORT% "') do (
    taskkill /PID %%a /F >nul 2>&1
)
exit /b 0

:backend_failed
echo Backend failed to start, see %LOG_FILE% >> "%LOG_FILE%"
exit /b 1

:frontend_missing
echo Frontend build not found. Run "flutter build windows" in frontend\ first.
exit /b 1
