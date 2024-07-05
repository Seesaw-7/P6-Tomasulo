`ifndef __RESERVATION_STATION_VH__
`define __RESERVATION_STATION_VH__

// local header


typedef struct packed {
    ALU1_FUNC insn;
    logic [`REG_ADDR_WIDTH-1:0] inp1;
    logic [`REG_ADDR_WIDTH-1:0] inp2;
    logic ready1;
    logic ready2;
    logic [`REG_ADDR_WIDTH-1:0] dst;
    logic [`ENTRY_WIDTH-1:0] Bday;
    logic valid; // whether the data in this entry can be used
} RS_entry_t; // entry type for the issue queue ahead of ALU1

// typedef struct packed {
//     logic [REG_ADDR_WIDTH-1:0];
//     logic ready;
// } ready_bits_t;

`endif
