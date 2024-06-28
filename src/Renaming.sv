`include "Renaming.svh"

module RegisterRenaming (
    input logic clk,
    input logic reset,
    input ARCH_REG arch_reg,
    input logic return_flag, //from ROB (if instruction graduating from ROB have a destination reg)
    input logic assign_flag, // from decoder (if instruction decoding from decoder have a destination reg)
    input logic [4:0] commit_phys_reg,
    output PHYS_REG phys_reg //output logic PHYS_REG phys_reg
);

    logic [4:0] assign_dest_reg;
    PHYS_REG rat_phys_reg;

    //special case: if arch_reg.dest == 0 
    logic assign_flag_not_r0, commit_flag_not_r0;
    assign assign_flag_not_r0 = assign_flag && (arch_reg.dest != 5'd0);
    assign commit_flag_not_r0 = return_flag && (commit_phys_reg != 5'd0);
    
    always_comb begin
        if (assign_flag && (arch_reg.dest == 5'd0)) begin
            phys_reg = 5'd0;
        end
        else begin
            phys_reg = rat_phys_reg;
        end
    end

    // synchronize input
    logic assign_flag_reg, commit_flag_reg;
    ARCH_REG arch_reg_curr;
    logic [4:0] commit_phys_reg_curr;
    always_ff @(posedge clk) begin
        assign_flag_reg <= assign_flag_not_r0;
        commit_flag_reg <= commit_flag_not_r0;
        arch_reg_curr <= arch_reg;
        commit_phys_reg_curr <= commit_phys_reg;
    end
   
    RAT rat_inst(
        .clk(clk),
        .reset(reset),
        .arch_reg(arch_reg_curr),
        .assign_reg(assign_dest_reg),
        .assign_flag(assign_flag_reg),
        .phys_reg(rat_phys_reg)
    );

    FreeList freelist_inst(
        .clk(clk),
        .reset(reset),
        .assign_flag(assign_flag_reg),
        .return_flag(commit_flag_reg),
        .return_reg(commit_phys_reg_curr),
        .assign_reg(assign_dest_reg)
    );

endmodule


//map table: for source regs, search in the map table; for dest reg, update the map table
module RAT (
    input logic clk,
    input logic reset,
    input ARCH_REG arch_reg,
    input logic [4:0] assign_reg,
    input logic assign_flag,
    output PHYS_REG phys_reg
);
    typedef logic [(`REG_ADDR_LEN-1):0] Addr;

    Addr [(`REG_LEN-1):0] map_curr, map_next, map_on_reset;

    logic [4:0] assign_reg_curr;
    always_ff @(posedge clk) begin
        assign_reg_curr <= assign_reg;
    end

    always_ff @(posedge clk) begin
        unique if (reset) begin
            map_curr <= map_on_reset;
        end 
        else begin
            map_curr <= map_next;
        end 
    end

    // initialization
    assign map_on_reset = '{default:0}; 

    always_comb begin
        phys_reg.src1 = map_curr[arch_reg.src1];
        phys_reg.src2 = map_curr[arch_reg.src2];
        phys_reg.dest = (arch_reg.dest == 5'd0) ? 5'd0 : assign_reg;
        phys_reg.dest_old = map_curr[arch_reg.dest];
        map_next = map_curr;
        if (assign_flag) map_next[arch_reg.dest] = assign_reg;
    end

endmodule 


//manage the available physical registers in the free list
module FreeList (
    input logic clk,
    input logic reset,
    input logic assign_flag, 
    input logic return_flag, //from ROB
    input logic [4:0] return_reg,  
    output logic [4:0] assign_reg //phys_reg_dest
);

    logic [4:0] free_list [30:0];
    logic [4:0] free_list_front; 
    logic [4:0] free_list_end; 

    logic [4:0] free_list_front_curr;

    //assign phys_reg for new instruction and return phys_reg from ROB
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i=0; i<31; i++) begin
            free_list[i] <= i+1;
            end
            free_list_front <= 5'b00000;
            free_list_end <= 5'b11110; 
        end
        else begin
            if (assign_flag) begin
            free_list_front <= (free_list_front + 1) % 31;
            free_list_front_curr <= free_list_front;
            end
            if (return_flag) begin
            //free_list[(free_list_end + 1) % 31] <= return_reg;
            free_list_end <= (free_list_end + 1) % 31;
            end
        end
    end

assign assign_reg = assign_flag ? free_list[free_list_front] : 5'd0;

endmodule
