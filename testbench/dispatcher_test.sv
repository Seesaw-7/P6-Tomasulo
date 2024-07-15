`timescale 1ns/100ps

module dispatcher_tb;

    localparam CLK_PERIOD = 10; 

    logic clk;
    logic reset;

    // Inputs
    DECODED_PACK decoded_pack;
    logic [`REG_NUM-1:0] [`XLEN-1:0] registers;
    ROB_ENTRY rob [`ROB_SIZE-1:0];
    logic [`ROB_TAG_LEN-1:0] assign_rob_tag;
    logic return_flag;
    logic ready_flag;
    logic [`ROB_TAG_LEN-1:0] rob_tag_from_rob;
    logic [`REG_ADDR_LEN-1:0] reg_addr_from_rob;
    logic [`ROB_TAG_LEN-1:0] rob_tag_from_cdb;
    logic [`XLEN-1:0] wb_data;
    logic unsigned [3:0] RS_is_full;

    // Outputs
    INST_RS inst_rs;
    INST_ROB inst_rob;
    logic stall;
    logic unsigned [3:0] RS_load;

    dispatcher dut (
        .clk(clk),
        .reset(reset),
        .decoded_pack(decoded_pack),
        .registers(registers),
        .rob(rob),
        .assign_rob_tag(assign_rob_tag),
        .inst_rs(inst_rs),
        .inst_rob(inst_rob),
        .stall(stall),
        .return_flag(return_flag),
        .ready_flag(ready_flag),
        .rob_tag_from_rob(rob_tag_from_rob),
        .reg_addr_from_rob(reg_addr_from_rob),
        .rob_tag_from_cdb(rob_tag_from_cdb),
        .wb_data(wb_data),
        .RS_is_full(RS_is_full),
        .RS_load(RS_load)
    );

    always # (CLK_PERIOD / 2) clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        
        # (2 * CLK_PERIOD) reset = 0;

        registers = '{default: '0};
        rob = '{default: '{default: '0}};
        assign_rob_tag = '0;
        return_flag = '0;
        ready_flag = '0;
        rob_tag_from_rob = '0;
        reg_addr_from_rob = '0;
        rob_tag_from_cdb = '0;
        wb_data = '0;
        RS_is_full = '0;

        # (2 * CLK_PERIOD);
        
        // TEST 1: Example ALU instruction
        decoded_pack.valid = 1'b1;
        decoded_pack.fu = FU_ALU; 
        decoded_pack.arch_reg = 'h10;
        decoded_pack.alu_func = ALU_ADD; 
        decoded_pack.rs1_valid = 1'b1;
        decoded_pack.rs2_valid = 1'b1;
        decoded_pack.pc_valid = 1'b1;
        decoded_pack.pc = 32'h8000;
        registers[5'h10] = 32'h100;
        registers[5'h20] = 32'h200;
         
        # (10 * CLK_PERIOD);

        // TEST 2: Example Branch instruction
        decoded_pack.valid = 1'b1;
        decoded_pack.fu = FU_BTU;  
        decoded_pack.arch_reg = 'h30;
        decoded_pack.imm = 32'h5678;
        decoded_pack.rs1_valid = 1'b1;
        decoded_pack.rs2_valid = 1'b1;
        decoded_pack.pc_valid = 1'b1;
        decoded_pack.pc = 32'hA000;
 
        # (10 * CLK_PERIOD);
 
        # (10 * CLK_PERIOD);
        $finish;
    end
 
    initial begin
        $monitor("Time=%0t | stall=%b | inst_rs=%h | inst_rob=%h | RS_load=%b", 
                 $time, stall, inst_rs, inst_rob, RS_load);
    end

endmodule
