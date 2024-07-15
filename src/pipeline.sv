`ifndef __PIPELINE_V__
`define __PIPELINE_V__

`timescale 1ns/100ps

`include "sys_defs.svh"
`include "ISA.svh"

module pipeline (

	input         clock,                    // System clock
	input         reset,                    // System reset
	input [3:0]   mem2proc_response,        // Tag from memory about current request
	input [63:0]  mem2proc_data,            // Data coming back from memory
	input [3:0]   mem2proc_tag,              // Tag from memory about current reply
	
	output logic [1:0]  proc2mem_command,    // command sent to memory
	output logic [`XLEN-1:0] proc2mem_addr,      // Address sent to memory
	output logic [63:0] proc2mem_data,      // Data sent to memory
	output MEM_SIZE proc2mem_size,          // data size sent to memory

	output logic [3:0]  pipeline_completed_insts,
	// output EXCEPTION_CODE   pipeline_error_status,
	output logic [4:0]  pipeline_commit_wr_idx,
	output logic [`XLEN-1:0] pipeline_commit_wr_data,
	output logic        pipeline_commit_wr_en,
	output logic [`XLEN-1:0] pipeline_commit_NPC,
	
    // debug
    output [`REG_NUM-1:0] [`XLEN-1:0] pipeline_registers_out
	
	// testing hooks (these must be exported so we can test
	// the synthesized version) data is tested by looking at
	// the final values in memory
	
// `ifdef DEBUG	
// 	// Outputs from IF-Stage 
// 	output logic [`XLEN-1:0] if_NPC_out,
// 	output logic [31:0] if_IR_out,
// 	output logic        if_valid_inst_out,
	
// 	// Outputs from IF/ID Pipeline Register
// 	output logic [`XLEN-1:0] if_id_NPC,
// 	output logic [31:0] if_id_IR,
// 	output logic        if_id_valid_inst,
	
	
// 	// Outputs from ID/EX Pipeline Register
// 	output logic [`XLEN-1:0] id_ex_NPC,
// 	output logic [31:0] id_ex_IR,
// 	output logic        id_ex_valid_inst,
	
	
// 	// Outputs from EX/MEM Pipeline Register
// 	output logic [`XLEN-1:0] ex_mem_NPC,
// 	output logic [31:0] ex_mem_IR,
// 	output logic        ex_mem_valid_inst,
	
	
// 	// Outputs from MEM/WB Pipeline Register
// 	output logic [`XLEN-1:0] mem_wb_NPC,
// 	output logic [31:0] mem_wb_IR,
// 	output logic        mem_wb_valid_inst
// `endif

);

assign proc2mem_command = BUS_NONE;
assign proc2mem_addr = proc2Imem_addr;
	//if it's an instruction, then load a double word (64 bits)
assign proc2mem_size = DOUBLE;
assign proc2mem_data = 64'b0;

assign pipeline_completed_insts = {3'b0, wb_en};
// assign pipeline_error_status =  mem_wb_illegal             ? ILLEGAL_INST :
//                                 mem_wb_halt                ? HALTED_ON_WFI :
//                                 (mem2proc_response==4'h0)  ? LOAD_ACCESS_FAULT :
//                                 NO_ERROR;

assign pipeline_commit_wr_idx = 5'b0;
assign pipeline_commit_wr_data = `XLEN'b0;
assign pipeline_commit_wr_en = 1'b0;
assign pipeline_commit_NPC = rob_commit_npc;

//////////////////////////////////////////////////
//                                              //
//                 Fetch-Stage                  //
//                                              //
//////////////////////////////////////////////////
PREFETCH_PACKET fetch_stage_packet;
logic [`XLEN-1:0] proc2Imem_addr;
prefetch_queue fetch_stage_0 (
    .clock(clock),
    .reset(reset),
    .en(!stall),	
    .mem_bus_none(proc2Dmem_command == BUS_NONE),
    .take_branch(flush),
    .branch_target_pc(branch_target_pc),
    .Imem2proc_data(mem2proc_data),
    .proc2Imem_addr(proc2Imem_addr),
    .packet_out(fetch_stage_packet)
);

