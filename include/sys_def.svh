`ifndef __SYS_DEFS_VH__
`define __SYS_DEFS_VH__

// Global header

`define REG_ADDR_LEN           5 // regFile has 2^5 entries
`define REG_NUM 32

`define XLEN 32 // ISA bit length

typedef enum logic [3:0] {
	ALU_ADD     = 4'h0,
	ALU_SUB     = 4'h1,
	ALU_SLT     = 4'h2,
	ALU_SLTU    = 4'h3,
	ALU_AND     = 4'h4,
	ALU_OR      = 4'h5,
	ALU_XOR     = 4'h6,
	ALU_SLL     = 4'h7,
	ALU_SRL     = 4'h8,
	ALU_SRA     = 4'h9
} ALU1_FUNC; // functions of ALU1


`endif // __SYS_DEFS_VH__
