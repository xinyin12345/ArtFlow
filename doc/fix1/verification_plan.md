# FIX1 verification plan

Require native Questa functional checks, unchanged user configuration and XML bytes,
firmware build, Efinity implementation, positive normal timing and every new reset
chain stage after the first. Hardware acceptance remains a separate NOT_RUN gate.
The receiver boundary model exercises reset sequencing; it cannot reproduce analog
lane/FIFO alignment or validate the encrypted CSI packet decoder.
