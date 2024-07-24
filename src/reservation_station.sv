`timescale 1ns/100ps

`include "sys_defs.svh"
`include "reservation_station.svh"

//TODO: use CAM instead of loop to improve gate latency

// Note: this module assumes that wakeup is stable at posedge, and wakeup is one clock behind issue
// Besides, it assumes that wakeup_tag and wakeup_value are stable at clock edge, which is kind of weird


module reservation_station #(
    parameter NUM_ENTRIES = 8, // #entries in the reservation station
    parameter ENTRY_WIDTH = 3  // #entries = 2^{ENTRY_WIDTH}
) (
    // control signals
    input clk,
    input reset,

    // from dispatch
    input logic load,
    input INST_RS insn_load,

    // from FU reg 
    input unsigned [3:0] wakeup ,
    input [3:0] [`XLEN-1:0] wakeup_value,
    input [3:0] [`ROB_TAG_LEN-1:0] wakeup_tag, // tag already executed
    // input [3:0] [`ROB_TAG_LEN-1:0] ex_tag, 
    // wakeup_tag under execution (before or after fu based on issue)

    // from issue unit
    input unsigned clear,
    input [`ROB_TAG_LEN-1:0] clear_tag,

    output RS_ENTRY insn_for_ex, // not always ready & reg
    output logic is_full
);

    RS_ENTRY issue_queue_curr [NUM_ENTRIES]; 
    RS_ENTRY issue_queue_next [NUM_ENTRIES]; 
    RS_ENTRY insn_for_ex_next; // not always ready & reg

    always_ff @(posedge clk) begin
        unique if (reset) begin
            issue_queue_curr <= 0;
            insn_for_ex <= 0;
        end else begin
            issue_queue_curr <= issue_queue_next;
            insn_for_ex <= insn_for_ex_next;
        end
    end

    always_comb begin
        issue_queue_next = issue_queue_curr;
        // load insn from dispatcher
        if (load) begin
            issue_queue_next[NUM_ENTRIES-1].insn = insn_load;
            issue_queue_next[NUM_ENTRIES-1].valid = 1;
        // clear insn
        if (clear) begin
            for (int i=0; i<ENTRY_NUM; ++i) begin
                if (issue_queue_next[i].insn.insn_tag == clear_tag) begin
                    issue_queue_next[i].valid = 0;
                end
            end
        end
        // move everything to the end
        for (int i=0; i<NUM_ENTRIES-1; ++i) begin // TODO: test whether parallel
            if (!issue_queue_next[i].valid) begin
                issue_queue_next[i] = issue_queue_next[i+1];
            end
        end
    end
    
    // wakeup
    always_comb begin
        for (int j=0; j<4; ++j) begin
           if (wakeup[j]) begin
                for (int i=0; i<NUM_ENTRIES; ++i) begin
                    if (issue_queue_next[i].tag_src1 == wakeup_tag[j]) begin
                        issue_queue_next[i].value_src1 = wakeup_value[j];
                        issue_queue_next[i].ready_src1 = 1;
                    end
                    if (issue_queue_next[i].tag_src2 == wakeup_tag[j]) begin
                        issue_queue_next[i].value_src2 = wakeup_value[j];
                        issue_queue_next[i].ready_src2 = 1;
                    end
                end 
            end
        end
    end

    RS_ENTRY insn_ready, insn_to_ready;

    // find the first ready insn
    always_comb begin
        insn_ready = 0;
        insn_to_ready = 0;
        // TODO: check whether this for loop siquentially assign variables
        for (int i=NUM_ENTRIES; i>=0; --i) begin
            unique if (issue_queue_next[i].valid && issue_queue_next[i].insn.ready_rs1 && issue_queue_next[i].insn.ready_rs2) begin
                insn_ready = issue_queue_next[i];
            end else begin
                insn_ready = insn_ready;
            end
        end
    end

    // find the first ready insn with the fast fu
        /*
            for i <- 0 : NUM_ENTRIES-1
                if valid 
                    for j <- flip [FU_LSU, FU_MULT, FU_BTU, FU_ALU]
                        if !wakeup[j] -- not ready 
                            flag <- check whether add wake_up tag will be ready
                            if (src1 ready && tag2 == wakeup_tag[j]) or (src2 ready && tag2 == wakeup_tag[j]) or (tag1 == tag2 == wakeup_tag[j]) -- we don't care about two src with different tag ready together in the future
                                insn_to_ready = current insn
                                break
                else
                    break
        */ 
    always_comb begin
        for (int i=NUM_ENTRIES; i>=0; --i) begin
            unique if (issue_queue_next[i].valid) begin
                for (int j=0; j<4; ++j) begin //  j follows order [FU_LSU, FU_MULT, FU_BTU, FU_ALU]
                    unique if (wake_up[j]) begin
                        insn_to_ready = insn_to_ready;
                    end else begin
                        unique if (
                            (issue_queue_next[i].insn.ready_src1 && (issue_queue_next[i].insn.tag_src2 == wakeup_tag[j])) ||
                            (issue_queue_next[i].insn.ready_src2 && (issue_queue_next[i].insn.tag_src1 == wakeup_tag[j])) ||
                            ((issue_queue_next[i].insn.tag_src1 == wakeup_tag[j]) && (issue_queue_next[i].insn.tag_src2 == wakeup_tag[j]))
                        ) begin
                           insn_to_ready = issue_queue_next[i]; 
                        end else begin
                            insn_to_ready = insn_to_ready;
                        end
                    end
                end
            end else begin
                insn_to_ready = insn_to_ready;
            end
        end
    end

    assign insn_for_ex_next = insn_ready.insn.valid ? insn_ready : insn_to_ready;
    assign is_full =  issue_queue_next[NUM_ENTRIES-1].valid;
    
endmodule

/*
module reservation_station #(
    parameter NUM_ENTRIES = 8, // #entries in the reservation station
    parameter ENTRY_WIDTH = 3  // #entries = 2^{ENTRY_WIDTH}
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
    input logic [`ROB_TAG_LEN-1:0] t1, t2, dst, // previous renaming unit ensures that dst != inp1 and dst != inp2
    input logic ready1, ready2,
    input logic [`XLEN-1:0] v1, v2, 
    input logic [`XLEN-1:0] pc, imm,
    input logic [`ROB_TAG_LEN-1:0] wakeup_tag,
    input logic [`XLEN-1:0] wakeup_value, 

    // output signals
    output logic insn_ready, // to issue unit, indicating if there exists an instruction that is ready to be issued
    output logic is_full, // to dispatcher, indicating that all entries of the reservation station is occupied, cannot load in more inputs
    output logic start, // output to FU

    // output data
    output ALU_FUNC func_out, // to FU
    output logic [`XLEN-1:0] v1_out, v2_out, 
    output logic [`XLEN-1:0] pc_out, imm_out,// to FU
    output logic [`ROB_TAG_LEN-1:0] dst_tag // to issue unit, TODO: to FU in m3
);

    logic [`ROB_TAG_LEN-1:0] wakeup_tag_reg;
    logic [`XLEN-1:0] wakeup_value_reg;

    assign wakeup_tag_reg = wakeup? wakeup_tag : wakeup_tag_reg; // in case values are not stable at clock edge
    assign wakeup_value_reg = wakeup? wakeup_value : wakeup_value_reg; 

    // the only internal storage that need to be updated synchronously
    RS_ENTRY_M2 entries [NUM_ENTRIES];

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
    assign dst_tag = exist_ready_out ? entries[min_idx].dst : '0;

    logic [ENTRY_WIDTH-1:0] min_Bday, min_idx; // min Bday of ready entries and its corresponding index  
    always_comb begin
        min_Bday = {ENTRY_WIDTH{1'b1}}; // initialize to maximum value
        min_idx = 0; // initialize to 0
        for (int i = 0; i < NUM_ENTRIES; i++) begin
            if (ready_flags[i] && (entries[i].Bday <= min_Bday)) begin
                min_Bday = entries[i].Bday;
                min_idx = ENTRY_WIDTH'(i);
            end else
                ;
        end
    end


    // update issue
    // logic issue_internal;

    RS_ENTRY_M2 empty_entry;
    // assign empty_entry = '{func: ALU_ADD, 
    //                             t1: '0, 
    //                             t2: '0, 
    //                             v1: '0, 
    //                             v2: '0, 
    //                             pc: '0,
    //                             dst: '0, 
    //                             Bday: '0, 
    //                             ready1: '0,
    //                             ready2: '0,
    //                             valid: 1'b0};
    assign empty_entry = 0; 

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                entries[i] <= empty_entry;
            end
            func_out <= ALU_ADD;
            v1_out <= 0;
            v2_out <= 0;
            pc_out <= 0;
            imm_out <= 0;
            start <=0;
            // dst_tag <= 0;
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
                                    pc: pc,
                                    imm: imm,
                                    Bday: (issue && exist_ready_out) ? `ENTRY_WIDTH'(num_entry_used) - 1'd1 : `ENTRY_WIDTH'(num_entry_used), 
                                    valid: 1'd1};
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
                v2_out <= (wakeup && wakeup_tag_reg == t2) ? wakeup_value_reg : entries[min_idx].v2;
                pc_out <= entries[min_idx].pc;
                imm_out <= entries[min_idx].imm;
                // dst_tag <= entries[min_idx].dst;
                start <= 1;
                entries[min_idx].valid <= 0; 

                // update Bday if it is younger than the output insn
                for (int i = 0; i < NUM_ENTRIES; i++) begin
                    if (entries[i].valid && entries[i].Bday > min_Bday) begin // Bday: the smallest, the oldest
                        entries[i].Bday <= entries[i].Bday - 1; // Bday: the smallest, the oldes
                    end
                end      

            end else
                start <= 0;

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
*/
