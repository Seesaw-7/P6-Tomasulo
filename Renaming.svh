`ifndef _RENAMING_
`define _RENAMING_

`define REG_LEN 32
`define REG_WIDTH 32
`define REG_ADDR_LEN 5

typedef struct packed {
    logic unsigned [REG_ADDR_LEN:0] arch_reg_src1;
    logic unsigned [REG_ADDR_LEN:0] arch_reg_src2;
    logic unsigned [REG_ADDR_LEN:0] arch_reg_dest;
    logic unsigned [REG_ADDR_LEN:0] phys_reg_src1;
    logic unsigned [REG_ADDR_LEN:0] phys_reg_src2;
    logic unsigned [REG_ADDR_LEN:0] phys_reg_dest;
    logic unsigned [REG_ADDR_LEN:0] phys_reg_dest_old;
} INST;

`endif _RENAMING_