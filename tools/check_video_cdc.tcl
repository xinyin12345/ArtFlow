# Invoked by run_efinity.ps1 against the generated CDC-only audit SDC.
# A valid bus-skew report must contain all 32 endpoints per crossing.
foreach name {count_meta epoch_meta} {
    set cells [get_cells u_video_pipe/u_store/${name}*~FF]
    puts "CDC_ENDPOINTS $name count=[llength $cells]"
    if {[llength $cells] != 32} {error "Missing CDC endpoints: $name"}
}
report_bus_skew -npaths 32 -nworst 1 -file ArtFlow.video_bus_skew.rpt
report_bus_skew -setup -npaths 32 -nworst 1 -file ArtFlow.video_bus_delay.rpt
