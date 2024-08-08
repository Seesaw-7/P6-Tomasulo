`timescale 1ns/100ps
`define HALF_CYCLE 25

`include "decoder.svh"

module test_decoder();
    logic clk;
    logic in_valid, flush, csr_op, halt, illegal;
    INST inst;
    logic [`XLEN-1:0] in_pc;
    DECODED_PACK decoded_pack;

    decoder my_decoder (
        .in_valid (in_valid),
        .inst (inst),
        .flush (flush),
        .in_pc (in_pc),
        .csr_op (csr_op),
        .halt (halt),
        .illegal (illegal),
        .decoded_pack (decoded_pack)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever begin
            #`HALF_CYCLE clk = ~clk;
        end
    end

    task wait_until_done;
        @(negedge clk);
    endtask

    // Task to initialize inputs
    task initialize_inputs();
        in_valid = 0;
        flush = 0;
        inst = 0;
        in_pc = 0;
        csr_op = 0;
        halt = 0;
        illegal = 0;
    endtask

    // Task to apply a single instruction and check outputs
    task test_instruction(INST i);
        begin
            inst = i;
            in_valid = 1;
            wait_until_done();
            in_valid = 0;
            wait_until_done();
        end
    endtask

    initial begin
        // Initialize inputs
        initialize_inputs();

        // Test LUI instruction
        // todo: change this
        inst = 32'h12345037; // LUI x1, 0x12345
        test_instruction(inst);

        // Test halt
        halt = 1;
        wait_until_done();
        $finish;
    end

endmodule
