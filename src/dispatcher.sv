`include "map_table.svh"
`include "decoder.svh"
`include "dispatcher.svh"

//TODO: figure out whether to add imm & rs1 or rs1 & rs2
// ?


module dispatcher (
    // control signals
    input clk,
    // input reset, // since combinatinal, no need to reset // TODO: update in m3

    // input from decoder,
    input DECODED_PACK decoded_pack; // update the code after changing input
    input [`REG_NUM-1:0] [`XLEN-1:0] registers, // wires from regfile

    // input from ROB
    input ROB_ENTRY rob [`ROB_SIZE-1:0],
    input [`ROB_ADDR_LEN-1:0] assign_rob_tag,

    // entry to RS
    output INST_RS inst_rs,

    // entry to ROB
    output INST_ROB inst_rob,
    output assign_rob,

    // stall prefetch and decoder
    output stall_pre, // TODO: output stall signal

    // forward to map table
    input return_flag, //？
    input ready_flag,   //？
    input [`REG_ADDR_LEN-1:0] reg_addr_from_rob, 
    input [`ROB_TAG_LEN-1:0] rob_tag_from_rob,
    input [`REG_ADDR_LEN-1:0] reg_addr_from_cdb,
    input [`ROB_TAG_LEN-1:0] rob_tag_from_cdb,
    input [`ROB_SIZE] [`XLEN-1:0] wb_data, //wires from rob values

    // RS control
    input unsigned [3:0] RS_is_full, // 4 RS
    output unsigned [3:0] RS_load
);

    // syncronize input
    logic DECODED_PACK insn_reg;
    always_ff @(posedge clk) begin
        if (reset) begin
            insn_reg <= 0;
        end else begin
            insn_reg <= decoded_pack;
        end
    end

    // map table
    RENAMED_PACK renamed_pack; // TODO: update renamed_pack 
    ARCH_REG arch_reg; // ？
    assign arch_reg = decoded_pack.arch_reg; 
    map_table mt (.*); 

    // assign inst_rs
    assign inst_rs.fu = insn_reg.fu;
    assign inst_rs.func = insn_reg.func;
    assign inst_rs.imm = insn_reg.imm;
    assign inst_rs.pc = insn_reg.pc;
    always_comb begin
        inst_rs.tag_dest = renamed_pack.rob_tag; 
        inst_rs.tag_src1 = renamed_pack.src1.rob_tag;
        inst_rs.tag_src2 = renamed_pack.src2.rob_tag;
        // src1
        unique case (renamed_pack.src1.data_stat)
            2'b00: begin
                inst_rs.ready_src1 = 1'b1;
                inst_rs.value_src1 = registers[renamed_pack.src1.reg_addr];
            end
            2'b11: begin 
                inst_rs.ready_src1 = 1'b1;
                inst_rs.value_src1 = rob[renamed_pack.src1.rob_tag].result; //TODO:
            end
            default: begin
                inst_rs.ready_src1 = 1'b0;
                inst_rs.value_src1 = 0;
            end 
        endcase
        // src2
        unique case (renamed_pack.src2.data_stat)
            2'b00: begin
                inst_rs.ready_src2 = 1'b1;
                inst_rs.value_src2 = registers[renamed_pack.src2.reg_addr];
            end
            2'b11: begin 
                inst_rs.ready_src2 = 1'b1;
                inst_rs.value_src2 = rob[renamed_pack.src2.rob_tag].result; //TODO:
            end
            default: begin
                inst_rs.ready_src2 = 1'b0;
                inst_rs.value_src2 = 0;
            end 
        endcase   
    end

    // RS control
    logic RS_load_cnt;
    always_ff @(posedge clk) begin
        if (reset) RS_load_cnt <= 0;
        else RS_load_cnt <= !RS_load_cnt
    end
    always_comb begin
        RS_load = 4'b0;
        priority case (FU)
            3'd 0: RS_load[0] = RS_is_full[0] ? 1'b0 : 1'b1; // Int Unit
            3'd 1: begin // Mult Unit
                RS_load[1] = RS_is_full[1] ? 1'b0 : 1'b1; // Branch Unit
            end
            3'd 2: RS_load[2] = RS_is_full[2] ? 1'b0 : 1'b1; // Branch Unit
            3'd 3: RS_load[3] = RS_is_full[3] ? 1'b0 : 1'b1; // lw/sw Unit
        endcase
    end

    // assign inst_rob
    assign inst_rob.ROB_tag = assign_rob_tag;
    assign inst_rob.reg = renamed_pack.dest;
    assign assign_rob = |(RS_Load);

endmodule