/////////////////////////////////////////////////////////////////////////
// Module name : arithmetic_logic_unit.sv
// Description : This module performs arithmetic and logic operations.
/////////////////////////////////////////////////////////////////////////
`timescale 1ns/100ps

`include "sys_defs.svh"
`include "dispatcher.svh"

//
// The ALU
//
// given the command code CMD and proper operands A and B, compute the
// result of the instruction
//
// This module is purely combinational
//
module arithmetic_logic_unit(
	// input [`XLEN-1:0] opa,
	// input [`XLEN-1:0] opb,
	input INST_RS insn,
	// input INSN_FUNC     func, //TODO: input here?
	input en,
    // TODO: input INST inst

    // TODO: output INST inst
	output logic [`XLEN-1:0] result,
	output [`ROB_TAG_LEN-1:0] insn_tag,
	output [`ROB_TAG_LEN-1:0] result_tag,
	output done
);
	wire [`XLEN-1:0] opa, opb;
	wire INSN_FUNC func;
	assign opa = insn.value_src1;
	assign opb = insn.value_src2;
	assign func = insn.func;
	wire signed [`XLEN-1:0] signed_opa, signed_opb;
	wire signed [2*`XLEN-1:0] signed_mul, mixed_mul;
	wire        [2*`XLEN-1:0] unsigned_mul;
	assign signed_opa = opa;
	assign signed_opb = opb;
	assign signed_mul = signed_opa * signed_opb;
	assign unsigned_mul = opa * opb;
	assign mixed_mul = signed_opa * opb;

	always_comb begin
		unique case (func)
			ALU_ADD:      result = opa + opb;
			ALU_SUB:      result = opa - opb;
			ALU_AND:      result = opa & opb;
			ALU_SLT:      result = 32'(signed_opa < signed_opb);
			ALU_SLTU:     result = 32'(opa < opb);
			ALU_OR:       result = opa | opb;
			ALU_XOR:      result = opa ^ opb;
			ALU_SRL:      result = opa >> opb[4:0];
			ALU_SLL:      result = opa << opb[4:0];
			ALU_SRA:      result = signed_opa >>> opb[4:0]; // arithmetic from logical shift
			// ALU_MUL:      result = signed_mul[`XLEN-1:0];
			// ALU_MULH:     result = signed_mul[2*`XLEN-1:`XLEN];
			// ALU_MULHSU:   result = mixed_mul[2*`XLEN-1:`XLEN];
			// ALU_MULHU:    result = unsigned_mul[2*`XLEN-1:`XLEN];

			default:      result = `XLEN'hfacebeec;  // here to prevent latches
		endcase
	end

	assign insn_tag = insn.insn_tag;
	assign result_tag = insn.tag_dest;

	assign done = en;
endmodule // alu
