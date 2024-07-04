`include "sys_defs.svh"

module prefetch_queue #(
    size = 4;
) (
    input clock,
    input reset,
    input en,
    input take_branch,
    input [`XLEN-1:0] branch_target_pc,
    input [63:0] Imem2proc_datas [size-1:0],
    input hit [size-1:0],
    output logic [`XLEN-1:0] proc2Imem_addrs [size-1:0],
    output PREFETCH_PACKET packet_out
    // output decoder_enable
);

    logic take_branch_reg;
    logic [`XLEN-1:0] branch_target_pc_reg;
    logic [63:0] Imem2proc_datas_reg [size-1:0];
    logic hit_reg [size-1:0];

    always_ff @(posedge clock) begin
        take_branch_reg <= take_branch;
        branch_target_pc_reg <= branch_target_pc;
        Imem2proc_datas_reg <= Imem2proc_datas;
        hit_reg <= hit;
    end


    typedef struct packed {
        logic [63:0] inst_queue [size-1:0];
        logic hit_queue [size-1:0];
        logic [`XLEN-1:0] PC;
    } Config;

    Config conf_curr, conf_next, conf_reset;

    always_ff @(posedge clock) begin
		unique if(reset)
            conf_curr <= conf_reset;
		else
            conf_curr <= conf_next
	end  // always

    assign conf_reset = 0;
    
    always_comb begin
        conf_next = conf_curr;
        unique if (take_branch_reg) begin
            conf_next = conf_reset;
            conf_next.PC = branch_target_pc_reg;
        end else begin
            conf_next.hit_queue = hit_reg;
            // first hit -> << queue; else: keep the same
            if (conf_next.hit_queue[size-1]) begin
                for (int i=1; i<size; ++i) begin
                    conf_next.inst_queue[i] =  conf_curr.inst_queue[i-1];
                end
                conf_next.inst_queue[0] = 63'b0;
                conf_next.PC = conf_curr.PC + 4;
            end 
            // merge input
            for (int i=0; i<size; ++i) begin
                if (!conf_curr.hit_queue[i]) begin
                    conf_next.inst_queue[i] = Imem2proc_datas_reg[i];
                end
            end
        end
    end 

    // output packet_out
    assign packet_out.valid = conf_curr.hit_queue[size-1];
    assign packet_out.inst = conf_curr.PC[2] ? conf_curr.inst_queue[size-1] [63:32] : conf_curr.inst_queue[size-1] [31:0];
    assign packet_out.PC = conf_curr.PC;
    assign packet_out.NPC = conf_curr.PC + 4;

    // output addrs
    always_comb begin
        for (int i=0; i<size; ++i) begin
            proc2Imem_addrs[i] = {(conf_next.PC + (i << 2))[`XLEN-1:3], 3'b0};
        end
    end
	
    
endmodule
