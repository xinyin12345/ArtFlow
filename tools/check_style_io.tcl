set meta u_video_pipe/u_accel_dma/styles.banks/reader/miso_meta~FF
if {[llength [get_cells $meta]] != 1} {error "Missing SPI input synchronizer"}
report_timing -setup -from [get_ports flash_miso] -to [get_cells $meta] -npaths 1 -file ArtFlow.spi_input.rpt
foreach port {flash_sck flash_mosi flash_cs_n} {
 if {[llength [get_cells ${port}~FF]] != 1} {error "Missing SPI output register"}
 report_timing -setup -from [get_cells ${port}~FF] -to [get_ports $port] -npaths 1 -file ArtFlow.spi_${port}.rpt
}
