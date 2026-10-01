@echo off
REM ==============================================================================
REM File: run_tb_fault_injection.bat
REM Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
REM ==============================================================================

echo ============================================================
echo   Running Phase 6: Fault Injection Campaign ^& SVA (XSim)
echo ============================================================

powershell -ExecutionPolicy Bypass -File "%~dp0run_tb_fault_injection.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Simulation failed with code %ERRORLEVEL%!
    exit /b %ERRORLEVEL%
)
echo [SUCCESS] Fault Injection Campaign completed cleanly.
exit /b 0
