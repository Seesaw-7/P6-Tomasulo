/////////////////////////////////////////////////////////////////////////
// Module name : map_table.sv
// Description : This module implements the map table for register renaming in an out-of-order execution CPU. It supports reading the renamed map of architectural registers at the dispatch stage, updating the mapping when a new instruction is assigned, and returning the physical register when the instruction commits.
/////////////////////////////////////////////////////////////////////////
`timescale 1ns/100ps

`include "sys_defs.svh"
`include "map_table.svh"

module map_table(
    input clk,
    input reset,
    input ARCH_REG arch_reg,
    input assign_flag,
    input return_flag, 
    input ready_flag,
    input [`ROB_TAG_LEN-1:0] assign_rob_tag_reg,
    input [`REG_ADDR_LEN-1:0] reg_addr_from_rob, 
    input [`ROB_TAG_LEN-1:0] rob_tag_from_rob,
    input [`ROB_TAG_LEN-1:0] rob_tag_from_cdb,
    output RENAMED_PACK renamed_pack
);
    
    MAP_ENTRY map_table_curr [`REG_NUM-1:0];
    MAP_ENTRY map_table_next [`REG_NUM-1:0];
    
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i=0; i<`REG_NUM; i++) begin
                // if a map table entry doesn't have ROB tag stored, its rob_tag = {ROB_TAG_LEN{1'b1}}
                map_table_curr[i].rob_tag <= {`ROB_TAG_LEN{1'b1}};
                map_table_curr[i].ready_in_rob <= 1'b0;
            end
        end 
        else begin
            map_table_curr <= map_table_next;
        end 
    end
    
    // map table's update logic based on assign/return/ready
    always_comb begin
        for (int i=0; i<`REG_NUM; i++) begin
            map_table_next[i] = map_table_curr[i];
        end

        if (assign_flag) begin
            if (arch_reg.dest != {`REG_ADDR_LEN{1'b0}}) begin 
                map_table_next[arch_reg.dest].rob_tag = assign_rob_tag_reg;
                map_table_next[arch_reg.dest].ready_in_rob = 1'b0;
            end
        end

        if (return_flag) begin
            if (map_table_curr[reg_addr_from_rob].rob_tag == rob_tag_from_rob) begin
                map_table_next[reg_addr_from_rob].rob_tag = {`ROB_TAG_LEN{1'b1}};
                map_table_next[reg_addr_from_rob].ready_in_rob = 1'b0;
            end
        end

        if (ready_flag) begin
            for (int i=1; i<`REG_NUM; i++) begin
                if (map_table_curr[i].rob_tag == rob_tag_from_cdb) begin
                    map_table_next[i].ready_in_rob = 1'b1;
                end
            end
        end
    end
    
    // output renamed_pack logic 
    always_comb begin 
    
        // src1
        if (map_table_curr[arch_reg.src1].rob_tag == {`ROB_TAG_LEN{1'b1}}) begin
            renamed_pack.src1.data_stat = 2'b00;
            renamed_pack.src1.reg_addr = arch_reg.src1;
            renamed_pack.src1.rob_tag = {`ROB_TAG_LEN{1'b1}};
        end
        else begin
            if (arch_reg.src1 == '0) begin
                renamed_pack.src1.data_stat = 2'b00;
                renamed_pack.src1.reg_addr = arch_reg.src1;
                renamed_pack.src1.rob_tag = {`ROB_TAG_LEN{1'b1}};
            end
            else begin
                if (map_table_curr[arch_reg.src1].ready_in_rob == 1'b0) begin
                    renamed_pack.src1.data_stat = 2'b10;
                    renamed_pack.src1.reg_addr = arch_reg.src1;
                    renamed_pack.src1.rob_tag = map_table_curr[arch_reg.src1].rob_tag;    
                end
                else begin
                    renamed_pack.src1.data_stat = 2'b11;
                    renamed_pack.src1.reg_addr = arch_reg.src1;
                    renamed_pack.src1.rob_tag = map_table_curr[arch_reg.src1].rob_tag;
                end
            end               
        end
        
        //src2
        if (map_table_curr[arch_reg.src2].rob_tag == {`ROB_TAG_LEN{1'b1}}) begin
            renamed_pack.src2.data_stat = 2'b00;
            renamed_pack.src2.reg_addr = arch_reg.src2;
            renamed_pack.src2.rob_tag = {`ROB_TAG_LEN{1'b1}};
        end
        else begin
            if (arch_reg.src1 == '0) begin
                renamed_pack.src1.data_stat = 2'b00;
                renamed_pack.src1.reg_addr = arch_reg.src1;
                renamed_pack.src1.rob_tag = {`ROB_TAG_LEN{1'b1}};
            end
            else begin 
                if (map_table_curr[arch_reg.src2].ready_in_rob == 1'b0) begin
                    renamed_pack.src2.data_stat = 2'b10;
                    renamed_pack.src2.reg_addr = arch_reg.src2;
                    renamed_pack.src2.rob_tag = map_table_curr[arch_reg.src2].rob_tag;    
                end
                else begin
                    renamed_pack.src2.data_stat = 2'b11;
                    renamed_pack.src2.reg_addr = arch_reg.src2;
                    renamed_pack.src2.rob_tag = map_table_curr[arch_reg.src2].rob_tag;
                end
            end                
        end
        
        renamed_pack.dest = arch_reg.dest;
        renamed_pack.rob_tag = assign_rob_tag_reg;
        
    end
    
endmodule
