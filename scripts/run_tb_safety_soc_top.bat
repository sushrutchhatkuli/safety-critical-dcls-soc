@echo off
REM ==============================================================================
REM File: run_tb_safety_soc_top.bat
REM Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
REM ==============================================================================

echo ============================================================
echo   Running Phase 4: Top-Level Safety SoC Simulation (XSim)
echo ============================================================

powershell -ExecutionPolicy Bypass -File "%~dp0run_tb_safety_soc_top.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Simulation failed with code %ERRORLEVEL%!
    exit /b %ERRORLEVEL%
)
echo [SUCCESS] Top-Level Safety SoC simulation completed cleanly.
