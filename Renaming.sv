`include "Renaming.svh"

module RegisterRenaming (
    input logic clk,
    input logic reset,
    input ARCH_REG arch_reg,
    input logic commit_flag, //from ROB
    input logic assign_flag, // form decoder
    input logic [4:0] commit_phys_reg, 
    output PHYS_REG phys_reg
);

    logic [4:0] assign_dest_reg;
    
    RAT rat_inst(
        .clk(clk),
        .reset(reset),
        .arch_reg(arch_reg),
        .allocate_reg(assign_dest_reg),
        .phys_reg(phys_reg)
    );
    
    FreeList freelist_inst(
        .clk(clk),
        .reset(reset),
        .assign_flag(assign_flag),
        .return_flag(commit_flag),
        .return_reg(commit_phys_reg),
        .assign_reg(assign_dest_reg)
    )

endmodule


module RAT (
    input logic clk,
    input logic reset,
    input ARCH_REG arch_reg,
    input logic [4:0] allocate_reg,
    output PHYS_REG phys_reg
);

logic [(REG_LEN*REG_ADDR_LEN-1):0] map_curr, map_next, map_on_reset;
logic [4:0] old_phys_reg_dest;

always_ff @(posedge clock) begin
    if (reset) begin
        map_curr <= map_on_reset;
    end else begin
        map_curr <= map_next;
    end 
end

// initialization
assign map_on_reset = 1'b0 << REG_LEN*REG_ADDR_LEN; 

assign phys_reg.src1 = map_curr[(arch_reg.src1+1)*REG_ADDR_LEN-1 : arch_reg.src1*REG_ADDR_LEN];
assign phys_reg.src2 = map_curr[(arch_reg.src2+1)*REG_ADDR_LEN-1 : arch_reg.src2*REG_ADDR_LEN];
assign phys_reg.dest_old = map_curr[(arch_reg.dest+1)*REG_ADDR_LEN-1 : arch_reg.dest*REG_ADDR_LEN];

always_comb begin
    map_next = map_curr;
    map_next[(arch_reg.dest+1)*REG_ADDR_LEN-1 : arch_reg.dest*REG_ADDR_LEN]; = allocate_reg;
end

endmodule 


module FreeList (
    input logic clk,
    input logic reset,
    input logic assign_flag, 
    input logic return_flag, //from ROB
    input logic [4:0] return_reg,  
    output logic [4:0] assign_reg //phys_reg_dest
);

    logic [4:0] free_list [31:0];
    logic [4:0] free_list_front; //assign
    logic [4:0] free_list_end; //return

    //assign phys_reg for new instruction and return phys_reg from ROB
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i=0; i<32; i++) begin
            free_list[i] <= i;
            end
            free_list_front <= 5'b00000;
            free_list_end <= 5'b11111; 
        end
        else begin
            if (assign_flag) begin
            assign_reg <= free_list[free_list_front];
            free_list_front <= (free_list_front + 1) % 32;
            end
            if (return_flag) begin
            free_list[(free_list_end + 1) % 32] <= return_reg;
            free_list_end <= (free_list_end + 1) % 32;
        end
    end
        
endmodule

