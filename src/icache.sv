`include "sys_defs.svh"

`define CACHE_LEN  32
`define CACHE_BLOCK_INDEX_LEN  5
`define BLOCK_SIZE  1
`define CACHE_TAG_LEN 8 // 1 word per block 16 - 3 - 5

typedef struct packed {
    logic valid;
    logic [`CACHE_TAG_LEN-1:0] tag;
    logic [63:0] data; // 1 word
} CACHE_BLOCK;

module icache (
    input clock,
    input reset,

    input [`XLEN-1:0] proc2Icache_addr,	
    output [63:0] Icache2proc_data,
    output Icache2proc_data_valid,

    input [3:0]  mem2proc_response, // 0 = can't accept, other=tag of transaction i
	input [63:0] mem2proc_data,     // data resulting from a load
	input [3:0]  mem2proc_tag,       // 0 = no value, other=tag of transaction
    output logic [1:0] proc2Imem_command,	
    output logic [`XLEN-1:0] proc2Imem_addr      // Address sent to data-memory
);

CACHE_BLOCK [`CACHE_LEN-1:0] cache_curr, cache_next;
logic [`CACHE_TAG_LEN-1:0] current_tag, last_tag;
logic [`CACHE_BLOCK_INDEX_LEN-1:0] current_index, last_index;

always_ff @(posedge clock) begin
    if (reset) begin
        cache_curr <= 0;
        last_index <= 0;
        last_tag <= 0;
    end else begin
        cache_curr <= cache_next;
        last_index <= current_index;
        last_tag <= current_tag;
    end
end

// read from cache
assign {current_tag, current_index} = proc2Icache_addr[15:3];
assign Icache2proc_data = cache_curr[current_index].data;
logic miss;
assign miss = cache_curr[current_index].valid && (cache_curr[current_index].tag == current_tag);
assign Icache2proc_data_valid = miss;
// miss
always_comb begin
    if (miss) begin
        cache_next.valid = 0;
        cache_next.tag = current_tag;
    end
end 

wire changed_addr = (current_index!=last_index) || (current_tag!=last_tag);

// write from mem
always_comb begin
    cache_next = cache_curr;
    if (mem2proc_response != 0 && (mem2proc_response == mem2proc_tag)) begin // succeed in getting data from mem
        cache_next.data = mem2proc_data;
        cache_next.valid = 1;
    end
end

assign proc2Imem_command = changed_addr ? BUS_NONE : BUS_LOAD;
assign proc2Imem_addr = {proc2Icache_addr[31:3], 3'b0};


    
endmodule
