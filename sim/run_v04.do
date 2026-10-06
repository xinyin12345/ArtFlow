# Native Questa entry; the shared Python registry prepares vectors and commands.
# From project root: do sim/run_v04.do [full|smoke]
onerror {quit -code 1}
set project_root [file normalize [pwd]]
if {[info exists ::env(V04_PROJECT_ROOT)]} {set project_root [file normalize $::env(V04_PROJECT_ROOT)]}
while {![file exists [file join $project_root tools run_v04.py]]} {
 set parent [file dirname $project_root]
 if {$parent==$project_root} {error "Run from ArtFlow v04 or set V04_PROJECT_ROOT"}
 set project_root $parent
}
set mode {}
if {$argc>0} {
 if {$1=="full"} {set mode --full} elseif {$1=="smoke"} {set mode --smoke} else {error "Expected full or smoke"}
}
set run_dir [file join $project_root work questa_v04_[clock seconds]]
file mkdir $run_dir
set suite [file join $run_dir suite.do]
puts [exec python -B [file join $project_root tools run_v04.py] {*}$mode --run-dir $run_dir --emit-tcl $suite]
do $suite
cd $project_root
