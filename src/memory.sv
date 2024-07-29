`timescale 1ns/100ps
`include "sys_defs.svh"

module main_memory #(
    parameter MEM_SIZE = 1024 // Memory size in words (32-bit)
) (
    input logic clk,
    input logic rst,
    input logic [`XLEN-1:0] addr,
    input logic [`XLEN-1:0] write_data,
    input logic mem_read,
    input logic mem_write,
    output logic mem_ready,
    output logic [`XLEN-1:0] read_data
);

    // Memory array
    logic [`XLEN-1:0] memory [0:MEM_SIZE-1];

    // Address index
    logic [$clog2(MEM_SIZE)-1:0] index;

    always_comb begin
        index = addr[$clog2(MEM_SIZE)-1:0];
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_ready <= 0;
            read_data <= 0;
            // Initialize memory with some default values (optional)
            for (int i = 0; i < MEM_SIZE; i++) begin
                memory[i] <= 0;
            end
        end else begin
            mem_ready <= 0;
            if (mem_read) begin
                read_data <= memory[index];
                mem_ready <= 1;
            end
            if (mem_write) begin
                memory[index] <= write_data;
                mem_ready <= 1;
            end
        end
    end

endmodule