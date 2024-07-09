`include "sys_defs.svh"

//
// BrCond module
//
// Given the instruction code, compute the proper condition for the
// instruction; for branches this condition will indicate whether the
// target is taken.
//
// This module is purely combinational
//
module brcond(// Inputs
	input [`XLEN-1:0] rs1,    // Value to check against condition
	input [`XLEN-1:0] rs2,
	input  [2:0] func,  // Specifies which condition to check

	output logic cond,    // 0/1 condition result (False/True)
	output [`XLEN-1:0] target_addr
);

	logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;
	always_comb begin
		// cond = 0;
		unique case (func)
			3'b000: cond = signed_rs1 == signed_rs2;  // BEQ
			3'b001: cond = signed_rs1 != signed_rs2;  // BNE
			3'b100: cond = signed_rs1 < signed_rs2;   // BLT
			3'b101: cond = signed_rs1 >= signed_rs2;  // BGE
			3'b110: cond = rs1 < rs2;                 // BLTU
			3'b111: cond = rs1 >= rs2;                // BGEU
			default: cond = 1'b0;
		endcase
	end
	
endmodule // brcond
