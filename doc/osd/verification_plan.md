# Verification plan

P0: preserve two-cycle RGB/DE/HS/VS alignment and all non-border source pixels;
no image resizing; disabled OSD equals baseline; all three layouts retain operation.
P0: actual-published style metadata across AXI/display clocks without unsafe bus CDC.
P0: preserve freeze/curtain/window/blend and SPI stream data and ownership.
P0: legal routing and non-negative final setup/hold before releasing a bit.
P1: clear title and separate lines; original and eight style labels; exact glyph
scaling from unchanged-size ROM; four palette attributes; 0/29/30/31/999 bar
limits; invalid startup, stopped/frozen independent one-second counters.

Pass requires simulator exit success, no Error/Fatal, explicit PASS evidence,
independent reference comparison, source hashes and real tool reports. No claimed
functional coverage closure: directed cases and pixel checks are reported explicitly.

CAP/OUT revision: OUT must count actual final VS edges and keep counting frozen
rasters; zero must publish with no new VS while its pixel-clock timebase runs.
No clock implies no new OSD image and no elapsed-time measurement.
