# ==============================================================================
# File: run_synth.ps1
# Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
# Description: Automated Vivado batch synthesis runner for AMD/Xilinx Artix-7.
# ==============================================================================

$ErrorActionPreference = "Stop"

$VIVADO_BIN = "C:\Xilinx\2025.1\Vivado\bin"
$VIVADO = "$VIVADO_BIN\vivado.bat"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Running Phase 7: FPGA Synthesis (AMD/Xilinx Artix-7)       " -ForegroundColor Cyan
Write-Host " Target Part: xc7a100tcsg324-1 | Clock Target: 100 MHz      " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Clean previous synthesis outputs
Remove-Item -Recurse -Force synth_output, reports, .Xil, *.log, *.jou -ErrorAction SilentlyContinue

& $VIVADO -mode batch -source synth/synth.tcl
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Vivado synthesis execution failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "============================================================" -ForegroundColor Green
Write-Host " Phase 7 FPGA Synthesis Succeeded! Check reports/           " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
