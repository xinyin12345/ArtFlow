# Post-route audit with clock groups removed in the audit-only SDC.
# All pointer synchronizer stages must exist and retain timed same-clock paths.
foreach {fifo aw} {jobs 2 events 2 ar 2 aw 2 w 3 r 3 b 2} {
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