logic decoder_csr_op;
assign decoder_csr_op = RS_load[0]; //TODO:
logic decoder_halt;
logic decoder_illegal;
DECODED_PACK decoded_pack;
decoder decoder_0 (
    .in_valid(fetch_stage_packet.valid),
    .inst(fetch_stage_packet.inst),
    .flush(stall),
    .in_pc(fetch_stage_packet.PC),
    .csr_op(decoder_csr_op),
    .halt(decoder_halt),
    .illegal(decoder_illegal),
    .decoded_pack(decoded_pack)
);


//////////////////////////////////////////////////
//                                              //
//                Dispatch-Stage                //
//                                              //
//////////////////////////////////////////////////
logic stall;
logic [3:0] RS_load;
INST_RS inst_dispatch_to_rs;
INST_ROB inst_dispatch_to_rob;
logic [3:0] dispatcher_RS_is_full;
assign dispatcher_RS_is_full[FU_ALU] = rs_alu_full;
assign dispatcher_RS_is_full[FU_MULT] = rs_mult_full;
assign dispatcher_RS_is_full[FU_BTU] = rs_btu_full;
assign dispatcher_RS_is_full[FU_LSU] = 1'b0;
dispatcher dispatch_stage (
    .clk(clock),
    .reset(reset),
    .decoded_pack(decoded_pack),
    .registers(registers),
    .rob(rob_entries),
    .assign_rob_tag(rob_tag_for_dispatch),
    .inst_rs(inst_dispatch_to_rs),
    .inst_rob(inst_dispatch_to_rob),
    .stall(stall),
    .return_flag(wb_en), // TODO:
    .ready_flag(select_flag_from_cdb),
    .reg_addr_from_rob(wb_reg),
    .rob_tag_from_rob(retire_rob_tag),
    .rob_tag_from_cdb(rob_tag_from_cdb),
    .wb_data(0), //TODO: redundant for m2
    .RS_is_full(dispatcher_RS_is_full), //TODO: four rs is_full from right to left
    .RS_load(RS_load)
);



//////////////////////////////////////////////////
//                                              //
//                 Issue-Stage                  //
//                                              //
//////////////////////////////////////////////////

// Integer Unit
logic rs_alu_full;
logic rs_alu_insn_ready;
logic enable_alu;
// output data
ALU_FUNC rs_alu_func_out; // to FU
logic [`XLEN-1:0] rs_alu_v1_out, rs_alu_v2_out; 
logic [`XLEN-1:0] rs_alu_pc_out, rs_alu_imm_out;// to FU
logic [`ROB_TAG_LEN-1:0] rs_alu_dst_tag; // to issue unit, TODO: to FU in m3
logic [`ROB_TAG_LEN-1:0] rs_alu_dest_rob_tag;

reservation_station RS_ALU (
    .clk(clock),
    .reset(reset || flush), // flush when mis predict
    .load(RS_load[FU_ALU]), // whether we load in the instruction (assigned by dispatcher)
    .issue(issue_signal_out[FU_ALU]), // whether the issue queue should output one instruction (assigned by issue unit), should be stable during clock edge
    .wakeup(select_flag_from_cdb), // set by issue unit, indicating whether to set the ready tag of previously issued dst L to Yes
                        // this should better be set 1 cycle after issue exactly is the FU latency is one, should be stable during clock edge
    .func(inst_dispatch_to_rs.func),
    .t1(inst_dispatch_to_rs.tag_src1), 
    .t2(inst_dispatch_to_rs.tag_src2), 
    .dst(inst_dispatch_to_rs.tag_dest), // previous renaming unit ensures that dst != inp1 and dst != inp2
    .ready1(inst_dispatch_to_rs.ready_src1), 
    .ready2(inst_dispatch_to_rs.ready_src2),
    .v1(inst_dispatch_to_rs.value_src1), 
    .v2(inst_dispatch_to_rs.value_src2), 
    .pc(inst_dispatch_to_rs.pc), 
    .imm(inst_dispatch_to_rs.imm),
    .wakeup_tag(rob_tag_from_cdb),
    .wakeup_value(value_from_cdb), 

    // output signals
    .insn_ready(rs_alu_insn_ready), // to issue unit, indicating if there exists an instruction that is ready to be issued
    .is_full(rs_alu_full), // to dispatcher, indicating that all entries of the reservation station is occupied, cannot load in more inputs
    .start(enable_alu), // output to FU

    // output data
    .func_out(rs_alu_func_out), // to FU
    .v1_out(rs_alu_v1_out), 
    .v2_out(rs_alu_v2_out), 
    .pc_out(rs_alu_pc_out), 
    .imm_out(rs_alu_imm_out),// to FU
    .dst_tag(rs_alu_dest_rob_tag) 
);

