`timescale 1ns/100ps
`define HALF_CYCLE 25

`include "issue_queue.svh"
`include "sys_def.svh"

module test_issue_queue_v2();

    // Parameters
    parameter NUM_ENTRIES = 4;
    parameter ENTRY_WIDTH = 2;

    // Control signals
    logic clk, reset, load, issue;
    
    // Input data
    ALU1_FUNC insn;
    logic [REG_ADDR_LEN-1:0] inp1, inp2, dst;
    
    // Output signals
    logic issue_ready, is_full;
    
    // Output data
    logic [NUM_ENTRIES-1:0] insn_out;
    logic [REG_ADDR_LEN-1:0] inp1_out, inp2_out, dst_out;

    // Instantiate the issue_queue
    issue_queue #(
        .NUM_ENTRIES(NUM_ENTRIES),
        .ENTRY_WIDTH(ENTRY_WIDTH)
    ) uut (
        .clk(clk),
        .reset(reset),
        .load(load),
        .issue(issue),
        .insn(insn),
        .inp1(inp1),
        .inp2(inp2),
        .dst(dst),
        .issue_ready(issue_ready),
        .is_full(is_full),
        .insn_out(insn_out),
        .inp1_out(inp1_out),
        .inp2_out(inp2_out),
        .dst_out(dst_out)
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
    task test_load_instruction(input ALU1_FUNC test_insn, input logic [REG_ADDR_LEN-1:0] test_inp1, test_inp2, test_dst);
        reset = 1'b0;
        load = 1'b0;
        issue = 1'b0;
        insn = test_insn;
        inp1 = test_inp1;
        inp2 = test_inp2;
        dst = test_dst;
        @(negedge clk);
        reset = 1'b0;
        load = 1'b1;
        wait_until_done();
        load = 1'b0;
    endtask

    // Test task for issuing instruction
    task test_issue_instruction();
        reset = 1'b0;
        issue = 1'b1;
        wait_until_done();
        issue = 1'b0;
    endtask

    // Initial block to run tests
    initial begin
        // Initialize signals
        clk = 0;
        reset = 1;
        load = 0;
        issue = 0;
        insn = ALU_ADD;
        inp1 = 0;
        inp2 = 0;
        dst = 0;

        // Reset the unit
        @(negedge clk);
        reset = 0;

        // Test case 0: Add a new instruction to an empty IQ
        test_load_instruction(ALU_ADD, 5'b00001, 5'b00010, 5'b00011);
        $display("Load complete: ALU_ADD");

        // Test case 1: Add multiple instructions to fill the IQ
        test_load_instruction(ALU_SUB, 5'b00100, 5'b00101, 5'b00110);
        $display("Load complete: ALU_SUB");
        
        test_load_instruction(ALU_AND, 5'b01000, 5'b01001, 5'b01010);
        $display("Load complete: ALU_AND");

        test_load_instruction(ALU_OR, 5'b10000, 5'b10001, 5'b10010);
        $display("Load complete: ALU_OR");

        // Check if IQ is full
        test_load_instruction(ALU_SLL, 5'b11100, 5'b00000, 5'b11110);
        assert(is_full) else $fatal("IQ should be full, but it is not.");
        $display("Loading into full IQ: ALU_SLL");

        // Issue instructions
        test_issue_instruction();
        $display("Issue complete: ALU_ADD");

        test_issue_instruction();
        $display("Issue complete: ALU_SUB");

        test_issue_instruction();
        $display("Issue complete: ALU_AND");

        test_issue_instruction();
        $display("Issue complete: ALU_OR");

        // Test case 2: Add new instructions after issuing
        test_load_instruction(ALU_XOR, 5'b01100, 5'b01101, 5'b01110);
        $display("Load complete: ALU_XOR");

        test_load_instruction(ALU_SRL, 5'b10011, 5'b10100, 5'b10101);
        $display("Load complete: ALU_SRL");

        // Issue the new instructions
        test_issue_instruction();
        $display("Issue complete: ALU_XOR");

        test_issue_instruction();
        $display("Issue complete: ALU_SRL");

        // Finish the simulation
        $finish;
    end

endmodule
