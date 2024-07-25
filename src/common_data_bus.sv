`timescale 1ns/1ps

`include "sys_defs.svh"

// P6 style Description: 
// The CDB (Common Data Bus) module selects and broadcasts results from functional units (FUs) to 
// the reorder buffer (ROB) and reservation station. It takes inputs from functional units and the issue unit, 
// selects the appropriate result based on a select signal, and outputs the result to the reservation station and ROB.

// Inputs:
// - in_values ([`XLEN-1:0] [FU_NUM-1:0]): Array of results from functional units.
// - ROB_tag：bypass to ROB, forward to RS
// - select_flag (logic): Indicates if selection is valid, bypass to ROB
// - select_signal (logic [$clog2(FU_NUM)-1:0]): signal selecting which result to output.

// Outputs:
// - out_select_flag (logic): Passes through the input select flag.
// - out_ROB_tag (logic [4:0]): Passes through the input ROB tag, bypass to ROB, forward to RS
// - out_value (logic [`XLEN-1:0]): Value output to the ROB, forward to RS.

module common_data_bus (
    input [3:0] [`XLEN-1:0] fu_results,
    input [3:0] fu_result_ready,
    input [3:0] [`ROB_TAG_LEN-1:0] fu_tags,
    input unsigned fu_mis_predict,
    input [`XLEN-1:0] fu_target_pc,

    output logic unsigned rob_enable,
    output logic [1:0] select_fu,
    output logic [`XLEN-1:0] cdb_value,
    output logic [`XLEN-1:0] cdb_tag,
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
        for (int i=0; i<4; ++i) begin
            if (fu_result_ready[i]) begin
                select_fu = i;
                cdb_value = fu_results[i];
                cdb_tag = fu_tags[i];
            end
        end
    end 

    
endmodule