// Branch Unit

logic rs_btu_full;
logic rs_btu_insn_ready;
logic enable_btu;
// output data
ALU_FUNC rs_btu_func_out; // to FU
logic [`XLEN-1:0] rs_btu_v1_out, rs_btu_v2_out; 
logic [`XLEN-1:0] rs_btu_pc_out, rs_btu_imm_out;// to FU
logic [`ROB_TAG_LEN-1:0] rs_btu_dst_tag; // to issue unit, TODO: to FU in m3
logic [`ROB_TAG_LEN-1:0] rs_btu_dest_rob_tag;

reservation_station RS_BTU (
    .clk(clock),
    .reset(reset || flush), // flush when mis predict
    .load(RS_load[FU_BTU]), // whether we load in the instruction (assigned by dispatcher)
    .issue(issue_signal_out[FU_BTU]), // whether the issue queue should output one instruction (assigned by issue unit), should be stable during clock edge
    .wakeup(select_flag_from_cdb), // set by issue unit, indicating whether to set the ready tag of previously issued dst reg to Yes
                        // this should better be set 1 cycle after issue exactly is the FU latency is one, should be stable during clock edge
    .func(inst_dispatch_to_rs.func),
    .t1(inst_dispatch_to_rs.tag_src1), 
    .t2(inst_dispatch_to_rs.tag_src2), 
    .dst(inst_dispatch_to_rs.tag_dest), // previous renaming unit ensures that dst != inp1 and dst != inp2
    .ready1(inst_dispatch_to_rs.ready_src1), 
    .ready2(inst_dispatch_to_rs.ready_src2),
    .v1(inst_dispatch_to_rs.value_src1), 
    .v2(inst_dispatch_to_rs.value_src2), 
    .pc(inst_dispatch_to_rs.pc), 
    .imm(inst_dispatch_to_rs.imm),
    .wakeup_tag(rob_tag_from_cdb),
    .wakeup_value(value_from_cdb), 

    // output signals
    .insn_ready(rs_btu_insn_ready), // to issue unit, indicating if there exists an instruction that is ready to be issued
    .is_full(rs_btu_full), // to dispatcher, indicating that all entries of the reservation station is occupied, cannot load in more inputs
    .start(enable_btu), // output to FU

    // output data
    .func_out(rs_btu_func_out), // to FU
    .v1_out(rs_btu_v1_out), 
    .v2_out(rs_btu_v2_out), 
    .pc_out(rs_btu_pc_out), 
    .imm_out(rs_btu_imm_out),// to FU
    .dst_tag(rs_btu_dest_rob_tag) 
);

// Mult Unit

logic rs_mult_full;
logic rs_mult_insn_ready;
logic enable_mult;
// output data
ALU_FUNC rs_mult_func_out; // to FU
logic [`XLEN-1:0] rs_mult_v1_out, rs_mult_v2_out; 
logic [`XLEN-1:0] rs_mult_pc_out, rs_mult_imm_out;// to FU
logic [`ROB_TAG_LEN-1:0] rs_mult_dst_tag; // to issue unit, TODO: to FU in m3
logic [`ROB_TAG_LEN-1:0] rs_mult_dest_rob_tag;

