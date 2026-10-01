# ==============================================================================
# File: compile_all.ps1
# Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
# Description: Automated Vivado xvlog syntax & compilation verification script.
# ==============================================================================

$ErrorActionPreference = "Stop"

$VIVADO_BIN = "C:\Xilinx\2025.1\Vivado\bin"
if (-not (Test-Path "$VIVADO_BIN\xvlog.bat")) {
    # Fallback to PATH
    $XVLOG = "xvlog"
} else {
    $XVLOG = "$VIVADO_BIN\xvlog.bat"
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Compiling Safety Critical DCLS SoC RTL with Vivado xvlog " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Gather files
$CORE_FILES = (Get-ChildItem -Path "rtl\core\*.sv").FullName
$BUS_FILES  = (Get-ChildItem -Path "rtl\bus\*.sv").FullName
$ACCEL_FILES = (Get-ChildItem -Path "rtl\accel\*.sv").FullName
$UART_PKG    = (Resolve-Path "rtl\uart\uart_pkg.sv").Path
$UART_FILES  = (Get-ChildItem -Path "rtl\uart\*.sv" | Where-Object { $_.Name -ne "uart_pkg.sv" }).FullName

$ALL_FILES = @()
$ALL_FILES += $UART_PKG
$ALL_FILES += $CORE_FILES
$ALL_FILES += $BUS_FILES
$ALL_FILES += $ACCEL_FILES
$ALL_FILES += $UART_FILES

# Check if dcls directory has files
if (Test-Path "rtl\dcls\*.sv") {
    $DCLS_FILES = (Get-ChildItem -Path "rtl\dcls\*.sv").FullName
    $ALL_FILES += $DCLS_FILES
}

# Check if top-level exists
if (Test-Path "rtl\safety_soc_top.sv") {
    $ALL_FILES += (Resolve-Path "rtl\safety_soc_top.sv").Path
}

Write-Host "Found $($ALL_FILES.Count) SystemVerilog source files to compile." -ForegroundColor Yellow

$CMD_ARGS = @(
    "-sv",
    "-i", "rtl\core",
    "-i", "rtl\uart"
) + $ALL_FILES

& $XVLOG @CMD_ARGS

if ($LASTEXITCODE -eq 0) {
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " SUCCESS: All RTL modules compiled with ZERO errors!        " -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
} else {
    Write-Host " ERROR: Compilation failed with exit code $LASTEXITCODE      " -ForegroundColor Red
    exit $LASTEXITCODE
}
