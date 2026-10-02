open_wave_database tb_fault_inj_snap.wdb
set objs [get_objects /tb_fault_injection_campaign/*]
puts "TB OBJECTS: $objs"
set dut_objs [get_objects /tb_fault_injection_campaign/dut/*]
puts "DUT OBJECTS: $dut_objs"
exit