reservation_station RS_mult (
    .clk(clock),
    .reset(reset || flush), // flush when mis predict
    .load(RS_load[FU_MULT]), // whether we load in the instruction (assigned by dispatcher)
    .issue(issue_signal_out[FU_MULT]), // whether the issue queue should output one instruction (assigned by issue unit), should be stable during clock edge
    .wakeup(select_flag_from_cdb), // set by issue unit, indicating whether to set the ready tag of previously issued dst reg to Yes
                        // this should better be set 1 cycle after issue exactly is the FU latency is one, should be stable during clock edge
    .func(inst_dispatch_to_rs.func),
    .t1(inst_dispatch_to_rs.tag_src1), 
    .t2(inst_dispatch_to_rs.tag_src2), 
    .dst(inst_dispatch_to_rs.tag_dest), // previous renaming unit ensures that dst != inp1 and dst != inp2
    .ready1(inst_dispatch_to_rs.ready_src1), 
    .ready2(inst_dispatch_to_rs.ready_src2),
    .v1(inst_dispatch_to_rs.value_src1), 
    .v2(inst_dispatch_to_rs.value_src2), 
    .pc(inst_dispatch_to_rs.pc), 
    .imm(inst_dispatch_to_rs.imm),
    .wakeup_tag(rob_tag_from_cdb),
    .wakeup_value(value_from_cdb), 

    // output signals
    .insn_ready(rs_mult_insn_ready), // to issue unit, indicating if there exists an instruction that is ready to be issued
    .is_full(rs_mult_full), // to dispatcher, indicating that all entries of the reservation station is occupied, cannot load in more inputs
    .start(enable_mult), // output to FU

    // output data
    .func_out(rs_mult_func_out), // to FU
    .v1_out(rs_mult_v1_out), 
    .v2_out(rs_mult_v2_out), 
    .pc_out(rs_mult_pc_out), 
    .imm_out(rs_mult_imm_out),// to FU
    .dst_tag(rs_mult_dest_rob_tag) 
);

// load store unit
logic rs_lsu_full;
logic rs_lsu_insn_ready;
logic enable_lsu;
// output data
ALU_FUNC rs_lsu_func_out; // to FU
logic [`XLEN-1:0] rs_lsu_v1_out, rs_lsu_v2_out; 
logic [`XLEN-1:0] rs_lsu_pc_out, rs_lsu_imm_out;// to FU
logic [`ROB_TAG_LEN-1:0] rs_lsu_dst_tag; // to issue unit, TODO: to FU in m3
logic [`ROB_TAG_LEN-1:0] rs_lsu_dest_rob_tag;

reservation_station RS_LSU (
    .clk(clock),
    .reset(reset || flush), // flush when mis predict
    .load(RS_load[FU_LSU]), // whether we load in the instruction (assigned by dispatcher)
    .issue(issue_signal_out[FU_LSU]), // whether the issue queue should output one instruction (assigned by issue unit), should be stable during clock edge
    .wakeup(select_flag_from_cdb), // set by issue unit, indicating whether to set the ready tag of previously issued dst reg to Yes
                        // this should better be set 1 cycle after issue exactly is the FU latency is one, should be stable during clock edge
    .func(inst_dispatch_to_rs.func),
    .t1(inst_dispatch_to_rs.tag_src1), 
    .t2(inst_dispatch_to_rs.tag_src2), 
    .dst(inst_dispatch_to_rs.tag_dest), // previous renaming unit ensures that dst != inp1 and dst != inp2
    .ready1(inst_dispatch_to_rs.ready_src1), 
    .ready2(inst_dispatch_to_rs.ready_src2),
    .v1(inst_dispatch_to_rs.value_src1), 
    .v2(inst_dispatch_to_rs.value_src2), 
    .pc(inst_dispatch_to_rs.pc), 
    .imm(inst_dispatch_to_rs.imm),
    .wakeup_tag(rob_tag_from_cdb),
    .wakeup_value(), 

    // output signals
    .insn_ready(rs_lsu_insn_ready), // to issue unit, indicating if there exists an instruction that is ready to be issued
    .is_full(rs_lsu_full), // to dispatcher, indicating that all entries of the reservation station is occupied, cannot load in more inputs
    .start(enable_lsu), // output to FU

    // output data
    .func_out(rs_lsu_func_out), // to FU
    .v1_out(rs_lsu_v1_out), 
    .v2_out(rs_lsu_v2_out), 
    .pc_out(rs_lsu_pc_out), 
    .imm_out(rs_lsu_imm_out),// to FU
    .dst_tag(rs_lsu_dest_rob_tag) 
);





