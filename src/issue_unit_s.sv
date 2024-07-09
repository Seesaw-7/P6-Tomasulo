`timescale 1ns/1ps

module issue_unit (
    input logic clk,
    input logic reset,
    
    input logic [3:0] instr_ready,
    input logic [3:0][`ROB_TAG_LEN-1:0] ROB_tag,

    output logic [3:0] issue_signal,

    output logic [`ROB_TAG_LEN-1:0] ROB_tag_out,
    output logic select_flag,
    output logic [1:0] select_signal
);

    logic [10:0][3:0] fu_cycles;
    logic [3:0] ready_fu;
    logic [10:0][`ROB_TAG_LEN-1:0] ROB_tag_reg;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            fu_cycles <= '{default: -1};
            ready_fu <= 4'b1111;
            select_flag <= 0;
            select_signal <= 2'b00;
            issue_signal <= 4'b0000;
        end else begin
            select_flag <= 0;  // Default to 0 each clock cycle
            for (int i = 0; i < 11; i++) begin
                if (fu_cycles[i] > 0) begin
                    if (fu_cycles[i] == 1) begin
                        ROB_tag_out <= ROB_tag_reg[i];
                        if (i > 2) i = 3;
                        ready_fu[i] <= 1;
                        fu_cycles[i] <= -1;
                        select_flag <= 1;
                        select_signal <= i;
                    end
                    fu_cycles[i] <= fu_cycles[i] - 1;
                end
            end
        end
    end

    always_comb begin
        logic [3:0] issue_signal_temp;
        issue_signal_temp = 4'b0000;
        for (int i = 0; i < 4; i++) begin
            if (instr_ready[i] && ready_fu[i]) begin
                logic [3:0] temp_cycle = 0;
                logic issue_flag = 1;
                case (i)
                    0: temp_cycle = 1;  // Integer unit
                    1: temp_cycle = 1;  // Branching unit
                    2: temp_cycle = 4;  // load/store
                    3: temp_cycle = 8;  // Multiply
                endcase
                for (int j = 0; j < 11; j++) begin
                    if (temp_cycle == fu_cycles[j]) begin
                        issue_flag = 0;
                        break;
                    end
                end
                if (issue_flag) begin
                    issue_signal_temp[i] = 1;
                    if (i < 3) begin
                        ready_fu[i] = 0;
                        fu_cycles[i] = temp_cycle;
                        ROB_tag_reg[i] = ROB_tag[i];
                    end else begin
                        for (int j = 3; j < 11; j++) begin
                            if (fu_cycles[j] == -1) begin
                                fu_cycles[j] = temp_cycle;
                                ROB_tag_reg[j] = ROB_tag[3];
                                break;
                            end
                        end
                    end
                    break;
                end
            end
        end
        issue_signal = issue_signal_temp;
    end

endmodule
