`ifndef _RENAMING_
`define _RENAMING_

typedef struct packed {
    logic unsigned [`REG_ADDR_LEN-1:0] src1;
    logic unsigned [`REG_ADDR_LEN-1:0] src2;
    logic unsigned [`REG_ADDR_LEN-1:0] dest;
} ARCH_REG;

typedef struct packed {
    logic unsigned [`REG_ADDR_LEN-1:0] src1;
    logic unsigned [`REG_ADDR_LEN-1:0] src2;
    logic unsigned [`REG_ADDR_LEN-1:0] dest;
    logic unsigned [`REG_ADDR_LEN-1:0] dest_old;
} PHYS_REG;

`endif // _RENAMING_
