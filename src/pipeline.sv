`ifndef __PIPELINE_V__
`define __PIPELINE_V__

`timescale 1ns/100ps

`include "sys_defs.svh"
`include "ISA.svh"

`define BRANCH_PRE_EN

module pipeline (
	input         clock,                    // System clock
	input         reset,                    // System reset
	input [3:0]   mem2proc_response,        // Tag from memory about current request
	input [63:0]  mem2proc_data,            // Data coming back from memory
	input [3:0]   mem2proc_tag,              // Tag from memory about current reply
	
	output logic [1:0]  proc2mem_command,    // command sent to memory
	output logic [`XLEN-1:0] proc2mem_addr,      // Address sent to memory
	output logic [63:0] proc2mem_data,      // Data sent to memory
	// output MEM_SIZE proc2mem_size,          // data size sent to memory

	output logic [3:0]  pipeline_completed_insts,
	output EXCEPTION_CODE   pipeline_error_status,
	output logic [4:0]  pipeline_commit_wr_idx,
	output logic [`XLEN-1:0] pipeline_commit_wr_data,
	output logic        pipeline_commit_wr_en,
	output logic [`XLEN-1:0] pipeline_commit_NPC,
	
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

assign proc2mem_command = (proc2Dmem_command == BUS_NONE)? BUS_LOAD:proc2Dmem_command;
assign proc2mem_addr = proc2Imem_addr;
	//if it's an instruction, then load a double word (64 bits)
`ifndef CACHE_MODE
    assign proc2mem_size = DOUBLE;
`endif

assign proc2mem_data = 64'b0;

assign pipeline_completed_insts = {3'b0, wb_en};
assign pipeline_error_status =  rob_commit_illegal             ? ILLEGAL_INST :
                                rob_commit_halt                ? HALTED_ON_WFI :
                                (mem2proc_response==4'h0)  ? LOAD_ACCESS_FAULT :
                                NO_ERROR;


assign pipeline_commit_wr_idx = 5'b0;
assign pipeline_commit_wr_data = `XLEN'b0;
assign pipeline_commit_wr_en = 1'b0;
assign pipeline_commit_NPC = rob_commit_npc;

//////////////////////////////////////////////////
//                                              //
//                 Fetch-Stage                  //
//                                              //
//////////////////////////////////////////////////
logic rs_full;
logic stall_fetch; 

always_comb begin
    rs_full = 1'b0;
    stall_fetch = 1'b0;
    if (rs_alu_full || rs_btu_full || rs_mult_full || rs_lsu_full) begin
        rs_full = 1'b1;
    end
    if (rs_full || rob_full) begin 
        stall_fetch = 1'b1;
    end
end

PREFETCH_PACKET fetch_stage_packet;
logic [`XLEN-1:0] proc2Imem_addr;
logic [`XLEN-1:0] prefetch_queue_branch_target_pc;
assign prefetch_queue_branch_target_pc = flush ? rob_commit_npc : predict_target; // priority flush > predict_taken
prefetch_queue fetch_stage_0 (
    .clock(clock),
    .reset(reset),
    .en(!stall_fetch),	
    .mem_bus_none(proc2Dmem_command == BUS_NONE),
    .take_branch(flush || predict_taken),
    .branch_target_pc(prefetch_queue_branch_target_pc),
    .Imem2proc_data(mem2proc_data),
    .proc2Imem_addr(proc2Imem_addr),
    .packet_out(fetch_stage_packet)
);

//////////////////////////////////////////////////
//                                              //
//                Dispatch-Stage                //
//                                              //
//////////////////////////////////////////////////

logic decoder_csr_op;
// assign decoder_csr_op = RS_load[0]; //TODO:
logic decoder_halt;
logic decoder_illegal;
DECODED_PACK decoded_pack;
decoder decoder_0 (
    .in_valid(fetch_stage_packet.valid),
    .inst(fetch_stage_packet.inst),
    //.flush(stall),
    .in_pc(fetch_stage_packet.PC),
    .csr_op(decoder_csr_op),
    // .halt(decoder_halt),
    // .illegal(decoder_illegal),
    .decoded_pack(decoded_pack)
);


DECODED_PACK predicted_pack;
logic unsigned predict_taken;
logic [`XLEN-1:0] predict_target;
branch_predictor branch_predictor_0 (
    .clk(clock),
    .reset(reset),
    .pc_search(decoded_pack.pc),
    .pc_from_rob(rob_commit_pc),
    .branch_taken_from_rob(rob_commit_branch),
    .branch_target_from_rob(rob_commit_npc),
    .predict_taken(predict_taken),
    .predict_target(predict_target)
);

always_comb begin
    predicted_pack = decoded_pack;
    if ((decoded_pack.alu_func == BTU_BEQ) 
        || (decoded_pack.alu_func == BTU_BNE) 
        || (decoded_pack.alu_func == BTU_BLT) 
        || (decoded_pack.alu_func == BTU_BGE) 
        || (decoded_pack.alu_func == BTU_BLTU) 
        || (decoded_pack.alu_func == BTU_BGEU) 
        || (decoded_pack.alu_func == BTU_JAL) 
        || (decoded_pack.alu_func == BTU_JALR) 
    ) begin
       predicted_pack.npc = predict_target;
    end
end

// TODO: check whether invalid insn are dropped
//logic stall;
logic dispatch_rob;
logic [3:0] RS_load;
INST_RS inst_dispatch_to_rs;
INST_ROB inst_dispatch_to_rob;
logic [3:0] dispatcher_RS_is_full;
assign dispatcher_RS_is_full[FU_ALU] = rs_alu_full;
assign dispatcher_RS_is_full[FU_MULT] = rs_mult_full;
assign dispatcher_RS_is_full[FU_BTU] = rs_btu_full;
assign dispatcher_RS_is_full[FU_LSU] = 1'b0;

dispatcher dispatcher_0 (
    .clk(clock),
    .reset(reset || flush),
`ifdef BRANCH_PRE_EN
    .decoded_pack(predicted_pack),
    .branch_from_bp(predict_taken),
`else
    .decoded_pack(decoded_pack),
    .branch_from_bp(1'b0), // always not taken
`endif
    .registers(registers), // forward from register (reg)
    .rob(rob_entries), // forward from rob (reg)
    .assign_rob_tag(rob_tag_for_dispatch),
    .inst_rs(inst_dispatch_to_rs), //output
    .inst_rob(inst_dispatch_to_rob), //output
    //.stall(stall), // output
    .dispatch(dispatch_rob),
    .return_flag(wb_en), 
    .ready_flag(rob_enable),
    .reg_addr_from_rob(wb_reg),
    .rob_tag_from_rob(retire_rob_tag),
    .rob_tag_from_cdb(rob_tag_from_cdb),
    // .wb_data(0), //TODO: redundant for m2
    .RS_is_full(dispatcher_RS_is_full), 
    .RS_load(RS_load) //output
);


//////////////////////////////////////////////////
//                                              //
//                 Issue-Stage                  //
//                                              //
//////////////////////////////////////////////////

// Integer Unit
    logic rs_alu_full;
    RS_ENTRY alu_entry_out;

    reservation_station RS_ALU (
        .clk(clock),
        .reset(reset || flush), // flush when mis predict
        .load(RS_load[FU_ALU]),
        .insn_load(inst_dispatch_to_rs),
        .wakeup(execute_reg_curr.ready), 
        .wakeup_value(execute_reg_curr.result),
        .wakeup_tag(execute_reg_curr.tag_result), 
        .clear(rs_clear[FU_ALU]), 
        .clear_tag(fu_insn[FU_ALU].insn_tag),
        .alu_ex_tag(fu_insn[FU_ALU].tag_dest),
        .insn_for_ex(alu_entry_out),
        .is_full(rs_alu_full)
    );


// Branch Unit

    logic rs_btu_full;
    RS_ENTRY btu_entry_out;

    reservation_station RS_BTU (
        .clk(clock),
        .reset(reset || flush), // flush when mis predict
        .load(RS_load[FU_BTU]),
        .insn_load(inst_dispatch_to_rs),
        .wakeup(execute_reg_curr.ready), 
        .wakeup_value(execute_reg_curr.result),
        .wakeup_tag(execute_reg_curr.tag_result), 
        .clear(rs_clear[FU_BTU]), 
        .clear_tag(fu_insn[FU_BTU].insn_tag),
        .alu_ex_tag(fu_insn[FU_ALU].tag_dest),
        .insn_for_ex(btu_entry_out),
        .is_full(rs_btu_full)
    );

// Mult Unit
    logic rs_mult_full;
    RS_ENTRY mult_entry_out;

    reservation_station RS_MULT (
        .clk(clock),
        .reset(reset || flush), // flush when mis predict
        .load(RS_load[FU_MULT]),
        .insn_load(inst_dispatch_to_rs),
        .wakeup(execute_reg_curr.ready), 
        .wakeup_value(execute_reg_curr.result),
        .wakeup_tag(execute_reg_curr.tag_result), 
        .clear(rs_clear[FU_MULT]), 
        .clear_tag(fu_insn[FU_MULT].insn_tag),
        .alu_ex_tag(fu_insn[FU_ALU].tag_dest),
        .insn_for_ex(mult_entry_out),
        .is_full(rs_mult_full)
    );

// load store unit
    logic rs_lsu_full;
    RS_ENTRY lsu_entry_out;

    reservation_station RS_LSU (
        .clk(clock),
        .reset(reset || flush), // flush when mis predict
        .load(RS_load[FU_LSU]),
        .insn_load(inst_dispatch_to_rs),
        .wakeup(execute_reg_curr.ready), 
        .wakeup_value(execute_reg_curr.result),
        .wakeup_tag(execute_reg_curr.tag_result), 
        .clear(rs_clear[FU_LSU]), 
        .clear_tag(fu_insn[FU_LSU].insn_tag),
        .alu_ex_tag(fu_insn[FU_ALU].tag_dest),
        .insn_for_ex(lsu_entry_out),
        .is_full(rs_lsu_full)
    );

//////////////////////////////////////////////////
//                                              //
//                Execute-Stage                 //
//                                              //
//////////////////////////////////////////////////

    // issue unit
    logic [3:0] rs_clear;
    INST_RS [3:0] fu_insn;

    RS_ENTRY [3:0] rs_entries_ex;
    assign rs_entries_ex[FU_ALU] = alu_entry_out;
    assign rs_entries_ex[FU_MULT] = mult_entry_out;
    assign rs_entries_ex[FU_BTU] = btu_entry_out;
    assign rs_entries_ex[FU_LSU] = lsu_entry_out;

    issue_unit issue_unit_0 (
        .insns_ready(execute_reg_curr.ready),
        .cdb_select(1 << cdb_select_fu),
        .alu_result(execute_reg_curr.result[FU_ALU]),
        .alu_result_tag(execute_reg_curr.tag_result[FU_ALU]),
        .rs_entries_ex(rs_entries_ex),
        .fu_en(rs_clear),
        .insns_select(fu_insn)
    );

    // Integer Unit
    logic [`XLEN-1:0] alu_result;
    logic [`ROB_TAG_LEN-1:0] alu_result_tag;
    logic [`ROB_TAG_LEN-1:0] alu_insn_tag;
    logic alu_done;

    arithmetic_logic_unit ALU (
        .insn(fu_insn[FU_ALU]),
        .en(rs_clear[FU_ALU]),
        .result(alu_result),
        .insn_tag(alu_insn_tag),
        .result_tag(alu_result_tag),
        .done(alu_done)
    );


// branch unit

    logic [`XLEN-1:0] btu_wb_data;
    logic [`XLEN-1:0] btu_target_pc;
    logic btu_mis_predict;
    logic [`ROB_TAG_LEN-1:0] btu_insn_tag;
    logic [`ROB_TAG_LEN-1:0] btu_result_tag;
    logic btu_done;
    branch_unit BTU (
        .insn(fu_insn[FU_BTU]),
        .en(rs_clear[FU_BTU]),
        .cond(btu_mis_predict), // 1 for misprediction/flush
        .wb_data(btu_wb_data), 
        .target_pc(btu_target_pc),
        .insn_tag(btu_insn_tag),
        .result_tag(btu_result_tag),
        .done(btu_done)
    );

// mult unit
    logic [63:0] mult_result;
    logic mult_done;
    logic [`ROB_TAG_LEN-1:0] mult_result_tag;
    logic [`ROB_TAG_LEN-1:0] mult_insn_tag;
    multiplier mult_0 (
        .clock(clock),
        .reset(reset || flush),
        .mcand({32'b0, fu_insn[FU_MULT].value_src1}), 
        .mplier({32'b0, fu_insn[FU_MULT].value_src2}),
        .insn_tag_in(fu_insn[FU_MULT].insn_tag),
        .result_tag_in(fu_insn[FU_MULT].tag_dest),
        .start(rs_clear[FU_MULT]),
        .product(mult_result),
        .insn_tag(mult_insn_tag),
        .result_tag(mult_result_tag),
        .done(mult_done)
    );

// load store unit

// memory
logic [1:0]  proc2Dmem_command;
assign proc2Dmem_command = BUS_NONE;
// logic [63:0] Imem2proc_data;


//////////////////////////////////////////////////
//                                              //
//           Execute Pipeline Register          //
//                                              //
//////////////////////////////////////////////////

    typedef struct packed {
        logic [3:0] ready;
        logic [3:0] [`XLEN-1:0] result; 
        logic [3:0] [`ROB_TAG_LEN-1:0] tag_insn_ex;
        logic [3:0] [`ROB_TAG_LEN-1:0] tag_result;
        logic [`XLEN-1:0] target_pc;
        logic miss_predict;
    } EXECUTE_PACK;

    EXECUTE_PACK execute_reg_curr, execute_reg_next;

    always_comb begin
        execute_reg_next.ready[FU_ALU] = alu_done ? 1'b1 : (cdb_select_fu == FU_ALU) ? 1'b0 : execute_reg_curr.ready[FU_ALU];
        execute_reg_next.ready[FU_MULT] = mult_done ? 1'b1 : (cdb_select_fu == FU_MULT) ? 1'b0 : execute_reg_curr.ready[FU_MULT];
        execute_reg_next.ready[FU_BTU] = btu_done ? 1'b1 : (cdb_select_fu == FU_BTU) ? 1'b0 : execute_reg_curr.ready[FU_BTU];
        // TODO:
        execute_reg_next.result[FU_ALU] = alu_result;
        execute_reg_next.result[FU_MULT] = mult_result[31:0];
        execute_reg_next.result[FU_BTU] = btu_wb_data;
        execute_reg_next.tag_insn_ex[FU_ALU] = alu_insn_tag;
        execute_reg_next.tag_result[FU_ALU] = alu_result_tag;
        execute_reg_next.tag_insn_ex[FU_MULT] = mult_insn_tag;
        execute_reg_next.tag_result[FU_MULT] = mult_result_tag;
        execute_reg_next.tag_insn_ex[FU_BTU] = btu_insn_tag;
        execute_reg_next.tag_result[FU_BTU] = btu_result_tag;
        execute_reg_next.target_pc = btu_target_pc;
        execute_reg_next.miss_predict = btu_mis_predict;
        //TODO:
    end

    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset || flush) begin 
            execute_reg_curr <= 0;
		end else begin// if (reset)
			execute_reg_curr <= `SD execute_reg_next; 
		end
	end // always

//////////////////////////////////////////////////
//                                              //
//                Complete-Stage                //
//                                              //
//////////////////////////////////////////////////
logic  [3:0] [`XLEN-1:0] cdb_in_values; 
assign cdb_in_values[FU_ALU] = alu_result;
assign cdb_in_values[FU_BTU] = btu_wb_data;
assign cdb_in_values[FU_MULT] = 32'(mult_result);
assign cdb_in_values[FU_LSU] = 32'd1;

logic rob_enable;
logic [`ROB_TAG_LEN-1:0] rob_tag_from_cdb;
logic [`XLEN-1:0] value_from_cdb;
logic mispredict_from_cdb;
logic [`XLEN-1:0] pc_from_cdb; 
logic [1:0] cdb_select_fu; 

    common_data_bus CDB(
        // input
        .fu_results(execute_reg_curr.result),
        .fu_result_ready(execute_reg_curr.ready),
        .fu_tags(execute_reg_curr.tag_insn_ex),
        .fu_mis_predict(execute_reg_curr.miss_predict),
        .fu_target_pc(execute_reg_curr.target_pc),
        // output
        .rob_enable(rob_enable),
        .select_fu(cdb_select_fu),
        .cdb_value(value_from_cdb),
        .cdb_tag(rob_tag_from_cdb),
        .target_pc(pc_from_cdb),
        .mis_predict(mispredict_from_cdb)
    );


//logic [`XLEN-1:0] branch_target_pc;
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
logic unsigned rob_commit_branch;
logic unsigned rob_commit_branch_taken;
logic [`XLEN-1:0] rob_commit_pc;
logic [`XLEN-1:0] rob_commit_npc;
logic br_jp;
assign br_jp = (inst_dispatch_to_rob.func == BTU_BEQ)
    || (inst_dispatch_to_rob.func == BTU_BNE)
    || (inst_dispatch_to_rob.func == BTU_BLT)
    || (inst_dispatch_to_rob.func == BTU_BGE)
    || (inst_dispatch_to_rob.func == BTU_BLTU)
    || (inst_dispatch_to_rob.func == BTU_BGEU)
    || (inst_dispatch_to_rob.func == BTU_JAL)
    || (inst_dispatch_to_rob.func == BTU_JALR);
logic rob_commit_halt, rob_commit_illegal;

reorder_buffer ROB_0 (
    .clk(clock),
    .reset(reset), 
    // .dispatch(!dispatch_reg_curr.stall),
    // .reg_addr_from_dispatcher(dispatch_reg_curr.inst_rob.register),
    // .npc_from_dispatcher(dispatch_reg_curr.inst_rob.inst_npc),
    // .pc_from_dispatcher(dispatch_reg_curr.inst_rob.inst_pc),
    .dispatch(dispatch_rob),
    .reg_addr_from_dispatcher(inst_dispatch_to_rob.register),
    .npc_from_dispatcher(inst_dispatch_to_rob.inst_npc),
    .pc_from_dispatcher(inst_dispatch_to_rob.inst_pc),
    // .func_from_dispatcher(inst_dispatch_to_rob.func),
    .br_jp_from_dispatcher(br_jp),
    .predict_branch_from_dispatcher(inst_dispatch_to_rob.branch),
    .halt_from_dispatcher(inst_dispatch_to_rob.halt),
    .illegal_from_dispatcher(inst_dispatch_to_rob.illegal),
     
    .cdb_to_rob(rob_enable),
    .rob_tag_from_cdb(rob_tag_from_cdb),
    .wb_data_from_cdb(value_from_cdb),
    .target_pc_from_cdb(pc_from_cdb),
    .mispredict_from_cdb(mispredict_from_cdb),
    
    .search_src1_rob_tag(0), // from dispatcher
    .search_src2_rob_tag(0),
    
    .wb_en(wb_en), //wb to reg
    .wb_reg(wb_reg), 
    .wb_data(wb_data),
    
    // .target_pc(target_pc_from_rob),
    .flush(flush), //also indicate write to pc
    
    .assign_rob_tag_to_dispatcher(rob_tag_for_dispatch),
    .rob_full_adv(rob_full), 
    
    .search_src1_data(src1_data_from_rob), // to dispatcher
    .search_src2_data(src2_data_from_rob),
    .rob_curr(rob_entries),

    .retire_rob_tag(retire_rob_tag),
    .commit_br_jp(rob_commit_branch),
    .commit_pc(rob_commit_pc),
    .commit_npc(rob_commit_npc),

    .halt(rob_commit_halt),
    .illegal(rob_commit_illegal)
);


//////////////////////////////////////////////////
//                                              //
//                 Retire-Stage                 //
//                                              //
//////////////////////////////////////////////////

assign pipeline_registers_out = registers;

logic [`REG_NUM-1:0] [`XLEN-1:0] registers;
register_file register_file_0 (
    .reg_addr(wb_reg),
    .wr_data(wb_data),
    .wr_en(wb_en),
    .clk(clock),
    .reset(reset),
    .regfile(registers)
);


endmodule

`endif
