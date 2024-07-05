`include "reservation_station.svh"

`timescale 1ns/1ps

module reservation_station #(
    parameter NUM_ENTRIES = 4, // #entries in the reservation station
    parameter ENTRY_WIDTH = 2  // #entries = 2^{ENTRY_WIDTH}
)(
    // control signals
    input logic clk,
    input logic reset,
    input logic load, // whether we load in the instruction (assigned by dispatcher)
    input logic issue, // whether the issue queue should output one instruction (assigned by issue unit)
    input logic wakeup, // set by outside logic, indicating whether to set the ready bit of previously issued dst reg to Yes

    // input data
    // input AL_FUNC insn, 
    input DECODED_INST insn,
    input logic [PHY_REG_ADDR_LEN-1:0] inp1, inp2, dst, // previous renaming unit ensures that dst != inp1 and dst != inp2
    input logic wakeup_reg_addr, 

    // output signals
    // output logic issue_ready, // indicates if an instruction is ready to be executed
    output logic insn_ready, // indicates if there exists an instruction that is ready to be issued
    output logic is_full, // all entries of the reservation station is occupied, cannot load in more inputs

    // output data
    // output logic [NUM_ENTRIES-1:0] insn_out,
    input DECODED_INST insn_out,
    output logic [PHY_REG_ADDR_LEN-1:0] inp1_out, inp2_out, dst_out
);


    // the only two internal storages that need to be updated synchronously
    issue_queue_entry_t entries [NUM_ENTRIES];
    logic [PHY_REG_NUM-1:0] ready_table;


    // internal signals below are all updated with combinational logic
    logic [ENTRY_WIDTH:0] num_entry_used; // can be 0,1,2,3,4, so ENTRY_WIDTH do not need to be decremented by 1
    always_comb begin
        num_entry_used = 0;
        for (int i = 0; i < NUM_ENTRIES; i++) begin
            if (entries[i].valid) begin
                num_entry_used++;
            end else
                ;
        end
    end

    assign is_full = num_entry_used == NUM_ENTRIES;

    logic [NUM_ENTRIES-1:0] ready_flags; // if this insn is ready
    generate
        genvar i;
        for (i = 0; i < NUM_ENTRIES; i++) begin : check_ready
        assign ready_flags[i] = entries[i].valid && entries[i].ready1 && entries[i].ready2;
        end
    endgenerate

    logic exist_ready_out;
    assign exist_ready_out = |ready_flags; // reduction OR to check if any entry is ready  
    assign insn_ready = exist_ready_out;

    logic [ENTRY_WIDTH-1:0] min_Bday, min_idx; // min Bday of ready entries and its corresponding index  
    always_comb begin
        min_Bday = {ENTRY_WIDTH{1'b1}}; // initialize to maximum value
        min_idx = 0; // initialize to 0
        for (int i = 0; i < NUM_ENTRIES; i++) begin
            if (ready_flags[i] && (entries[i].Bday <= min_Bday)) begin
                min_Bday = entries[i].Bday;
                min_idx = i;
            end else
                ;
        end
    end


    // update issue
    // logic issue_internal;


    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                entries[i] <= '{insn: ALU_ADD, 
                                inp1: '0, 
                                inp2: '0, 
                                ready1: 1'b0, 
                                ready2: 1'b0, 
                                dst: '0, 
                                Bday: '0, 
                                valid: 1'b0};
            end
            for (int i = 0; i < PHY_REG_NUM; i++) begin
                ready_table[i] <= 1;
            end
            insn_out <= 0;
            inp1_out <= 0;
            inp2_out <= 0;
            dst_out <= 0;
        end else begin
            // add new instruction to reservation station
            if (load && ~is_full) begin
                for (int i = 0; i < NUM_ENTRIES; i++) begin // it's for sure that an empty entry exists
                    if (!entries[i].valid) begin
                        entries[i] <= '{insn: insn, 
                                    inp1: inp1, 
                                    inp2: inp2, 
                                    ready1: ready_table[inp1], 
                                    ready2: ready_table[inp2], 
                                    dst: dst, 
                                    Bday: (issue && exist_ready_out) ? num_entry_used - 1 : num_entry_used, 
                                    valid: 1};
                        break;
                    end else
                        ;
                end

                // update ready table
                ready_table[dst] <= dst == 0; // reg0 should always be 0, so always ready

                // we do not need to update exsiting valid entries whose inp1 == dst or inp2 ==dst
                // namely ready1 and ready2 for existing entries do not need to be updated
                // because earlier insns must not depend on later insns

            end else
                ;

            // issue insn
            if (issue) begin // it's for sure that exist_ready_out == 1, guaranteed by external issue unit

                //output insn
                insn_out <= entries[min_idx].insn;
                inp1_out <= entries[min_idx].inp1;
                inp2_out <= entries[min_idx].inp2;
                dst_out <= entries[min_idx].dst;
                entries[min_idx].valid <= 0; 

                // update Bday if it is younger than the output insn
                for (int i = 0; i < NUM_ENTRIES; i++) begin
                    if (entries[i].valid && entries[i].Bday > min_Bday) begin // Bday: the smallest, the oldest
                        entries[i].Bday <= entries[i].Bday - 1; // Bday: the smallest, the oldes
                    end
                end      

            end else
                ;

            // wakeup other insns if their inp is equal to the dst of the output insn
            if (wakeup) begin
                ready_table[wakeup_reg_addr] <= 1;
                for (int i = 0; i < NUM_ENTRIES; i++) begin
                    entries[i].ready1 <= (entries[i].valid && entries[i].inp1 == wakeup_reg_addr) ? 1:entries[i].ready1;
                    entries[i].ready2 <= (entries[i].valid && entries[i].inp2 == wakeup_reg_addr) ? 1:entries[i].ready2;
                end  
            end else
                ;              
        end
    end


endmodule
