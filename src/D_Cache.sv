`timescale 1ns/100ps
`include "sys_defs.svh"

module D_Cache #(
    parameter CACHE_SIZE = 256
) (
    input logic clk,
    input logic rst,
    input logic [`XLEN-1:0] addr,
    input logic [`XLEN-1:0] write_data,
    input logic read,
    input logic write,
    input logic mem_ready,
    input logic [`XLEN-1:0] mem_data,
    output logic [`XLEN-1:0] read_data,
    output logic hit,
    output logic [`XLEN-1:0] mem_addr,
    output logic [`XLEN-1:0] mem_write_data,
    output logic mem_write,
    output logic mem_request
);

    typedef struct packed {
        logic valid;
        logic [`XLEN-1:0] tag;
        logic [`XLEN-1:0] data;
    } cache_line_t;

    cache_line_t cache [CACHE_SIZE];

    logic [$clog2(CACHE_SIZE)-1:0] index;
    logic [`XLEN-1:0] tag;
    logic [`XLEN-1:0] fetched_data;

    always_comb begin
        index = addr[$clog2(CACHE_SIZE)-1:0];
        tag = addr[`XLEN-1:$clog2(CACHE_SIZE)];
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < CACHE_SIZE; i++) begin
                cache[i].valid <= 0;
                cache[i].tag <= '0;
                cache[i].data <= '0;
            end
            mem_request <= 0;
            mem_write <= 0;
            hit <= 0;
            read_data <= '0;
            mem_addr <= '0;
            mem_write_data <= '0;
        end else begin
            if (read) begin
                if (cache[index].valid && cache[index].tag == tag) begin
                    read_data <= cache[index].data;
                    hit <= 1;
                    mem_request <= 0;
                end else begin
                    mem_request <= 1;
                    mem_addr <= addr;
                    hit <= 0;
                    if (mem_ready) begin
                        cache[index].valid <= 1;
                        cache[index].tag <= tag;
                        cache[index].data <= mem_data;
                        read_data <= mem_data;
                        mem_request <= 0;
                    end
                end
            end else if (write) begin
                cache[index].valid <= 1;
                cache[index].tag <= tag;
                cache[index].data <= write_data;
                mem_write <= 1;
                mem_addr <= addr;
                mem_write_data <= write_data;
                hit <= 1;
            end else begin
                mem_write <= 0;
                mem_request <= 0;
                hit <= 0;
            end
        end
    end
endmodule