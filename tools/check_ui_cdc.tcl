# Audit v06 synchronizer existence and the timed second-stage path.
# Normal ArtFlow.sdc stays active; first-stage async exceptions must not cut this path.
foreach {tag head tail} {
    mode u_ui/u_mode_key/key_meta u_ui/u_mode_key/key_sync
    osd u_ui/u_osd_key/key_meta u_ui/u_osd_key/key_sync
    capture u_ui/u_fps/cap_meta u_ui/u_fps/cap_sync
    process u_process_fps/cap_meta u_process_fps/cap_sync
    diag_vs {u_control/diag_meta[0]} {u_control/diag_sync[0]}
    diag_raw {u_control/diag_meta[1]} {u_control/diag_sync[1]}
    diag_bin {u_control/diag_meta[2]} {u_control/diag_sync[2]}
    csi_core_1 {u_csi_reset/core_release[0]} {u_csi_reset/core_release[1]}
    csi_core_2 {u_csi_reset/core_release[1]} {csi_reset_core_n}
    csi_byte_1 {u_csi_reset/byte_release[0]} {u_csi_reset/byte_release[1]}
    csi_byte_2 {u_csi_reset/byte_release[1]} {csi_reset_byte_n}
    csi_pixel_1 {u_csi_reset/pixel_release[0]} {u_csi_reset/pixel_release[1]}
    csi_pixel_2 {u_csi_reset/pixel_release[1]} {csi_reset_pixel_n}
} {
    foreach name [list $head $tail] {
        set cells [get_cells ${name}~FF]
        puts "UI_CDC_ENDPOINT $name count=[llength $cells]"
        if {[llength $cells] != 1} {error "Missing UI synchronizer: $name"}
    }
    report_timing -setup -from [get_cells ${head}~FF] -to [get_cells ${tail}~FF] -npaths 1 -file ArtFlow.ui_${tag}_setup.rpt
    report_timing -hold -from [get_cells ${head}~FF] -to [get_cells ${tail}~FF] -npaths 1 -file ArtFlow.ui_${tag}_hold.rpt
}
