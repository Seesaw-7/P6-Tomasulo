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
    input logic [2:0] mem_size, 
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
        logic [2:0] size;
    } mshr_entry_t;

    cache_line_t cache [CACHE_SIZE];
    mshr_entry_t mshr [MSHR_SIZE];

    logic [$clog2(CACHE_SIZE)-1:0] index;
    logic [`XLEN-1:0] tag;
    logic [1:0] offset;
    logic mshr_full;
    logic mshr_hit;
    logic [$clog2(MSHR_SIZE)-1:0] mshr_index;
    logic need_writeback;
    logic writing_back;

    // Helper functions for read and write operations
    function automatic logic [`XLEN-1:0] read_data_by_size(logic [`XLEN-1:0] data, logic [2:0] size, logic [1:0] offset);
        logic [`XLEN-1:0] result;
        case (size)
            3'b000: result = {{(`XLEN-8){1'b0}}, data[offset*8 +: 8]};  // Byte
            3'b001: result = {{(`XLEN-16){1'b0}}, data[offset[1]*16 +: 16]};  // Halfword
            3'b010: result = data;  // Word
            default: result = data;
        endcase
        return result;
    endfunction

    function automatic logic [`XLEN-1:0] write_data_by_size(logic [`XLEN-1:0] old_data, logic [`XLEN-1:0] new_data, logic [2:0] size, logic [1:0] offset);
        logic [`XLEN-1:0] result = old_data;
        case (size)
            3'b000: result[offset*8 +: 8] = new_data[7:0];  // Byte
            3'b001: result[offset[1]*16 +: 16] = new_data[15:0];  // Halfword
            3'b010: result = new_data;  // Word
            default: result = new_data;
        endcase
        return result;
    endfunction

    always_comb begin
        index = addr[$clog2(CACHE_SIZE)-1:0];
        tag = addr[`XLEN-1:$clog2(CACHE_SIZE)];
        offset = addr[1:0];
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
                        read_data <= read_data_by_size(cache[index].data, mem_size, offset);
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
                    cache[index].data <= write_data_by_size(cache[index].data, write_data, mem_size, offset);
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
                                cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].data <= write_data_by_size(
                                    cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].data,
                                    mshr[i].data,
                                    mshr[i].size,
                                    mshr[i].addr[1:0]
                                );
                                cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].dirty <= 1;
                            end else begin
                                cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].data <= mem_data;
                                cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].dirty <= 0;
                            end
                            if (mshr[i].read) begin
                                read_data <= read_data_by_size(mem_data, mshr[i].size, mshr[i].addr[1:0]);
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