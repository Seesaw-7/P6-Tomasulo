`include "sys_defs.svh"

module branch_unit(
    input logic b_j, // 0 for b-type ; 1 for j-type
    input [`XLEN-1:0] pc, //target addr cal
    input [`XLEN-1:0] imm,

    // b-type
    input [`XLEN-1:0] rs1, // also for jalr
	input [`XLEN-1:0] rs2,
	input  [2:0] func, // specifies which condition to check, for b-type
	// j-type
	input logic jal_jalr; // 0 for jal ; 1 for jalr

	output logic cond, // 1 for misprediction/flush
	output [`XLEN-1:0] target_pc
);
    
    // check branch condition 
    logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;
	always_comb begin
	    if (b_j == 1'b0) begin
            cond = 0;
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
        else begin
            cond = 1;
        end
	end
	
	// traget address calculation 
	logic [`XLEN-1:0] addr_src1, addr_src2;
	assign addr_src1 = pc;
	assign addr_src2 = imm;
	
	always_comb begin
	   if (b_j == 1'b0) begin
		  target_pc = pc + imm;
	   end
	   else begin
	       if (jal_jalr == 1'b0) begin
		      target_pc = pc + imm;
		   end
		   else begin
		      target_pc = rs1 + imm;
		   end
	   end
	end
	
	/*
	opa_select  = OPA_IS_PC;
	opb_select  = OPB_IS_B_IMM;
	
	OPA_IS_PC:   opa_mux_out = id_ex_packet_in.PC;
	OPB_IS_B_IMM: opb_mux_out = `RV32_signext_Bimm(id_ex_packet_in.inst);
	*/
	
endmodule
