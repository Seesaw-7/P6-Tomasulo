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
	output EXCEPTION_CODE   pipeline_error_status,
	output logic [4:0]  pipeline_commit_wr_idx,
	output logic [`XLEN-1:0] pipeline_commit_wr_data,
	output logic        pipeline_commit_wr_en,
	output logic [`XLEN-1:0] pipeline_commit_NPC,
	
	
	// testing hooks (these must be exported so we can test
	// the synthesized version) data is tested by looking at
	// the final values in memory
	
`ifdef DEBUG	
	// Outputs from IF-Stage 
	output logic [`XLEN-1:0] if_NPC_out,
	output logic [31:0] if_IR_out,
	output logic        if_valid_inst_out,
	
	// Outputs from IF/ID Pipeline Register
	output logic [`XLEN-1:0] if_id_NPC,
	output logic [31:0] if_id_IR,
	output logic        if_id_valid_inst,
	
	
	// Outputs from ID/EX Pipeline Register
	output logic [`XLEN-1:0] id_ex_NPC,
	output logic [31:0] id_ex_IR,
	output logic        id_ex_valid_inst,
	
	
	// Outputs from EX/MEM Pipeline Register
	output logic [`XLEN-1:0] ex_mem_NPC,
	output logic [31:0] ex_mem_IR,
	output logic        ex_mem_valid_inst,
	
	
	// Outputs from MEM/WB Pipeline Register
	output logic [`XLEN-1:0] mem_wb_NPC,
	output logic [31:0] mem_wb_IR,
	output logic        mem_wb_valid_inst
`endif

);


//////////////////////////////////////////////////
//                                              //
//                 Fetch-Stage                  //
//                                              //
//////////////////////////////////////////////////
PREFETCH_PACKET fetch_stage_packet;
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

logic decoder_csr_opRS_load[0]; //TODO:
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
dispatcher dispatch_stage (
    .clk(clock),
    .reset(reset),
    .decoded_pack(decoded_pack),
    .registers(registers),
    .rob(rob_entries),
    .assign_rob_tag(),
    .inst_rs(inst_dispatch_to_rs),
    .inst_rob(inst_dispatch_to_rob),
    .stall(stall),
    .return_flag(),
    .ready_flag(),
    .reg_addr_from_rob(),
    .rob_tag_from_rob(rob_tag_for_dispatch),
    .reg_addr_from_cdb(),
    .rob_tag_from_cdb(),
    .wb_data().
    .RS_is_full('{rs_alu_full}), //TODO: four rs is_full from right to left
    .RS_load(RS_load)
);


    // input from ROB
    // input ROB_ENTRY rob [`ROB_SIZE-1:0],
    // input [`ROB_ADDR_LEN-1:0] assign_rob_tag,

    // entry to RS
    // output INST_RS inst_rs,

    // entry to ROB
    // output INST_ROB inst_rob,

    // stall prefetch, decoder and rob
    // output stall,


    // forward to map table
    // input return_flag,
    // input ready_flag,
    // input [`REG_ADDR_LEN-1:0] reg_addr_from_rob, 
    // input [`ROB_TAG_LEN-1:0] rob_tag_from_rob,
    // input [`REG_ADDR_LEN-1:0] reg_addr_from_cdb,
    // input [`ROB_TAG_LEN-1:0] rob_tag_from_cdb,
    // input [`ROB_SIZE] [`XLEN-1:0] wb_data, //wires from rob values

    // RS control
    // input unsigned [3:0] RS_is_full, // 4 RS
    // output unsigned [3:0] RS_load





//////////////////////////////////////////////////
//                                              //
//                 Issue-Stage                  //
//                                              //
//////////////////////////////////////////////////

