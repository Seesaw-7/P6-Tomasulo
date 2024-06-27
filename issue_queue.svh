`ifndef __SYS_DEFS_VH__
`define __SYS_DEFS_VH__

// local header

// issue queue 1 is ahead of ALU1
`define ISSUE_QUEUE_1_ENTRY_NUM 4 // #entries in issue queue 1
`define ENTRY_WIDTH 2 // #entries = 2^{ENTRY_WIDTH}

typedef struct packed {
    ALU1_FUNC insn;
    logic [REG_ADDR_WIDTH-1:0] inp1;
    logic [REG_ADDR_WIDTH-1:0] inp2;
    logic ready1;
    logic ready2;
    logic [REG_ADDR_WIDTH-1:0] dst;
    logic [ENTRY_WIDTH-1:0] Bday;
    logic valid; // whether the data in this entry can be used
} issue_queue_entry_t1; // entry type for the issue queue ahead of ALU1

// typedef struct packed {
//     logic [REG_ADDR_WIDTH-1:0];
//     logic ready;
// } ready_bits_t;

`endif // __SYS_DEFS_VH__
