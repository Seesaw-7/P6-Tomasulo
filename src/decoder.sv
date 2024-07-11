
  // Decode an instruction: given instruction bits IR produce the
  // appropriate datapath control signals.
  //
  // This is a *combinational* module (basically a PLA).
  //

`include "decoder.svh"

module decoder(

	//input valid_inst_in,  // ignore inst when low, outputs will
	                      // reflect noop (except valid_inst)
	//see sys_defs.svh for definition
	// input from IF_ID_PACKET if_packet
	input logic in_valid;
	input INST inst;
	input logic flush;
	input [`XLEN-1:0] in_pc;
	
	output logic csr_op,    // used for CSR operations, we only used this as 
	                        //a cheap way to get the return code out
	output logic halt,      // non-zero on a halt
	output logic illegal,    // non-zero on an illegal instruction
	// output logic valid_inst,  // for counting valid instructions executed
	//                         // and for making the fetch stage die on halts/
	//                         // keeping track of when to allow the next
	//                         // instruction out of fetch
	//                         // 0 for HALT and illegal instructions (die on halt)
	output DECODED_PACK decoded_pack;

);
	// TODO: add queue in m3
	DECODED_PACK decoded_pack;

	logic valid_inst_in;
	assign valid_inst_in = in_valid;
	assign decoded_pack.valid    = valid_inst_in & ~illegal;
	assign decoded_pack.pc = in_pc;

	always_comb begin
		// default control values:
		// - valid instructions must override these defaults as necessary.
		//	 opa_select, opb_select, and alu_func should be set explicitly.
		// - invalid instructions should clear valid_inst.
		// - These defaults are equivalent to a noop
		// * see sys_defs.vh for the constants used here
		
		// todo: do we really need to initialize here?
		decoded_pack.valid = 0;
		decoded_pack.fu = 2'b11; //by default arithmetic and logic unit
		decoded_pack.arch_reg.src1 = 5'b00000;
		decoded_pack.arch_reg.scr2 = 5'b00000;
		decoded_pack.arch_reg.dest = 5'b00000;
		decoded_pack.imm = {`XLEN{1'b0}};
		decoded_pack.alu_func = 6'h00;
		//decoded_pack.cond_branch = 0;
		//decoded_pack.uncond_branch = 0;

		csr_op = 0;
		halt = 0;
		illegal = 0;

		if(valid_inst_in) begin
			casez (inst) 
				`RV32_LUI: begin
				    decoded_pack.fu = 2'b11;
					decoded_pack.arch_reg.dest = inst.r.rd;
					// decoded_pack.imm = {inst[31:12], 12'b0};
					decoded_pack.imm = `RV32_signext_Uimm(inst);
					// dest_reg   = DEST_RD;
					// opa_select = OPA_IS_ZERO;
					// opb_select = OPB_IS_U_IMM;
				end
				`RV32_AUIPC: begin
					dest_reg   = DEST_RD;
					opa_select = OPA_IS_PC;
					opb_select = OPB_IS_U_IMM;
					// decoded_pack.imm = {inst[31:12], 12'b0};
					decoded_pack.imm = `RV32_signext_Uimm(inst);
				end
				`RV32_JAL: begin
					dest_reg      = DEST_RD;
					opa_select    = OPA_IS_PC;
					opb_select    = OPB_IS_J_IMM;
					uncond_branch = `TRUE;
					// decoded_pack.imm = $signed({inst[31], inst[19:12],
					   inst[20], inst[30:21]});
					decoded_pack.imm = `RV32_signext_Jimm(inst);
				end
				`RV32_JALR: begin
					dest_reg      = DEST_RD;
					opa_select    = OPA_IS_RS1;
					opb_select    = OPB_IS_I_IMM;
					uncond_branch = `TRUE;
					// decoded_pack.imm = $signed(inst[31:20]);
					decoded_pack.imm = `RV32_signext_Iimm(inst);
				end
				`RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
				`RV32_BLTU, `RV32_BGEU: begin
					opa_select  = OPA_IS_PC;
					opb_select  = OPB_IS_B_IMM;
					cond_branch = `TRUE;
					// opa opb select are not PC and imm anymore
				end
				`RV32_LB, `RV32_LH, `RV32_LW,
				`RV32_LBU, `RV32_LHU: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					rd_mem     = `TRUE;
				end
				`RV32_SB, `RV32_SH, `RV32_SW: begin
					opb_select = OPB_IS_S_IMM;
					wr_mem     = `TRUE;
				end
				`RV32_ADDI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					// decoded_pack.imm = $signed(inst[31:20]);
					decoded_pack.imm = `RV32_signext_Iimm(inst);
				end
				`RV32_SLTI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLT;
					// decoded_pack.imm = $signed(inst[31:20]);
					decoded_pack.imm = `RV32_signext_Iimm(inst);
				end
				`RV32_SLTIU: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLTU;
					// decoded_pack.imm = {20'b0, inst[31:20]};
					decoded_pack.imm = `RV32_signext_Iimm(inst);
				end
				`RV32_ANDI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_AND;
					// decoded_pack.imm = $signed(inst[31:20]);
					decoded_pack.imm = `RV32_signext_Iimm(inst);
				end
				`RV32_ORI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_OR;
					// decoded_pack.imm = $signed(inst[31:20]);
					decoded_pack.imm = `RV32_signext_Iimm(inst);
				end
				`RV32_XORI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_XOR;
					// decoded_pack.imm = $signed(inst[31:20]);
					decoded_pack.imm = `RV32_signext_Iimm(inst);
				end
				`RV32_SLLI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLL;
					// decoded_pack.imm = {20'b0, inst[31:20]};
					decoded_pack.imm = `RV32_signext_Iimm(inst);
				end
				`RV32_SRLI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SRL;
					// decoded_pack.imm = {20'b0, inst[31:20]};
					decoded_pack.imm = `RV32_signext_Iimm(inst);
				end
				`RV32_SRAI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SRA;
					// decoded_pack.imm = {20'b0, inst[31:20]};
				    decoded_pack.imm = `RV32_signext_Iimm(inst);
				end
				`RV32_ADD: begin
					// dest_reg   = DEST_RD;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
				end
				`RV32_SUB: begin
					// dest_reg   = DEST_RD;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					// alu_func   = ALU_SUB;
					decoded_pack.alu_func = ALU_SUB;
				end
				`RV32_SLT: begin
					// dest_reg   = DEST_RD;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					// alu_func   = ALU_SLT;
					decoded_pack.alu_func = ALU_SLT;
				end
				`RV32_SLTU: begin
					// dest_reg   = DEST_RD;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					// alu_func   = ALU_SLTU;
					decoded_pack.alu_func = ALU_SLTU;
				end
				`RV32_AND: begin
					// dest_reg   = DEST_RD;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					// alu_func   = ALU_AND;
					decoded_pack.alu_func = ALU_ADD;
				end
				`RV32_OR: begin
					// dest_reg   = DEST_RD;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					// alu_func   = ALU_OR;
					decoded_pack.arch_func = ALU_OR;
				end
				`RV32_XOR: begin
					// dest_reg   = DEST_RD;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					// alu_func   = ALU_XOR;
					decoded_pack.arch_func = ALU_XOR;
				end
				`RV32_SLL: begin
					// dest_reg   = DEST_RD;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					// alu_func   = ALU_SLL;
					decoded_pack.arch_func = ALU_SLL;
				end
				`RV32_SRL: begin
					// dest_reg   = DEST_RD;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					// alu_func   = ALU_SRL;
					decoded_pack.arch_func = ALU_SRA;
				end
				`RV32_SRA: begin
					// dest_reg   = DEST_RD;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					// alu_func   = ALU_SRA;
					decoded_pack.arch_func = ALU_SRA;
				end
				`RV32_MUL: begin
					// dest_reg   = DEST_RD;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					// alu_func   = ALU_MUL;
					decoded_pack.alu_func = MULT_MUL;
				end
				`RV32_MULH: begin
					// dest_reg   = DEST_RD;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					// alu_func   = ALU_MULH;
					decoded_pack.alu_func = MULT_MULH;
				end
				`RV32_MULHSU: begin
					// dest_reg   = DEST_RD;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					// alu_func   = ALU_MULHSU;
					decoded_pack.alu_func = MULT_MULHSU;
				end
				`RV32_MULHU: begin
					// dest_reg   = DEST_RD;
					decoded_pack.arch_reg.src1 = inst.r.rs1;
					decoded_pack.arch_reg.src2 = inst.r.rs2;
					decoded_pack.arch_reg.dest = inst.r.rd;
					// alu_func   = ALU_MULHU;
					decoded_pack.alu_func = MULT_MULHU;
				end
				`RV32_CSRRW, `RV32_CSRRS, `RV32_CSRRC: begin
					csr_op = `TRUE;
				end
				`WFI: begin
					halt = `TRUE;
				end
				default: illegal = `TRUE;

		endcase // casez (inst)
		end // if(valid_inst_in)
	end // always
endmodule // decoder