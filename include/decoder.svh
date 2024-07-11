`ifndef __DECODER_SVH__
`define __DECODER_SVH__

typedef struct packed {
	logic unsigned valid;
	FUNC_UNIT fu; // 4 kinds of FU in enum
	ARCH_REG arch_reg; // TODO: 5'b0 if empty, especially lw sw
	logic [`XLEN-1:0] imm; // TODO: immediate or offest; f empty: 0
	ALU_FUNC alu_func;
	// logic rd_mem;
	// logic wr_mem;
	//logic cond_branch;
	//logic uncond_branch; 
	logic [`XLEN-1:0] pc;
} DECODED_PACK;

`endif
