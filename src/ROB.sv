`include "ROB.svh"

module ROB(
    input logic clk,
    input logic reset,
    
    input logic dispatch,
    input [1:0] fun_code,
    input [`REG_ADDR_LEN-1:0] reg_addr_from_dispatcher,
     
    input logic cdb_to_rob,
    input [`ROB_TAG_LEN-1:0] rob_tag_from_cdb,
    input [`XLEN-1:0] cdb_result,
    
    output logic wb_en, //wb to reg
    output [`REG_ADDR_LEN-1:0] wb_reg, 
    output [`XLEN-1:0] wb_data,
    
    output logic flush,
    
    output [`ROB_TAG_LEN-1:0] assign_rob_tag_to_dispatcher,
    output logic rob_full_adv
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
        flush = 1'b0;
        
        if (dispatch) begin
            rob_next[tail_curr].valid = 1;
            rob_next[tail_curr].ready = 0;
            rob_next[tail_curr].fun_code = fun_code;
            rob_next[tail_curr].wb_reg = reg_addr_from_dispatcher;
            rob_next[tail_curr].wb_data = {`XLEN{1'b0}};
            tail_next = (tail_curr + 1) % `ROB_SIZE;
        end
        
        if (cdb_to_rob) begin
            rob_next[rob_tag_from_cdb].wb_data = cdb_result;
            rob_next[rob_tag_from_cdb].ready = 1;
        end
        
        if (rob_curr[head_curr].valid && rob_curr[head_curr].ready) begin
            if (rob_curr[head_curr].fun_code == 2'b00) begin
                wb_en = 1;
                wb_reg = rob_curr[head_curr].wb_reg;
                wb_data = rob_curr[head_curr].wb_data;
            end
            if (rob_curr[head_curr].fun_code == 2'b01) begin
                flush = (rob_curr[head_curr].wb_data == {`XLEN{1'b0}});
            end
            rob_next[head_curr].valid = 0;
            head_next = (head_curr + 1) % `ROB_SIZE;
        end

    end

    assign assign_rob_tag_to_dispatcher = tail_curr;
    assign rob_full_adv = (head_curr == tail_next);
    
    always_ff @(posedge clk) begin
        if (reset || flush) begin
            head_curr <= 0;
            tail_curr <= 0;
            for (int i=0; i<`ROB_SIZE; i++) begin
                rob_curr[i].valid <= 0;
                rob_curr[i].ready <= 0; 
            end
        end
        else begin
            rob_curr <= rob_next;
            head_curr <= head_next;
            tail_curr <= tail_next;
        end
    end
    
endmodule
