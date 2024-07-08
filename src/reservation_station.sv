`include "reservation_station.svh"

`timescale 1ns/1ps

//TODO: use CAM instead of loop to improve gate number
//TODO: async accept wakeup value but sync update RS entries, so async judge insn_ready based on wakeup tag as well

module reservation_station #(
    parameter NUM_ENTRIES = 4, // #entries in the reservation station
    parameter ENTRY_WIDTH = 2  // #entries = 2^{ENTRY_WIDTH}
)(
    // control signals
    input logic clk,
    input logic reset,
    input logic load, // whether we load in the instruction (assigned by dispatcher)
    input logic issue, // whether the issue queue should output one instruction (assigned by issue unit), should be stable during clock edge
    input logic wakeup, // set by issue unit, indicating whether to set the ready tag of previously issued dst reg to Yes
                        // this should better be set 1 cycle after issue exactly is the FU latency is one, should be stable during clock edge

    // input data
    input ALU_FUNC func,
    input logic [ROB_TAG_LEN-1:0] t1, t2, dst, // previous renaming unit ensures that dst != inp1 and dst != inp2
    input ready1, ready2,
    input logic [XLEN-1:0] v1, v2, 
    input logic [ROB_TAG_LEN-1:0] wakeup_tag,
    input logic [XLEN-1:0] wakeup_value, 

    // output signals
    output logic insn_ready, // indicates if there exists an instruction that is ready to be issued
    output logic is_full, // all entries of the reservation station is occupied, cannot load in more inputs

    // output data
    output ALU_FUNC func_out,
    output logic [XLEN-1:0] v1_out, v2_out,
    output [`ROB_TAG_LEN-1:0] dst_tag
);

    logic [ROB_TAG_LEN-1:0] wakeup_tag_reg;
    logic [XLEN-1:0] wakeup_value_reg;

    assign wakeup_tag_reg = wakeup? wakeup_tag : wakeup_tag_reg; // in case values are not stable at clock edge
    assign wakeup_value_reg = wakeup? wakeup_value : wakeup_value_reg; 

    // the only internal storage that need to be updated synchronously
    RS_ENTRY entries [NUM_ENTRIES];

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
        assign ready_flags[i] = entries[i].valid 
                                && (entries[i].ready1 || (wakeup && wakeup_tag_reg == entries[i].t1)) 
                                && (entries[i].ready2 || (wakeup && wakeup_tag_reg == entries[i].t2));
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

    RS_ENTRY empty_entry;
    assign empty_entry = '{func: ALU_ADD, 
                                t1: '0, 
                                t2: '0, 
                                v1: 1'b0, 
                                v2: 1'b0, 
                                dst: '0, 
                                Bday: '0, 
                                valid: 1'b0};

    always_comb begin

    end


    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                entries[i] <= empty_entry;
            end
            for (int i = 0; i < PHY_REG_NUM; i++) begin
                ready_table[i] <= 1;
            end
            func_out <= 0;
            v1_out <= 0;
            v2_out <= 0;
            dst_tag <= 0;
        end else begin
            // add new instruction to reservation station
            if (load && ~is_full) begin
                for (int i = 0; i < NUM_ENTRIES; i++) begin // it's for sure that an empty entry exists
                    if (!entries[i].valid) begin
                        entries[i] <= '{func: func, 
                                    t1: t1, 
                                    t2: t2, 
                                    dst: dst, 
                                    ready1: ready1 || (wakeup && wakeup_tag_reg == t1), 
                                    ready2: ready2 || (wakeup && wakeup_tag_reg == t2), 
                                    v1: (wakeup && wakeup_tag_reg == t1) ? wakeup_value_reg : v1,
                                    v2: (wakeup && wakeup_tag_reg == t2) ? wakeup_value_reg : v2,
                                    Bday: (issue && exist_ready_out) ? num_entry_used - 1 : num_entry_used, 
                                    valid: 1};
                        break;
                    end else
                        ;
                end

                // we do not need to update exsiting valid entries whose inp1 == dst or inp2 ==dst
                // namely ready1 and ready2 for existing entries do not need to be updated
                // because earlier insns must not depend on later insns

            end else
                ;

            // issue insn
            if (issue) begin // it's for sure that exist_ready_out == 1, guaranteed by external issue unit

                //output insn
                func_out <= entries[min_idx].func; // output at clock edge just to make sure that RS output one single and stable value per clock cycle
                v1_out <= (wakeup && wakeup_tag_reg == t1) ? wakeup_value_reg : entries[min_idx].v1;
                v2_out <= (wakeup && wakeup_tag_reg == t2) ? entries[min_idx].v2;
                dst_tag <= entries[min_idx].dst;
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
                for (int i = 0; i < NUM_ENTRIES; i++) begin
                    entries[i].ready1 <= (entries[i].valid && entries[i].t1 == wakeup_tag_reg) ? 1:entries[i].ready1;
                    entries[i].ready2 <= (entries[i].valid && entries[i].t2 == wakeup_tag_reg) ? 1:entries[i].ready2;
                    entries[i].v1 <= (entries[i].valid && entries[i].t1 == wakeup_tag_reg) ? wakeup_value_reg:entries[i].v1;
                    entries[i].v2 <= (entries[i].valid && entries[i].t2 == wakeup_tag_reg) ? wakeup_value_reg:entries[i].v2;
                end  
            end else
                ;              
        end
    end


endmodule
