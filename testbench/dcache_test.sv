`timescale 1ns/100ps
`include "sys_defs.svh"

module D_Cache_tb;

    // Parameters
    parameter CACHE_SIZE = 256;
    parameter MSHR_SIZE = 4;

    // Signals
    logic clk;
    logic rst;
    logic [`XLEN-1:0] addr;
    logic [`XLEN-1:0] write_data;
    logic [2:0] mem_size;
    logic read;
    logic write;
    logic mem_ready;
    logic [`XLEN-1:0] mem_data;
    logic [`XLEN-1:0] read_data;
    logic hit;
    logic [`XLEN-1:0] mem_addr;
    logic [`XLEN-1:0] mem_write_data;
    logic mem_write;
    logic mem_request;

    // Instantiate the D_Cache module
    D_Cache #(
        .CACHE_SIZE(CACHE_SIZE),
        .MSHR_SIZE(MSHR_SIZE)
    ) dut (.*);

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Test procedure
    initial begin
        // Initialize signals
        rst = 1;
        addr = 0;
        write_data = 0;
        mem_size = 3'b010; // Word size
        read = 0;
        write = 0;
        mem_ready = 0;
        mem_data = 0;

        // Apply reset
        #20;
        rst = 0;
        #10;

        // Test 1: Write a word to cache
        $display("Test 1: Write a word to cache");
        addr = 32'h00000010;
        write_data = 32'hDEADBEEF;
        mem_size = 3'b010; // Word size
        write = 1;
        #10;
        write = 0;
        #10;

        // Test 2: Read the word from cache (should hit)
        $display("Test 2: Read the word from cache (should hit)");
        addr = 32'h00000010;
        mem_size = 3'b010; // Word size
        read = 1;
        #10;
        read = 0;
        #10;
        if (read_data !== 32'hDEADBEEF) $display("Test 2 Failed: Expected 0xDEADBEEF, got 0x%h", read_data);

        // Test 3: Write a byte to cache
        $display("Test 3: Write a byte to cache");
        addr = 32'h00000020;
        write_data = 32'h000000FF;
        mem_size = 3'b000; // Byte size
        write = 1;
        #10;
        write = 0;
        #10;

        // Test 4: Read the byte from cache (should hit)
        $display("Test 4: Read the byte from cache (should hit)");
        addr = 32'h00000020;
        mem_size = 3'b000; // Byte size
        read = 1;
        #10;
        read = 0;
        #10;
        if (read_data !== 32'h000000FF) $display("Test 4 Failed: Expected 0x000000FF, got 0x%h", read_data);

        // Test 5: Write a halfword to cache
        $display("Test 5: Write a halfword to cache");
        addr = 32'h00000030;
        write_data = 32'h0000ABCD;
        mem_size = 3'b001; // Halfword size
        write = 1;
        #10;
        write = 0;
        #10;

        // Test 6: Read the halfword from cache (should hit)
        $display("Test 6: Read the halfword from cache (should hit)");
        addr = 32'h00000030;
        mem_size = 3'b001; // Halfword size
        read = 1;
        #10;
        read = 0;
        #10;
        if (read_data !== 32'h0000ABCD) $display("Test 6 Failed: Expected 0x0000ABCD, got 0x%h", read_data);

        // Test 7: Write to the same cache line with different size (should not write to memory immediately)
        $display("Test 7: Write to the same cache line with different size");
        addr = 32'h00000030;
        write_data = 32'h87654321;
        mem_size = 3'b010; // Word size
        write = 1;
        #10;
        write = 0;
        #10;

        // Test 8: Read from a new address to cause eviction (should write back dirty data)
        $display("Test 8: Read from a new address to cause eviction");
        addr = 32'h00001030; // Same index as 0x00000030, different tag
        mem_size = 3'b010; // Word size
        read = 1;
        #10;
        mem_ready = 1;
        mem_data = 32'hCAFEBABE;
        #10;
        mem_ready = 0;
        #10;
        read = 0;
        #20; // Allow time for potential write-back

        // Test 9: Non-blocking read (multiple outstanding requests)
        $display("Test 9: Non-blocking read (multiple outstanding requests)");
        addr = 32'h00002040;
        mem_size = 3'b010; // Word size
        read = 1;
        #10;
        addr = 32'h00002050;
        #10;
        addr = 32'h00002060;
        #10;
        addr = 32'h00002070;
        #10;
        mem_data = 32'hAABBCCDD;
        mem_ready = 1;
        #10;
        mem_ready = 0;
        #10;
        mem_data = 32'h11223344;
        mem_ready = 1;
        #10;
        mem_ready = 0;
        #10;
        mem_data = 32'h55667788;
        mem_ready = 1;
        #10;
        mem_ready = 0;
        #10;
        mem_data = 32'h99AABBCC;
        mem_ready = 1;
        #10;
        mem_ready = 0;
        #10;
        read = 0;
        #20;

        $display("All tests completed.");
        $finish;
    end

    // Monitor for cache operations
    always @(posedge clk) begin
        if (hit)
            $display("Time %0t: Cache hit for address 0x%h", $time, addr);
        if (mem_request)
            $display("Time %0t: Cache miss for address 0x%h", $time, mem_addr);
        if (mem_write)
            $display("Time %0t: Write-back to memory for address 0x%h, data 0x%h", $time, mem_addr, mem_write_data);
    end

endmodule