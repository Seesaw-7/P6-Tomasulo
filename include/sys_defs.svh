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

typedef struct packed {
	logic [`XLEN-1:0] alu_result; // alu_result
	logic [`XLEN-1:0] NPC; //pc + 4
	logic             take_branch; // is this a taken branch?
	//pass throughs from decode stage
	logic [`XLEN-1:0] rs2_value;
	logic             rd_mem, wr_mem;
	logic [4:0]       dest_reg_idx;
	logic             halt, illegal, csr_op, valid;
	logic [2:0]       mem_size; // byte, half-word or word
} EX_MEM_PACKET;

//
// ALU function code input
// probably want to leave these alone
//
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
	// ALU_DIV     = 5'h0e,
	// ALU_DIVU    = 5'h0f,
	// ALU_REM     = 5'h10,
	// ALU_REMU    = 5'h11
} ALU_FUNC;

`define XLEN 				32 // ISA bit length

`define RS_INT_ENTRY_NUM 8 // #entries in RS, ahead of integer unit
`define RS_INT_ENTRY_WIDTH 3 // #entries = 2^{ENTRY_WIDTH}

`define RS_MULT_ENTRY_NUM 4 // #entries in RS, ahead of multiplier
`define RS_MULT_ENTRY_WIDTH 2

`define RS_BRANCH_ENTRY_NUM 4 // #entries in RS, ahead of branch unit
`define RS_BRANCH_ENTRY_WIDTH 2

`define RS_LS_ENTRY_NUM 8 // #entries in RS, ahead of load/store unit
`define RS_LS_ENTRY_WIDTH 3


`endif // __SYS_DEFS_VH__