logic [3:0] issue_signal_out;
logic [`ROB_TAG_LEN-1:0] rob_tag_from_issue_unit;
logic select_flag_from_issue_unit;
FUNC_UNIT select_signal_from_issue_unit;

logic [3:0] issue_unit_insn_ready;
assign issue_unit_insn_ready[FU_ALU] = rs_alu_insn_ready;
assign issue_unit_insn_ready[FU_MULT] = rs_mult_insn_ready;
assign issue_unit_insn_ready[FU_BTU] = rs_btu_insn_ready; 
assign issue_unit_insn_ready[FU_LSU] = 1'b1;

logic [3:0][`ROB_TAG_LEN-1:0] issue_unit_ROB_tag;
assign issue_unit_ROB_tag[FU_ALU] = rs_alu_dest_rob_tag;
assign issue_unit_ROB_tag[FU_MULT] = rs_mult_dest_rob_tag;
assign issue_unit_ROB_tag[FU_BTU] = rs_btu_dest_rob_tag;
assign issue_unit_ROB_tag[FU_LSU] = rs_lsu_dest_rob_tag;

issue_unit issue_unit_0 (
    // control signals
    .clk(clock),
    .reset(reset || flush), 
    // data
    .insn_ready(issue_unit_insn_ready),
    .ROB_tag(issue_unit_ROB_tag), 

    // output control signals
    .issue_signals(issue_signal_out), // to each RS
    // output data
    .ROB_tag_out(rob_tag_from_issue_unit), // TODO: delete in m3
    .select_flag(select_flag_from_issue_unit), // to CDB 
    .select_signal(select_signal_from_issue_unit) // to CDB as select, to RS as wakeup 
);





//////////////////////////////////////////////////
//                                              //
//                Execute-Stage                 //
//                                              //
//////////////////////////////////////////////////
// Integer Unit
logic [`XLEN-1:0] alu_result;
arithmetic_logic_unit ALU (
    .opa(rs_alu_v1_out),
    .opb(rs_alu_v2_out), //TODO: where is imm?
    .func(rs_alu_func_out),
    .result(alu_result)
);

// branch unit

logic branch_from_lsu;
logic [`XLEN-1:0] btu_wb_data;
logic [`XLEN-1:0] btu_target_pc;
branch_unit BTU (
    .func(rs_btu_func_out),
    .pc(rs_btu_pc_out), //target addr cal
    .imm(rs_btu_imm_out),
    .rs1(rs_btu_v1_out), // also for jalr
    .rs2(rs_btu_v2_out),
    .cond(branch_from_lsu), // 1 for misprediction/flush
    .wb_data(btu_wb_data), 
    .target_pc(btu_target_pc)
);

// mult unit
logic [63:0] mult_result;
logic mult_done;
multiplier mult_0 (
    .clock(clock),
    .reset(reset || flush),
    .mcand(64'(rs_mult_v1_out)), // TODO: 32 bits to 64 bits?
    .mplier(64'(rs_mult_v2_out)),
    .start(enable_mult),
    .product(mult_result),
    .done(mult_done)
);

// load store unit

// memory
logic [1:0]  proc2Dmem_command;
assign proc2Dmem_command = BUS_NONE;
// logic [63:0] Imem2proc_data;


//////////////////////////////////////////////////
//                                              //
//                Complete-Stage                //
//                                              //
//////////////////////////////////////////////////
logic  [3:0] [`XLEN-1:0] cdb_in_values; // TODO: make FU_NUM global
assign cdb_in_values[FU_ALU] = alu_result;
assign cdb_in_values[FU_BTU] = btu_wb_data;
assign cdb_in_values[FU_MULT] = 32'(mult_result);
assign cdb_in_values[FU_LSU] = 32'd1;

