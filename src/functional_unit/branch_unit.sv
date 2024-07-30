`timescale 1ns/100ps

`include "sys_defs.svh"

module branch_unit(
    input INST_RS insn,
    input en,

    // for branch condition check

    output logic cond, // 1 for misprediction/flush
    output logic [`XLEN-1:0] wb_data, 
    output logic [`XLEN-1:0] target_pc,
    
    output logic [`ROB_TAG_LEN-1:0] insn_tag,
    output logic done
);
    assign ALU_FUNC func = insn.func;
    assign [`XLEN-1:0] pc = insn.pc;
    assign [`XLEN-1:0] imm = insn.imm;
    assign [`XLEN-1:0] rs1 = insn.value_src1;
    assign [`XLEN-1:0] rs2 = insn.value_src2;
    
	// branch condition check
	logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;
	always_comb begin
        cond = 0;
        unique case (func)
            BTU_BEQ: cond = signed_rs1 == signed_rs2;  // BEQ
            BTU_BNE: cond = signed_rs1 != signed_rs2;  // BNE
            BTU_BLT: cond = signed_rs1 < signed_rs2;   // BLT
            BTU_BGE: cond = signed_rs1 >= signed_rs2;  // BGE
            BTU_BLTU: cond = rs1 < rs2;                 // BLTU
            BTU_BGEU: cond = rs1 >= rs2;                // BGEU
            
            BTU_JAL: cond = 1'b1;
            BTU_JALR: cond = 1'b1;            
            default: cond = 1'b0;
        endcase
	end
	
	// target address calculation 
	always_comb begin
	   wb_data = {`XLEN{1'b0}};
	   target_pc = {`XLEN{1'b0}};
	   
	   if ((func == BTU_BEQ) || (func == BTU_BNE) || (func == BTU_BLT) || 
                (func == BTU_BGE) || (func == BTU_BLTU) || (func == BTU_BGEU)) begin
           target_pc = pc + imm;
       end

	   else if (func == BTU_JAL) begin
	       target_pc = pc + imm;
	       wb_data = pc + 4;
	   end
	   else if (func == BTU_JALR) begin
	       target_pc = rs1 + imm;
	       wb_data = pc + 4;
	   end
	   else begin
	       target_pc = pc + 4;
	   end
	end

    assign insn_tag = insn.insn_tag;
    assign done = en;

endmodule
