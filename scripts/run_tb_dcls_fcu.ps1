# ==============================================================================
# File: run_tb_dcls_fcu.ps1
# Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
# Description: Automated Vivado XSim runner for FCU Blackbox Telemetry TB.
# ==============================================================================

$ErrorActionPreference = "Stop"

$VIVADO_BIN = "C:\Xilinx\2025.1\Vivado\bin"
$XVLOG = "$VIVADO_BIN\xvlog.bat"
$XELAB = "$VIVADO_BIN\xelab.bat"
$XSIM  = "$VIVADO_BIN\xsim.bat"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Running FCU Blackbox Telemetry Simulation (Vivado XSim)   " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Clean previous simulation artifacts
Remove-Item -Recurse -Force xsim.dir, .Xil, *.log, *.pb, *.jou -ErrorAction SilentlyContinue

# 1. Compile FCU & Testbench
Write-Host "Step 1: Compiling SystemVerilog source files with xvlog..." -ForegroundColor Yellow
$CMD_ARGS = @(
    "-sv",
    "-i", "rtl\dcls",
    "rtl\dcls\dcls_fcu.sv",
    "tb\tb_dcls_fcu.sv"
)

& $XVLOG @CMD_ARGS
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] xvlog failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

# 2. Elaborate Snapshot with xelab
Write-Host "Step 2: Elaborating design snapshot with xelab..." -ForegroundColor Yellow
& $XELAB -top tb_dcls_fcu -snapshot tb_fcu_snap -timescale 1ns/1ps -debug typical
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] xelab elaboration failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

# 3. Simulate with xsim
Write-Host "Step 3: Running simulation with xsim..." -ForegroundColor Yellow
& $XSIM tb_fcu_snap -R
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] xsim execution failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "============================================================" -ForegroundColor Green
Write-Host " FCU Blackbox Telemetry Simulation Completed Successfully! " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

# Clean up temporary logs to keep workspace clean
Remove-Item -Recurse -Force xsim.dir, .Xil, *.log, *.pb, *.jou -ErrorAction SilentlyContinue
