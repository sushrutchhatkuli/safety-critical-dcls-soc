@echo off
setlocal
set VIVADO_BIN=C:\Xilinx\2025.1\Vivado\bin
set WDB_FILE=tb_fault_inj_snap.wdb
set WCFG_FILE=tb_fault_inj.wcfg

if not "%~1"=="" (
    set WDB_FILE=%~1
)

if not exist "%WDB_FILE%" (
    echo [ERROR] Waveform database "%WDB_FILE%" not found.
    echo Available waveforms in this directory:
    dir /b *.wdb
    exit /b 1
)

echo Opening "%WDB_FILE%" with pre-configured waveform viewer...
if exist "%WCFG_FILE%" (
    call "%VIVADO_BIN%\vivado.bat" %WDB_FILE% -view %WCFG_FILE%
) else (
    call "%VIVADO_BIN%\vivado.bat" %WDB_FILE%
)
exit /b 0
