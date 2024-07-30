`timescale 1ns/100ps

`include "sys_defs.svh"
`include "issue_unit.svh"
`include "reservation_station.svh"

module issue_unit (
    // data
    input [3:0] insns_ready,
    input [3:0] cdb_select,
    // broadcast
    input [`XLEN-1:0] alu_result,
    input [`ROB_TAG_LEN-1:0] alu_result_tag,
    input RS_ENTRY [3:0] rs_entries_ex, 

    // output control signals
    output logic [3:0] fu_en, // to each RS
    output INST_RS [3:0] insns_select
);

RS_ENTRY entry_for_ex [3:0];
always_comb begin
    // initialize
   for (int i=0; i<4; ++i) begin
        entry_for_ex[i] = rs_entries_ex[i];
   end 
    // broadcast
    for (int i=0; i<4; ++i) begin
        if (insns_ready[FU_ALU]) begin
            if (entry_for_ex[i].insn.tag_src1 == alu_result_tag) begin
                entry_for_ex[i].insn.value_src1 = alu_result;
                entry_for_ex[i].insn.ready_src1 = 1'b1;
            end
            if (entry_for_ex[i].insn.tag_src2 == alu_result_tag) begin
                entry_for_ex[i].insn.value_src2 = alu_result;
                entry_for_ex[i].insn.ready_src2 = 1'b1;
            end
        end
    end
    for (int i=0; i<4; ++i) begin
        fu_en[i] = entry_for_ex[i].valid && (!insns_ready[i] || cdb_select[i]) && entry_for_ex[i].insn.ready_src1 && entry_for_ex[i].insn.ready_src2; 
        insns_select[i] = entry_for_ex[i].insn;
    end
end


endmodule
