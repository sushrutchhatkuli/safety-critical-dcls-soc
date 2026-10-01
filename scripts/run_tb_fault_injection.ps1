# ==============================================================================
# File: run_tb_fault_injection.ps1
# Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
# Description: Automated Vivado XSim runner for Phase 6 Fault Injection Campaign.
# ==============================================================================

$ErrorActionPreference = "Stop"

$VIVADO_BIN = "C:\Xilinx\2025.1\Vivado\bin"
$XVLOG = "$VIVADO_BIN\xvlog.bat"
$XELAB = "$VIVADO_BIN\xelab.bat"
$XSIM  = "$VIVADO_BIN\xsim.bat"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Running Phase 6: Fault Injection Campaign & SVA Verification" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Clean previous simulation artifacts
Remove-Item -Recurse -Force xsim.dir, .Xil, *.log, *.pb, *.jou -ErrorAction SilentlyContinue

# 1. Ensure fresh assembly binary exists
Write-Host "Step 1: Assembling RISC-V Safety Firmware (sw/imem.mem)..." -ForegroundColor Yellow
python sw/rv32i_asm.py sw/abs_safety_app.S sw/imem.mem
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Assembler failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

# 2. Gather all RTL and TB source files
$CORE_FILES  = (Get-ChildItem -Path "rtl\core\*.sv").FullName
$BUS_FILES   = (Get-ChildItem -Path "rtl\bus\*.sv").FullName
$ACCEL_FILES = (Get-ChildItem -Path "rtl\accel\*.sv").FullName
$UART_PKG    = (Resolve-Path "rtl\uart\uart_pkg.sv").Path
$UART_FILES  = (Get-ChildItem -Path "rtl\uart\*.sv" | Where-Object { $_.Name -ne "uart_pkg.sv" }).FullName
$DCLS_FILES  = (Get-ChildItem -Path "rtl\dcls\*.sv").FullName
$TOP_FILE    = (Resolve-Path "rtl\safety_soc_top.sv").Path
$TB_FILE     = (Resolve-Path "tb\tb_fault_injection_campaign.sv").Path

$ALL_FILES = @($UART_PKG) + $CORE_FILES + $BUS_FILES + $ACCEL_FILES + $UART_FILES + $DCLS_FILES + @($TOP_FILE, $TB_FILE)

Write-Host "Step 2: Compiling $($ALL_FILES.Count) SystemVerilog source files with xvlog..." -ForegroundColor Yellow
$CMD_ARGS = @(
    "-sv",
    "-i", "rtl\core",
    "-i", "rtl\uart",
    "-i", "rtl\dcls"
) + $ALL_FILES

& $XVLOG @CMD_ARGS
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] xvlog failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

# 3. Elaborate Snapshot with xelab
Write-Host "Step 3: Elaborating design snapshot with xelab..." -ForegroundColor Yellow
& $XELAB -top tb_fault_injection_campaign -snapshot tb_fault_inj_snap -timescale 1ns/1ps -debug typical
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] xelab elaboration failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

# 4. Simulate with xsim
Write-Host "Step 4: Running simulation with xsim..." -ForegroundColor Yellow
& $XSIM tb_fault_inj_snap -R
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] xsim execution failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "============================================================" -ForegroundColor Green
Write-Host " Phase 6 Fault Injection Campaign Succeeded!                " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

# Clean up temporary logs to keep workspace clean
Remove-Item -Recurse -Force xsim.dir, .Xil, *.log, *.pb, *.jou -ErrorAction SilentlyContinue
