@echo off
REM ==============================================================================
REM File: run_tb_dcls_wrapper.bat
REM Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
REM ==============================================================================

echo ============================================================
echo   Running Phase 2: DCLS Core Wrapper Simulation (Vivado XSim)
echo ============================================================

powershell -ExecutionPolicy Bypass -File "%~dp0run_tb_dcls_wrapper.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Simulation failed with code %ERRORLEVEL%!
    exit /b %ERRORLEVEL%
)
echo [SUCCESS] Phase 2 simulation completed cleanly.
