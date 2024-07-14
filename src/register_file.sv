/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  register_file.v                                     //
//                                                                     //
//  Description :  This module creates the Regfile read before FU calculation and  // 
//                 written at ROB （WB） .                          //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

`include "sys_defs.svh"

module register_file(
        input   [4:0] wr_idx,    // read/write index
        input  [`XLEN-1:0] wr_data,            // write data
        input         wr_en, clk, reset,

        output [`REG_NUM-1:0] [`XLEN-1:0] registers
          
      );
  
  logic    [`REG_NUM-1:0] [`XLEN-1:0] registers;   // 32, 64-bit Registers
  logic    [`REG_NUM-1:0] [`XLEN-1:0] registers_next;   // 32, 64-bit Registers

  always_ff @(posedge clk) begin
    if (reset) begin
      registers <= 0;
    end else begin
      registers <= registers_next;
    end
  end

  always_comb begin
    registers_next = registers;
    if (wr_en) begin
      registers_next[wr_idx] = wr_data;
    end
  end

endmodule
