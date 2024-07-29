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
        logic [`XLEN-1:0] tag;
        logic [`XLEN-1:0] data;
    } cache_line_t;

    typedef struct packed {
        logic valid;
        logic [`XLEN-1:0] addr;
        logic [`XLEN-1:0] data;
        logic read;
        logic write;
        logic [2:0] mem_size;
    } mshr_entry_t;

    cache_line_t cache [CACHE_SIZE];
    mshr_entry_t mshr [MSHR_SIZE];

    logic [$clog2(CACHE_SIZE)-1:0] index;
    logic [`XLEN-1:0] tag;
    logic mshr_full;
    logic mshr_hit;
    logic [$clog2(MSHR_SIZE)-1:0] mshr_index;

    always_comb begin
        index = addr[$clog2(CACHE_SIZE)-1:0];
        tag = addr[`XLEN-1:$clog2(CACHE_SIZE)];
    end

    // Check if MSHR has space
    always_comb begin
        mshr_full = 1'b1;
        for (int i = 0; i < MSHR_SIZE; i++) begin
            if (!mshr[i].valid) begin
                mshr_full = 1'b0;
                mshr_index = i[$clog2(MSHR_SIZE)-1:0];
                break;
            end
        end
    end

    // Check if address is already in MSHR
    always_comb begin
        mshr_hit = 1'b0;
        for (int i = 0; i < MSHR_SIZE; i++) begin
            if (mshr[i].valid && mshr[i].addr == addr) begin
                mshr_hit = 1'b1;
                mshr_index = i[$clog2(MSHR_SIZE)-1:0];
                break;
            end
        end
    end

    // Helper function to extract data based on mem_size
    function automatic logic [`XLEN-1:0] extract_data(logic [`XLEN-1:0] full_data, logic [2:0] size, logic [`XLEN-1:0] addr);
        logic [1:0] offset = addr[1:0];
        case (size)
            3'b000: return {{(`XLEN-8){1'b0}}, full_data[offset*8 +: 8]};  // Byte
            3'b001: return {{(`XLEN-16){1'b0}}, full_data[offset[1]*16 +: 16]};  // Halfword
            3'b010: return full_data;  // Word
            default: return full_data;
        endcase
    endfunction

    // Helper function to insert data based on mem_size
    function automatic logic [`XLEN-1:0] insert_data(logic [`XLEN-1:0] old_data, logic [`XLEN-1:0] new_data, logic [2:0] size, logic [`XLEN-1:0] addr);
        logic [1:0] offset = addr[1:0];
        case (size)
            3'b000: begin  // Byte
                old_data[offset*8 +: 8] = new_data[7:0];
                return old_data;
            end
            3'b001: begin  // Halfword
                old_data[offset[1]*16 +: 16] = new_data[15:0];
                return old_data;
            end
            3'b010: return new_data;  // Word
            default: return new_data;
        endcase
    endfunction

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < CACHE_SIZE; i++) begin
                cache[i].valid <= 0;
                cache[i].tag <= '0;
                cache[i].data <= '0;
            end
            for (int i = 0; i < MSHR_SIZE; i++) begin
                mshr[i].valid <= 0;
                mshr[i].addr <= '0;
                mshr[i].data <= '0;
                mshr[i].read <= 0;
                mshr[i].write <= 0;
                mshr[i].mem_size <= 0;
            end
            mem_request <= 0;
            mem_write <= 0;
            hit <= 0;
            read_data <= '0;
            mem_addr <= '0;
            mem_write_data <= '0;
        end else begin
            if (read || write) begin
                if (cache[index].valid && cache[index].tag == tag) begin
                    hit <= 1;
                    if (read) begin
                        read_data <= extract_data(cache[index].data, mem_size, addr);
                    end else if (write) begin
                        cache[index].data <= insert_data(cache[index].data, write_data, mem_size, addr);
                        mem_write <= 1;
                        mem_addr <= addr;
                        mem_write_data <= write_data;
                    end
                end else begin
                    hit <= 0;
                    if (!mshr_hit && !mshr_full) begin
                        mshr[mshr_index].valid <= 1;
                        mshr[mshr_index].addr <= addr;
                        mshr[mshr_index].data <= write_data;
                        mshr[mshr_index].read <= read;
                        mshr[mshr_index].write <= write;
                        mshr[mshr_index].mem_size <= mem_size;
                        mem_request <= 1;
                        mem_addr <= addr;
                        mem_write_data <= write_data;
                        mem_write <= write;
                    end
                end
            end else begin
                hit <= 0;
            end

            if (mem_ready) begin
                for (int i = 0; i < MSHR_SIZE; i++) begin
                    if (mshr[i].valid && mshr[i].addr[`XLEN-1:$clog2(CACHE_SIZE)] == mem_addr[`XLEN-1:$clog2(CACHE_SIZE)]) begin
                        cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].valid <= 1;
                        cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].tag <= mshr[i].addr[`XLEN-1:$clog2(CACHE_SIZE)];
                        if (mshr[i].write) begin
                            cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].data <= insert_data(mem_data, mshr[i].data, mshr[i].mem_size, mshr[i].addr);
                        end else begin
                            cache[mshr[i].addr[$clog2(CACHE_SIZE)-1:0]].data <= mem_data;
                        end
                        if (mshr[i].read) begin
                            read_data <= extract_data(mem_data, mshr[i].mem_size, mshr[i].addr);
                        end
                        mshr[i].valid <= 0;
                    end
                end
                mem_request <= 0;
            end
        end
    end
endmodule