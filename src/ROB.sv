`include "ROB.svh"
`include "sys_defs.svh"

`timescale 1ns / 1ps

module ROB(
    input logic clk,
    input logic reset,
    input DECODED_INST inst_from_dispatcher,
    input ARCH_REG arch_reg,
    input PHYS_REG phys_reg, 
    input logic cdb_to_rob,
    input logic [`ROB_ADDR_LEN-1:0] rob_tag_from_cdb,
    input logic [`XLEN-1:0] cdb_result,
    //input logic [`XLEN-1:0] cdb_result,
    input logic flush,
    output logic commit, //wb_to_reg
    output logic [`ARCH_REG_ADDR_LEN-1:0] wb_arch_reg_addr, 
    output logic [`XLEN-1:0] wb_data,
    output logic [`ROB_ADDR_LEN-1:0] rob_tag_inst_from_dispatcher
    );
    
    ROB_ENTRY rob [`ROB_SIZE-1:0];
    logic [`ROB_ADDR_LEN-1:0] head;
    logic [`ROB_ADDR_LEN-1:0] tail;
    
    logic commit_ready;
    always_comb begin
        commit_ready = rob[head].valid && rob[head].ready;
    end
    
    logic [`ROB_ADDR_LEN-1:0] next_tail;
    always_comb begin
        next_tail = tail;
        if (inst_from_dispatcher.valid) begin
            rob[next_tail].valid = 1;
            rob[next_tail].ready = 0;
            rob[next_tail].inst_rob = inst_from_dispatcher;
            rob[next_tail].arch_reg = arch_reg;
            rob[next_tail].phys_reg = phys_reg;
            next_tail = (tail + 1) % ROB_SIZE;
        end
    end
    
    always_comb begin
        if (cdb_to_rob && rob[rob_tag_from_cdb].valid) begin
            rob[rob_tag_from_cdb].ready = 1;
            rob[rob_tag_from_cdb].result = cdb_result;
        end
    end
    
    always_ff @(posedge clk) begin
        if (reset || flush) begin
            head <= 0;
            tail <= 0;
            for (int i=0; i<ROB_SIZE; i++) begin
                rob[i].valid <= 0;
                rob[i].ready <= 0; 
            end
        end
        else begin
            tail <= next_tail;
            rob_tag_inst_from_dispatcher <= tail;
            
            if (commit_ready) begin
                wb_arch_reg_addr <= rob[head].arch_reg.dest;
                wb_data <= rob[head].result;
                commit <= 1;
                rob[head].valid <= 0;
                head <= (head + 1) % ROB_SIZE;
            end    
            else begin
                commit <= 0;
            end
            
        end
endmodule


