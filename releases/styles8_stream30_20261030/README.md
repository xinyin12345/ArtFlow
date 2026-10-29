# Eight-style 30 Hz streaming release

Offline gates passed; hardware acceptance is still required. No hardware was programmed.

New IDs 00..07 map to previous fifteen-style IDs [00,05,01,03,02,14,07,08].
Default glass, sketch, oil, starry, halftone, sand, inkwash, woodrich.

Use ArtFlow_styles8_stream30_with_models.hex as the combined FPGA Flash image at address 0.
The model section starts at 0x400000, has length 0x20000, and ends at 0x41FFFF.
ArtFlow_styles8_stream30.bit is the new volatile-configuration image; it still needs the matching models in Flash for style switching.
models8_parameters.hex is a simulation byte file, not a configuration HEX.

The existing ESP app is unchanged. This release contains no ESP application binary or credentials.
Do not pair this eight-style FPGA build with the old fifteen-style model archive.
Previous release/rollback files remain intact.

See verification_results.md for mapping, actual tests, resource/timing results, limitations and hashes.
manifest.json binds all release evidence and generated artifacts by SHA256.
