@echo off
REM ==============================================================================
REM File: run_tb_abs_firmware.bat
REM Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
REM ==============================================================================

echo ============================================================
echo   Running Phase 5: Bare-Metal ABS Firmware Simulation (XSim)
echo ============================================================

powershell -ExecutionPolicy Bypass -File "%~dp0run_tb_abs_firmware.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Simulation failed with code %ERRORLEVEL%!
    exit /b %ERRORLEVEL%
)
echo [SUCCESS] Bare-Metal ABS Firmware simulation completed cleanly.
