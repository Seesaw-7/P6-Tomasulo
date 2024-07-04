/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.vh                                         //
//                                                                     //
//  Description :  This file has the macro-defines for macros used in  //
//                 the OoO      design.                                //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

// Global header

`ifndef __SYS_DEFS_VH__
`define __SYS_DEFS_VH__


`define REG_ADDR_LEN         5 // regFile has 2^5 entries
`define REG_NUM 			32


`define XLEN 				32 // ISA bit length

// typedef enum logic [3:0] {
// 	ALU_ADD     = 4'h0,
// 	ALU_SUB     = 4'h1,
// 	ALU_SLT     = 4'h2,
// 	ALU_SLTU    = 4'h3,
// 	ALU_AND     = 4'h4,
// 	ALU_OR      = 4'h5,
// 	ALU_XOR     = 4'h6,
// 	ALU_SLL     = 4'h7,
// 	ALU_SRL     = 4'h8,
// 	ALU_SRA     = 4'h9
// } ALU1_FUNC; // functions of ALU1

typedef enum logic [4:0] {
	ALU_ADD     = 5'h00,
	ALU_SUB     = 5'h01,
	ALU_SLT     = 5'h02,
	ALU_SLTU    = 5'h03,
	ALU_AND     = 5'h04,
	ALU_OR      = 5'h05,
	ALU_XOR     = 5'h06,
	ALU_SLL     = 5'h07,
	ALU_SRL     = 5'h08,
	ALU_SRA     = 5'h09,
	ALU_MUL     = 5'h0a,
	ALU_MULH    = 5'h0b,
	ALU_MULHSU  = 5'h0c,
	ALU_MULHU   = 5'h0d,
} AL_FUNC;

`endif // __SYS_DEFS_VH__
