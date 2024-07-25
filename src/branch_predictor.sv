`timescale 1ns/100ps

`include "sys_defs.svh"
`include "branch_predictor.svh"

module branch_predictor(
    input logic clk,
    input logic reset,
    
    input [`XLEN-1:0] pc_search,
    input [`XLEN-1:0] pc_from_rob,
    input logic branch_taken_from_rob,
    input [`XLEN-1:0] branch_target_from_rob,
    
    output logic predict_taken,
    output [`XLEN-1:0] predict_target 
);
    
    logic [`BPB_INDEX_LEN-1:0] bpb_index_search;
    logic [`BHB_INDEX_LEN-1:0] bhb_index_search;
    logic [`BPB_INDEX_LEN-1:0] bpb_index_update;
    logic [`BHB_INDEX_LEN-1:0] bhb_index_update;
    
    logic [1:0] BPB [`BPB_SIZE-1:0];
    BHB_ENTRY [`BHB_SIZE-1:0] BHB; 

    assign bpb_index_search = pc_search[(`BPB_INDEX_LEN+1):2]; 
    assign bhb_index_search = pc_search[(`BHB_INDEX_LEN+1):2];
    assign bpb_index_update = pc_from_rob[(`BPB_INDEX_LEN+1):2]; 
    assign bhb_index_update = pc_from_rob[(`BHB_INDEX_LEN+1):2];
 
    logic [1:0] bpb_state;
    
    // make prediction 
    always_comb begin
        bpb_state = BPB[bpb_index_search];
        predict_taken = (bpb_state >= 2'b10);        
        // access bhb if predicted taken
        if (predict_taken) begin
            if (BHB[bhb_index_search].tag == pc_search) begin
                predict_target = BHB[bhb_index_search].target_pc;
            end 
            else begin
                predict_target = pc_search + 4; 
            end
        end 
        else begin
            predict_target = pc_search + 4; 
        end
    end

    // update bpb and bhb
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i=0; i<`BPB_SIZE; i++) begin
                BPB[i] <= 2'b01; //instead of reset as 00, 01 might be better
            end
            for (int j=0; j<`BHB_SIZE; j++) begin
                BHB[j].tag <= 32'b0;
                BHB[j].target_pc <= 32'b0;
            end
        end 
        else begin
            if (branch_taken_from_rob) begin
                if (BPB[bpb_index_update] < 2'b11) BPB[bpb_index_update] <= BPB[bpb_index_update]+1;
            end 
            else begin
                if (BPB[bpb_index_update] > 2'b00) BPB[bpb_index_update] <= BPB[bpb_index_update]-1;
            end

            if (branch_taken_from_rob) begin
                BHB[bhb_index_update].tag <= pc_from_rob;
                BHB[bhb_index_update].target_pc <= branch_target_from_rob;
            end
        end
    end
    
endmodule