logic rs_alu_full;
logic [`ROB_TAG_LEN-1:0] rs_alu_dest_rob_tag;
logic rs_alu_insn_ready;
logic enable_alu;
reservation_station RS_ALU (
    .clk(clock),
    .reset(reset || flush), // flush when mis predict
    .load(RS_load[0]), // whether we load in the instruction (assigned by dispatcher)
    .issue(), // whether the issue queue should output one instruction (assigned by issue unit), should be stable during clock edge
    .wakeup(), // set by issue unit, indicating whether to set the ready tag of previously issued dst reg to Yes
                        // this should better be set 1 cycle after issue exactly is the FU latency is one, should be stable during clock edge
    .func(),
    .t1(), 
    .t2(), 
    .dst(), // previous renaming unit ensures that dst != inp1 and dst != inp2
    .ready1(), 
    .ready2(),
    .v1(), 
    .v2(), 
    .pc(), 
    .imm(),
    .wakeup_tag(),
    .wakeup_value(), 

    // output signals
    .insn_ready(rs_alu_insn_ready), // to issue unit, indicating if there exists an instruction that is ready to be issued
    .is_full(rs_alu_full), // to dispatcher, indicating that all entries of the reservation station is occupied, cannot load in more inputs
    .start(enable_alu), // output to FU

    // output data
    .func_out(), // to FU
    .v1_out(), 
    .v2_out(), 
    .pc_out(), 
    .imm_out(),// to FU
    .dst_tag(rs_alu_dest_rob_tag) 
);

logic [3:0] issue_signal_from_issue_unit;
logic [`ROB_TAG_LEN-1:0] rob_tag_from_issue_unit;
logic select_flag_from_issue_unit;
logic [1:0] select_signal_from_issue_unit;
issue_unit issue_unit_0 (
    // control signals
    .clk(clock),
    .reset(reset || flush), 
    // data
    .insn_ready(), // from RS
    .ROB_tag('{}), // TODO: 

    // output control signals
    .issue_signals(issue_signal_from_issue_unit), // to each RS
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

// memory
assign proc2Dmem_command = BUS_NONE;
logic [63:0] Imem2proc_data;


//////////////////////////////////////////////////
//                                              //
//                Complete-Stage                //
//                                              //
//////////////////////////////////////////////////
logic [`XLEN-1:0] branch_target_pc;
ROB_ENTRY rob_entries [`ROB_SIZE-1:0];
logic[`XLEN-1:0] target_pc_from_rob 
logic flush;
logic [`ROB_TAG_LEN-1:0] rob_tag_for_dispatch;
logic rob_full;
logic [`ROB_TAG_LEN-1:0] src1_data_from_rob;
logic [`ROB_TAG_LEN-1:0] src2_data_from_rob;

reorder_buffer ROB_0 (
    .clk(clock),
    .reset(reset), //TODO: flush when take_branch
    
    .dispatch(!stall),
    .reg_addr_from_dispatcher(inst_dispatch_to_rob.reg),
     
    .cdb_to_rob(),
    .rob_tag_from_cdb(),
    .wb_data_from_cdb(),
    .target_pc_from_cdb(),
    .mispredict_from_cdb(),
    
    .search_src1_rob_tag(0), // from dispatcher
    .search_src2_rob_tag(0),
    
    .wb_en(), //wb to reg
    .wb_reg(), 
    .wb_data(),
    
    .target_pc(target_pc_from_rob),
    .flush(flush), //also indicate write to pc
    
    .assign_rob_tag_to_dispatcher(rob_tag_for_dispatch),
    .rob_full_adv(rob_full), // TODO: not used in m2
    
    .search_src1_data(src1_data_from_rob), // to dispatcher
    .search_src2_data(src2_data_from_rob),
    .rob_curr(rob_entries);
    
    //rob_curr output
);





//////////////////////////////////////////////////
//                                              //
//                 Retire-Stage                 //
//                                              //
//////////////////////////////////////////////////

logic [`REG_NUM-1:0] [`XLEN-1:0] registers;
register_file regfile (
    .wr_idx(),
    .wr_data(),
    .wr_en(),
    .clk(clock),
    .reset(reset),
    .registers(registers)
);

// module register_file(
//         input   [4:0] wr_idx,    // read/write index
//         input  [`XLEN-1:0] wr_data,            // write data
//         input         wr_en, clk, reset

//         output [`REG_NUM-1:0] [`XLEN-1:0] registers
          
//       );




endmodule

