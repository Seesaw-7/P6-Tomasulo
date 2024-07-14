`timescale 1ns/100ps

`include "sys_defs.svh"
`include "reservation_station.svh"

module reservation_station_tb;

    parameter NUM_ENTRIES = 8;
    parameter ENTRY_WIDTH = 3;
    
    //input
    logic clk;
    logic reset;
    logic load;
    logic issue;
    logic wakeup;

    //output
    ALU_FUNC func;
    logic [`ROB_TAG_LEN-1:0] t1, t2, dst;
    logic ready1, ready2;
    logic [`XLEN-1:0] v1, v2;
    logic [`XLEN-1:0] pc, imm;
    logic [`ROB_TAG_LEN-1:0] wakeup_tag;
    logic [`XLEN-1:0] wakeup_value;

    logic insn_ready;
    logic is_full;
    logic start;

    ALU_FUNC func_out;
    logic [`XLEN-1:0] v1_out, v2_out;
    logic [`XLEN-1:0] pc_out, imm_out;
    logic [`ROB_TAG_LEN-1:0] dst_tag;

    // Instantiate the reservation_station module
    reservation_station #(
        .NUM_ENTRIES(NUM_ENTRIES),
        .ENTRY_WIDTH(ENTRY_WIDTH)
    ) uut (
        .clk(clk),
        .reset(reset),
        .load(load),
        .issue(issue),
        .wakeup(wakeup),
        .func(func),
        .t1(t1),
        .t2(t2),
        .dst(dst),
        .ready1(ready1),
        .ready2(ready2),
        .v1(v1),
        .v2(v2),
        .pc(pc),
        .imm(imm),
        .wakeup_tag(wakeup_tag),
        .wakeup_value(wakeup_value),
        .insn_ready(insn_ready),
        .is_full(is_full),
        .start(start),
        .func_out(func_out),
        .v1_out(v1_out),
        .v2_out(v2_out),
        .pc_out(pc_out),
        .imm_out(imm_out),
        .dst_tag(dst_tag)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        load = 0;
        issue = 0;
        wakeup = 0;
        func = 0;
        t1 = 0;
        t2 = 0;
        dst = 0;
        ready1 = 0;
        ready2 = 0;
        v1 = 0;
        v2 = 0;
        pc = 0;
        imm = 0;
        wakeup_tag = 0;
        wakeup_value = 0;

        // Reset
        #10;
        reset = 0;

        // Test issue operation
        issue = 1;
        #10;
        issue = 0;

        // Test wakeup operation
        wakeup = 1;
        wakeup_tag = 6;
        wakeup_value = 32'hCCCC;
        #10;
        wakeup = 0;

        // Finish simulation
        #100;
        $finish;
    end

    // Monitor
    initial begin
        $monitor("Time: %0t | insn_ready: %0b | is_full: %0b | start: %0b | func_out: %0b | v1_out: %0h | v2_out: %0h | pc_out: %0h | imm_out: %0h | dst_tag: %0b",
                 $time, insn_ready, is_full, start, func_out, v1_out, v2_out, pc_out, imm_out, dst_tag);
    end

endmodule
