`timescale 1ns/100ps
`include "sys_defs.svh"

module D_Cache #(
    parameter CACHE_SIZE = 256,
    parameter MSHR_SIZE = 4
) (
    input logic clk,
    input logic rst,
    input logic [`XLEN-1:0] proc2cache_addr,
    input logic [63:0] proc2cache_data,
    input MEM_SIZE proc2cache_size,
    input logic [1:0] proc2cache_command,
    
    output logic [63:0] cache2proc_data,
    output logic cache2proc_valid,
    
    // Memory interface
    output logic [`XLEN-1:0] cache2mem_addr,
    output logic [63:0] cache2mem_data,
    output logic [1:0] cache2mem_command,
    input logic [3:0] mem2cache_response,
    input logic [63:0] mem2cache_data,
    input logic [3:0] mem2cache_tag
);

    // Cache line and MSHR entry structures
    typedef struct packed {
        logic valid;
        logic dirty;
        logic [`XLEN-1:$clog2(CACHE_SIZE)] tag;
        logic [63:0] data;
    } cache_line_t;

    typedef struct packed {
        logic valid;
        logic [`XLEN-1:0] addr;
        logic [63:0] data;
        MEM_SIZE size;
        logic [1:0] command;
    } mshr_entry_t;

    // Cache and MSHR arrays
    cache_line_t cache [CACHE_SIZE];
    mshr_entry_t mshr [MSHR_SIZE];

    // Internal signals
    logic [$clog2(CACHE_SIZE)-1:0] index;
    logic [`XLEN-1:$clog2(CACHE_SIZE)] tag;
    logic [2:0] offset;
    logic mshr_full, mshr_hit;
    logic [$clog2(MSHR_SIZE)-1:0] mshr_index;
    logic need_writeback, writing_back;
    logic [3:0] current_mem_tag;

    // Address decoding
    always_comb begin
        index = proc2cache_addr[$clog2(CACHE_SIZE)+2:3];
        tag = proc2cache_addr[`XLEN-1:$clog2(CACHE_SIZE)+3];
        offset = proc2cache_addr[2:0];
    end

    // MSHR logic
    always_comb begin
        mshr_full = 1'b1;
        mshr_hit = 1'b0;
        mshr_index = '0;
        for (int i = 0; i < MSHR_SIZE; i++) begin
            if (mshr[i].valid && mshr[i].addr == proc2cache_addr) begin
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

    // Main cache logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cache <= '{default: '0};
            mshr <= '{default: '0};
            cache2mem_command <= BUS_NONE;
            cache2proc_valid <= 0;
            cache2cache_data <= '0;
            cache2mem_addr <= '0;
            cache2mem_data <= '0;
            writing_back <= 0;
            current_mem_tag <= '0;
        end else begin
            if (proc2cache_command != BUS_NONE) begin
                handle_cache_access();
            end

            if (mem2cache_response != 0) begin
                handle_memory_response();
            end
        end
    end

    // Helper tasks
    task handle_cache_access();
        if (cache[index].valid && cache[index].tag == tag) begin
            handle_cache_hit();
        end else begin
            handle_cache_miss();
        end
    endtask

    task handle_cache_hit();
        cache2proc_valid <= 1;
        if (proc2cache_command == BUS_LOAD) begin
            cache2proc_data <= extract_data(cache[index].data, proc2cache_size, offset);
        end else if (proc2cache_command == BUS_STORE) begin
            cache[index].data <= insert_data(cache[index].data, proc2cache_data, proc2cache_size, offset);
            cache[index].dirty <= 1;
        end
    endtask

    task handle_cache_miss();
        cache2proc_valid <= 0;
        need_writeback = cache[index].valid && cache[index].dirty;
        if (!mshr_hit && !mshr_full) begin
            if (need_writeback && !writing_back) begin
                start_writeback();
            end else if (!writing_back) begin
                start_memory_request();
            end
        end
    endtask

    task start_writeback();
        writing_back <= 1;
        cache2mem_command <= BUS_STORE;
        cache2mem_addr <= {cache[index].tag, index, 3'b000};
        cache2mem_data <= cache[index].data;
    endtask

    task start_memory_request();
        mshr[mshr_index].valid <= 1;
        mshr[mshr_index].addr <= proc2cache_addr;
        mshr[mshr_index].data <= proc2cache_data;
        mshr[mshr_index].size <= proc2cache_size;
        mshr[mshr_index].command <= proc2cache_command;
        cache2mem_command <= BUS_LOAD;
        cache2mem_addr <= proc2cache_addr;
    endtask

    task handle_memory_response();
        if (writing_back) begin
            writing_back <= 0;
            cache2mem_command <= BUS_LOAD;
            cache2mem_addr <= mshr[current_mem_tag-1].addr;
        end else begin
            update_cache_from_memory();
            cache2mem_command <= BUS_NONE;
        end
        current_mem_tag <= mem2cache_response;
    endtask

    task update_cache_from_memory();
        cache[index].valid <= 1;
        cache[index].tag <= tag;
        cache[index].data <= mem2cache_data;
        cache[index].dirty <= 0;
        
        if (mshr[current_mem_tag-1].command == BUS_LOAD) begin
            cache2proc_valid <= 1;
            cache2proc_data <= extract_data(mem2cache_data, mshr[current_mem_tag-1].size, offset);
        end else if (mshr[current_mem_tag-1].command == BUS_STORE) begin
            cache[index].data <= insert_data(mem2cache_data, mshr[current_mem_tag-1].data, mshr[current_mem_tag-1].size, offset);
            cache[index].dirty <= 1;
        end
        
        mshr[current_mem_tag-1].valid <= 0;
    endtask

    // Helper functions
    function logic [63:0] extract_data(logic [63:0] data, MEM_SIZE size, logic [2:0] offset);
        case (size)
            BYTE:   return {56'b0, data[offset*8 +: 8]};
            HALF:   return {48'b0, data[{offset[2:1], 1'b0}*8 +: 16]};
            WORD:   return {32'b0, data[{offset[2], 2'b0}*8 +: 32]};
            DOUBLE: return data;
        endcase
    endfunction

    function logic [63:0] insert_data(logic [63:0] old_data, logic [63:0] new_data, MEM_SIZE size, logic [2:0] offset);
        case (size)
            BYTE:   old_data[offset*8 +: 8] = new_data[7:0];
            HALF:   old_data[{offset[2:1], 1'b0}*8 +: 16] = new_data[15:0];
            WORD:   old_data[{offset[2], 2'b0}*8 +: 32] = new_data[31:0];
            DOUBLE: old_data = new_data;
        endcase
        return old_data;
    endfunction

endmodule
