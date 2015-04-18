read_verilog [ glob ./*.v ]
read_xdc constraints.xdc

set outputDir ./build
file mkdir $outputDir

set thepart xc7z015clg485-1
synth_design -top top -part $thepart -flatten_hierarchy none
write_checkpoint -force $outputDir/post_synth
opt_design
place_design
write_checkpoint -force $outputDir/post_place
phys_opt_design
route_design
write_checkpoint -force $outputDir/post_route

report_timing_summary -file $outputDir/post_route_timing_summary.rpt
report_timing -sort_by group -max_paths 5 -path_type summary -file $outputDir/post_route_timing.rpt
report_utilization -file $outputDir/post_route_util.rpt
report_drc -file $outputDir/post_imp_drc.rpt
write_verilog -force $outputDir/imp_netlist.v
write_xdc -no_fixed_only -force $outputDir/imp.xdc

write_bitstream -force -bin_file -file $outputDir/out.bit
