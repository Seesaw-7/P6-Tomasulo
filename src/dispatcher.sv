`timescale 1ns/100ps

`include "sys_defs.svh"
`include "map_table.svh"
`include "decoder.svh"
`include "dispatcher.svh"
`include "reorder_buffer.svh"

// TODO: add instruction queue in m3
// TODO: check maptable input
// TODO: edit LSU stall in m3

module dispatcher (
    // control signals
    input clk,
    input reset, 

    // input from decoder,
    input DECODED_PACK decoded_pack,
    input [`REG_NUM-1:0] [`XLEN-1:0] registers, // wires from regfile
    input branch_from_bp,

    // input from ROB
    input ROB_ENTRY [`ROB_SIZE-1:0] rob ,
    input [`ROB_TAG_LEN-1:0] assign_rob_tag,

    // entry to RS
    output INST_RS inst_rs,

    // entry to ROB
    output INST_ROB inst_rob,

    // stall prefetch, decoder and rob
    // the decoded_packed just received will be kept in dispatcher
    output logic stall,

    // forward to map table
    input return_flag,
    input ready_flag,
    input [`ROB_TAG_LEN-1:0] rob_tag_from_rob,
    input [`REG_ADDR_LEN-1:0] reg_addr_from_rob,
    input [`ROB_TAG_LEN-1:0] rob_tag_from_cdb,

    // input data from ROB
    // input [`XLEN-1:0] wb_data, //wires from rob values

    // RS control
    input unsigned [3:0] RS_is_full, // 4 RS
    output logic unsigned [3:0] RS_load
);

    // syncronize input
    DECODED_PACK insn_reg;
    logic [`ROB_TAG_LEN-1:0] assign_rob_tag_reg;
//    always_ff @(posedge clk) begin
//        if (reset) begin
//            insn_reg <= 0;
//            assign_rob_tag_reg <= 0;
//        end else begin
//            unique if (stall)
//                insn_reg <= insn_reg;
//            else
//                insn_reg <= decoded_pack;
//            assign_rob_tag_reg <= assign_rob_tag;
//        end
//    end
    assign insn_reg = decoded_pack;
    assign assign_rob_tag_reg = assign_rob_tag;

    // map table
    RENAMED_PACK renamed_pack; 
    ARCH_REG arch_reg;
    assign arch_reg = insn_reg.arch_reg; 
    logic assign_flag;
    assign assign_flag = ~stall;
    map_table mt (.*); 

    // assign inst_rs
    assign inst_rs.fu = insn_reg.fu;
    assign inst_rs.func = insn_reg.alu_func;
    assign inst_rs.tag_dest = renamed_pack.rob_tag; 
    assign inst_rs.tag_src1 = renamed_pack.src1.rob_tag;
    assign inst_rs.tag_src2 = renamed_pack.src2.rob_tag;
    assign inst_rs.imm = insn_reg.fu == FU_BTU? insn_reg.imm : '0;
    assign inst_rs.pc = insn_reg.fu == FU_BTU? insn_reg.pc : '0;
    assign inst_rs.npc = insn_reg.fu == FU_BTU? insn_reg.npc : '0;
    assign inst_rs.insn_tag = assign_rob_tag;

    always_comb begin
        // src1
        unique case (renamed_pack.src1.data_stat)
            2'b00: begin // ready in RegFile
                inst_rs.ready_src1 = 1'b1;
                inst_rs.value_src1 = (insn_reg.fu != FU_BTU && insn_reg.pc_valid) ?
                                    insn_reg.pc : registers[renamed_pack.src1.reg_addr];
            end
            2'b11: begin // ready in ROB
                inst_rs.ready_src1 = 1'b1;
                inst_rs.value_src1 = (insn_reg.fu != FU_BTU && insn_reg.pc_valid) ? 
                                    insn_reg.pc : rob[renamed_pack.src1.rob_tag].wb_data; 
            end
            default: begin // not ready
                inst_rs.ready_src1 = (insn_reg.fu != FU_BTU && insn_reg.pc_valid) ?
                                        1'b1: 1'b0;
                inst_rs.value_src1 = (insn_reg.fu != FU_BTU && insn_reg.pc_valid) ? 
                                    insn_reg.pc : 0; 
            end 
        endcase
        // src2
        unique case (renamed_pack.src2.data_stat)
            2'b00: begin
                inst_rs.ready_src2 = 1'b1;
                inst_rs.value_src2 = (insn_reg.fu != FU_BTU && insn_reg.imm_valid) ?
                                    insn_reg.imm : registers[renamed_pack.src2.reg_addr];
            end
            2'b11: begin 
                inst_rs.ready_src2 = 1'b1;
                inst_rs.value_src2 = (insn_reg.fu != FU_BTU && insn_reg.imm_valid) ?
                                    insn_reg.imm : rob[renamed_pack.src2.rob_tag].wb_data; 
            end
            default: begin
                inst_rs.ready_src2 = (insn_reg.fu != FU_BTU && insn_reg.imm_valid) ?
                                        1'b1:1'b0;
                inst_rs.value_src2 = (insn_reg.fu != FU_BTU && insn_reg.imm_valid) ?
                                        insn_reg.imm : 0; 
            end 
        endcase   
    end

    // RS control
    // logic RS_load_cnt;
    // always_ff @(posedge clk) begin
    //     if (reset) RS_load_cnt <= 0;
    //     else RS_load_cnt <= !RS_load_cnt;
    // end

    always_comb begin
        RS_load = 4'b0;
        stall = 0;
        case (insn_reg.fu)
            FU_LSU : begin
                RS_load[FU_LSU] = 1; 
            end // Load Store Unit TODO: edit stall and rs_load in m3
            FU_MULT: begin 
                RS_load[FU_MULT] = RS_is_full[FU_MULT] ? 1'b0 : 1'b1; // Mult Unit
                stall = ~RS_is_full[FU_MULT] ? 1'b0 : 1'b1; 
            end
            FU_BTU: begin 
                RS_load[FU_BTU] = RS_is_full[FU_BTU] ? 1'b0 : 1'b1; // Branch Unit
                stall = ~RS_is_full[FU_BTU] ? 1'b0 : 1'b1; 
            end
            FU_ALU: begin 
                RS_load[FU_ALU] = RS_is_full[FU_ALU] ? 1'b0 : 1'b1; // ALU
                stall = ~RS_is_full[FU_ALU] ? 1'b0 : 1'b1; 
            end
        endcase
    end

    // assign inst_rob
    assign inst_rob.register = renamed_pack.dest;
    assign inst_rob.inst_pc = insn_reg.pc;
    assign inst_rob.inst_npc = insn_reg.npc;
    assign inst_rob.func = insn_reg.alu_func;
    assign inst_rob.branch = branch_from_bp;

    // assign stall = |(RS_Load);//TODO: use this in m3

endmodule
