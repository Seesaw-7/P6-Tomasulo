`ifndef __RESERVATION_STATION_VH__
`define __RESERVATION_STATION_VH__

// local header

`define RS_INT_ENTRY_NUM 8 // #entries in RS, ahead of integer unit
`define RS_INT_ENTRY_WIDTH 3 // #entries = 2^{ENTRY_WIDTH}

`define RS_MULT_ENTRY_NUM 4 // #entries in RS, ahead of multiplier
`define RS_MULT_ENTRY_WIDTH 2

`define RS_BRANCH_ENTRY_NUM 4 // #entries in RS, ahead of branch unit
`define RS_BRANCH_ENTRY_WIDTH 2

`define RS_LS_ENTRY_NUM 8 // #entries in RS, ahead of load/store unit
`define RS_LS_ENTRY_WIDTH 3

typedef struct packed {
    ALU1_FUNC insn;
    logic [`REG_ADDR_WIDTH-1:0] inp1;
    logic [`REG_ADDR_WIDTH-1:0] inp2;
    logic ready1;
    logic ready2;
    logic [`REG_ADDR_WIDTH-1:0] dst;
    logic [`ENTRY_WIDTH-1:0] Bday;
    logic valid; // whether the data in this entry can be used
} issue_queue_entry_t1; // entry type for the issue queue ahead of ALU1

// typedef struct packed {
//     logic [REG_ADDR_WIDTH-1:0];
//     logic ready;
// } ready_bits_t;

`endif
