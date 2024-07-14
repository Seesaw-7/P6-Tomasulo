module reorder_buffer(
    input logic clk,
    input logic reset,
    
    input logic dispatch,
    input [`REG_ADDR_LEN-1:0] reg_addr_from_dispatcher,
    input [`XLEN-1:0] npc_from_dispatcher,
     
    input logic cdb_to_rob,
    input [`ROB_TAG_LEN-1:0] rob_tag_from_cdb,
    input [`XLEN-1:0] wb_data_from_cdb,
    input [`XLEN-1:0] target_pc_from_cdb,
    input logic mispredict_from_cdb,
    
    input [`ROB_TAG_LEN-1:0] search_src1_rob_tag,
    input [`ROB_TAG_LEN-1:0] search_src2_rob_tag,
    
    output logic wb_en,
    output [`REG_ADDR_LEN-1:0] wb_reg,
    output [`XLEN-1:0] wb_data,
    output logic flush,
    output [`ROB_TAG_LEN-1:0] assign_rob_tag_to_dispatcher,
    output logic rob_full_adv,
    output [`XLEN-1:0] search_src1_data,
    output [`XLEN-1:0] search_src2_data,
    output ROB_ENTRY rob_curr [`ROB_SIZE-1:0],
    output ROB_ENTRY rob_next [`ROB_SIZE-1:0], // Added rob_next output
    output [`ROB_TAG_LEN-1:0] retire_rob_tag,
    output [`XLEN-1:0] commit_npc
);
    
    // Other internal signals
    logic [`ROB_TAG_LEN-1:0] head_curr;
    logic [`ROB_TAG_LEN-1:0] head_next;
    logic [`ROB_TAG_LEN-1:0] tail_curr;
    logic [`ROB_TAG_LEN-1:0] tail_next;
    
    always_comb begin
        for (int i=0; i<`ROB_SIZE; ++i) begin
            rob_next[i] = rob_curr[i];
        end
        head_next = head_curr;
        tail_next = tail_curr;
        
        wb_en = 1'b0;
        wb_reg = {`REG_ADDR_LEN{1'b0}};
        wb_data = {`XLEN{1'b0}};
        flush = 1'b0;
        assign_rob_tag_to_dispatcher = {`ROB_TAG_LEN{1'b0}};
        retire_rob_tag = {`ROB_TAG_LEN{1'b0}};
        commit_npc = {`XLEN{1'b0}};
        
        if (dispatch) begin
            rob_next[tail_curr].valid = 1'b1;
            rob_next[tail_curr].ready = 1'b0;
            rob_next[tail_curr].mispredict = 1'b0;
            rob_next[tail_curr].wb_reg = reg_addr_from_dispatcher;
            rob_next[tail_curr].wb_data = {`XLEN{1'b0}};
            rob_next[tail_curr].npc = npc_from_dispatcher;
            tail_next = tail_curr + 1;
            assign_rob_tag_to_dispatcher = tail_curr;
        end
        
        if (cdb_to_rob) begin
            rob_next[rob_tag_from_cdb].wb_data = wb_data_from_cdb;
            rob_next[rob_tag_from_cdb].mispredict = mispredict_from_cdb;
            if (mispredict_from_cdb == 1'b1) begin
                rob_next[rob_tag_from_cdb].npc = target_pc_from_cdb;
            end
            rob_next[rob_tag_from_cdb].ready = 1'b1;
        end
        
        if (rob_curr[head_curr].valid && rob_curr[head_curr].ready) begin
            wb_en = 1'b1;
            wb_reg = rob_curr[head_curr].wb_reg;
            wb_data = rob_curr[head_curr].wb_data;
            commit_npc = rob_curr[head_curr].npc;
            retire_rob_tag = head_curr;
            if (rob_curr[head_curr].mispredict == 1'b1) begin
                flush = 1'b1;
            end
            rob_next[head_curr].valid = 1'b0;
            head_next = head_curr + 1;
        end
    end
    
    assign search_src1_data = rob_curr[search_src1_rob_tag].wb_data;
    assign search_src2_data = rob_curr[search_src2_rob_tag].wb_data;

    assign rob_full_adv = (head_curr == tail_next);
    
    always_ff @(posedge clk) begin
        if (reset || flush) begin
            head_curr <= {(`ROB_TAG_LEN){1'b0}};
            tail_curr <= {`ROB_TAG_LEN{1'b0}};
            for (int i=0; i<`ROB_SIZE; i++) begin
                rob_curr[i].valid <= 1'b0;
                rob_curr[i].ready <= 1'b0; 
                rob_curr[i].mispredict <= 1'b0;
                rob_curr[i].wb_reg <= {`REG_ADDR_LEN{1'b0}};
                rob_curr[i].wb_data <= {`XLEN{1'b0}};
                rob_curr[i].npc <= {`XLEN{1'b0}};
            end
        end
        else begin
            rob_curr <= rob_next;
            head_curr <= head_next;
            tail_curr <= tail_next;
        end
    end
    
endmodule
