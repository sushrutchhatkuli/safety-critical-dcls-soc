# ==============================================================================
# File: synth.tcl
# Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
# Description: Vivado Batch Synthesis Script for AMD/Xilinx Artix-7 FPGA.
#              Targets: xc7a100tcsg324-1 (Digilent Nexys A7-100T / Arty A7-100T)
#              Clock: 100 MHz (10.0 ns period)
# ==============================================================================

set PROJECT_NAME "safety_dcls_soc"
set PART_NAME    "xc7a100tcsg324-1"
set TOP_MODULE   "safety_soc_top"
set OUTPUT_DIR   "synth_output"

# Create output reports directory
file mkdir $OUTPUT_DIR
file mkdir "reports"

# 1. Read SystemVerilog RTL Sources
puts "------------------------------------------------------------"
puts " Reading SystemVerilog Design Files..."
puts "------------------------------------------------------------"

read_verilog -sv rtl/uart/uart_pkg.sv
read_verilog -sv [glob rtl/core/*.sv]
read_verilog -sv [glob rtl/bus/*.sv]
read_verilog -sv [glob rtl/accel/*.sv]
read_verilog -sv [glob rtl/uart/axi4_lite_slave.sv]
read_verilog -sv [glob rtl/uart/fifo_circular.sv]
read_verilog -sv [glob rtl/uart/uart_axi_top.sv]
read_verilog -sv [glob rtl/uart/uart_baud_gen.sv]
read_verilog -sv [glob rtl/uart/uart_rx.sv]
read_verilog -sv [glob rtl/uart/uart_tx.sv]
read_verilog -sv [glob rtl/dcls/*.sv]
read_verilog -sv rtl/safety_soc_top.sv

# 2. Set Include Directories
set_property include_dirs [list rtl/core rtl/uart rtl/dcls] [current_fileset]

# 3. Read Physical & Timing Constraints
read_xdc synth/constraints.xdc

# 4. Run Logic Synthesis
puts "------------------------------------------------------------"
puts " Running Vivado Synthesis for $TOP_MODULE on $PART_NAME..."
puts "------------------------------------------------------------"
synth_design -top $TOP_MODULE -part $PART_NAME -flatten_hierarchy rebuilt

# 5. Write Checkpoint
write_checkpoint -force "$OUTPUT_DIR/${TOP_MODULE}_synth.dcp"

# 6. Generate Sign-Off Reports
puts "------------------------------------------------------------"
puts " Generating Timing, Utilization, and DRC Reports..."
puts "------------------------------------------------------------"
report_utilization -file "reports/utilization.rpt" -pb "reports/utilization.pb"
report_timing_summary -file "reports/timing_summary.rpt" -max_paths 10
report_drc -file "reports/drc.rpt"
report_clock_utilization -file "reports/clock_utilization.rpt"

puts "------------------------------------------------------------"
puts " Synthesis Completed Successfully!"
puts " Output Checkpoint: $OUTPUT_DIR/${TOP_MODULE}_synth.dcp"
puts " Reports Directory: reports/"
puts "------------------------------------------------------------"
