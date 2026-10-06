# Audit v06 synchronizer existence and the timed second-stage path.
# Normal ArtFlow.sdc stays active; first-stage async exceptions must not cut this path.
foreach {tag head tail} {
    mode u_ui/u_mode_key/key_meta u_ui/u_mode_key/key_sync
    osd u_ui/u_osd_key/key_meta u_ui/u_osd_key/key_sync
    capture u_ui/u_fps/cap_meta u_ui/u_fps/cap_sync
} {
    foreach name [list $head $tail] {
        set cells [get_cells ${name}~FF]
        puts "UI_CDC_ENDPOINT $name count=[llength $cells]"
        if {[llength $cells] != 1} {error "Missing UI synchronizer: $name"}
    }
    report_timing -setup -from [get_cells ${head}~FF] -to [get_cells ${tail}~FF] -npaths 1 -file ArtFlow.ui_${tag}_setup.rpt
    report_timing -hold -from [get_cells ${head}~FF] -to [get_cells ${tail}~FF] -npaths 1 -file ArtFlow.ui_${tag}_hold.rpt
}
