@echo off
REM ==============================================================================
REM File: run_tb_dcls_fcu.bat
REM Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
REM ==============================================================================

echo ============================================================
echo   Running FCU Blackbox Telemetry Simulation (Vivado XSim)
echo ============================================================

powershell -ExecutionPolicy Bypass -File "%~dp0run_tb_dcls_fcu.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Simulation failed with code %ERRORLEVEL%!
    exit /b %ERRORLEVEL%
)
echo [SUCCESS] FCU simulation completed cleanly.
