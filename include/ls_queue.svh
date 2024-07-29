`ifndef __LS_QUEUE_SVH__
`define __LS_QUEUE_SVH__

`include "sys_defs.svh"
`include "dispatcher.svh"

`define LS_QUEUE_SIZE 8
`define LS_QUEUE_POINTER_LEN 3

typedef struct packed {
    logic valid; 
    logic ready; 
    logic read_write; // read:1 write:0
    INST_RS insn; 
} LS_QUEUE_ENTRY;

typedef struct packed {
    logic read_write; 
    INST_RS insn; 
} LS_UNIT_PACK;

`endif