logic select_flag_from_cdb;
logic [`ROB_TAG_LEN-1:0] rob_tag_from_cdb;
logic [`XLEN-1:0] value_from_cdb;
logic branch_from_cdb;
logic [`XLEN-1:0] pc_from_cdb; //TODO: change output size of out_pc
common_data_bus CDB (
    .in_values(cdb_in_values),
    .mispredict(branch_from_lsu),
    .pc(btu_target_pc),
    .select_flag(select_flag_from_issue_unit),
    .select_signal(select_signal_from_issue_unit),
    .ROB_tag(rob_tag_from_issue_unit),
    .out_select_flag(select_flag_from_cdb),
    .out_ROB_tag(rob_tag_from_cdb),
    .out_value(value_from_cdb),
    .out_mispredict(branch_from_cdb),
    .out_pc(pc_from_cdb)
);


logic [`XLEN-1:0] branch_target_pc;
ROB_ENTRY [`ROB_SIZE-1:0] rob_entries ;
// logic[`XLEN-1:0] target_pc_from_rob; 
logic flush;
logic [`ROB_TAG_LEN-1:0] rob_tag_for_dispatch;
logic rob_full;
logic wb_en;
logic [`REG_ADDR_LEN-1:0] wb_reg;
logic [`XLEN-1:0] wb_data;
logic [`XLEN-1:0] src1_data_from_rob;
logic [`XLEN-1:0] src2_data_from_rob;
logic [`ROB_TAG_LEN-1:0] retire_rob_tag; 
logic [`XLEN-1:0] rob_commit_npc;
reorder_buffer ROB_0 (
    .clk(clock),
    .reset(reset), //TODO: flush when take_branch
    
    .dispatch(!stall),
    .reg_addr_from_dispatcher(inst_dispatch_to_rob.register),
    .npc_from_dispatcher(inst_dispatch_to_rob.inst_npc),
     
    .cdb_to_rob(select_flag_from_cdb),
    .rob_tag_from_cdb(rob_tag_from_cdb),
    .wb_data_from_cdb(value_from_cdb),
    .target_pc_from_cdb(pc_from_cdb),
    .mispredict_from_cdb(branch_from_cdb),
    
    .search_src1_rob_tag(0), // from dispatcher
    .search_src2_rob_tag(0),
    
    .wb_en(wb_en), //wb to reg
    .wb_reg(wb_reg), 
    .wb_data(wb_data),
    
    // .target_pc(target_pc_from_rob),
    .flush(flush), //also indicate write to pc
    
    .assign_rob_tag_to_dispatcher(rob_tag_for_dispatch),
    .rob_full_adv(rob_full), // TODO: not used in m2
    
    .search_src1_data(src1_data_from_rob), // to dispatcher
    .search_src2_data(src2_data_from_rob),
    .rob_curr(rob_entries),

    .retire_rob_tag(retire_rob_tag),
    .commit_npc(rob_commit_npc)
);





//////////////////////////////////////////////////
//                                              //
//                 Retire-Stage                 //
//                                              //
//////////////////////////////////////////////////

assign pipeline_registers_out = registers;

logic [`REG_NUM-1:0] [`XLEN-1:0] registers;
register_file regfile (
    .wr_idx(wb_reg),
    .wr_data(wb_data),
    .wr_en(wb_en),
    .clk(clock),
    .reset(reset),
    .registers(registers)
);





endmodule

`endif
