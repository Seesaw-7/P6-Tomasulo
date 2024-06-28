`timescale 1ns/100ps
`define HALF_CYCLE 25

`include "issue_queue.svh"
`include "sys_def.svh"

module test_issue_queue();

    // Parameters
    parameter NUM_ENTRIES = 4;
    parameter ENTRY_WIDTH = 2;
    parameter REG_ADDR_WIDTH = 5;
    parameter REG_NUM = 32;

    // Control signals
    logic clk, reset, load, issue;
    
    // Input data
    ALU1_FUNC insn;
    logic [REG_ADDR_WIDTH-1:0] inp1, inp2, dst;
    
    // Output signals
    logic issue_ready, is_full;
    
    // Output data
    logic [NUM_ENTRIES-1:0] insn_out;
    logic [REG_ADDR_WIDTH-1:0] inp1_out, inp2_out, dst_out;

    // Instantiate the issue_queue
    issue_queue #(
        .NUM_ENTRIES(NUM_ENTRIES),
        .ENTRY_WIDTH(ENTRY_WIDTH),
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
        .REG_NUM(REG_NUM)
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
    task test_load_instruction(input ALU1_FUNC test_insn, input logic [REG_ADDR_WIDTH-1:0] test_inp1, test_inp2, test_dst);
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
        // reset = 1'b1;
        // load = 1'b0;
        // issue = 1'b0;
        // @(negedge clk);
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
        $display("Load complete");

        // Test case 1: Add a new instruction to a full IQ, check whether it stalls when the IQ is full
        test_load_instruction(ALU_SUB, 5'b00100, 5'b00101, 5'b00110);
        test_load_instruction(ALU_AND, 5'b01000, 5'b01001, 5'b01010);
        test_load_instruction(ALU_OR, 5'b10000, 5'b10001, 5'b10010);
        $display("Loading into full IQ");
        test_load_instruction(ALU_SLL, 5'b11100, 5'b00000, 5'b11110);
        assert(is_full) else $fatal("IQ should be full, but it is not.");
        $display("Load complete");

        // Test case 2: Check output
        test_issue_instruction();
        test_issue_instruction();
        test_issue_instruction();
        test_issue_instruction();
        assert(issue_ready) else $fatal("issue should be ready, but it is not.");

        // Test case 3: Check issue_ready is down when issue queue is empty
        test_issue_instruction();
        assert(!issue_ready) else $fatal("issue should not be ready, but it is.");


        // Test case 4: Check out of order output
        test_load_instruction(ALU_ADD, 5'b01110, 5'b01111, 5'b10000);
        test_load_instruction(ALU_ADD, 5'b01011, 5'b01100, 5'b01101);
        test_load_instruction(ALU_OR, 5'b00001, 5'b00010, 5'b00011);
        test_load_instruction(ALU_SUB, 5'b00011, 5'b00100, 5'b00101);
        test_issue_instruction();
        test_issue_instruction();
        test_load_instruction(ALU_AND, 5'b00101, 5'b00110, 5'b00111);
        test_load_instruction(ALU_XOR, 5'b01000, 5'b01001, 5'b01010);
        test_issue_instruction();
        assert(insn_out == ALU_OR) else $fatal("wrong output");
        test_issue_instruction();
        assert(insn_out == ALU_SUB) else $fatal("wrong output");
        test_issue_instruction();
        assert(insn_out == ALU_AND) else $fatal("wrong output");
        test_issue_instruction();
        // test_load_instruction(ALU_XOR, 5'b01000, 5'b01001, 5'b01010);


        // Test case 5: Check when two entries are ready, the older one should be issued first
        test_load_instruction(ALU_ADD, 5'b01110, 5'b01111, 5'b10000);
        test_load_instruction(ALU_ADD, 5'b01011, 5'b01100, 5'b01101);
        test_load_instruction(ALU_OR, 5'b00001, 5'b00010, 5'b00011);
        test_load_instruction(ALU_SUB, 5'b00011, 5'b00100, 5'b00101);
        test_issue_instruction();
        test_issue_instruction();
        test_load_instruction(ALU_AND, 5'b00110, 5'b00111, 5'b01000);
        test_load_instruction(ALU_XOR, 5'b01001, 5'b01010, 5'b01011);
        test_issue_instruction();
        assert(insn_out == ALU_OR) else $fatal("wrong output");
        test_issue_instruction();
        assert(insn_out == ALU_SUB) else $fatal("wrong output");
        test_issue_instruction();
        assert(insn_out == ALU_AND) else $fatal("wrong output");
        test_issue_instruction();
        test_load_instruction(ALU_XOR, 5'b01000, 5'b01001, 5'b01010);

        // Test case 2: Check whether the ready bit of output is cleared before writing new data into IQ slot
        // test_issue_instruction();
        // test_load_instruction(4'b1100, 5'b11000, 5'b11001, 5'b11010);
        // todo: assert ready bits are cleared and then reloaded
        
        // Test case 3: Add instructions with ready and not ready physical regs
        // test_load_instruction(4'b0110, 5'b01001, 5'b01101, 5'b01110); // ready regs
        // // todo: Update ready table to make inp1 not ready
        // // ready_table[inp1] = 0;
        // test_load_instruction(4'b1110, 5'b11011, 5'b11101, 5'b11111); // not ready regs
        // $display("Load complete");

        // // Issue instructions
        // test_issue_instruction();
        // test_issue_instruction();

        // // Load more instructions after issuing
        // test_load_instruction(4'b1010, 5'b10100, 5'b10101, 5'b10110);

        // // More issues
        // test_issue_instruction();

        // // Randomized testing
        // for (int i = 0; i < 10; i++) begin
        //     ALU1_FUNC rand_insn = $urandom_range(0, 15);
        //     logic [REG_ADDR_WIDTH-1:0] rand_inp1 = $urandom_range(0, 31);
        //     logic [REG_ADDR_WIDTH-1:0] rand_inp2 = $urandom_range(0, 31);
        //     logic [REG_ADDR_WIDTH-1:0] rand_dst = $urandom_range(0, 31);
        //     test_load_instruction(rand_insn, rand_inp1, rand_inp2, rand_dst);
        // end

        // Finish the simulation
        $finish;
    end

endmodule
