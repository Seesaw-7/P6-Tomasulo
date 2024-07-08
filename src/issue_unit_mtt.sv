`timescale 1ns/1ps

module issue_unit (
    // pure combinational?
    input logic clk,
    input logic reset,
    
    // Inputs from reservation stations
    input logic [4:0] instr_ready,          // 每个功能单元的指令准备状态 


    // Select signal and flag
    output logic select_flag,
    output logic [2:0] select_signal,

    // Issue signal and flag
    output logic issue_flag,
    output logic [2:0] issue_signal
);

    // 内部信号和逻辑
    logic [4:0] fu_busy;      // 功能单元的忙碌状态
    logic [4:0] [3:0] fu_cycles;    // 功能单元的剩余计算周期(可以改成0)
    logic [4:0] ready_fu;     // 当前准备好的功能单元
    logic [2:0] rand_select;  // 随机选择的功能单元
    logic [2:0] temp_cycle;   // 随机选择的功能单元的剩余计算周期


    // 初始化
    initial begin
        fu_busy = 5'b00000;
        fu_cycles = {5{4'b0000}};  // 0表示未运行
        ready_fu = 5'b00000;
        select_flag = 0;
        select_signal = 3'b000;
        issue_flag = 0;
        issue_signal = 3'b000;
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
            fu_cycles <= {5{4'b0000}};
            ready_fu <= 5'b00000;
            select_flag <= 0;
            select_signal <= 3'b000;
            issue_flag <= 0;
            issue_signal <= 3'b000;
        end else begin
            for (int i = 0; i < 5; i++) begin
                if (fu_busy[i] && fu_cycles[i] > 0) begin
                    fu_cycles[i] <= fu_cycles[i] - 1;
                    if (fu_cycles[i] == 1) begin
                        fu_busy[i] <= 0;
                        select_flag <= 1;
                        select_signal <= i;
                    end
                end
            end
        end
    end

    // 指令发射逻辑
    always_comb begin
        // ready_fu = 5'b00000;
        for (int i = 0; i < 5; i++) begin
            if (instr_ready[rand_select] && !fu_busy[rand_select]) begin
                case (rand_select)
                    3'b000: temp_cycle = 1;  // Integer unit
                    3'b001: temp_cycle = 8;  // Mult unit 1
                    3'b010: temp_cycle = 8;  // Mult unit 2
                    3'b011: temp_cycle = 1;  // Branching unit
                    3'b100: temp_cycle = 4;  // Load/Store unit (假设4周期延迟)
                endcase
                ready_fu[i] = 1;
                for (int j = 0; j < 5; i++) begin
                    if (fu_cycles[j] == temp_cycle) begin
                        ready_fu[i] = 0;
                    end
                end
                if (ready_fu[i] == 1) begin
                    fu_cycles[rand_select] = temp_cycle;
                    fu_busy[rand_select] = 1;
                    issue_flag = 1;
                    issue_signal = i;
                    break;
                end
            end
            rand_select = (rand_select + 1) % 5;
        end
    end

    // // 随机选择准备好的功能单元
    // always_ff @(posedge clk or posedge reset) begin
    //     if (reset) begin
    //         select_flag <= 0;
    //         select_signal <= 3'b000;
    //     end else begin
    //         if (ready_fu != 5'b00000) begin
    //             select_signal <= rand_select;
    //             select_flag <= 1; 

    //             // 更新功能单元的忙碌状态和计算周期
    //             case (rand_select)
    //                 3'b000: fu_cycles[rand_select] <= 1;  // Integer unit
    //                 3'b001: fu_cycles[rand_select] <= 8;  // Mult unit 1
    //                 3'b010: fu_cycles[rand_select] <= 8;  // Mult unit 2
    //                 3'b011: fu_cycles[rand_select] <= 1;  // Branching unit
    //                 3'b100: fu_cycles[rand_select] <= 4;  // Load/Store unit (假设4周期延迟)
    //             endcase
    //             fu_busy[rand_select] <= 1;
    //         end else begin
    //             select_flag <= 0;
    //         end
    //     end
    // end

endmodule
