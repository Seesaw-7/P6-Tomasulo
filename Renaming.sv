`include "Renaming.svh"

module RegisterRenaming (
    input logic clk,
    input logic reset,
    input ARCH_REG arch_reg,
    input logic commit_flag, //from ROB
    input logic assign_flag, // form decoder
    input logic [4:0] commit_phys_reg,
    output PHYS_REG phys_reg //output logic PHYS_REG phys_reg
    // output done
);

    logic [4:0] assign_dest_reg;
    //    logic freelist_inst_done;
    PHYS_REG rat_phys_reg;
    
    assign phys_reg = (arch_reg.dest == 5'd0) ? 5'd0 : rat_phys_reg;
    //assign phys_reg = rat_phys_reg;
    
    RAT rat_inst(
        .clk(clk),
        .reset(reset),
        .assign_flag(assign_flag),
        .arch_reg(arch_reg),
        .assign_reg(assign_dest_reg),
        .phys_reg(rat_phys_reg)
        // .done(rat_done)
    );
    
    FreeList freelist_inst(
        .clk(clk),
        .reset(reset),
        .assign_flag(assign_flag),
        .return_flag(commit_flag),
        .return_reg(commit_phys_reg),
        .assign_reg(assign_dest_reg)
        // .done(freelist_done)
    );

endmodule


module RAT (
    input logic clk,
    input logic reset,
    // input logic en,
    input ARCH_REG arch_reg,
    input logic [4:0] assign_reg,
    input logic assign_flag,
    output PHYS_REG phys_reg
    // output done
);

    logic [(`REG_LEN*`REG_ADDR_LEN-1):0] map_curr, map_next, map_on_reset;
//    logic [4:0] old_phys_reg_dest;
    
    // ARCH_REG arch_reg_reg;
    logic [4:0] assign_reg_curr;
     always_ff @(posedge clk) begin
         assign_reg_curr <= assign_reg;
     end
    
    always_ff @(posedge clk) begin
        unique if (reset) begin
            map_curr <= map_on_reset;
            // done <= 1'b0;
        end 
        else begin
            map_curr <= map_next;
            // done <= 1'b1;
        end 
    end
    
    // initialization
    assign map_on_reset = 1'b0 << `REG_LEN*`REG_ADDR_LEN; 

    always_comb begin
        map_next = map_curr;
        if (assign_flag) map_next = map_next | (assign_reg_curr << arch_reg.dest*`REG_ADDR_LEN);
    end
    
    assign phys_reg.src1 = map_curr >> (arch_reg.src1*`REG_ADDR_LEN);
    assign phys_reg.src2 = map_curr >> (arch_reg.src2*`REG_ADDR_LEN);
//    assign phys_reg.dest = (assign_reg == 5'd0) ? 5'd0 : assign_reg;
    assign phys_reg.dest = assign_reg_curr;
    assign phys_reg.dest_old = map_curr >> (arch_reg.dest*`REG_ADDR_LEN);

endmodule 


module FreeList (
    input logic clk,
    input logic reset,
    input logic assign_flag, 
    input logic return_flag, //from ROB
    input logic [4:0] return_reg,  
    output logic [4:0] assign_reg //phys_reg_dest
    // output done
);

    logic [4:0] free_list [30:0];
    logic [4:0] free_list_front; //assign
    logic [4:0] free_list_end; //return
    
    logic [4:0] free_list_front_curr;

    //assign phys_reg for new instruction and return phys_reg from ROB
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i=0; i<31; i++) begin
            free_list[i] <= i+1;
            end
            free_list_front <= 5'b00000;
            free_list_end <= 5'b11110; 
            // done <= 1'b0;
        end
        else begin
            if (assign_flag) begin
            free_list_front <= (free_list_front + 1) % 31;
            free_list_front_curr <= free_list_front;
            //assign_reg = free_list[free_list_front];
            end
            if (return_flag) begin
            free_list[(free_list_end + 1) % 31] <= return_reg;
            free_list_end <= (free_list_end + 1) % 31;
            end
            // done <= 1'b1;
        end
    end
    
assign assign_reg = assign_flag ? free_list[free_list_front_curr] : 5'b00000;
        
endmodule
