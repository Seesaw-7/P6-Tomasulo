`timescale 1ns/100ps

`include "sys_defs.svh"
`include "issue_unit.svh"

module issue_unit (
    // control signals
    input logic clk,
    input logic reset,
    
    // data
    input logic [3:0] insn_ready, // from RS
    input logic [3:0][`ROB_TAG_LEN-1:0] ROB_tag, // TODO: delete in m3

    // output control signals
    output logic [3:0] issue_signals, // to each RS

    // output data
    output logic [`ROB_TAG_LEN-1:0] ROB_tag_out, // TODO: delete in m3
    output logic select_flag, // to CDB 
    output FUNC_UNIT select_signal // to CDB as select, to RS as wakeup 
);

    logic [10:0][4:0] fu_cycles_curr;
    logic [10:0][4:0] fu_cycles_next;
    logic [10:0][`ROB_TAG_LEN-1:0] ROB_tag_reg_curr;
    logic [10:0][`ROB_TAG_LEN-1:0] ROB_tag_next;


    always_ff @(posedge clk) begin
        if (reset) begin
            fu_cycles_curr <= 0; // TODO： check 2d array reset
            ROB_tag_reg_curr <= 0;
        end else begin
            fu_cycles_curr <= fu_cycles_next;
            ROB_tag_reg_curr <= ROB_tag_next;
        end
    end


    // update CDB selection based on fu_cycles_curr
    always_comb begin
        if (reset) begin
            select_flag <= 0;
            select_signal <= FU_LSU;
        end else begin
            select_flag = 0;
            for (int i = 0; i < 11; i++) begin
                if (fu_cycles_curr[i] > 0) begin
                    if (fu_cycles_curr[i] == 1) begin
                        ROB_tag_out = ROB_tag_reg_curr[i];
                        select_flag = 1;
                        if (i == 0)
                            select_signal = FU_LSU;
                        else if (0 < i && i <= 8)
                            select_signal = FU_MULT;
                        else if (i == 9)
                            select_signal = FU_BTU;
                        else
                            select_signal = FU_ALU;
                        break;
                    end
                end
            end  
        end
    end


    // Whether to issue
    // update internal countings (fu_cycles_next & ROB_tag_next) and issue signal 
    always_comb begin
        for (int i = 0; i < 11; i++) begin 
            
            // logic [6:0] delay,
            // logic [5:0] higher_priority_index;

            // if (i == 0) begin
            //     delay = `LS_LATE;
            //     higher_priority_index = 0;
            // end
            // else if (0 < i && i <= 8) begin
            //     delay = `MULT_LATE;
            //     higher_priority_index= 1;
            // end
            // else if (i == 9) begin
            //     delay = `BTU_LATE;
            //     higher_priority_index = 9;
            // end
            // else begin
            //     delay = `ALU_LATE;
            //     higher_priority_index = 10;
            // end

            // Load/Store Unit
            if (i == 0) begin 

                logic issue_flag1, issue_flag2;

                // all the other FUs are not previously scheduled to use CDB at the same time with this one   issue_flag1 = 1;
                for (int j = 0; j < 11; j++) begin
                    if (fu_cycles_curr[j] == 1 + `LS_LATE) begin
                        issue_flag1 = 0;
                        break;
                    end
                end
                
                // all the other higher priority FUs are not scheduled in this forloop to use the CDB
                issue_flag2 = 1; 
                for (int j = 0; j < 0; j++) begin
                    if (fu_cycles_next[j] == `LS_LATE) begin
                        issue_flag2 = 0;
                        break;
                    end
                end
                
                if (insn_ready[FU_LSU] 
                    && (fu_cycles_curr[i] == 0 || fu_cycles_curr[i] == 1) 
                    && issue_flag1
                    && issue_flag2) 
                begin
                    issue_signals[FU_LSU] = 1;
                    fu_cycles_next[i] = `LS_LATE;
                    ROB_tag_next[i] = ROB_tag[FU_LSU];
                end else begin
                    issue_signals[FU_LSU] = 0;
                    fu_cycles_next[i] = fu_cycles_curr[i] > 0 ? fu_cycles_curr[i]-1 : 0;
                    ROB_tag_next[i] = ROB_tag_next[i];
                end
            end


            // Multiplier
            else if (0 < i && i <= 8) begin

                logic issue_flag1, issue_flag2;

                // all the other FUs are not previously scheduled to use CDB at the same time with this one
                issue_flag1 = 1;
                for (int j = 0; j < 11; j++) begin
                    if (fu_cycles_curr[j] == 1 + `MULT_LATE) begin
                        issue_flag1 = 0;
                        break;
                    end
                end
                
                // all the other higher priority FUs are not scheduled in this forloop to use the CDB
                issue_flag2 = 1; 
                for (int j = 0; j < 1; j++) begin
                    if (fu_cycles_next[j] == `MULT_LATE) begin
                        issue_flag2 = 0;
                        break;
                    end
                end
                
                if (insn_ready[FU_MULT] 
                    && (fu_cycles_curr[i] == 0 || fu_cycles_curr[i] == 1) 
                    && issue_flag1
                    && issue_flag2) 
                begin
                    issue_signals[FU_MULT] = 1;
                    fu_cycles_next[i] = `MULT_LATE;
                    ROB_tag_next[i] = ROB_tag[FU_MULT];
                end else begin
                    issue_signals[FU_MULT] = 0;
                    fu_cycles_next[i] = fu_cycles_curr[i] > 0 ? fu_cycles_curr[i]-1 : 0;
                    ROB_tag_next[i] = ROB_tag_next[i];
                end                
            end


            // Branch Unit
            else if (i == 9) begin
                logic issue_flag1, issue_flag2;

                // all the other FUs are not previously scheduled to use CDB at the same time with this one
                issue_flag1 = 1;
                for (int j = 0; j < 11; j++) begin
                    if (fu_cycles_curr[j] == 1 + `BTU_LATE) begin
                        issue_flag1 = 0;
                        break;
                    end
                end
                
                // all the other higher priority FUs are not scheduled in this forloop to use the CDB
                issue_flag2 = 1; 
                for (int j = 0; j < 9; j++) begin
                    if (fu_cycles_next[j] == `BTU_LATE) begin
                        issue_flag2 = 0;
                        break;
                    end
                end
                
                if (insn_ready[FU_BTU] 
                    && (fu_cycles_curr[i] == 0 || fu_cycles_curr[i] == 1) 
                    && issue_flag1
                    && issue_flag2) 
                begin
                    issue_signals[FU_BTU] = 1;
                    fu_cycles_next[i] = `BTU_LATE;
                    ROB_tag_next[i] = ROB_tag[FU_BTU];
                end else begin
                    issue_signals[FU_BTU] = 0;
                    fu_cycles_next[i] = fu_cycles_curr[i] > 0 ? fu_cycles_curr[i]-1 : 0;
                    ROB_tag_next[i] = ROB_tag_next[i];
                end                
            end


            // ALU
            else begin
                logic issue_flag1, issue_flag2;

                // all the other FUs are not previously scheduled to use CDB at the same time with this one
                issue_flag1 = 1;
                for (int j = 0; j < 11; j++) begin
                    if (fu_cycles_curr[j] == 1 + `ALU_LATE) begin
                        issue_flag1 = 0;
                        break;
                    end
                end
                
                // all the other higher priority FUs are not scheduled in this forloop to use the CDB
                issue_flag2 = 1; 
                for (int j = 0; j < 10; j++) begin
                    if (fu_cycles_next[j] == `ALU_LATE) begin
                        issue_flag2 = 0;
                        break;
                    end
                end
                
                if (insn_ready[FU_ALU] 
                    && (fu_cycles_curr[i] == 0 || fu_cycles_curr[i] == 1) 
                    && issue_flag1
                    && issue_flag2) 
                begin
                    issue_signals[FU_ALU] = 1;
                    fu_cycles_next[i] = `ALU_LATE;
                    ROB_tag_next[i] = ROB_tag[FU_ALU];
                end else begin
                    issue_signals[FU_ALU] = 0;
                    fu_cycles_next[i] = fu_cycles_curr[i] > 0 ? fu_cycles_curr[i]-1 : 0;
                    ROB_tag_next[i] = ROB_tag_next[i];
                end                
            end
        end
    end

endmodule
