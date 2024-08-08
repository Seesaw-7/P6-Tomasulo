`ifndef __DISPATCHER_SVH__
`define __DISPATCHER_SVH__

`include "sys_defs.svh"

typedef struct packed {
    FUNC_UNIT fu;
    INSN_FUNC func;
    logic unsigned [`ROB_TAG_LEN-1:0] insn_tag;
    logic unsigned [`ROB_TAG_LEN-1:0] tag_dest;
    logic unsigned [`ROB_TAG_LEN-1:0] tag_src1;
    logic unsigned [`ROB_TAG_LEN-1:0] tag_src2;
    logic unsigned ready_src1;
    logic unsigned [`XLEN-1:0] value_src1;
    logic unsigned ready_src2;
    logic unsigned [`XLEN-1:0] value_src2;
    logic [`XLEN-1:0] imm;
    logic [`XLEN-1:0] pc;
    logic [`XLEN-1:0] npc;
    logic [2:0] func3;
} INST_RS;

typedef struct packed {
   logic unsigned [`REG_ADDR_LEN-1:0] register; // architectural reg for dest
   logic [`XLEN-1:0] inst_pc; // current pc for this instruction
   logic [`XLEN-1:0] inst_npc; // next pc for this instruction
   INSN_FUNC func;
   logic branch;
   logic halt;
} INST_ROB;

`endif