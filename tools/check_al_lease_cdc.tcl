# Two explicit synchronization chains added by A. All four endpoints required.
foreach {head tail} {park_meta park_sync ack_meta ack_sync} {
 set h u_video_pipe/u_accel_dma/${head}~FF
 set t u_video_pipe/u_accel_dma/${tail}~FF
 if {[llength [get_cells $h]] != 1 || [llength [get_cells $t]] != 1} {error "Missing A lease synchronizer"}
 foreach kind {setup hold} {
  report_timing -$kind -from [get_cells $h] -to [get_cells $t] -npaths 1 -file ArtFlow.lease_${head}_${kind}.rpt
 }
}
