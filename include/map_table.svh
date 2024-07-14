`ifndef __MAP_TABLE_SVH__
`define __MAP_TABLE_SVH__

`include "sys_defs.svh"

typedef struct packed {
    logic [1:0] data_stat; // data status: 00 = in regfile, 10 = in ROB (not ready), 11 = in ROB (ready)
    logic [`REG_ADDR_LEN-1:0] reg_addr; // register address
    logic [`ROB_TAG_LEN-1:0] rob_tag; // ROB entry
} RENAMED_REG;

typedef struct packed {
    RENAMED_REG src1;
    RENAMED_REG src2;
    logic [`REG_ADDR_LEN-1:0] dest;
    logic [`ROB_TAG_LEN-1:0] rob_tag;
} RENAMED_PACK;

typedef struct packed {
    logic [`ROB_TAG_LEN-1:0] rob_tag;
    logic ready_in_rob;
} MAP_ENTRY;

`endif
