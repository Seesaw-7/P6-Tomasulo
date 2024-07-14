`timescale 1ns/1ps

`include "sys_defs.svh"

// functional unit: integer unit, branching, load/store, mult

module issue_unit #(
    parameter int FU_NUM = 4
) (
    input logic clk,
    input logic reset,
    
    // Inputs from reservation stations
    input logic [3:0] instr_ready,          // 每个功能单元的指令准备状态 
    input logic [3:0][`ROB_TAG_LEN-1:0] in_ROB_tag, 

    // Select signal and flag
    output logic select_flag,
    output logic [1:0] select_signal,

    // Issue signal (since we use one-hot encoded issue_signal, we don't need flag)
    output logic [3:0] issue_signal

    // ROB tag to 
    output logic [`ROB_TAG_LEN-1:0] out_ROB_tag, 
);

    // 内部信号和逻辑
    logic [10:0] [3:0] fu_cycles;    // 功能单元的剩余计算周期(可以改成0)
    // logic [10:0] ready_fu;     // 当前准备好的功能单元
    logic [3:0] rand_select;  // 随机选择的功能单元
    logic [3:0] temp_cycle;   // 随机选择的功能单元的剩余计算周期
    logic [3:0][`ROB_TAG_LEN-1:0] ROB_tag;
    logic [3:0] select_index;

    // 初始化 真的需要初始化吗
    function automatic void initialize_signals();
        begin
            fu_cycles = 10'b0;  // 0表示未运行
            // ready_fu = 10'b0;
            select_flag = 0;
            select_signal = 4'b0000;
            issue_flag = 0;
            issue_signal = 4'b0000;
            ROB_tag = 4{(ROB_TAG_LEN)'b0};
            select_index = 4'b1111;
        end
    endfunction

    // 调用初始化函数
    initial begin
        initialize_signals();
    end
    
    // 随机数生成器
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            rand_select <= 4'b0;
        end else begin
            rand_select <= $random % 11;
        end
    end

    // 功能单元的状态更新
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            initialize_signals();
        end else begin
            for (int i = 0; i < 10; i++) begin
                if (fu_cycles[i] > 0) begin
                    fu_cycles[i] <= fu_cycles[i] - 1;
                    if (fu_cycles[i] == 1) begin
                        out_ROB_tag <= ROB_tag[i]
                        select_index <= i;
                    end
                end
            end
        end
    end

    // 指令发射逻辑
    // select
    always_comb begin
        for (int i = 0; i < 10; i++) begin
            // select_flag and select_signal
            if (select_index != 4'b1111) begin
                if (select_index > 2) select_index = 3;
                select_flag = 1;
                select_signal = select_index;
                break;
            end
        end
    end

    // issue
    always_comb begin
        for (int i = 0; i < 10; i++) begin

            logic [1:0] rand_fu;
            if (rand_select > 2) begin
                rand_fu = 3;
            end
            else rand_fu = rand_select;

            if (instr_ready[rand_fu] && fu_cycles[rand_select] == 0) begin
                case (rand_fu)
                    2'b00: temp_cycle = 1;  // Integer unit
                    2'b01: temp_cycle = 1;  // Branching unit
                    2'b10: temp_cycle = 4;  // Load/Store unit (assuming 4 cycle latency)
                    2'b11: temp_cycle = 8;  // multiplier unit
                endcase
                issue_flag = 1;
                for (int j = 0; j < 11; j++) begin
                    if (fu_cycles[j] == temp_cycle) begin
                        issue_flag = 0;
                    end
                end
                if (issue_flag == 1) begin
                    fu_cycles[rand_select] = temp_cycle;
                    issue_signal = rand_fu;
                    ROB_tag[rand_select] = in_ROB_tag[rand_fu];
                    break;
                end
            end
            rand_select = (rand_select + 1) % 11;
        end
    end
endmodule
