
foreach {tag head tail} {
 req1 {u_video_pipe/u_store/osd_req_sync[0]} {u_video_pipe/u_store/osd_req_sync[1]}
 req2 {u_video_pipe/u_store/osd_req_sync[1]} {u_video_pipe/u_store/osd_req_sync[2]}
 ack1 {u_video_pipe/u_store/osd_ack_sync[0]} {u_video_pipe/u_store/osd_ack_sync[1]}
} {
 foreach name [list $head $tail] {
  if {[llength [get_cells ${name}~FF]] != 1} {error "Missing OSD CDC synchronizer $name"}
 }
 report_timing -setup -from [get_cells ${head}~FF] -to [get_cells ${tail}~FF] -npaths 1 -file ArtFlow.osd_${tag}_setup.rpt
 report_timing -hold -from [get_cells ${head}~FF] -to [get_cells ${tail}~FF] -npaths 1 -file ArtFlow.osd_${tag}_hold.rpt
}
for {set bit 0} {$bit < 4} {incr bit} {
 set head [format {u_video_pipe/u_store/osd_payload[%d]~FF} $bit]
 set tail [format {u_video_pipe/u_store/osd_pending[%d]~FF} $bit]
 if {[llength [get_cells $head]] != 1 || [llength [get_cells $tail]] != 1} {error "Missing OSD payload bit"}
 report_timing -setup -from [get_cells $head] -to [get_cells $tail] -npaths 1 -file ArtFlow.osd_data_${bit}.rpt
}
