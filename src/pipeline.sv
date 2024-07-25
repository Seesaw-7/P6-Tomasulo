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
	
    output [`REG_NUM-1:0] [`XLEN-1:0] pipeline_registers_out
    // output flush, stall,
    // output dispatcher_RS_is_full,
    // output issue_unit_insn_ready,
    // output issue_signal_out,
    // output decoded_pack,
    // output inst_dispatch_to_rs,
    // output value_from_cdb,
    // output select_signal_from_issue_unit,
    // output rob_tag_from_issue_unit,
    // output rs_alu_v1_out,
    // output rs_alu_v2_out,
    // output alu_result
	
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
//            Fetch Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

    typedef struct packed {
        DECODED_PACK decoded_pack; 
        logic [`ROB_TAG_LEN-1:0] rob_tag;
        logic unsigned [3:0] rs_is_full;
        // map table
        logic return_flag;
        logic ready_flag;
        logic [`ROB_TAG_LEN-1:0] rob_tag_from_rob;
        logic [`REG_ADDR_LEN-1:0] reg_addr_from_rob;
        logic [`ROB_TAG_LEN-1:0] rob_tag_from_cdb;
    } FETCH_REG;

    FETCH_REG fetch_reg_curr, fetch_reg_next;

    always_comb begin
        fetch_reg_next.decoded_pack = decoded_pack;
        fetch_reg_next.rs_is_full = dispatcher_RS_is_full; //TODO:
        fetch_reg_next.return_flag = wb_en;
        fetch_reg_next.ready_flag = select_flag_from_cdb;
        fetch_reg_next.rob_tag_from_rob = retire_rob_tag;
        fetch_reg_next.reg_addr_from_rob = wb_reg;
        fetch_reg_next.rob_tag_from_cdb = rob_tag_from_cdb;
    end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin //TODO: flush
            fetch_reg_curr <= 0;
		end else begin// if (reset)
			fetch_reg_curr <= `SD fetch_reg_next; 
            // neglect enable signal since invalid insn are dropped in dispatcher 
		end
	end // always

//////////////////////////////////////////////////
//                                              //
//                Dispatch-Stage                //
//                                              //
//////////////////////////////////////////////////
// TODO: check whether invalid insn are dropped
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
    .decoded_pack(fetch_reg_curr.decoded_pack),
    .registers(registers), // forward from register (reg)
    .rob(rob_entries), // forward from rob (reg)
    .assign_rob_tag(fetch_reg_curr.rob_tag),
    .inst_rs(inst_dispatch_to_rs), //output
    .inst_rob(inst_dispatch_to_rob), //output
    .stall(stall), // output
    .return_flag(fetch_reg_curr.return_flag), 
    .ready_flag(fetch_reg_curr.ready_flag),
    .reg_addr_from_rob(fetch_reg_curr.reg_addr_from_rob),
    .rob_tag_from_rob(fetch_reg_curr.rob_tag_from_rob),
    .rob_tag_from_cdb(fetch_reg_curr.rob_tag_from_cdb),
    // .wb_data(0), //TODO: redundant for m2
    .RS_is_full(fetch_reg_curr.rs_is_full), 
    .RS_load(RS_load) //output
);

//////////////////////////////////////////////////
//                                              //
//            Dispatch Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

    typedef struct packed {
       INST_RS inst_rs;
       INST_ROB inst_rob; 
       logic stall;
       logic unsigned [3:0] rs_load;
    } DISPATCH_PACK;

    DISPATCH_PACK dispatch_reg_curr, dispatch_reg_next;

    always_comb begin
        dispatch_reg_next.inst_rs = inst_dispatch_to_rs;
        dispatch_reg_next.inst_rob = inst_dispatch_to_rob;
        dispatch_reg_next.stall = stall;
        dispatch_reg_next.rs_load = RS_load;
    end

    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin //TODO: flush
            dispatch_reg_curr <= 0;
		end else begin// if (reset)
			dispatch_reg_curr <= `SD dispatch_reg_next; 
            // neglect enable signal since invalid insn are dropped in dispatcher 
		end
	end // always

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
        .load(dispatch_reg_curr.rs_load[FU_ALU]),
        .insn_load(dispatch_reg_curr.inst_rs),
        .wakeup(execute_reg_curr.ready), 
        .wakeup_value(execute_reg_curr.result),
        .wakeup_tag(execute_reg_curr.tag_result), 
        .clear(rs_clear[FU_ALU]), 
        .clear_tag(rs_clear_tag[FU_ALU]),
        .insn_for_ex(alu_entry_out),
        .is_full(rs_alu_full)
    );


