`include "map.sch"

typedef struct packed {
//    logic [2:0] FU; // 4 kinds of FU
   logic unsigned [6:0] op;
   logic unsigned [`ROB_TAG_LEN-1:0] tag_dest;
   logic unsigned [`ROB_TAG_LEN-1:0] tag_src1;
   logic unsigned [`ROB_TAG_LEN-1:0] tag_src2;
   logic unsigned ready_src1;
   logic unsigned [`XLEN-1] value_src1;
   logic unsigned ready_src2;
   logic unsigned [`XLEN-1] value_src2;
} INST_RS;

typedef struct packed {
   logic unsigned [`ROB_TAG_LEN-1:0] ROB_tag; // ROB tag for insn
   logic unsigned [`REG_ADDR_LEN-1:0] reg; // architectural reg for dest
//    logic [`XLEN-1] value; // value in reg
} INST_ROB;


typedef struct packed {
   logic unsigned valid;
   logic [2:0] FU; // 4 kinds of FU
   logic unsigned [6:0] op;
   ARCH_REG arch_reg;
} INST;


module dispatcher (
    input clk,
    input reset,
    input INST insn,
    input [`REG_NUM-1:0] [`XLEN-1:0] registers, // wires from regfile
    // from ROB
    input ROB_ENTRY rob [`ROB_SIZE-1:0],
    input [`ROB_ADDR_LEN-1:0] rob_tail,
    // entry to RS
    output INST_RS inst_rs,
    // entry to ROB
    output INST_ROB inst_rob,

    // forward to map table
    input assign_flag,
    input return_flag, 
    input ready_flag,
    input [`REG_ADDR_LEN-1:0] reg_addr_from_rob, 
    input [`ROB_TAG_LEN-1:0] rob_tag_from_rob,
    input [`REG_ADDR_LEN-1:0] reg_addr_from_cdb,
    input [`ROB_TAG_LEN-1:0] rob_tag_from_cdb,

    // RS control
    input unsigned [3:0] RS_is_full, // 5 RS
    output unsigned [3:0] RS_load
);

    // syncronize input
    logic INST insn_reg;
    always_ff @(posedge clk) begin
        if (reset) begin
            insn_reg <= 0;
        end else begin
            insn_reg <= insn;
        end
    end

    // map table
    RENAMED_PACK renamed_pack;
    logic [`ROB_TAG_LEN-1:0] assign_rob_tag;
    ARCH_REG arch_reg;
    assign arch_reg = insn_reg.arch_reg; 
    assign assign_rob_tag = rob_tail + `ROB_TAG_LEN'd1;
    logic assign_flag;
    assign assign_flag = (insn_reg.arch_reg.dest == 0) ? 1'b0 : 1'b1; // remove r0
    map_table mt (.*); 

    // assign inst_rs
    always_comb begin
        inst_rs.op = insn_reg.op;
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
                priority if ((RS_is_full[1] == 1'b0) && (RS_is_full[2] == 1'b0)) begin
                    RS_load[1] = RS_load_cnt ? 1'b1 : 1'b0;
                    RS_load[2] = RS_load_cnt ? 1'b0 : 1'b1;
                end else if ((RS_is_full[1] == 1'b0) && (RS_is_full[2] == 1'b1)) begin
                    RS_load[1] = 1'b1;
                end else if ((RS_is_full[1] == 1'b1) && (RS_is_full[2] == 1'b0)) begin
                    RS_load[2] = 1'b1;
                end
            end
            3'd 2: RS_load[3] = RS_is_full[3] ? 1'b0 : 1'b1; // Branch Unit
            3'd 3: RS_load[4] = RS_is_full[4] ? 1'b0 : 1'b1; // lw/sw Unit
        endcase
        
    end

    // assign inst_rob
    assign inst_rob.ROB_tag = assign_rob_tag;
    assign inst_rob.reg = renamed_pack.dest;

endmodule