`timescale 1ns/100ps

module tb_issue_unit;

    parameter CLK_PERIOD = 10;

    // Inputs
    logic clk;
    logic reset;
    logic [3:0] insn_ready;
    logic [3:0][`ROB_TAG_LEN-1:0] ROB_tag;

    // Outputs
    logic [3:0] issue_signals;
    logic [`ROB_TAG_LEN-1:0] ROB_tag_out;
    logic select_flag;
    logic [1:0] select_signal;

    issue_unit dut (
        .clk(clk),
        .reset(reset),
        .insn_ready(insn_ready),
        .ROB_tag(ROB_tag),
        .issue_signals(issue_signals),
        .ROB_tag_out(ROB_tag_out),
        .select_flag(select_flag),
        .select_signal(select_signal)
    );

    always begin
        clk = 0;
        #(CLK_PERIOD / 2);
        clk = 1;
        #(CLK_PERIOD / 2);
    end

    initial begin
        reset = 1;
        insn_ready = 4'b0000;
        ROB_tag = '{default: 0};

        #(2 * CLK_PERIOD);
        reset = 0;

        // Test case 1: Issue instruction to Multiplier
        insn_ready = 4'b0010;
        ROB_tag[1] = 4'b0010;
        #(2 * CLK_PERIOD);

        // Test case 2: Issue instruction to Branch Unit
        insn_ready = 4'b0100;
        ROB_tag[2] = 4'b0011;
        #(2 * CLK_PERIOD);

        // Test case 3: Issue instruction to ALU
        insn_ready = 4'b1000;
        ROB_tag[3] = 4'b0100;
        #(2 * CLK_PERIOD);

        // Test case 4: Multiple instructions ready
        insn_ready = 4'b1111;
        ROB_tag = '{4'b0101, 4'b0110, 4'b0111, 4'b1000};
        #(2 * CLK_PERIOD);

        // Deassert all instructions ready
        insn_ready = 4'b0000;
        #(2 * CLK_PERIOD);

        // End simulation
        $finish;
    end

    // Monitor signals
    initial begin
        $monitor("Time: %0t, insn_ready: %b, issue_signals: %b, select_flag: %b, select_signal: %b",
                 $time, insn_ready, issue_signals, select_flag, select_signal);
    end

endmodule
