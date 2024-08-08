/////////////////////////////////////////////////////////////////////////
// Module name : decoder.sv
// Description : This module decodes instructions. It checks the validity of the instruction. The decoded information is packed.
/////////////////////////////////////////////////////////////////////////
`timescale 1ns/100ps

`include "sys_defs.svh"
`include "ISA.svh"
`include "decoder.svh"

module decoder(
	input in_valid,
	input INST inst,
	input flush,
	input [`XLEN-1:0] in_pc,
	
	output logic csr_op,    // used for CSR operations, we only used this as a cheap way to get the return code out
	// output logic halt,      // non-zero on a halt
	// output logic illegal,    // non-zero on an illegal instruction
	// output logic valid_inst,  // for counting valid instructions executed
	//                         // and for making the fetch stage die on halts/
	//                         // keeping track of when to allow the next
	//                         // instruction out of fetch
	//                         // 0 for HALT and illegal instructions (die on halt)
	
	output DECODED_PACK decoded_pack
);
	// TODO: add queue in m3
	// DECODED_PACK decoded_pack;

	logic valid_inst_in;
	assign valid_inst_in = in_valid;
	assign decoded_pack.valid = valid_inst_in & ~decoded_pack.illegal;
	assign decoded_pack.pc = in_pc;
	assign decoded_pack.npc = in_pc + 4;

	always_comb begin
		// default control values: equivalent to a nop
		// valid instructions must override these defaults as necessary
		// ps: invalid instructions should clear valid_inst
		decoded_pack.fu = FU_ALU; //by default arithmetic and logic unit
		decoded_pack.arch_reg.src1 = {`REG_ADDR_LEN{1'b0}};
		decoded_pack.arch_reg.src2 = {`REG_ADDR_LEN{1'b0}};
		decoded_pack.arch_reg.dest = {`REG_ADDR_LEN{1'b0}};
		decoded_pack.imm = {`XLEN{1'b0}};
		decoded_pack.alu_func = ALU_ADD;
		decoded_pack.rs1_valid = 1'b0;
		decoded_pack.rs2_valid = 1'b0;
		decoded_pack.imm_valid = 1'b0;
		decoded_pack.pc_valid = 1'b0;
		//decoded_pack.pc = {`XLEN{1'b0}}; 
		decoded_pack.func3 = 3'b000;
        
		csr_op = `FALSE;
		decoded_pack.halt = `FALSE;
		decoded_pack.illegal = `FALSE;

		if(valid_inst_in) begin
			casez (inst) 
				`RV32_LUI: begin
					decoded_pack.arch_reg.dest = inst.u.rd;
					decoded_pack.imm = `RV32_signext_Uimm(inst);
					decoded_pack.imm_valid = 1'b1;
				end
				`RV32_AUIPC: begin
					decoded_pack.arch_reg.dest = inst.u.rd;
					decoded_pack.imm = `RV32_signext_Uimm(inst);
					decoded_pack.pc_valid = 1'b1;
					decoded_pack.imm_valid = 1'b1;
				end
				`RV32_JAL: begin
				    decoded_pack.fu = FU_BTU;
                    decoded_pack.arch_reg.dest = inst.j.rd;
					decoded_pack.imm = `RV32_signext_Jimm(inst);
					decoded_pack.pc_valid = 1'b1;
					decoded_pack.imm_valid = 1'b1;
					decoded_pack.alu_func = BTU_JAL;
				end
				`RV32_JALR: begin
				    decoded_pack.fu = FU_BTU;
				    decoded_pack.arch_reg.src1 = inst.i.rs1;
				    decoded_pack.arch_reg.dest = inst.i.rd;    
					decoded_pack.imm = `RV32_signext_Iimm(inst);
					decoded_pack.pc_valid = 1'b1;
					decoded_pack.imm_valid = 1'b1;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.alu_func = BTU_JALR;
				end
				`RV32_BEQ: begin
				    decoded_pack.fu = FU_BTU;
				    decoded_pack.arch_reg.src1 = inst.b.rs1;
				    decoded_pack.arch_reg.src2 = inst.b.rs2;
					decoded_pack.imm = `RV32_signext_Bimm(inst);
					decoded_pack.pc_valid = 1'b1;
					decoded_pack.imm_valid = 1'b1;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = BTU_BEQ;
				end
				`RV32_BNE: begin
				    decoded_pack.fu = FU_BTU;
				    decoded_pack.arch_reg.src1 = inst.b.rs1;
				    decoded_pack.arch_reg.src2 = inst.b.rs2;
					decoded_pack.imm = `RV32_signext_Bimm(inst);
					decoded_pack.pc_valid = 1'b1;
					decoded_pack.imm_valid = 1'b1;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = BTU_BNE;
				end
			    `RV32_BLT: begin
				    decoded_pack.fu = FU_BTU;
				    decoded_pack.arch_reg.src1 = inst.b.rs1;
				    decoded_pack.arch_reg.src2 = inst.b.rs2;
					decoded_pack.imm = `RV32_signext_Bimm(inst);
					decoded_pack.pc_valid = 1'b1;
					decoded_pack.imm_valid = 1'b1;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = BTU_BLT;
				end
				`RV32_BGE: begin
				    decoded_pack.fu = FU_BTU;
				    decoded_pack.arch_reg.src1 = inst.b.rs1;
				    decoded_pack.arch_reg.src2 = inst.b.rs2;
					decoded_pack.imm = `RV32_signext_Bimm(inst);
					decoded_pack.pc_valid = 1'b1;
					decoded_pack.imm_valid = 1'b1;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = BTU_BGE;
				end
				`RV32_BLTU: begin
				    decoded_pack.fu = FU_BTU;
				    decoded_pack.arch_reg.src1 = inst.b.rs1;
				    decoded_pack.arch_reg.src2 = inst.b.rs2;
					decoded_pack.imm = `RV32_signext_Bimm(inst);
					decoded_pack.pc_valid = 1'b1;
					decoded_pack.imm_valid = 1'b1;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = BTU_BLTU;
				end
				`RV32_BGEU: begin
				    decoded_pack.fu = FU_BTU;
				    decoded_pack.arch_reg.src1 = inst.b.rs1;
				    decoded_pack.arch_reg.src2 = inst.b.rs2;
					decoded_pack.imm = `RV32_signext_Bimm(inst);
					decoded_pack.pc_valid = 1'b1;
					decoded_pack.imm_valid = 1'b1;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = BTU_BGEU;
				end
				`RV32_LB, `RV32_LH, `RV32_LW: begin
				    decoded_pack.fu = FU_LSU;
				    decoded_pack.arch_reg.src1 = inst.i.rs1;
				    decoded_pack.arch_reg.dest = inst.i.rd;
				    decoded_pack.imm = `RV32_signext_Iimm(inst);
				    decoded_pack.imm_valid = 1'b1;
					decoded_pack.rs1_valid = 1'b1; 
				    decoded_pack.alu_func = LS_LOAD;
				    decoded_pack.func3 = inst.i.funct3; 
				end
				`RV32_LBU, `RV32_LHU: begin
				    decoded_pack.fu = FU_LSU;
				    decoded_pack.arch_reg.src1 = inst.i.rs1;
				    decoded_pack.arch_reg.dest = inst.i.rd;
				    decoded_pack.imm = `RV32_signext_Iimm(inst);
					decoded_pack.imm_valid = 1'b1;
					decoded_pack.rs1_valid = 1'b1; 
				    decoded_pack.alu_func = LS_LOADU;
				    decoded_pack.func3 = inst.i.funct3; 
				end
				`RV32_SB, `RV32_SH, `RV32_SW: begin
				    decoded_pack.fu = FU_LSU;
				    decoded_pack.arch_reg.src1 = inst.s.rs1;
				    decoded_pack.arch_reg.src2 = inst.s.rs2;
				    decoded_pack.imm = `RV32_signext_Simm(inst);
				    decoded_pack.imm_valid = 1'b1;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1;
				    decoded_pack.alu_func = LS_STORE; 
				    decoded_pack.func3 = inst.s.funct3; 
				end
				`RV32_ADDI: begin
				    decoded_pack.arch_reg.src1 = inst.i.rs1;
				    decoded_pack.arch_reg.dest = inst.i.rd; 
				    decoded_pack.imm = `RV32_signext_Iimm(inst);
				    decoded_pack.imm_valid = 1'b1;
				    decoded_pack.rs1_valid = 1'b1; 
				end
				`RV32_SLTI: begin
				    decoded_pack.arch_reg.src1 = inst.i.rs1;
					decoded_pack.arch_reg.dest = inst.i.rd; 
					decoded_pack.imm = `RV32_signext_Iimm(inst);
					decoded_pack.imm_valid = 1'b1;
				    decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.alu_func = ALU_SLT;
				end
				`RV32_SLTIU: begin
				    decoded_pack.arch_reg.src1 = inst.i.rs1;
					decoded_pack.arch_reg.dest = inst.i.rd; 
					decoded_pack.imm = `RV32_signext_Iimm(inst);
					decoded_pack.imm_valid = 1'b1;
				    decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.alu_func = ALU_SLTU;
				end
				`RV32_ANDI: begin
				    decoded_pack.arch_reg.src1 = inst.i.rs1;
				    decoded_pack.arch_reg.dest = inst.i.rd; 
				    decoded_pack.imm = `RV32_signext_Iimm(inst);
				    decoded_pack.imm_valid = 1'b1;
				    decoded_pack.rs1_valid = 1'b1; 
				    decoded_pack.alu_func = ALU_AND;
				end
				`RV32_ORI: begin
				    decoded_pack.arch_reg.src1 = inst.i.rs1;
				    decoded_pack.arch_reg.dest = inst.i.rd; 
				    decoded_pack.imm = `RV32_signext_Iimm(inst);
				    decoded_pack.imm_valid = 1'b1;
				    decoded_pack.rs1_valid = 1'b1; 
				    decoded_pack.alu_func = ALU_OR;
				end
				`RV32_XORI: begin
				    decoded_pack.arch_reg.src1 = inst.i.rs1;
				    decoded_pack.arch_reg.dest = inst.i.rd; 
				    decoded_pack.imm = `RV32_signext_Iimm(inst);
				    decoded_pack.imm_valid = 1'b1;
				    decoded_pack.rs1_valid = 1'b1; 
				    decoded_pack.alu_func = ALU_XOR;
				end
				`RV32_SLLI: begin
				    decoded_pack.arch_reg.src1 = inst.i.rs1;
				    decoded_pack.arch_reg.dest = inst.i.rd; 
				    decoded_pack.imm = `RV32_signext_Iimm(inst);
				    decoded_pack.imm_valid = 1'b1;
				    decoded_pack.rs1_valid = 1'b1; 
				    decoded_pack.alu_func = ALU_SLL;
				end
				`RV32_SRLI: begin
				    decoded_pack.arch_reg.src1 = inst.i.rs1;
				    decoded_pack.arch_reg.dest = inst.i.rd; 
				    decoded_pack.imm = `RV32_signext_Iimm(inst);
				    decoded_pack.imm_valid = 1'b1;
				    decoded_pack.rs1_valid = 1'b1; 
				    decoded_pack.alu_func = ALU_SRL;
				end
				`RV32_SRAI: begin
				    decoded_pack.arch_reg.src1 = inst.i.rs1;
				    decoded_pack.arch_reg.dest = inst.i.rd; 
				    decoded_pack.imm = `RV32_signext_Iimm(inst);
				    decoded_pack.imm_valid = 1'b1;
				    decoded_pack.rs1_valid = 1'b1; 
				    decoded_pack.alu_func = ALU_SRA;
				end
				`RV32_ADD: begin
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
				end
				`RV32_SUB: begin
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = ALU_SUB;
				end
				`RV32_SLT: begin
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = ALU_SLT;
				end
				`RV32_SLTU: begin
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = ALU_SLTU;
				end
				`RV32_AND: begin
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = ALU_AND;
				end
				`RV32_OR: begin
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = ALU_OR;
				end
				`RV32_XOR: begin
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = ALU_XOR;
				end
				`RV32_SLL: begin
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = ALU_SLL;
				end
				`RV32_SRL: begin
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = ALU_SRL;
				end
				`RV32_SRA: begin
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = ALU_SRA;
				end
				`RV32_MUL: begin
					decoded_pack.fu = FU_MULT;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = MULT_MUL;
				end
				`RV32_MULH: begin
					decoded_pack.fu = FU_MULT;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = MULT_MULH;
				end
				`RV32_MULHSU: begin
					decoded_pack.fu = FU_MULT;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = MULT_MULHSU;
				end
				`RV32_MULHU: begin
					decoded_pack.fu = FU_MULT;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					decoded_pack.rs1_valid = 1'b1; 
					decoded_pack.rs2_valid = 1'b1; 
					decoded_pack.alu_func = MULT_MULHU;
				end
				`RV32_CSRRW, `RV32_CSRRS, `RV32_CSRRC: begin
					csr_op = `TRUE;
				end
				`WFI: begin
					decoded_pack.halt = `TRUE;
				end
				default: decoded_pack.illegal = `TRUE;

		endcase 
		end 
	end
endmodule
