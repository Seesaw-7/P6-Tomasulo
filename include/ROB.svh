`ifndef _ROB_
`define _ROB_

`define ROB_SIZE 64
`define ROB_ADDR_LEN 6
`define XLEN 32
`define ARCH_REG_ADDR_LEN 5

typedef struct packed {
    logic valid;
    logic ready;
    logic DECODED_INST inst_rob;
    logic ARCH_REG arch_reg;
    logic PHYS_REG phys_reg;
    logic [`XLEN-1:0] result;
} ROB_ENTRY;

typedef struct packed {
	logic ARCH_REG arch_reg;
	logic PHYS_REG phys_reg;
	logic INST inst;
} DECODED_INST;

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

`endif // _ROB_