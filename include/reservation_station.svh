`ifndef __RESERVATION_STATION_SVH__
`define __RESERVATION_STATION_SVH__

`include "sys_defs.svh"
`include "dispatcher.svh"

`define ENTRY_NUM 8 // TODO: revise later
`define ENTRY_WIDTH 3

// typedef struct packed {
//     INSN_FUNC                       func;
//     logic    [`ROB_TAG_LEN-1:0]     t1;
//     logic    [`ROB_TAG_LEN-1:0]     t2;
//     logic    [`ROB_TAG_LEN-1:0]     dst;
//     logic                           ready1;
//     logic                           ready2;
//     logic    [`XLEN-1:0]            v1;
//     logic    [`XLEN-1:0]            v2;
//     logic    [`ENTRY_WIDTH-1:0]     Bday;
//     logic                          valid;  // whether the data in this entry can be used
// } RS_ENTRY; // entry type for all RS

typedef struct packed {
    INSN_FUNC                       func;
    logic    [`ROB_TAG_LEN-1:0]     t1;
    logic    [`ROB_TAG_LEN-1:0]     t2;
    logic    [`ROB_TAG_LEN-1:0]     dst;
    logic                           ready1;
    logic                           ready2;
    logic    [`XLEN-1:0]            v1;
    logic    [`XLEN-1:0]            v2;
    logic    [`XLEN-1:0]            pc;
    logic    [`XLEN-1:0]            imm;
    logic    [`ENTRY_WIDTH-1:0]     Bday;
    logic                          valid;  // whether the data in this entry can be used
} RS_ENTRY_M2; // temporary entry type for milestone 2

typedef struct packed {
    INST_RS insn;
    logic                          valid;  // whether the data in this entry can be used
} RS_ENTRY;

`endif
