`include "reorder_buffer.svh"
`include "sys_defs.svh"

module reorder_buffer(
    input logic clk,
    input logic reset,
    
    input logic dispatch,
    input [`REG_ADDR_LEN-1:0] reg_addr_from_dispatcher,
     
    input logic cdb_to_rob,
    input [`ROB_TAG_LEN-1:0] rob_tag_from_cdb,
    input [`XLEN-1:0] wb_data_from_cdb,
    input [`XLEN-1:0] target_pc_from_cdb,
    input logic mispredict_from_cdb,
    
    output logic wb_en, //wb to reg
    output [`REG_ADDR_LEN-1:0] wb_reg, 
    output [`XLEN-1:0] wb_data,
    
    output [`XLEN-1:0] target_pc,
    output logic flush, //also indicate write to pc
    
    output [`ROB_TAG_LEN-1:0] assign_rob_tag_to_dispatcher,
    output logic rob_full_adv 
    
    //rob_curr output
);
    
    ROB_ENTRY rob_curr [`ROB_SIZE-1:0];
    ROB_ENTRY rob_next [`ROB_SIZE-1:0];

    logic [`ROB_TAG_LEN-1:0] head_curr;
    logic [`ROB_TAG_LEN-1:0] head_next;
    logic [`ROB_TAG_LEN-1:0] tail_curr;
    logic [`ROB_TAG_LEN-1:0] tail_next;
    
    always_comb begin
        for (int i=0; i<`ROB_SIZE; i++) begin
            rob_next[i] = rob_curr[i];
        end
        head_next = head_curr;
        tail_next = tail_curr;
        
        wb_en = 1'b0;
        wb_reg = {`REG_ADDR_LEN{1'b0}};
        wb_data = {`XLEN{1'b0}};
        target_pc = {`XLEN{1'b0}};
        flush = 1'b0;
        assign_rob_tag_to_dispatcher = {`ROB_TAG_LEN{1'b0}};
        
        if (dispatch) begin
            rob_next[tail_curr].valid = 1'b1;
            rob_next[tail_curr].ready = 1'b0;
            rob_next[tail_curr].mispredict = 1'b0;
            rob_next[tail_curr].wb_reg = reg_addr_from_dispatcher;
            rob_next[tail_curr].wb_data = {`XLEN{1'b0}};
            tail_next = (tail_curr + 1) % `ROB_SIZE;
            
            assign_rob_tag_to_dispatcher = tail_curr;
        end
        
        if (cdb_to_rob) begin
            rob_next[rob_tag_from_cdb].wb_data = wb_data_from_cdb;
            rob_next[rob_tag_from_cdb].target_pc = target_pc_from_cdb;
            rob_next[rob_tag_from_cdb].mispredict = mispredict_from_cdb;
            rob_next[rob_tag_from_cdb].ready = 1'b1;
        end
        
        if (rob_curr[head_curr].valid && rob_curr[head_curr].ready) begin
            wb_en = 1'b1;
            wb_reg = rob_curr[head_curr].wb_reg;
            wb_data = rob_curr[head_curr].wb_data;
            target_pc = rob_curr[head_curr].target_pc;
            if (rob_curr[head_curr].mispredict == 1'b1) begin
                flush = 1'b1;
            end
            rob_next[head_curr].valid = 1'b0;
            head_next = (head_curr + 1) % `ROB_SIZE;
        end

    end

    assign rob_full_adv = (head_curr == tail_next);
    
    always_ff @(posedge clk) begin
        if (reset || flush) begin
            head_curr <= {`REG_ADDR_LEN{1'b0}};
            tail_curr <= {`REG_ADDR_LEN{1'b0}};
            for (int i=0; i<`ROB_SIZE; i++) begin
                rob_curr[i].valid <= 1'b0;
                rob_curr[i].ready <= 1'b0; 
                rob_curr[i].mispredict <= 1'b0;
                rob_curr[i].wb_reg <= {`REG_ADDR_LEN{1'b0}};
                rob_curr[i].wb_data <= {`XLEN{1'b0}};
                rob_curr[i].target_pc <= {`XLEN{1'b0}};
            end
        end
        else begin
            rob_curr <= rob_next;
            head_curr <= head_next;
            tail_curr <= tail_next;
        end
    end
    
endmodule
