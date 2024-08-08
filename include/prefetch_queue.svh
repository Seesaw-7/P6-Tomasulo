`ifndef __PREFETCH_QUEUE_SVH__
`define __PREFETCH_QUEUE_SVH__

`include "sys_defs.svh"

`define PF_ENTRY_NUM 8

typedef struct packed {
	logic valid; // If low, the data in this struct is garbage
    INST  inst;  // fetched instruction out
	logic [`XLEN-1:0] NPC; // PC + 4
	logic [`XLEN-1:0] PC;  // PC 
} PREFETCH_PACKET;

typedef struct packed {
	INST inst;
	logic [`XLEN-1:0] PC;  // PC 
} PREFETCH_ENTRY;

typedef struct packed {
	PREFETCH_ENTRY [`PF_ENTRY_NUM-1:0] entries;
	logic unsigned [2:0] num;
    logic [`XLEN-1:0] PC;
} PREFETCH_QUEUE;

`endif
