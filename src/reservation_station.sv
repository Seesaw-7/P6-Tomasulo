`timescale 1ns/100ps

`include "sys_defs.svh"
 `include "reservation_station.svh"

//TODO: use CAM instead of loop to improve gate latency

// Note: this module assumes that wakeup is stable at posedge, and wakeup is one clock behind issue
// Besides, it assumes that wakeup_tag and wakeup_value are stable at clock edge, which is kind of weird


module reservation_station #(
    parameter NUM_ENTRIES = 8, // #entries in the reservation station
    parameter ENTRY_WIDTH = 3  // #entries = 2^{ENTRY_WIDTH}
) (
    // control signals
    input clk,
    input reset,

    // from dispatch
    input logic load,
    input INST_RS insn_load,

    // from FU reg 
    input unsigned [3:0] wakeup ,
    input [3:0] [`XLEN-1:0] wakeup_value,
    input [3:0] [`ROB_TAG_LEN-1:0] wakeup_tag, // tag already executed
    // input [3:0] [`ROB_TAG_LEN-1:0] ex_tag, 
    // wakeup_tag under execution (before or after fu based on issue)

    // from issue unit
    input unsigned clear,
    input [`ROB_TAG_LEN-1:0] clear_tag,
    input [`ROB_TAG_LEN-1:0] alu_ex_tag,

    output RS_ENTRY insn_for_ex, // not always ready & reg
    output logic is_full
);

    RS_ENTRY issue_queue_curr [NUM_ENTRIES-1:0]; 
    RS_ENTRY issue_queue_next [NUM_ENTRIES-1:0]; 
    RS_ENTRY insn_for_ex_next; // not always ready & reg

    always_ff @(posedge clk) begin
        unique if (reset) begin
            for (int i=0; i<NUM_ENTRIES; ++i) begin
                issue_queue_curr[i] <= 0;
            end
            insn_for_ex <= 0;
        end else begin
            issue_queue_curr <= issue_queue_next;
            insn_for_ex <= insn_for_ex_next;
        end
    end

    always_comb begin
        issue_queue_next = issue_queue_curr;
        // load insn from dispatcher
        if (load) begin
            issue_queue_next[NUM_ENTRIES-1].insn = insn_load;
            issue_queue_next[NUM_ENTRIES-1].valid = 1;
        end
        // clear insn
        if (clear) begin
            for (int i=0; i<NUM_ENTRIES; ++i) begin
                if (issue_queue_next[i].insn.insn_tag == clear_tag) begin
                    issue_queue_next[i].valid = 0;
                end
            end
        end
        // move everything to the end
        for (int i=0; i<NUM_ENTRIES-1; ++i) begin 
            if (!issue_queue_next[i].valid) begin
                issue_queue_next[i] = issue_queue_next[i+1];
                issue_queue_next[i+1].valid = 1'b0;
            end
        end
        // wakeup
        for (int j=0; j<4; ++j) begin
           if (wakeup[j]) begin
                for (int i=0; i<NUM_ENTRIES; ++i) begin
                    if (!issue_queue_next[i].insn.ready_src1 && issue_queue_next[i].insn.tag_src1 == wakeup_tag[j]) begin
                        issue_queue_next[i].insn.value_src1 = wakeup_value[j];
                        issue_queue_next[i].insn.ready_src1 = 1;
                    end
                    if (!issue_queue_next[i].insn.ready_src2 && issue_queue_next[i].insn.tag_src2 == wakeup_tag[j]) begin
                        issue_queue_next[i].insn.value_src2 = wakeup_value[j];
                        issue_queue_next[i].insn.ready_src2 = 1;
                    end
                end 
            end
        end
    end

    RS_ENTRY insn_ready, insn_to_ready;

    // find the first ready insn
    always_comb begin
        insn_ready = 0;
        for (int i=NUM_ENTRIES; i>=0; --i) begin
            unique if (issue_queue_curr[i].valid && issue_queue_curr[i].insn.ready_src1 && issue_queue_curr[i].insn.ready_src2) begin
                insn_ready = issue_queue_curr[i];
            end else begin
                insn_ready = insn_ready;
            end
        end
    end

    // find the first ready insn with the alu tag
    RS_ENTRY issue_queue_predict [NUM_ENTRIES-1:0]; 
    always_comb begin
       issue_queue_predict = issue_queue_curr; 
       // fake wakeup
       for (int i=0; i<NUM_ENTRIES; ++i) begin
            if (issue_queue_predict[i].insn.tag_src1 == alu_ex_tag) begin
                issue_queue_predict[i].insn.ready_src1 = 1;
            end
            if (issue_queue_predict[i].insn.tag_src2 == alu_ex_tag) begin
                issue_queue_predict[i].insn.ready_src2 = 1;
            end
       end
       insn_to_ready = 0;
        for (int i=NUM_ENTRIES; i>=0; --i) begin
            unique if (issue_queue_predict[i].valid && issue_queue_predict[i].insn.ready_src1 && issue_queue_predict[i].insn.ready_src2) begin
                insn_to_ready = issue_queue_curr[i];
            end else begin
                insn_to_ready = insn_to_ready;
            end
        end
    end

    assign insn_for_ex_next = insn_ready.valid ? insn_ready : insn_to_ready;
    assign is_full =  issue_queue_curr[NUM_ENTRIES-2].valid;
    
endmodule



