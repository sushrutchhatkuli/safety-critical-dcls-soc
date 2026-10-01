@echo off
REM ==============================================================================
REM File: run_synth.bat
REM Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
REM ==============================================================================

echo ============================================================
echo   Running Phase 7: FPGA Synthesis (AMD/Xilinx Artix-7)
echo ============================================================

powershell -ExecutionPolicy Bypass -File "%~dp0run_synth.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Synthesis failed with code %ERRORLEVEL%!
    exit /b %ERRORLEVEL%
)
echo [SUCCESS] Synthesis completed cleanly.
exit /b 0
