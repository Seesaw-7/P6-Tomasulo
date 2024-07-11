`ifndef __DECODER_SVH__
`define __DECODER_SVH__

typedef struct packed {
	logic unsigned valid;
	FUNC_UNIT fu; // 4 kinds of FU in enum
	ARCH_REG arch_reg; // TODO: 5'b0 if empty, especially lw sw
	logic [`XLEN-1:0] imm; 
	ALU_FUNC alu_func;
	logic rs1_valid;
	logic rs2_valid;
	logic imm_valid;
	logic pc_valid;
	logic [`XLEN-1:0] pc;
} DECODED_PACK;

`endif
