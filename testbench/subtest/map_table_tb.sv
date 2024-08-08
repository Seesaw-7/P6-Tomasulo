`timescale 1ns/100ps

module tb_map_table;

    parameter CLK_PERIOD = 10;

    // input
    logic clk;
    logic reset;
    ARCH_REG arch_reg;
    logic assign_flag;
    logic return_flag;
    logic ready_flag;
    logic [`ROB_TAG_LEN-1:0] assign_rob_tag;
    logic [`REG_ADDR_LEN-1:0] reg_addr_from_rob;
    logic [`ROB_TAG_LEN-1:0] rob_tag_from_rob;
    logic [`ROB_TAG_LEN-1:0] rob_tag_from_cdb;

    // output
    RENAMED_PACK renamed_pack;
    MAP_ENTRY map_table_curr [`REG_NUM-1:0];
    MAP_ENTRY map_table_next [`REG_NUM-1:0];

    map_table dut (
        .clk(clk),
        .reset(reset),
        .arch_reg(arch_reg),
        .assign_flag(assign_flag),
        .return_flag(return_flag),
        .ready_flag(ready_flag),
        .assign_rob_tag(assign_rob_tag),
        .reg_addr_from_rob(reg_addr_from_rob),
        .rob_tag_from_rob(rob_tag_from_rob),
        .rob_tag_from_cdb(rob_tag_from_cdb),
        .renamed_pack(renamed_pack),
        .map_table_curr(map_table_curr),
        .map_table_next(map_table_next)
    );

    always begin
        clk = 0;
        #(CLK_PERIOD / 2);
        clk = 1;
        #(CLK_PERIOD / 2);
    end

    initial begin
        reset = 1;
        arch_reg = '{default: 0};
        assign_flag = 0;
        return_flag = 0;
        ready_flag = 0;
        assign_rob_tag = 0;
        reg_addr_from_rob = 0;
        rob_tag_from_rob = 0;
        rob_tag_from_cdb = 0;

        #(2 * CLK_PERIOD);
        reset = 0;

        // assign a ROB tag to a destination register
        arch_reg.dest = 5;
        assign_rob_tag = 6;
        assign_flag = 1;
        #(2 * CLK_PERIOD);
        assign_flag = 0;

        // mark the assigned ROB tag as ready
        rob_tag_from_cdb = 6;
        ready_flag = 1;
        #(2 * CLK_PERIOD);
        ready_flag = 0;

        // return a register to the architectural state
        reg_addr_from_rob = 5;
        rob_tag_from_rob = 6;
        return_flag = 1;
        #(2 * CLK_PERIOD);
        return_flag = 0;

        // assign another ROB tag to a different destination register
        arch_reg.dest = 10;
        assign_rob_tag = 15;
        assign_flag = 1;
        #(2 * CLK_PERIOD);
        assign_flag = 0;

        // mark the new ROB tag as ready
        rob_tag_from_cdb = 15;
        ready_flag = 1;
        #(2 * CLK_PERIOD);
        ready_flag = 0;
        
        // assign another ROB tag to a different destination register
        arch_reg.dest = 11;
        assign_rob_tag = 16;
        assign_flag = 1;
        #(2 * CLK_PERIOD);
        assign_flag = 0;
        
        // reg renaming check
        arch_reg.dest = 12;
        arch_reg.src1 = 10;
        arch_reg.src2 = 11;
        assign_rob_tag = 17;
        assign_flag = 1;
        #(2 * CLK_PERIOD);
        assign_flag = 0;
        // end
        $finish;
    end

    // output signals (monitor)
    initial begin
        $monitor("Time: %0t\narch_reg: %0h\nassign_flag: %b\nreturn_flag: %b\nready_flag: %b\nrenamed_pack: %0h\nmap_table_curr: %0p\nmap_table_next: %0p\n",
                 $time, arch_reg, assign_flag, return_flag, ready_flag, renamed_pack, map_table_curr, map_table_next);
    end

endmodule
