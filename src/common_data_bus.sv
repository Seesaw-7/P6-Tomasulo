/////////////////////////////////////////////////////////////////////////
// Module name : common_data_bus.sv
// Description : This module handles the communication between FU reg and ROB. 
/////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

`include "sys_defs.svh"

module common_data_bus (
    input [3:0] [`XLEN-1:0] fu_results,
    input [3:0] fu_result_ready,
    input [3:0] [`ROB_TAG_LEN-1:0] fu_tags,
    input unsigned fu_mis_predict,
    input [`XLEN-1:0] fu_target_pc,

    output logic unsigned rob_enable,
    output logic [1:0] select_fu,
    output logic [`XLEN-1:0] cdb_value,
    output logic [`ROB_TAG_LEN-1:0] cdb_tag,
    output logic [`XLEN-1:0] target_pc,
    output logic unsigned mis_predict
);

    assign rob_enable = | fu_result_ready;
    assign target_pc = (select_fu == FU_BTU) ? fu_target_pc : 0;
    assign mis_predict = (select_fu == FU_BTU) ? fu_mis_predict : 0;
    always_comb begin
        select_fu = 0;
        cdb_value = 0;
        cdb_tag = 0;
        for (int i=3; i>=0; --i) begin
//    for (int i=0; i<4; ++i) begin
            if (fu_result_ready[i]) begin
                select_fu = 2'(i);
                cdb_value = fu_results[i];
                cdb_tag = fu_tags[i];
            end
        end
    end 

    
endmodule
