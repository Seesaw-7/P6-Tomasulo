`ifndef _MAP_
`define _MAP_

`define REG_LEN 32
`define REG_WIDTH 32
`define REG_ADDR_LEN 5

`define ROB_SIZE 64
`define ROB_ADDR_LEN 6

typedef struct packed {
    logic unsigned [`REG_ADDR_LEN-1:0] src1;
    logic unsigned [`REG_ADDR_LEN-1:0] src2;
    logic unsigned [`REG_ADDR_LEN-1:0] dest;
} ARCH_REG;

typedef struct packed {
    logic [1:0] data_stat; // data status: 00 = in regfile, 10 = in ROB (not ready), 11 = in ROB (ready)
    logic [`REG_ADDR_LEN-1:0] reg_addr; // register address
    logic [`ROB_ADDR_LEN-1:0] rob_tag; // ROB entry
} RENAMED_REG;

typedef struct packed {
    RENAMED_REG src1;
    RENAMED_REG src2;
} RENAMED_SRC;

typedef struct packed {
    logic [`ROB_ADDR_LEN-1:0] rob_tag;
    logic ready_in_rob;
} MAP_ENTRY

`endif // _MAP_