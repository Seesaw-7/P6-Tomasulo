`timescale 1ns / 100ps

`include "cache.svh"


// TODO: figure out why mem latency is 2
// TODO: move to always_comb

module data_cache
(
    input clk,
    input rst,

    // LS Unit interface
    input cache_read,
    input cache_write,
    input [`XLEN-1:0] proc2cache_addr, //read/write addr
    input [`XLEN-1:0] proc2cache_data, //write data
    input [2:0] proc2cache_size, 
    
    output logic [`XLEN-1:0] cache2proc_data, //to ls_unit data
    output logic cache2proc_valid, // to ls_unit hit/miss
    
    // Memory interface
    output logic [`XLEN-1:0] cache2mem_addr,
    output logic [`XLEN-1:0] cache2mem_data,
    output BUS_COMMAND dcache2mem_command,

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


// update cache_mem
    always_ff @(posedge clk) begin
        if (rst) begin
            // Reset cache
            for (int i = 0; i < CACHE_SIZE; i++) begin
                cache_mem[i].valid <= 1'b0;
            end
        end else begin
            if ( cache_read || cache_write ) begin

                // LS read or write cache, and hit
                if (cache_hit) begin
                    if (cache_read) begin     

                    // LS Unit Write Cache
                    end else begin
                        // update cache
                        if proc2cache_addr[2] 
                            cache_mem[index].data[63:32] <= proc2cache_data;
                        else 
                            cache_mem[index].data[31:0] <= proc2cache_data;
                    end

                // LS read or write cache, but miss
                end else begin
                    // Handle Cache Miss
                    if(mem2cache_valid)begin
                        cache_mem[index].data <= mem2cache_data;
                        cache_mem[index].valid <= 1'b1;
                        cache_mem[index].tag <= tag;
                    end else begin
                    end
                end
            end else begin
            end
        end
    end

    assign cache2proc_valid = !rst && ((cache_read || cache_write ) && cache_hit);
    assign cache2mem_addr = proc2cache_addr;
    assign cache2mem_data = proc2cache_data;

    // update cache2proc_data (load data from cache to proc)
    always_comb begin
        case (proc2cache_size)
            3'b000: : begin // LB
                cache2proc_data <= {{(`XLEN-8){data_temp[7]}}, data_temp[7:0]};
            end
            3'b001: begin // LH
                cache2proc_data <= {{(`XLEN-16){data_temp[15]}}, data_temp[15:0]};
            end
            3'b010: begin // LW
                cache2proc_data <= data_temp;
            end
            3'b100: begin // LBU
                cache2proc_data <= {{(`XLEN-8){1'b0}}, data_temp[7:0]};
            end
            3'b101: begin // LHU
                cache2proc_data <= {{(`XLEN-16){1'b0}}, data_temp[15:0]};
            end
            default: begin
                cache2proc_data <= data_temp;
            end 
        endcase
    end


    // update dcache2mem_command
    always_comb begin
        if ( cache_read || cache_write ) begin

            // LS read or write cache, and hit
            if (cache_hit) begin
                // Handle Cache Hit

                if (cache_read) begin     
                end else begin
                    dcache2mem_command <= BUS_STORE;
                end

            // LS read or write cache, but miss
            end else begin
                // Handle Cache Miss
                if(mem2cache_valid)begin
                    dcache2mem_command <= BUS_NONE;
                end else begin
                    dcache2mem_command <= BUS_LOAD;
                end
            end
        end else begin
        end

    end
  

endmodule