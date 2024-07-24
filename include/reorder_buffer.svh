`ifndef __REORDER_BUFFER_SVH__
`define __REORDER_BUFFER_SVH__

`include "sys_defs.svh"

typedef struct packed {
    logic valid;
    logic ready;
    logic mispredict;
    logic unsigned [`REG_ADDR_LEN-1:0] wb_reg;
    logic [`XLEN-1:0] wb_data;
    logic [`XLEN-1:0] npc;
    logic [`XLEN-1:0] pc;
} ROB_ENTRY;

`endif
