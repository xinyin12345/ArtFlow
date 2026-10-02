# Native Questa entry: uses this session (compatible with single-session licenses).
# Run from the project, sim/, or work/: do sim/run_v03.do [full|smoke]
# Questa macros do not reliably set Tcl's info script to this .do path.
onerror {quit -code 1}
set v03_root [file normalize [pwd]]
if {[info exists ::env(V03_PROJECT_ROOT)]} {
    set v03_root [file normalize $::env(V03_PROJECT_ROOT)]
}
while {![file exists [file join $v03_root rtl video rgb_frame_store.v]]} {
    set v03_parent [file dirname $v03_root]
    if {$v03_parent == $v03_root} {
        error "Run from the v03 project directory or set V03_PROJECT_ROOT"
    }
    set v03_root $v03_parent
}
set v03_mode quick
if {$argc > 0} { set v03_mode $1 }
set v03_run [file join $v03_root work questa_[clock seconds]]
file mkdir $v03_run
cd $v03_run
catch {quit -sim}
vlib work
foreach source {
    rtl/frame_buffer/DC_FIFO.v rtl/frame_buffer/rst_n_piple.v
    rtl/video/bayer_bin2x2.v rtl/video/rgb_frame_store.v rtl/video/cam_fb_pipe.v
    rtl/true_dual_port_ram.v rtl/gamma_conrrection/gamma_correction.v
    rtl/gamma_conrrection/gamma_lut.v rtl/video/test_pattern.v
    sim/tb_gamma_lut.v sim/tb_test_pattern.v sim/tb_bayer_bin2x2.v
    sim/axi_memory_checked.sv sim/tb_v03_checked.sv
} { vlog [file join $v03_root $source] }
proc v03_gen {w h prefix frames} {
    global v03_root
    puts [exec python -B [file join $v03_root tools v03_golden.py] gen --w $w --h $h --out $prefix --frames $frames]
}
proc v03_case {name top options} {
    global v03_run
    set log [file join $v03_run ${name}.log]
    transcript file $log
    transcript on
    vsim -onfinish stop {*}$options work.$top
    run -all
    quit -sim
    transcript off
    set fh [open $log r]; set body [read $fh]; close $fh
    transcript on
    if {[regexp {\*\* (Error|Fatal)\M|\mFAIL\M|Errors:\s*[1-9]} $body] ||
        [string first "$top PASS" $body] < 0} { error "Regression failed: $name ($log)" }
    puts "$name PASS"
}
proc v03_check {prefix w h phase} {
    global v03_root
    set fh [open ${prefix}_cap_variant.txt r]; set variant [string trim [read $fh]]; close $fh
    puts [exec python -B [file join $v03_root tools v03_golden.py] check --w $w --h $h --out $prefix --phase $phase --frame $variant]
}
v03_gen 64 16 unit 0
v03_gen 160 40 small 8
v03_case gamma tb_gamma_lut {}
v03_case pattern tb_test_pattern {}
v03_case bayer tb_bayer_bin2x2 {}
set phases {0 1 2 3}
if {$v03_mode == "smoke"} { set phases {0} }
foreach phase $phases {
    v03_case small_$phase tb_v03_checked [list -sv_seed 1 -GPHASE=$phase]
    v03_check small 160 40 $phase
}
if {$v03_mode != "smoke"} {
    v03_case reverse_pulse tb_v03_checked {-sv_seed 17 -GREV=1 -GVS_MODE=1}
    v03_check small 160 40 0
    v03_gen 320 96 stress 8
    v03_case stress tb_v03_checked {-sv_seed 31 -GW=320 -GH=96 -GPREFIX=stress -GSTRESS=1 -GMAXFRM=80}
    v03_check stress 320 96 0
    v03_gen 16 8 tiny 8
    v03_case short_burst tb_v03_checked {-sv_seed 7 -GW=16 -GH=8 -GPREFIX=tiny}
    v03_check tiny 16 8 0
}
if {$v03_mode == "full"} {
    v03_gen 1920 1080 full 8
    v03_case full tb_v03_checked {-sv_seed 1 -GW=1920 -GH=1080 -GPREFIX=full -GGAP_PCT=10 -GVBLANK=20000 -GNGOOD=3 -GMAXFRM=15}
    v03_check full 1920 1080 0
}
puts "REGRESSION PASS ($v03_run)"
