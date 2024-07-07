`include "map.sch"

typedef struct packed {
   logic [2:0] FU; // 4 kinds of FU
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

    // for map table
    input logic assign_flag,
    input logic return_flag, 
    input logic ready_flag,
    input logic [`REG_ADDR_LEN-1:0] reg_addr_from_rob, 
    input logic [`ROB_TAG_LEN-1:0] rob_tag_from_rob,
    input logic [`REG_ADDR_LEN-1:0] reg_addr_from_cdb,
    input logic [`ROB_TAG_LEN-1:0] rob_tag_from_cdb
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
    assign arch_reg = insn.arch_reg; 
    assign assign_rob_tag = rob_tail + `ROB_TAG_LEN'd1;
    logic assign_flag;
    assign assign_flag = (insn.arch_reg.dest == 0) ? 1'b0 : 1'b1; // remove r0
    map_table mt (.*); 

    // assign inst_rs
    always_comb begin
        inst_rs.FU = insn.FU;
        inst_rs.op = insn.op;
        // assign inst_rs.busy = (renamed_pack.src1.data_stat != 2'b10) && (renamed_pack.src2.data_stat != 2'b10); // Both src not ready in 
        inst_rs.tag_dest = renamed_pack.rob_tag; 
        inst_rs.tag_src1 = renamed_pack.src1.rob_tag;
        inst_rs.tag_src2 = renamed_pack.src2.rob_tag;
        // src1
        unique case (renamed_pack.src1.data_stat)
            2'b00 : begin
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
            2'b00 : begin
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

    // assign inst_rob
    assign inst_rob.ROB_tag = assign_rob_tag;
    assign inst_rob.reg = renamed_pack.dest;

endmodule