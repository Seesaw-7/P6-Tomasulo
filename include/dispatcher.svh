`ifndef __DECODER_SVH__
`define __DECODER_SVH__

`include "sys_defs.svh"

typedef struct packed {
    FUNC_UNIT fu;
    ALU_FUNC func;
    logic unsigned [`ROB_TAG_LEN-1:0] tag_dest;
    logic unsigned [`ROB_TAG_LEN-1:0] tag_src1;
    logic unsigned [`ROB_TAG_LEN-1:0] tag_src2;
    logic unsigned ready_src1;
    logic unsigned [`XLEN-1] value_src1;
    logic unsigned ready_src2;
    logic unsigned [`XLEN-1] value_src2;
    logic [`XLEN-1:0] imm;
    logic [`XLEN-1:0] pc;
} INST_RS;

typedef struct packed {
   logic unsigned [`REG_ADDR_LEN-1:0] reg; // architectural reg for dest
   logic [`XLEN-1:0] inst_npc; // current pc for this instruction
} INST_ROB;

`endif
