`timescale 1ns/100ps

module dispatcher_tb;

    localparam CLK_PERIOD = 10;  

    logic clk;
    logic reset;
    logic stall;
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

    // Outputs
    INST_RS inst_rs;
    INST_ROB inst_rob;
    logic unsigned [3:0] RS_is_full;
 
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
        .RS_is_full(RS_is_full)
    );
  
    always #CLK_PERIOD clk = ~clk;
 
    initial begin
        clk = 0;
        reset = 1;
        stall = 0;
 
        decoded_pack = '0;
        registers = '0;
        rob = '{default: '0};
        assign_rob_tag = 0;
        return_flag = 0;
        ready_flag = 0;
        rob_tag_from_rob = 0;
        reg_addr_from_rob = 0;
        rob_tag_from_cdb = 0;
        wb_data = 0;
 
        #20 reset = 0;

        // Test 1: Test an ALU instruction 
        registers[5'h1] = 32'h100;  

        decoded_pack.fu = FU_ALU;  
        decoded_pack.func = 5'h02; 
        decoded_pack.src1.reg_addr = 5'h1;  
        decoded_pack.src2.data_stat = 2'b00;  
        decoded_pack.src2.reg_addr = 5'h2;  
        decoded_pack.arch_reg = 32'h20;  
  
        always @(posedge clk) begin
            $display("Cycle %0t: stall=%b, inst_rs=%h, inst_rob=%h", $time, stall, inst_rs, inst_rob);
        end
 
        #100;
 
        #1000;
        $finish;
    end

endmodule