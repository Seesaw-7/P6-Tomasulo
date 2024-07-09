`ifndef __RESERVATION_STATION_SVH__
`define __RESERVATION_STATION_SVH__

// local header

`include "map_table.svh"

typedef struct packed {
    ALU_FUNC                       func;    //TODO: revise later, decided by decoder and FU
    // logic    [6:0]                 opcode;  //TODO: revise later, decided by decoder and FU
    logic    [`ROB_TAG_LEN-1:0]     t1;
    logic    [`ROB_TAG_LEN-1:0]     t2;
    logic    [`ROB_TAG_LEN-1:0]     dst;
    logic                           ready1;
    logic                           ready2;
    logic    [`XLEN-1:0]            v1;
    logic    [`XLEN-1:0]            v2;
    logic    [`ENTRY_WIDTH-1:0]     Bday;
    logic                          valid;  // whether the data in this entry can be used
} RS_ENTRY; // entry type for all RS

`endif