// Branch Unit

    logic rs_btu_full;
    RS_ENTRY btu_entry_out;

    reservation_station RS_BTU (
        .clk(clock),
        .reset(reset || flush), // flush when mis predict
        .load(dispatch_reg_curr.rs_load[FU_BTU]),
        .insn_load(dispatch_reg_curr.inst_rs),
        .wakeup(execute_reg_curr.ready), 
        .wakeup_value(execute_reg_curr.result),
        .wakeup_tag(execute_reg_curr.tag_result), 
        .clear(rs_clear[FU_BTU]), 
        .clear_tag(rs_clear_tag[FU_BTU]),
        .insn_for_ex(btu_entry_out),
        .is_full(rs_btu_full)
    );

// Mult Unit
    logic rs_mult_full;
    RS_ENTRY mult_entry_out;

    reservation_station RS_MULT (
        .clk(clock),
        .reset(reset || flush), // flush when mis predict
        .load(dispatch_reg_curr.rs_load[FU_MULT]),
        .insn_load(dispatch_reg_curr.inst_rs),
        .wakeup(execute_reg_curr.ready), 
        .wakeup_value(execute_reg_curr.result),
        .wakeup_tag(execute_reg_curr.tag_result), 
        .clear(rs_clear[FU_MULT]), 
        .clear_tag(rs_clear_tag[FU_MULT]),
        .insn_for_ex(mult_entry_out),
        .is_full(rs_btu_full)
    );

// load store unit
    logic rs_lsu_full;
    RS_ENTRY lsu_entry_out;

    reservation_station RS_LSU (
        .clk(clock),
        .reset(reset || flush), // flush when mis predict
        .load(dispatch_reg_curr.rs_load[FU_LSU]),
        .insn_load(dispatch_reg_curr.inst_rs),
        .wakeup(execute_reg_curr.ready), 
        .wakeup_value(execute_reg_curr.result),
        .wakeup_tag(execute_reg_curr.tag_result), 
        .clear(rs_clear[FU_LSU]), 
        .clear_tag(rs_clear_tag[FU_LSU]),
        .insn_for_ex(lsu_entry_out),
        .is_full(rs_lsu_full)
    );


// logic [3:0] issue_signal_out;
// logic [`ROB_TAG_LEN-1:0] rob_tag_from_issue_unit;
// logic select_flag_from_issue_unit;
// FUNC_UNIT select_signal_from_issue_unit;

// logic [3:0] issue_unit_insn_ready;
// assign issue_unit_insn_ready[FU_ALU] = rs_alu_insn_ready;
// assign issue_unit_insn_ready[FU_MULT] = rs_mult_insn_ready;
// assign issue_unit_insn_ready[FU_BTU] = rs_btu_insn_ready; 
// assign issue_unit_insn_ready[FU_LSU] = 1'b0;

// logic [3:0][`ROB_TAG_LEN-1:0] issue_unit_ROB_tag;
// assign issue_unit_ROB_tag[FU_ALU] = rs_alu_dest_rob_tag;
// assign issue_unit_ROB_tag[FU_MULT] = rs_mult_dest_rob_tag;
// assign issue_unit_ROB_tag[FU_BTU] = rs_btu_dest_rob_tag;
// assign issue_unit_ROB_tag[FU_LSU] = rs_lsu_dest_rob_tag;

