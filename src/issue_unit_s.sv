`timescale 1ns/1ps

module issue_unit (
    input logic clk,
    input logic reset,

    // Inputs from reservation stations
    input logic [4:0] instr_ready,          // 每个功能单元的指令准备状态 


    // Select signal and flag
    output logic select_flag,
    output logic [2:0] select_signal
);

    // 内部信号和逻辑
    logic [4:0] fu_busy;      // 功能单元的忙碌状态
    logic [4:0] [3:0] fu_cycles;    // 功能单元的剩余计算周期 (-1表示未运行)
    logic [4:0] ready_fu;     // 当前准备好的功能单元
    logic [2:0] rand_select;  // 随机选择的功能单元

    // 初始化
    initial begin
        fu_busy = 5'b00000;
        fu_cycles = {5{4'b1111}};  // -1表示未运行
        select_flag = 0;
        select_signal = 3'b000;
    end

    // 随机数生成器
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            rand_select <= 3'b000;
        end else begin
            rand_select <= $random % 5;
        end
    end

    // 功能单元的状态更新
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            fu_busy <= 5'b00000;
            fu_cycles <= {5{4'b1111}};  // -1表示未运行
        end else begin
            for (int i = 0; i < 5; i++) begin
                if (fu_busy[i] && fu_cycles[i] > 0) begin
                    fu_cycles[i] <= fu_cycles[i] - 1;
                    if (fu_cycles[i] == 1) begin
                        fu_busy[i] <= 0;
                        fu_cycles[i] <= 4'b1111;  // 重置为-1
                    end
                end
            end
        end
    end

    // 指令发射逻辑
    always_comb begin
        ready_fu = 5'b00000;
        for (int i = 0; i < 5; i++) begin
            if (instr_ready[i] && !fu_busy[i]) begin
                ready_fu[i] = 1;
            end
        end
    end

    // 随机选择准备好的功能单元
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            select_flag <= 0;
            select_signal <= 3'b000;
        end else begin
            if (ready_fu != 5'b00000) begin
                select_signal <= rand_select;
                select_flag <= 1; 

                // 更新功能单元的忙碌状态和计算周期
                case (rand_select)
                    3'b000: fu_cycles[rand_select] <= 1;  // Integer unit
                    3'b001: fu_cycles[rand_select] <= 8;  // Mult unit 1
                    3'b010: fu_cycles[rand_select] <= 8;  // Mult unit 2
                    3'b011: fu_cycles[rand_select] <= 1;  // Branching unit
                    3'b100: fu_cycles[rand_select] <= 4;  // Load/Store unit (假设4周期延迟)
                endcase
                fu_busy[rand_select] <= 1;
            end else begin
                select_flag <= 0;
            end
        end
    end

endmodule
