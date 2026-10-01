# ==============================================================================
# File: open_waveform.ps1
# Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
# Description: Helper to open simulation waveform database in Vivado GUI.
# ==============================================================================

param(
    [string]$WdbFile = "tb_fault_inj_snap.wdb"
)

$VIVADO_BAT = "C:\Xilinx\2025.1\Vivado\bin\vivado.bat"

if (-not (Test-Path $VIVADO_BAT)) {
    Write-Host "[ERROR] Vivado executable not found at $VIVADO_BAT" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $WdbFile)) {
    Write-Host "[ERROR] Waveform file '$WdbFile' does not exist." -ForegroundColor Red
    Write-Host "Available waveforms in this directory:" -ForegroundColor Yellow
    Get-ChildItem -Filter *.wdb | ForEach-Object { Write-Host " - $($_.Name)" }
    exit 1
}

Write-Host "Opening '$WdbFile' with Vivado GUI..." -ForegroundColor Green
Start-Process -FilePath $VIVADO_BAT -ArgumentList $WdbFile
