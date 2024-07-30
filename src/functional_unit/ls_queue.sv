`timescale 1ns / 100ps

`include "sys_defs.svh"
`include "ls_queue.svh"

module ls_queue(
    input logic clk,
    input logic reset, 
    input logic flush, 
    
    input logic dispatch, 
    input INST_RS insn_in, 
    
    input commit_store, 
    input [`ROB_TAG_LEN-1:0] commit_store_rob_tag, 
    
    input [`ROB_TAG_LEN-1:0] forwarding_rob_tag, // synchronize with rs wake up 
    input [`XLEN-1:0] forwarding_data,
    
    input done_from_ls_unit, 
    
    output to_ls_unit, 
    output INST_RS insn_out_to_ls_unit, 
);
    
    LS_QUEUE_ENTRY [`LS_QUEUE_SIZE-1:0] ls_queue_curr; 
    LS_QUEUE_ENTRY [`LS_QUEUE_SIZE-1:0] ls_queue_next; 
    
    logic [`LS_QUEUE_POINTER_LEN-1:0] head_curr; 
    logic [`LS_QUEUE_POINTER_LEN-1:0] head_next; 
    logic [`LS_QUEUE_POINTER_LEN-1:0] tail_curr; 
    logic [`LS_QUEUE_POINTER_LEN-1:0] tail_next; 
    
    always_comb begin 
        for (int i=0; i<`LS_QUEUE_SIZE; i++) begin
            ls_queue_next[i] = ls_queue_curr[i];
        end
        head_next = head_curr;
        tail_next = tail_curr;
        
        // dispatch insn into ls queue
        if (dispatch) begin
            ls_queue_next[tail_curr].valid = 1'b1;
            ls_queue_next[tail_curr].ready = (insn_in.ready_src1) && (insn_in.ready_src2);
            if ((insn_in.func == LS_LOAD) || (insn_in.func == LS_LOADU)) begin
                ls_queue_next[tail_curr].read_write = 1'b1;
            end
            else if (insn_in.func == LS_WRITE) begin
                ls_queue_next[tail_curr].read_write = 1'b0;
            end
            else begin
                ls_queue_next[tail_curr].read_write = 1'b0;
            end
            ls_queue_next[tail_curr].insn = insn_in; 
            
            tail_next = tail_curr + 1; 
        end
        
        // to ls unit
        if (ls_queue_curr[head_curr].valid && ls_queue_curr[head_curr].ready && ls_queue_curr[head_curr].read_write == 1'b0) begin
            if (commit_store && (commit_store_rob_tag == ls_queue_curr[head_curr].insn.insn_tag)) begin
                to_ls_unit = 1'b1; 
                insn_out_to_ls_unit = ls_queue_curr[head_curr].insn;
                read_write = 1'b0;
            end
        end
        else if (ls_queue_curr[head_curr].valid && ls_queue_curr[head_curr].ready && ls_queue_curr[head_curr].read_write == 1'b1) begin
            to_ls_unit = 1'b1; 
            insn_out_to_ls_unit = ls_queue_curr[head_curr].insn;
            read_write = 1'b1;
        end
        
       // syncronize forwarding with rs  
        for (int i=0; i<`LS_QUEUE_SIZE; i++) begin
            if (ls_queue_curr[i].valid == 1'b1 && ls_queue_curr[i].ready == 1'b0) begin
                if (ls_queue_curr[i].insn.tag_src1 == forwarding_rob_tag) begin
                    ls_queue_next[i].insn.value_src1 = forwarding_data;
                    ls_queue_next[i].insn.ready_src1 = 1'b1;
                end
                else if (ls_queue_curr[i].insn.tag_src2 == forwarding_rob_tag) begin
                    ls_queue_next[i].insn.value_src2 = forwarding_data;
                    ls_queue_next[i].insn.ready_src2 = 1'b1;
                end
            end
            if (ls_queue_next[i].insn.ready_src1 && ls_queue_next[i].insn.ready_src2) begin
                ls_queue_next[i].ready = 1'b1;
            end
        end
        
        // clear ls queue's entry when ls done
        if (done_from_ls_unit) begin
            ls_queue_next[head_curr].valid = 1'b0;
            head_next = head_curr + 1;
        end
    end
    
    always_ff @(posedge clk) begin
        if (reset || flush) begin
            head_curr <= {(`LS_QUEUE_POINTER_LEN){1'b0}}; 
            tail_curr <= {(`LS_QUEUE_POINTER_LEN){1'b0}}; 
            for (int i=0; i<`LS_QUEUE_SIZE; i++) begin
                ls_queue_curr[i].valid = 1'b0;
            end
        end
        else begin
            ls_queue_curr <= ls_queue_next; 
            head_curr <= head_next;
            tail_curr <= tail_next; 
        end
    end
    
endmodule
