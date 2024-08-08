`ifndef __REORDER_BUFFER_VH__
`define __REORDER_BUFFER_VH__

`include "sys_defs.svh"

typedef struct packed {
    logic valid;
    logic ready;
    logic br_jp;
    logic mispredict;
    logic unsigned [`REG_ADDR_LEN-1:0] wb_reg;
    logic [`XLEN-1:0] wb_data;
    logic [`XLEN-1:0] npc;
    logic [`XLEN-1:0] pc;
    logic halt;
    //logic [`XLEN-1:0] target_pc;
} ROB_ENTRY;

`endif
