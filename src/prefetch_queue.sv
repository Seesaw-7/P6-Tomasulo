`timescale 1ns/100ps

`include "prefetch_queue.svh"


// typedef struct packed {
// 	logic valid; // If low, the data in this struct is garbage
//     INST  inst;  // fetched instruction out
// 	logic [`XLEN-1:0] NPC; // PC + 4
// 	logic [`XLEN-1:0] PC;  // PC 
// } PREFETCH_PACKET;

module prefetch_queue #(
    size = 40
) (
    input clock,
    input reset,
    input en, // enable output	
    input mem_bus_none,
    input take_branch,
    input [`XLEN-1:0] branch_target_pc,
    input [63:0] Imem2proc_data,
    output logic [`XLEN-1:0] proc2Imem_addr,
    output PREFETCH_PACKET packet_out
    // output decoder_enable
);

    PREFETCH_QUEUE queue_curr, queue_next, queue_buffer;
    logic [`XLEN-1:0] proc2Icache_addr;
    logic cache_data_valid;
    assign cache_data_valid = reset || mem_bus_none;

    assign proc2Imem_addr = proc2Icache_addr; //TODO: remove when enable icache
    assign proc2Icache_addr = {queue_curr.PC[`XLEN-1:3], 3'b0};

    logic [63:0] Icache2proc_data;
    assign Icache2proc_data = Imem2proc_data;

    always_ff @(posedge clock) begin
        if (reset) begin
            queue_curr <= 0;
        end else begin
            queue_curr <= queue_next;
        end
    end

//    logic [3:0] num;
    always_comb begin
        queue_buffer = queue_curr;
        queue_next = 0;
        if (!take_branch) begin
            // if en and queue not empty, output one insn
            unique if (en && queue_curr.num != 0) begin
                // shift right entries
                for (int i=0; i<`PF_ENTRY_NUM-1; ++i) begin
                    queue_buffer.entries[i] = queue_curr.entries[i+1];
                end
                queue_buffer.entries[`PF_ENTRY_NUM-1] = 0;
                queue_buffer.num = queue_curr.num - 1;
    //            queue_next.PC = queue_curr.PC;
            end else begin
               queue_buffer.num = queue_curr.num;
//               queue_next = queue_curr; 
            end
        end else begin
            queue_buffer = 0;
            queue_buffer.PC = branch_target_pc;
        end
        
        queue_next = queue_buffer;
        unique if (queue_buffer.num < `PF_ENTRY_NUM) begin
            // fetch one insn from cache
            if (cache_data_valid) begin
                queue_next.entries[queue_buffer.num].inst = queue_curr.PC[2] ? Icache2proc_data[63:32] : Icache2proc_data[31:0]; 
                queue_next.num = queue_buffer.num + 1;
                queue_next.entries[queue_buffer.num].PC = queue_curr.PC;
                // update PC
                queue_next.PC = take_branch ? branch_target_pc : queue_curr.PC + 4;
            end
        end else begin
            queue_next.num = queue_buffer.num;
        end
    end
    always_comb begin
        packet_out.valid = en && (queue_curr.num != 0);
        packet_out.inst = queue_curr.entries[0].inst;
        packet_out.PC = queue_curr.entries[0].PC;
        packet_out.NPC = queue_curr.entries[0].PC + 4;
    end


endmodule
