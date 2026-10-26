# Invoked by run_efinity.ps1 against the generated CDC-only audit SDC.
# All Gray-bus and gain-mailbox endpoints must survive the implemented netlist.
foreach {name bits} {count_meta 32 epoch_meta 32 layout_meta 2} {
    set cells [get_cells u_video_pipe/u_store/${name}*~FF]
    puts "CDC_ENDPOINTS $name count=[llength $cells]"
    if {[llength $cells] != $bits} {error "Missing CDC endpoints: $name"}
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

# Audit v06 synchronizer existence and the timed second-stage path.
# Normal ArtFlow.sdc stays active; first-stage async exceptions must not cut this path.
foreach {tag head tail} {
    layout_bit0 {u_video_pipe/u_store/layout_meta[0]} {u_video_pipe/u_store/layout_sync[0]}
    layout_bit1 {u_video_pipe/u_store/layout_meta[1]} {u_video_pipe/u_store/layout_sync[1]}
    style u_video_pipe/u_accel_dma/styles.key_filter/key_meta u_video_pipe/u_accel_dma/styles.key_filter/key_sync
    flash u_video_pipe/u_accel_dma/styles.banks/reader/miso_meta u_video_pipe/u_accel_dma/styles.banks/reader/miso_sync
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

# Post-route audit with clock groups removed in the audit-only SDC.
# All pointer synchronizer stages must exist and retain timed same-clock paths.
foreach {fifo aw} {jobs 2 events 2 ar 2 aw 2 w 3 r 3 b 2 style_status_fifo 2} {
    foreach direction {w r} {
        set base u_video_pipe/u_accel_dma/${fifo}/${direction}gray
        foreach stage {meta sync} {
            set cells [get_cells ${base}_${stage}*~FF]
            puts "CNN_CDC_SYNC ${fifo}_${direction}_${stage} count=[llength $cells]"
            if {[llength $cells] != [expr {$aw+1}]} {error "Missing CNN FIFO synchronizer"}
        }
        foreach kind {setup hold} {
            report_timing -$kind -from [get_cells ${base}_meta*~FF] -to [get_cells ${base}_sync*~FF] -npaths [expr {$aw+1}] -nworst 1 -file ArtFlow.cnn_${fifo}_${direction}_${kind}.rpt
        }
    }
}
foreach i {0 1} {
    set j [expr {$i+1}]
    set head [format {u_video_pipe/u_accel_dma/reset_cnn[%d]~FF} $i]
    set tail [format {u_video_pipe/u_accel_dma/reset_cnn[%d]~FF} $j]
    if {[llength [get_cells $head]] != 1 || [llength [get_cells $tail]] != 1} {error "Missing CNN reset synchronizer"}
    foreach kind {setup hold} {
        report_timing -$kind -from [get_cells $head] -to [get_cells $tail] -npaths 1 -file ArtFlow.cnn_reset_${i}_${kind}.rpt
    }
}
# Report the worst path to EVERY crossing endpoint. Data is stable in the
# queue until read capture. Each Gray route must fit one 222.222 MHz period;
# every payload route must fit the two-cycle synchronizer settling interval.
report_timing -setup -from_clock [get_clocks cnn_clk] -to_clock [get_clocks core_clk] -npaths 1024 -nworst 1 -file ArtFlow.cnn_to_core.rpt
report_timing -setup -from_clock [get_clocks core_clk] -to_clock [get_clocks cnn_clk] -npaths 1024 -nworst 1 -file ArtFlow.core_to_cnn.rpt
report_cdc -from [get_clocks cnn_clk] -to [get_clocks core_clk] -details -file ArtFlow.cnn_to_core_cdc.rpt
report_cdc -from [get_clocks core_clk] -to [get_clocks cnn_clk] -details -file ArtFlow.core_to_cnn_cdc.rpt

# Two explicit synchronization chains added by A. All four endpoints required.
foreach {head tail} {park_meta park_sync ack_meta ack_sync} {
 set h u_video_pipe/u_accel_dma/${head}~FF
 set t u_video_pipe/u_accel_dma/${tail}~FF
 if {[llength [get_cells $h]] != 1 || [llength [get_cells $t]] != 1} {error "Missing A lease synchronizer"}
 foreach kind {setup hold} {
  report_timing -$kind -from [get_cells $h] -to [get_cells $t] -npaths 1 -file ArtFlow.lease_${head}_${kind}.rpt
 }
}

set meta u_video_pipe/u_accel_dma/styles.banks/reader/miso_meta~FF
if {[llength [get_cells $meta]] != 1} {error "Missing SPI input synchronizer"}
report_timing -setup -from [get_ports flash_miso] -to [get_cells $meta] -npaths 1 -file ArtFlow.spi_input.rpt
foreach port {flash_sck flash_mosi flash_cs_n} {
 if {[llength [get_cells ${port}~FF]] != 1} {error "Missing SPI output register"}
 report_timing -setup -from [get_cells ${port}~FF] -to [get_ports $port] -npaths 1 -file ArtFlow.spi_${port}.rpt
}

set return_ram_cells [get_cells {u_video_pipe/u_accel_dma/r/storage_ram*.memory}]
puts "RETURN_RAM_RAW $return_ram_cells"
if {[llength $return_ram_cells] != 7} {error "Expected exactly seven return RAMs"}
foreach cell $return_ram_cells {puts "RETURN_RAM_CELL $cell"}
foreach kind {setup hold} {
 report_timing -$kind -from_clock [get_clocks core_clk] -to $return_ram_cells -npaths 2048 -nworst 1 -file ArtFlow.return_ram_write_${kind}.rpt
 report_timing -$kind -from_clock [get_clocks cnn_clk] -to $return_ram_cells -npaths 2048 -nworst 1 -file ArtFlow.return_ram_address_${kind}.rpt
 report_timing -$kind -from $return_ram_cells -to_clock [get_clocks cnn_clk] -npaths 2048 -nworst 1 -file ArtFlow.return_ram_data_${kind}.rpt
}
if {[llength [get_cells u_stream/packet/ready_meta~FF]] != 1} {error "Missing AFS first stage ready_meta"}
report_timing -setup -from [get_ports stream_ready] -to [get_cells u_stream/packet/ready_meta~FF] -npaths 1 -file ArtFlow.afs_stream_ready.rpt
if {[llength [get_cells u_stream/packet/ready_sync~FF]] != 1} {error "Missing AFS second stage ready_sync"}
report_timing -setup -from [get_cells u_stream/packet/ready_meta~FF] -to [get_cells u_stream/packet/ready_sync~FF] -npaths 1 -file ArtFlow.afs_ready_sync.rpt
if {[llength [get_cells u_stream/packet/miso_meta~FF]] != 1} {error "Missing AFS first stage miso_meta"}
report_timing -setup -from [get_ports stream_miso] -to [get_cells u_stream/packet/miso_meta~FF] -npaths 1 -file ArtFlow.afs_stream_miso.rpt
if {[llength [get_cells u_stream/packet/miso_sync~FF]] != 1} {error "Missing AFS second stage miso_sync"}
report_timing -setup -from [get_cells u_stream/packet/miso_meta~FF] -to [get_cells u_stream/packet/miso_sync~FF] -npaths 1 -file ArtFlow.afs_miso_sync.rpt
report_timing -setup -to [get_ports stream_sclk] -npaths 1 -file ArtFlow.afs_stream_sclk.rpt
report_timing -setup -to [get_ports stream_mosi] -npaths 1 -file ArtFlow.afs_stream_mosi.rpt
report_timing -setup -to [get_ports stream_cs_n] -npaths 1 -file ArtFlow.afs_stream_cs_n.rpt
