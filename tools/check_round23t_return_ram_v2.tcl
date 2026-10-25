set return_ram_cells [get_cells {u_video_pipe/u_accel_dma/r/storage_ram*.memory}]
puts "RETURN_RAM_RAW $return_ram_cells"
if {[llength $return_ram_cells] != 7} {error "Expected exactly seven return RAMs"}
foreach cell $return_ram_cells {puts "RETURN_RAM_CELL $cell"}
foreach kind {setup hold} {
 report_timing -$kind -from_clock [get_clocks core_clk] -to $return_ram_cells -npaths 2048 -nworst 1 -file ArtFlow.return_ram_write_${kind}.rpt
 report_timing -$kind -from_clock [get_clocks cnn_clk] -to $return_ram_cells -npaths 2048 -nworst 1 -file ArtFlow.return_ram_address_${kind}.rpt
 report_timing -$kind -from $return_ram_cells -to_clock [get_clocks cnn_clk] -npaths 2048 -nworst 1 -file ArtFlow.return_ram_data_${kind}.rpt
}
