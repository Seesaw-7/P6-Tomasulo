`include "sys_defs.svh"

module branch_unit(
    input ALU_FUNC func,
    input [`XLEN-1:0] pc, //target addr cal
    input [`XLEN-1:0] imm,

    // for branch condition check
    input [`XLEN-1:0] rs1, // also for jalr
	input [`XLEN-1:0] rs2,

	output logic cond, // 1 for misprediction/flush
	output [`XLEN-1:0] target_pc
);
    
    // branch condition check
    logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;
	always_comb begin
        cond = 0;
        unique case (func)
            6'h0e: cond = signed_rs1 == signed_rs2;  // BEQ
            6'h0f: cond = signed_rs1 != signed_rs2;  // BNE
            6'h10: cond = signed_rs1 < signed_rs2;   // BLT
            6'h11: cond = signed_rs1 >= signed_rs2;  // BGE
            6'h12: cond = rs1 < rs2;                 // BLTU
            6'h13: cond = rs1 >= rs2;                // BGEU
            
            6'h14: cond = 1'b1;
            6'h15: cond = 1'b1;
            6'h16: cond = 1'b1;
            
            default: cond = 1'b0;
        endcase
	end
	
	// target address calculation 
	always_comb begin
	   if ((func == 6'h0e) || (func == 6'h0f) || (func == 6'h10)
	       || (func == 6'h11) || (func == 6'h12) || (func == 6'h13) 
	       || (func == 6'h14) || (func == 6'h16)) begin
	       target_pc = pc + imm;
	   end
	   else if (func == 6'h15) begin
	       target_pc = rs1 + imm;
	   end
	   else begin
	       target_pc = pc + imm;
	   end
	end

endmodule
