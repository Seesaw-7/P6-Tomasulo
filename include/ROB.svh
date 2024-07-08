`ifndef _ROB_
`define _ROB_

`define XLEN 32

`define REG_LEN 32
`define REG_ADDR_LEN 5

`define ROB_SIZE 64
`define ROB_TAG_LEN 6

typedef struct packed {
    logic valid;
    logic ready;
    logic [1:0] fun_code; // operation: 00 = wb to reg, 01 = branch
    logic unsigned [`REG_ADDR_LEN-1:0] wb_reg;
    logic [`XLEN-1:0] wb_data;
} ROB_ENTRY;

`endif // _ROB_
