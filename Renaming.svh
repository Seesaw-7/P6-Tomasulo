`ifndef _RENAMING_
`define _RENAMING_

`define REG_LEN 32
`define REG_WIDTH 32
`define REG_ADDR_LEN 5

typedef struct packed {
    logic unsigned [REG_ADDR_LEN:0] src1;
    logic unsigned [REG_ADDR_LEN:0] src2;
    logic unsigned [REG_ADDR_LEN:0] dest;
} ARCH_REG;

typedef struct packed {
    logic unsigned [REG_ADDR_LEN:0] src1;
    logic unsigned [REG_ADDR_LEN:0] src2;
    logic unsigned [REG_ADDR_LEN:0] dest;
    logic unsigned [REG_ADDR_LEN:0] dest_old;
} PHYS_REG;

`endif _RENAMING_