@echo off
REM ==============================================================================
REM File: open_waveform.bat
REM Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
REM Description: Helper to open simulation waveform database in Vivado GUI.
REM ==============================================================================

set VIVADO_BIN=C:\Xilinx\2025.1\Vivado\bin
set WDB_FILE=tb_fault_inj_snap.wdb

if not "%~1"=="" (
    set WDB_FILE=%~1
)

if not exist "%WDB_FILE%" (
    echo [ERROR] Waveform database "%WDB_FILE%" not found.
    echo Available waveforms in this directory:
    dir /b *.wdb
    exit /b 1
)

echo Opening "%WDB_FILE%" with Vivado GUI...
start "" "%VIVADO_BIN%\vivado.bat" "%WDB_FILE%"
exit /b 0
