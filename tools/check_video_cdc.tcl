# Invoked by run_efinity.ps1 against the generated CDC-only audit SDC.
# All Gray-bus and gain-mailbox endpoints must survive the implemented netlist.
foreach name {count_meta epoch_meta} {
    set cells [get_cells u_video_pipe/u_store/${name}*~FF]
    puts "CDC_ENDPOINTS $name count=[llength $cells]"
    if {[llength $cells] != 32} {error "Missing CDC endpoints: $name"}
}
foreach name {camera_gain_r camera_gain_g camera_gain_b u_control/mailbox_r u_control/mailbox_g u_control/mailbox_b} {
    set cells [get_cells ${name}*~FF]
    puts "CDC_ENDPOINTS $name count=[llength $cells]"
    if {[llength $cells] != 16} {error "Missing gain mailbox cells: $name"}
}
# 48 allows every slow-corner destination, including the reference bit, to be
# checked in the bundled-data crossing; the two 32-bit buses remain mandatory.
report_bus_skew -npaths 48 -nworst 1 -file ArtFlow.video_bus_skew.rpt
report_bus_skew -setup -npaths 48 -nworst 1 -file ArtFlow.video_bus_delay.rpt
