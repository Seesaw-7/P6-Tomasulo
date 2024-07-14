`timescale 1ns/100ps

`include "sys_defs.svh"


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
    input en,	
    input mem_bus_none,
    input take_branch,
    input [`XLEN-1:0] branch_target_pc,
    input [63:0] Imem2proc_data,
    output logic [`XLEN-1:0] proc2Imem_addr,
    output PREFETCH_PACKET packet_out
    // output decoder_enable
);

    logic    [`XLEN-1:0] PC_reg;             // PC we are currently fetching
	
	logic    [`XLEN-1:0] PC_plus_4;
	logic    [`XLEN-1:0] next_PC;
	logic           PC_enable;
	
	assign proc2Imem_addr = {PC_reg[`XLEN-1:3], 3'b0};
	
	// this mux is because the Imem gives us 64 bits not 32 bits
	assign packet_out.inst = PC_reg[2] ? Imem2proc_data[63:32] : Imem2proc_data[31:0];
	
	// default next PC value
	assign PC_plus_4 = PC_reg + 4;
	
	// next PC is target_pc if there is a taken branch or
	// the next sequential PC (PC+4) if no branch
	// (halting is handled with the enable PC_enable;
	assign next_PC = take_branch ? branch_target_pc : PC_plus_4;
	
	// The take-branch signal must override stalling (otherwise it may be lost)
	assign PC_enable = (enable && packet_out.valid) || take_branch;
	assign enable = en && !take_branch;
	
	// Pass PC+4 down pipeline w/instruction
	assign packet_out.NPC = PC_plus_4;
	assign packet_out.PC  = PC_reg;
	assign packet_out.valid = reset || mem_bus_none;
	// This register holds the PC value
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset)
			PC_reg <= `SD 0;       // initial PC value is 0
		else if(PC_enable)
			PC_reg <= `SD next_PC; // transition to next PC
	end  // always


    // logic take_branch_reg;
    // logic [`XLEN-1:0] branch_target_pc_reg;
    // logic [63:0] Imem2proc_datas_reg [size-1:0];
    // logic hit_reg [size-1:0];
    // logic mem_bus_none_reg;

    // always_ff @(posedge clock) begin
    //     take_branch_reg <= take_branch;
    //     branch_target_pc_reg <= branch_target_pc;
    //     Imem2proc_datas_reg <= Imem2proc_data;
    //     hit_reg <= hit;
    //     mem_bus_none_reg <= mem_bus_none;
    // end

    // typedef struct packed {
    //     logic [63:0] inst_queue [size-1:0];
    //     logic hit_queue [size-1:0];
    //     logic [`XLEN-1:0] PC;
    // } Config;

    // Config conf_curr, conf_next, conf_reset;

    // always_ff @(posedge clock) begin
	// 	unique if(reset)
    //         conf_curr <= conf_reset;
	// 	else
    //         conf_curr <= conf_next
	// end  // always

    // assign conf_reset = 0;
    
    // always_comb begin
    //     conf_next = conf_curr;
    //     unique if (take_branch_reg) begin
    //         conf_next = conf_reset;
    //         conf_next.PC = branch_target_pc_reg;
    //     end else begin
    //         conf_next.hit_queue = hit_reg;
    //         // first hit -> << queue; else: keep the same
    //         if (conf_next.hit_queue[size-1]) begin
    //             for (int i=1; i<size; ++i) begin
    //                 conf_next.inst_queue[i] =  conf_curr.inst_queue[i-1];
    //             end
    //             conf_next.inst_queue[0] = 63'b0;
    //             conf_next.PC = conf_curr.PC + 4;
    //         end 
    //         // merge input
    //         for (int i=0; i<size; ++i) begin
    //             if (!conf_curr.hit_queue[i]) begin
    //                 conf_next.inst_queue[i] = Imem2proc_datas_reg[i];
    //             end
    //         end
    //     end
    // end 

    // output packet_out
    // assign packet_out.valid = conf_curr.hit_queue[size-1];
    // assign packet_out.inst = conf_curr.PC[2] ? conf_curr.inst_queue[size-1] [63:32] : conf_curr.inst_queue[size-1] [31:0];
    // assign packet_out.PC = conf_curr.PC;
    // assign packet_out.NPC = conf_curr.PC + 4;

    // output addrs
    // always_comb begin
        // for (int i=0; i<size; ++i) begin
            // proc2Imem_addrs[i] = {(conf_next.PC + (i << 2))[`XLEN-1:3], 3'b0};
        // end
    // end
	
    
endmodule
