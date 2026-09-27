
//Generic
`define CKE_WIDTH	1
`define CS_WIDTH	1
`define RANK_WIDTH	1
`define BANK_WIDTH	3
`define ROW_WIDTH	14
`define COL_WIDTH	10
`define DM_WIDTH	2
`define DQS_WIDTH	2
`define DQ_WIDTH	16
`define ODT_WIDTH	1
`define DQ_CNT_WIDTH	4
`define DQS_CNT_WIDTH	1
`define DRAM_WIDTH	8
`define CK_WIDTH	1
`define RANKS	1
//AXI
`define DATA_WIDTH	16
`define ADDR_WIDTH	30
`define AXI_ID_WIDTH	4
`define AXI_ADDR_WIDTH	32
`define AXI_DATA_WIDTH	128

//Timing
`define tCKE	7500

`define tFAW	35000

`define tRAS	35000
`define tRCD	15000
`define tREFI	7800000
`define tRFC	350000
`define tRP	15000
`define tRRD	10000
`define tRTP	10000
`define tWTR	10000
`define tZQI	128000000
`define tZQCS	64
`define tCK	2500
`define CWL	5
`define CL	6
`define nAL	0

//Options
`define RTT_NOM	"40"
`define RTT_WR	"60"
`define BURST_MODE	"8"
`define MEM_ADDR_ORDER	"BANK_ROW_COLUMN"
`define RX_CLK_SEL	2
`define TX_CLK_SEL	3
`define TX_CLK_90EDGE_SEL	0
`define CK_RATIO	4
`define ASYN_AXI_CLK	1
