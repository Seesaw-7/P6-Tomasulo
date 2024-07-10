`ifndef __REORDER_BUFFER_SVH__
`define __REORDER_BUFFER_SVH__

// `define XLEN 32

`define REG_LEN 32
`define REG_ADDR_LEN 5

// `define ROB_SIZE 64
// `define ROB_TAG_LEN 6

typedef struct packed {
    logic valid;
    logic ready;
    logic mispredict;
    logic unsigned [`REG_ADDR_LEN-1:0] wb_reg;
    logic [`XLEN-1:0] wb_data;
} ROB_ENTRY;

`endif
