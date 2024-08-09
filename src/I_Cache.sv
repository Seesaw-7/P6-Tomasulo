`timescale 1ns / 100ps

`include "cache.svh"

// TODO: figure out why mem latency is 2
// TODO: pipeline bus command control

module I_Cache
(
    input clk,
    input rst,

    // Prefetch queue interface
    input cache_read,
    input [`XLEN-1:0] proc2cache_addr, //read addr
    
    output logic [`XLEN-1:0] cache2proc_data, //to ls_unit data
    output logic cache2proc_valid, // to ls_unit hit/miss
    
    // Memory interface
    output logic [`XLEN-1:0] cache2mem_addr,
    output logic [`XLEN-1:0] cache2mem_data,
    output BUS_COMMAND icache2mem_command,

    input mem2cache_valid, // only valid for 1 cycle
    input [63:0] mem2cache_data
);

    // Cache Memory Definition
    typedef struct packed {
        logic [63:0] data;
        logic valid;
        logic [`XLEN-4:0] tag;
    } cache_line_t;

    cache_line_t [CACHE_SIZE-1:0] cache_mem;
    
    // Indexing and Tagging
    logic [CACHE_SIZE_BIT-1+3:3] index;
    logic [`XLEN-1:CACHE_SIZE_BIT+3] tag;

    logic [`XLEN-1:0] data_temp;
    assign data_temp = proc2cache_addr[2] ? cache_mem[index].data[63:32] : cache_mem[index].data[31:0];
    
    assign index = proc2cache_addr[31:3] % CACHE_SIZE;
    assign tag = proc2cache_addr[31:CACHE_SIZE_BIT+3];//

    // Cache Hit Detection
    logic cache_hit;
    assign cache_hit = (cache_mem[index].valid && cache_mem[index].tag == tag);


    
    // Processor to Cache Logic
    // always_ff @(posedge clk or posedge rst) begin
    always_ff @(posedge clk) begin
        if (rst) begin
            // Reset cache
            for (int i = 0; i < CACHE_SIZE; i++) begin
                cache_mem[i].valid <= 1'b0;
            end
            cache2proc_valid <= 1'b0;
        end else begin
            if ( cache_read ) begin

                // Prefetch read cache, and hit
                if (cache_hit) begin
                    // Handle Cache Hit
                    cache2proc_valid <= 1'b1;
                    cache2proc_data <= data_temp;

                // Prefetch read cache, but miss
                end else begin
                    cache2proc_valid <= 1'b0;
                    if(mem2cache_valid)begin
                        cache_mem[index].data <= mem2cache_data;
                        cache_mem[index].valid <= 1'b1;
                        cache_mem[index].tag <= tag;
                        icache2mem_command <= BUS_NONE;
                    end else begin
                        cache2mem_addr <= proc2cache_addr;
                        cache2mem_command <= BUS_LOAD;
                    end
                end
            end else begin
                cache2proc_valid <= 1'b0;
            end

        end
    end


endmodule