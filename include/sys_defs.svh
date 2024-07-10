/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.svh                                        //
//                                                                     //
//  Description :  This file has the macro-defines for macros used in  //
//                 the OoO      design.                                //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

// Global header

`ifndef __SYS_DEFS_SVH__
`define __SYS_DEFS_SVH__


`define ARCH_REG_ADDR_LEN         5 // architectural regFile has 2^5 entries
`define ARCH_REG_NUM 			32

`define PHY_REG_ADDR_LEN         6 // physical regFile has 2^5 entries
`define PHY_REG_NUM 			64


`define XLEN 				32 // ISA bit length

`define RS_INT_ENTRY_NUM 8 // #entries in RS, ahead of integer unit
`define RS_INT_ENTRY_WIDTH 3 // #entries = 2^{ENTRY_WIDTH}

`define RS_MULT_ENTRY_NUM 4 // #entries in RS, ahead of multiplier
`define RS_MULT_ENTRY_WIDTH 2

`define RS_BRANCH_ENTRY_NUM 4 // #entries in RS, ahead of branch unit
`define RS_BRANCH_ENTRY_WIDTH 2

`define RS_LS_ENTRY_NUM 8 // #entries in RS, ahead of load/store unit
`define RS_LS_ENTRY_WIDTH 3

`define REG_LEN 32
`define REG_ADDR_LEN 5

`define ROB_SIZE 64
`define ROB_TAG_LEN 6

`define FU_NUM 4

//
// ALU function code input
//
typedef enum logic [5:0] {
	ALU_ADD     = 6'h00,
	ALU_SUB     = 6'h01,
	ALU_SLT     = 6'h02,
	ALU_SLTU    = 6'h03,
	ALU_AND     = 6'h04,
	ALU_OR      = 6'h05,
	ALU_XOR     = 6'h06,
	ALU_SLL     = 6'h07,
	ALU_SRL     = 6'h08,
	ALU_SRA     = 6'h09,
	MULT_MUL     = 6'h0a,
	MULT_MULH    = 6'h0b,
	MULT_MULHSU  = 6'h0c,
	MULT_MULHU   = 6'h0d,
	BTU_BEQ		= 6'h0e,
	BTU_BNE 	= 6'h0f,
	BTU_BLT		= 6'h10,
	BTU_BGE		= 6'h11
	BTU_BLTU	= 6'h12,
	BTU_BGEU	= 6'h13,
	BTU_JAL		= 6'h14,
	BTU_JALR	= 6'h15,
	BTU_AUIPC       = 6'h16,
	// ALU_DIV     = 5'h0e,
	// ALU_DIVU    = 5'h0f,
	// ALU_REM     = 5'h10,
	// ALU_REMU    = 5'h11
} ALU_FUNC;

typedef enum logic [1:0] {
	FU_LSU    		= 2'b00, // load/store unit
	FU_MULT     	= 2'b01, // multiplier
	FU_BTU     		= 2'b10, // branch target unit
	FU_ALU     		= 2'b11, // arithmetic and logic unit
} FUNC_UNIT;

typedef struct packed {
    logic unsigned [`REG_ADDR_LEN-1:0] src1;
    logic unsigned [`REG_ADDR_LEN-1:0] src2;
    logic unsigned [`REG_ADDR_LEN-1:0] dest;
} ARCH_REG;

typedef struct packed {
    logic unsigned [`REG_ADDR_LEN-1:0] src1;
    logic unsigned [`REG_ADDR_LEN-1:0] src2;
    logic unsigned [`REG_ADDR_LEN-1:0] dest;
    logic unsigned [`REG_ADDR_LEN-1:0] dest_old;
} PHYS_REG;

typedef struct packed {

} DECODED_INST;

typedef struct packed {
	logic valid; // If low, the data in this struct is garbage
    INST  inst;  // fetched instruction out
	logic [`XLEN-1:0] NPC; // PC + 4
	logic [`XLEN-1:0] PC;  // PC 
} PREFETCH_PACKET;


// RISCV ISA SPEC
typedef union packed {
	logic [31:0] inst;
	struct packed {
		logic [6:0] funct7;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} r; //register to register instructions
	struct packed {
		logic [11:0] imm;
		logic [4:0]  rs1; //base
		logic [2:0]  funct3;
		logic [4:0]  rd;  //dest
		logic [6:0]  opcode;
	} i; //immediate or load instructions
	struct packed {
		logic [6:0] off; //offset[11:5] for calculating address
		logic [4:0] rs2; //source
		logic [4:0] rs1; //base
		logic [2:0] funct3;
		logic [4:0] set; //offset[4:0] for calculating address
		logic [6:0] opcode;
	} s; //store instructions
	struct packed {
		logic       of; //offset[12]
		logic [5:0] s;   //offset[10:5]
		logic [4:0] rs2;//source 2
		logic [4:0] rs1;//source 1
		logic [2:0] funct3;
		logic [3:0] et; //offset[4:1]
		logic       f;  //offset[11]
		logic [6:0] opcode;
	} b; //branch instructions
	struct packed {
		logic [19:0] imm;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} u; //upper immediate instructions
	struct packed {
		logic       of; //offset[20]
		logic [9:0] et; //offset[10:1]
		logic       s;  //offset[11]
		logic [7:0] f;	//offset[19:12]
		logic [4:0] rd; //dest
		logic [6:0] opcode;
	} j;  //jump instructions
`ifdef ATOMIC_EXT
	struct packed {
		logic [4:0] funct5;
		logic       aq;
		logic       rl;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} a; //atomic instructions
`endif
`ifdef SYSTEM_EXT
	struct packed {
		logic [11:0] csr;
		logic [4:0]  rs1;
		logic [2:0]  funct3;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} sys; //system call instructions
`endif

} INST; //instruction typedef, this should cover all types of instructions



`endif // __SYS_DEFS_SVH__
