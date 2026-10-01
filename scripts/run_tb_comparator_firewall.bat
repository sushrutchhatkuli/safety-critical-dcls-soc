@echo off
REM ==============================================================================
REM File: run_tb_comparator_firewall.bat
REM Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
REM ==============================================================================

echo ============================================================
echo   Running Phase 3: DCLS Comparator and Firewall Simulation
echo ============================================================

powershell -ExecutionPolicy Bypass -File "%~dp0run_tb_comparator_firewall.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Simulation failed with code %ERRORLEVEL%!
    exit /b %ERRORLEVEL%
)
echo [SUCCESS] Phase 3 simulation completed cleanly.