//////////////////////////////////////////////////
//                                              //
//                Execute-Stage                 //
//                                              //
//////////////////////////////////////////////////
    // Integer issue unit
    logic [3:0] rs_clear;
    logic [3:0] [`ROB_TAG_LEN-1:0] rs_clear_tag;
    INST_RS alu_insn;
    always_comb begin
        alu_insn = alu_entry_out.insn;
        // broadcast
        if (execute_reg_curr.ready[FU_ALU]) begin
            if (alu_insn.tag_src1 == execute_reg_curr.tag_result[FU_ALU])begin
                alu_insn.value_src1 = execute_reg_curr.result[FU_ALU];
                alu_insn.ready_src1 = 1'b1;
            end
            if (alu_insn.tag_src2 == execute_reg_curr.tag_result[FU_ALU])begin
                alu_insn.value_src2 = execute_reg_curr.result[FU_ALU];
                alu_insn.ready_src2 = 1'b1;
            end
        end
    end
    assign rs_clear[FU_ALU] = alu_entry_out.valid && !execute_reg_curr.ready[FU_ALU] && alu_insn.ready_src1 && alu_insn.ready_src1; // FU reg is empty and insn is ready 
    assign rs_clear_tag[FU_ALU] = alu_entry_out.insn.insn_tag;

    // Integer Unit
    logic [`XLEN-1:0] alu_result;
    logic [`ROB_TAG_LEN-1:0] alu_result_tag;
    logic alu_done;
    

    arithmetic_logic_unit ALU (
        .insn(alu_insn),
        .en(rs_clear[FU_ALU]),
        .result(alu_result),
        .insn_tag(alu_result_tag),
        .done(alu_done)
    );


// branch unit

logic [`XLEN-1:0] btu_wb_data;
logic [`XLEN-1:0] btu_target_pc;
logic btu_mis_predict;
branch_unit BTU (
    .func(btu_entry_out.insn.func),
    .pc(btu_entry_out.insn.pc), //target addr cal
    .imm(btu_entry_out.insn.imm),
    .rs1(btu_entry_out.insn.value_src1), // also for jalr
    .rs2(btu_entry_out.insn.value_src2),
    .cond(btu_mis_predict), // 1 for misprediction/flush
    .wb_data(btu_wb_data), 
    .target_pc(btu_target_pc)
);

// mult unit
logic [63:0] mult_result;
logic mult_done;
// multiplier mult_0 (
//     .clock(clock),
//     .reset(reset || flush),
//     .mcand(64'(rs_mult_v1_out)), // TODO: 32 bits to 64 bits?
//     .mplier(64'(rs_mult_v2_out)),
//     .start(enable_mult && !execute_reg_curr.ready[FU_MULT]),
//     .product(mult_result),
//     .done(mult_done)
// );

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
        logic [3:0] [`XLEN-1:0] result; //TODO: mult 64 bits
        logic [3:0] [`ROB_TAG_LEN-1:0] tag_insn_ex;
        logic [3:0] [`ROB_TAG_LEN-1:0] tag_result;
        logic [`XLEN-1:0] target_pc;
        logic miss_predict;
    } EXECUTE_PACK;

    EXECUTE_PACK execute_reg_curr, execute_reg_next;

    always_comb begin
        execute_reg_next.ready[FU_ALU] = alu_done;
        // TODO:
        execute_reg_next.result[FU_ALU] = alu_result;
        execute_reg_next.result[FU_MULT] = mult_result;
        execute_reg_next.result[FU_BTU] = btu_wb_data;
        execute_reg_next.tag_insn_ex[FU_ALU] = alu_result_tag; // TODO:
        execute_reg_next.tag_result[FU_ALU] = alu_result_tag;
        execute_reg_next.target_pc = btu_target_pc;
        execute_reg_next.miss_predict = btu_mis_predict;
        //TODO:
    end

    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin //TODO: flush
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
// common_data_bus CDB (
//     .in_values(cdb_in_values),
//     .mispredict(branch_from_lsu),
//     .pc(btu_target_pc),
//     .select_flag(select_flag_from_issue_unit),
//     .select_signal(select_signal_from_issue_unit),
//     .ROB_tag(rob_tag_from_issue_unit),
//     .out_select_flag(select_flag_from_cdb),
//     .out_ROB_tag(rob_tag_from_cdb),
//     .out_value(value_from_cdb),
//     .out_mispredict(branch_from_cdb),
//     .out_pc(pc_from_cdb)
// );
assign select_flag_from_cdb = execute_reg_curr.ready[FU_ALU];
assign rob_tag_from_cdb = execute_reg_curr.tag_insn_ex[FU_ALU];
assign value_from_cdb = execute_reg_curr.result[FU_ALU];
assign pc_from_cdb = execute_reg_curr.result[FU_BTU];
assign branch_from_cdb = 1'b0;



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
    .reg_addr_from_dispatcher(dispatch_reg_curr.inst_rob.register),
    .npc_from_dispatcher(dispatch_reg_curr.inst_rob.inst_npc),
    .pc_from_dispatcher(dispatch_reg_curr.inst_rob.inst_pc),
     
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
