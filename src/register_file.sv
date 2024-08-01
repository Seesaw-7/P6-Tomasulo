/////////////////////////////////////////////////////////////////////////
// Module name : register_file.sv
// Description : This module implements the register file. It supports reading at the dispatch stage and writing when the ROB commits.
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

`include "sys_defs.svh"

module register_file(
    input  [4:0] reg_addr,      // read/write index
    input  [`XLEN-1:0] wr_data,     // write data
    input  wr_en, clk, reset,

    output logic [`REG_NUM-1:0] [`XLEN-1:0] regfile 
);

    logic [`REG_NUM-1:0] [`XLEN-1:0] regfile_next;

    // sequentially update register file
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            regfile <= '0;   // reset all registers to 0
        end else begin
            regfile <= regfile_next;
        end
    end

    // combinational logic for writing to register file
    always_comb begin
        regfile_next = regfile;
        if (wr_en) begin
            if (reg_addr == 5'b0)
                regfile_next[reg_addr] = `XLEN'b0;  // reg0 is hardwired to 0
            else
                regfile_next[reg_addr] = wr_data;
        end
    end

endmodule

