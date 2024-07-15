`timescale 1ns/100ps
`define HALF_CYCLE 25

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

    // Clock generation
    always begin
        #`HALF_CYCLE;
        clk = ~clk;
    end

    // Wait until done task
    task wait_until_done;
        @(negedge clk);
    endtask

    // Test task for loading instruction
    task test_load_instruction(input ALU1_FUNC test_insn, input logic [`ROB_TAG_LEN-1:0] test_t1, test_t2, test_dst
                                input logic test_ready1, test_ready2, input logic [`XLEN-1:0] test_v1, test_v2);
        reset = 1'b0;
        load = 1'b0;
        issue = 1'b0;
        t1 = test_t1;
        t2 = test_t2;
        dst = test_dst;
        ready1 = test_ready1;
        ready2 = test_ready2;
        v1 = test_v1;
        v2 = test_v2;
        @(negedge clk);
        reset = 1'b0;
        load = 1'b1;
        wait_until_done();
        load = 1'b0;
    endtask

    // Test task for issuing instruction
    task test_issue_instruction();
        // reset = 1'b1;
        // load = 1'b0;
        // issue = 1'b0;
        // @(negedge clk);
        reset = 1'b0;
        issue = 1'b1;
        wait_until_done();
        issue = 1'b0;
    endtask

    task test_wakeup(input logic [`ROB_TAG_LEN-1:0] test_wakeup_tag, logic [`XLEN-1:0] test_wakeup_value);
        wakeup = 1'b0;
        wakeup_tag = test_wakeup_tag;
        wakeup_value = test_wakeup_value;
        @(negedge clk);
        wakeup = 1'b1;
        wait_until_done();
        wakeup = 1'b0;
    endtask


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

        // // Reset
        // #10;
        // reset = 0;


        // Reset the unit
        @(negedge clk);
        reset = 0;

        // Test case 0: Add a new instruction to an empty IQ
        test_load_instruction(ALU_ADD, 6'b001000, 6'b002000, 6'b003000, 1'b1, 1'b1, 32'h00000001, 32'h00000002;);
        $display("Load complete");

        // Test case 1: Add a new instruction to a full IQ, check whether it stalls when the IQ is full
        test_load_instruction(ALU_SUB, 6'b001001, 6'b002001, 6'b003001, 1'b1, 1'b1, 32'h00000010, 32'h00000020;);
        test_load_instruction(ALU_AND, 6'b001002, 6'b002002, 6'b003002, 1'b1, 1'b1, 32'h00000100, 32'h00000200;);
        test_load_instruction(ALU_OR, 6'b001003, 6'b002003, 6'b003003, 1'b1, 1'b1, 32'h00001000, 32'h00002000;);
        test_load_instruction(ALU_XOR, 6'b001004, 6'b002004, 6'b003004, 1'b1, 1'b1, 32'h00000011, 32'h00000022;);
        test_load_instruction(ALU_SLTU, 6'b001005, 6'b002005, 6'b003005, 1'b1, 1'b1, 32'h00000101, 32'h00000202;);
        test_load_instruction(ALU_SLT, 6'b001006, 6'b002006, 6'b003006, 1'b1, 1'b1, 32'h00001001, 32'h00002002;);
        test_load_instruction(ALU_SLL, 6'b001007, 6'b002007, 6'b003007, 1'b1, 1'b1, 32'h00010000, 32'h00020000;);
    
        $display("Loading into full IQ");
        test_load_instruction(ALU_ADD, 6'b001000, 6'b002000, 6'b003000, 1'b1, 1'b1, 32'h00000001, 32'h00000002;);
        assert(is_full) else $fatal("IQ should be full, but it is not.");
        $display("Load complete");

        // Test case 2: Check output and order
        test_issue_instruction();
        assert(insn_out == ALU_ADD) else $fatal("wrong output");
        test_issue_instruction();
        test_issue_instruction();
        assert(insn_out == ALU_AND) else $fatal("wrong output");
        test_issue_instruction();
        test_issue_instruction();
        test_issue_instruction();
        assert(insn_out == ALU_SLTU) else $fatal("wrong output");
        test_issue_instruction();
        test_issue_instruction();
        assert(issue_ready) else $fatal("issue should be ready, but it is not.");

        // Test case 3: Check issue_ready is down when issue queue is empty
        test_issue_instruction();
        assert(!issue_ready) else $fatal("issue should not be ready, but it is.");

        // Test case 4: Check wakeup
        test_load_instruction(ALU_SUB, 6'b001001, 6'b002001, 6'b003001, 1'b0, 1'b1, 32'h0, 32'h00000020;);
        test_load_instruction(ALU_ADD, 6'b001000, 6'b002000, 6'b003000, 1'b1, 1'b1, 32'h00000001, 32'h00000002;);
        test_issue_instruction();
        assert(insn_out == ALU_ADD) else $fatal("wrong output");
        test_wakeup(6'b001001, 32'h00000010);
        test_load_instruction(ALU_XOR, 6'b001004, 6'b002004, 6'b003004, 1'b1, 1'b1, 32'h00000011, 32'h00000022;);
        test_issue_instruction();
        assert(insn_out == ALU_SUB) else $fatal("wrong output");

        // // Test issue operation
        // issue = 1;
        // #10;
        // issue = 0;

        // // Test wakeup operation
        // wakeup = 1;
        // wakeup_tag = 6;
        // wakeup_value = 32'h11111111;
        // #10;
        // wakeup = 0;

        // // Finish simulation
        // #100;
        $finish;
    end

    // Monitor
    initial begin
        $monitor("Time: %0t | insn_ready: %0b | is_full: %0b | start: %0b | func_out: %0b | v1_out: %0h | v2_out: %0h | pc_out: %0h | imm_out: %0h | dst_tag: %0b",
                 $time, insn_ready, is_full, start, func_out, v1_out, v2_out, pc_out, imm_out, dst_tag);
    end

endmodule
