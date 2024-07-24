`ifndef __BRANCH_PREDICTOR_SVH__
`define __BRANCH_PREDICTOR_SVH__

`include "sys_defs.svh"

`define BPB_SIZE 256 
`define BHB_SIZE 128

typedef struct packed {
    logic [`XLEN:0] tag;
    logic [`XLEN:0] target_pc;
} BHB_ENTRY;

`endif

