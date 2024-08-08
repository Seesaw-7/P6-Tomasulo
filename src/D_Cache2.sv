module D_Cache #(
    parameter CACHE_SIZE = 256
) (
    input logic clk,
    input logic rst,
    input logic [`XLEN-1:0] proc2cache_addr,
    input logic [`XLEN-1:0] proc2cache_data,
    input MEM_SIZE proc2cache_size,
    input BUS_COMMAND proc2cache_command,
    
    output logic [`XLEN-1:0] cache2proc_data,
    output logic cache2proc_valid,
    
    // Memory interface
    output logic [`XLEN-1:0] cache2mem_addr,
    output logic [`XLEN-1:0] cache2mem_data,
    output BUS_COMMAND cache2mem_command,
    output MEM_SIZE cache2mem_size, 
    
    input logic [3:0] mem2cache_response,
    input logic [`XLEN-1:0] mem2cache_data,
    input logic [3:0] mem2cache_tag
);

    // Cache Memory Definition
    typedef struct packed {
        logic [`XLEN-1:0] data;
        logic valid;
        logic [`XLEN-1:0] tag;
    } cache_line_t;

    cache_line_t cache_mem[CACHE_SIZE-1:0];
    
    // Indexing and Tagging
    logic [31:0] index;
    logic [`XLEN-1:0] tag;
    
    assign index = proc2cache_addr[31:0] % CACHE_SIZE;
    assign tag = proc2cache_addr;

    // Cache Hit Detection
    logic cache_hit;
    assign cache_hit = (cache_mem[index].valid && cache_mem[index].tag == tag);
    
    // Processor to Cache Logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset cache
            for (int i = 0; i < CACHE_SIZE; i++) begin
                cache_mem[i].valid <= 1'b0;
            end
            cache2proc_valid <= 1'b0;
        end else begin
            if (proc2cache_command != BUS_NONE) begin
                if (cache_hit) begin
                    // Handle Cache Hit
                    cache2proc_valid <= 1'b1;
                    if (proc2cache_command == BUS_LOAD) begin
                        cache2proc_data <= cache_mem[index].data;
                    end else if (proc2cache_command == BUS_STORE) begin
                        cache_mem[index].data <= proc2cache_data;
                        // Write-through: write to memory as well
                        cache2mem_addr <= proc2cache_addr;
                        cache2mem_data <= proc2cache_data;
                        cache2mem_command <= BUS_STORE;
                        cache2mem_size <= proc2cache_size;
                    end
                end else begin
                    // Handle Cache Miss
                    cache2proc_valid <= 1'b0;
                    // Issue memory read command (simplified)
                    cache2mem_addr <= proc2cache_addr;
                    cache2mem_command <= BUS_LOAD;
                end
            end else begin
                cache2proc_valid <= 1'b0;
            end
        end
    end
    
    // Memory to Cache Logic
    always_ff @(posedge clk) begin
        if (mem2cache_response != 4'b0) begin
            // On memory response, update the cache and return data to processor
            cache_mem[index].data <= mem2cache_data;
            cache_mem[index].tag <= tag;
            cache_mem[index].valid <= 1'b1;
            cache2proc_data <= mem2cache_data;
            cache2proc_valid <= 1'b1;
        end
    end

endmodule
