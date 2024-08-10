`timescale 1ns/100ps

`include "sys_defs.svh"

module I_Cache #(
    parameter CACHE_SIZE = 256,
    parameter BLOCK_SIZE = 8  // 64 bits = 8 bytes
) (
    input logic clk,
    input logic reset,
    input logic [`XLEN-1:0] proc2Imem_addr,
    input logic mem_ready,
    input logic [63:0] mem_data,
    output logic [63:0] Imem2proc_data,
    output logic mem_bus_none,
    output logic [`XLEN-1:0] mem_addr,
    output logic mem_request
);

    // Cache line structure
    typedef struct packed {
        logic valid;
        logic [`XLEN-1:3] tag;
        logic [63:0] data;
    } cache_line_t;

    // Cache memory
    cache_line_t cache [CACHE_SIZE];

    // Internal signals
    logic [$clog2(CACHE_SIZE)-1:0] index;
    logic [`XLEN-1:3] tag;
    logic hit;

    // Compute index and tag
    assign index = proc2Imem_addr[$clog2(CACHE_SIZE)+2:3];
    assign tag = proc2Imem_addr[`XLEN-1:$clog2(CACHE_SIZE)+3];

    // Check for cache hit
    assign hit = cache[index].valid && (cache[index].tag == tag);

    // Output data on hit, otherwise request from memory
    assign Imem2proc_data = hit ? cache[index].data : 64'b0;
    assign mem_bus_none = hit;

    // Memory request logic
    assign mem_request = !hit;
    assign mem_addr = {proc2Imem_addr[`XLEN-1:3], 3'b0};

    // Cache update logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < CACHE_SIZE; i++) begin
                cache[i].valid <= 0;
                cache[i].tag <= '0;
                cache[i].data <= '0;
            end
        end else if (mem_ready && !hit) begin
            cache[index].valid <= 1;
            cache[index].tag <= tag;
            cache[index].data <= mem_data;
        end
    end

endmodule
