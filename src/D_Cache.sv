`timescale 1ns/100ps
`include "sys_defs.svh"

module D_Cache #(
    parameter CACHE_SIZE = 256,
    parameter MSHR_SIZE = 4
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
        logic dirty;
        logic [`XLEN-1:0] tag;
        logic [`XLEN-1:0] data;
    } cache_line_t;

    typedef struct packed {
        logic valid;
        logic [`XLEN-1:0] addr;
        logic [`XLEN-1:0] data;
        logic read;
        logic write;
    } mshr_entry_t;

    cache_line_t cache [CACHE_SIZE];
    mshr_entry_t mshr [MSHR_SIZE];

    logic [$clog2(CACHE_SIZE)-1:0] index;
    logic [`XLEN-1:0] tag;
    logic mshr_full;
    logic mshr_hit;
    logic [$clog2(MSHR_SIZE)-1:0] mshr_index;
    logic need_writeback;
    logic writing_back;

    always_comb begin
        index = addr[$clog2(CACHE_SIZE)-1:0];
        tag = addr[`XLEN-1:$clog2(CACHE_SIZE)];
    end

    // MSHR logic
    always_comb begin
        mshr_full = 1'b1;
        mshr_hit = 1'b0;
        mshr_index = '0;
        for (int i = 0; i < MSHR_SIZE; i++) begin
            if (mshr[i].valid && mshr[i].addr == addr) begin
                mshr_hit = 1'b1;
                mshr_index = i[$clog2(MSHR_SIZE)-1:0];
                break;
            end
            if (!mshr[i].valid && mshr_full) begin
                mshr_full = 1'b0;
                mshr_index = i[$clog2(MSHR_SIZE)-1:0];
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < CACHE_SIZE; i++) begin
                cache[i] <= '0;
            end
            for (int i = 0; i < MSHR_SIZE; i++) begin
                mshr[i] <= '0;
            end
            mem_request <= 0;
            mem_write <= 0;
            hit <= 0;
            read_data <= '0;
            mem_addr <= '0;
            mem_write_data <= '0;
            writing_back <= 0;
        end else begin
            if (read || write) begin
                if (cache[index].valid && cache[index].tag == tag) begin
                    hit <= 1;
                    if (read) begin
                        read_data <= cache[index].data;
                    end
                end else begin
                    hit <= 0;
                    need_writeback = cache[index].valid && cache[index].dirty;
                    if (!mshr_hit && !mshr_full) begin
                        if (need_writeback && !writing_back) begin
                            writing_back <= 1;
                            mem_write <= 1;
                            mem_addr <= {cache[index].tag, index, {$clog2(CACHE_SIZE){1'b0}}};
                            mem_write_data <= cache[index].data;
                        end else if (!writing_back) begin
                            mshr[mshr_index].valid <= 1;
                            mshr[mshr_index].addr <= addr;
                            mshr[mshr_index].data <= write_data;
                            mshr[mshr_index].read <= read;
                            mshr[mshr_index].write <= write;
                            mem_request <= 1;
                            mem_addr <= addr;
                        end
                    end
                end
                
                // Handle write operation regardless of hit or miss
                if (write) begin
                    cache[index].data <= write_data;
                    cache[index].dirty <= 1;
                    cache[index].valid <= 1;
                    cache[index].tag <= tag;
                end
            end else begin
                hit <= 0;
            end

            if (mem_ready) begin
                if (writing_back) begin
                    writing_back <= 0;
                    mem_write <= 0;
                    mem_request <= 1;
                    mem_addr <= addr;
                end else begin
                    for (int i = 0; i < MSHR_SIZE; i++) begin
                        if (mshr[i].valid && mshr[i].addr[`XLEN-1:$clog2(CACHE_SIZE)] == mem_addr[`XLEN-1:$clog2(CACHE_SIZE)]) begin
                            cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].valid <= 1;
                            cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].tag <= mshr[i].addr[`XLEN-1:$clog2(CACHE_SIZE)];
                            if (mshr[i].write) begin
                                cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].data <= mshr[i].data;
                                cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].dirty <= 1;
                            end else begin
                                cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].data <= mem_data;
                                cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].dirty <= 0;
                            end
                            if (mshr[i].read) begin
                                read_data <= mem_data;
                            end
                            mshr[i].valid <= 0;
                        end
                    end
                    mem_request <= 0;
                    mem_write <= 0;
                end
            end
        end
    end
endmodule