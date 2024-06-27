module RegisterRenaming (
    input logic clk,
    input logic reset,
    input logic [4:0] arch_reg_src1, 
    input logic [4:0] arch_reg_src2,
    input logic [4:0] arch_reg_dest,
    input logic commit, //from ROB 
    input logic [4:0] commit_phys_reg, 
    output logic [4:0] phys_reg_src1,
    output logic [4:0] phys_reg_src2,
    output logic [4:0] phys_reg_dest
);

endmodule


module RAT (
    input logic clk,
    input logic reset,
    input logic [4:0] arch_reg_src1,
    input logic [4:0] arch_reg_src2,
    input logic [4:0] arch_reg_dest,
    input logic [4:0] allocate_reg,
    output logic [4:0] phys_reg_src1,
    output logic [4:0] phys_reg_src2
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
always_comb begin 
    map_on_reset = 1'b0 << (REG_LEN*REG_ADDR_LEN-1); 
    for (int i=0; i<REG_LEN; ++i) begin
        // 00000 to 11111
       map_on_reset[(i+1)*REG_ADDR_LEN-1 : i*REG_ADDR_LEN] = REG_ADDR_LEN'd i; 
    end
end

assign phys_reg_src1 = map_curr[(arch_reg_src1+1)*REG_ADDR_LEN-1 : arch_reg_src1*REG_ADDR_LEN];
assign phys_reg_src2 = map_curr[(arch_reg_src2+1)*reg_addr_len-1 : arch_reg_src2*reg_addr_len];
assign old_phys_reg_dest = map_curr[(arch_reg_dest+1)*REG_ADDR_LEN-1 : arch_reg_dest*REG_ADDR_LEN];

always_comb begin
    map_next = map_curr;
    map_next[(arch_reg_dest+1)*REG_ADDR_LEN-1 : arch_reg_dest*REG_ADDR_LEN]; = allocate_reg;
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

    //initialize free list (start as full)
    initial begin
        for (int i=0; i<32; i++) begin
            free_list[i] = i;
        end
        free_list_front = 5'b00000;
        free_list_end = 5'b11111; 
    end
    
    //assign phys_reg for new instruction and return phys_reg from ROB
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i=0; i<32; i++) begin
            free_list[i] = i;
            end
            free_list_front = 5'b00000;
            free_list_end = 5'b11111; 
        end
        else begin
            if (assign_flag) begin
            assign_reg = free_list[free_list_front];
            free_list_front = (free_list_front + 1) % 32;
            end
            if (return_flag) begin
            free_list[(free_list_end + 1) % 32] = return_reg;
            free_list_end = (free_list_end + 1) % 32;
        end
    end
        
endmodule


