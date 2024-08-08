`ifndef __DECODER_SVH__
`define __DECODER_SVH__

`include "sys_defs.svh"

typedef struct packed {
	logic unsigned valid;
	FUNC_UNIT fu;
	ARCH_REG arch_reg; // TODO: 5'b0 if empty, especially lw sw
	logic [`XLEN-1:0] imm; 
	INSN_FUNC alu_func;
	logic rs1_valid;
	logic rs2_valid;
	logic imm_valid;
	logic pc_valid;
	logic [`XLEN-1:0] pc;
	logic [`XLEN-1:0] npc;
	logic [2:0] func3;
} DECODED_PACK;

`endif
