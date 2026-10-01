@echo off
REM ==============================================================================
REM File: compile_all.bat
REM Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
REM ==============================================================================

set VIVADO_BIN=C:\Xilinx\2025.1\Vivado\bin
if exist "%VIVADO_BIN%\xvlog.bat" (
    set XVLOG="%VIVADO_BIN%\xvlog.bat"
) else (
    set XVLOG=xvlog
)

echo ============================================================
echo   Compiling Safety Critical DCLS SoC RTL with Vivado xvlog
echo ============================================================

powershell -ExecutionPolicy Bypass -File "%~dp0compile_all.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed!
    exit /b %ERRORLEVEL%
)
echo [SUCCESS] Compilation completed cleanly.
