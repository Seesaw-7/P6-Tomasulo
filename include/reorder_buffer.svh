`ifndef __REORDER_BUFFER_VH__
`define __REORDER_BUFFER_VH__

`include "sys_defs.svh"

typedef struct packed {
    logic valid;
    logic ready;
    logic mispredict;
    logic unsigned [`REG_ADDR_LEN-1:0] wb_reg;
    logic [`XLEN-1:0] wb_data;
    logic [`XLEN-1:0] curr_pc;
    logic [`XLEN-1:0] target_pc;
} ROB_ENTRY;

`endif
