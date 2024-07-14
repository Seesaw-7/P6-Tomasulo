`timescale 1ns/100ps

module tb_reorder_buffer;

    parameter CLK_PERIOD = 10;

    // input
    logic clk;
    logic reset;
    logic dispatch;
    logic [`REG_ADDR_LEN-1:0] reg_addr_from_dispatcher;
    logic [`XLEN-1:0] npc_from_dispatcher;
    logic cdb_to_rob;
    logic [`ROB_TAG_LEN-1:0] rob_tag_from_cdb;
    logic [`XLEN-1:0] wb_data_from_cdb;
    logic [`XLEN-1:0] target_pc_from_cdb;
    logic mispredict_from_cdb;
    logic [`ROB_TAG_LEN-1:0] search_src1_rob_tag;
    logic [`ROB_TAG_LEN-1:0] search_src2_rob_tag;

    // output
    logic wb_en;
    logic [`REG_ADDR_LEN-1:0] wb_reg;
    logic [`XLEN-1:0] wb_data;
    logic flush;
    logic [`ROB_TAG_LEN-1:0] assign_rob_tag_to_dispatcher;
    logic rob_full_adv;
    logic [`XLEN-1:0] search_src1_data;
    logic [`XLEN-1:0] search_src2_data;
    ROB_ENTRY rob_curr [`ROB_SIZE-1:0];
    ROB_ENTRY rob_next [`ROB_SIZE-1:0]; // Added rob_next output
    logic [`ROB_TAG_LEN-1:0] retire_rob_tag;
    logic [`XLEN-1:0] commit_npc;

    // Instantiate the reorder_buffer module
    reorder_buffer dut (
        .clk(clk),
        .reset(reset),
        .dispatch(dispatch),
        .reg_addr_from_dispatcher(reg_addr_from_dispatcher),
        .npc_from_dispatcher(npc_from_dispatcher),
        .cdb_to_rob(cdb_to_rob),
        .rob_tag_from_cdb(rob_tag_from_cdb),
        .wb_data_from_cdb(wb_data_from_cdb),
        .target_pc_from_cdb(target_pc_from_cdb),
        .mispredict_from_cdb(mispredict_from_cdb),
        .search_src1_rob_tag(search_src1_rob_tag),
        .search_src2_rob_tag(search_src2_rob_tag),
        .wb_en(wb_en),
        .wb_reg(wb_reg),
        .wb_data(wb_data),
        .flush(flush),
        .assign_rob_tag_to_dispatcher(assign_rob_tag_to_dispatcher),
        .rob_full_adv(rob_full_adv),
        .search_src1_data(search_src1_data),
        .search_src2_data(search_src2_data),
        .rob_curr(rob_curr),
        .rob_next(rob_next), // Connect rob_next
        .retire_rob_tag(retire_rob_tag),
        .commit_npc(commit_npc)
    );

    always begin
        clk = 0;
        #(CLK_PERIOD / 2);
        clk = 1;
        #(CLK_PERIOD / 2);
    end

    initial begin
        reset = 1;
        dispatch = 0;
        reg_addr_from_dispatcher = 0;
        npc_from_dispatcher = 0;
        cdb_to_rob = 0;
        rob_tag_from_cdb = 0;
        wb_data_from_cdb = 0;
        target_pc_from_cdb = 0;
        mispredict_from_cdb = 0;
        search_src1_rob_tag = 0;
        search_src2_rob_tag = 0;

        #(2 * CLK_PERIOD);
        reset = 0;

        // dispatch instruction
        dispatch = 1;
        reg_addr_from_dispatcher = 5;
        npc_from_dispatcher = 32'h00001000;
        #(CLK_PERIOD);
        dispatch = 0;
        #(CLK_PERIOD);

        // CDB write-back
        cdb_to_rob = 1;
        rob_tag_from_cdb = 0;
        wb_data_from_cdb = 32'h12345678;
        target_pc_from_cdb = 32'h00002000;
        mispredict_from_cdb = 0;
        #(CLK_PERIOD);
        cdb_to_rob = 0;
        #(CLK_PERIOD);

        // dispatch another instruction
        dispatch = 1;
        reg_addr_from_dispatcher = 10;
        npc_from_dispatcher = 32'h00003000;
        #(CLK_PERIOD);
        dispatch = 0;
        #(CLK_PERIOD);

        // CDB write-back with misprediction
        cdb_to_rob = 1;
        rob_tag_from_cdb = 1;
        wb_data_from_cdb = 32'h87654321;
        target_pc_from_cdb = 32'h00004000;
        mispredict_from_cdb = 1;
        #(CLK_PERIOD);
        cdb_to_rob = 0;
        #(CLK_PERIOD);

        // search in ROB
        search_src1_rob_tag = 0;
        search_src2_rob_tag = 1;
        #(CLK_PERIOD);

        // end
        $finish;
    end

    // Monitor signals
    initial begin
        $monitor("Time: %0t, dispatch: %b, cdb_to_rob: %b, wb_en: %b, wb_reg: %0d, wb_data: %h, flush: %b, assign_rob_tag_to_dispatcher: %0d, rob_full_adv: %b, search_src1_data: %h, search_src2_data: %h, retire_rob_tag: %0d, commit_npc: %h",
                 $time, dispatch, cdb_to_rob, wb_en, wb_reg, wb_data, flush, assign_rob_tag_to_dispatcher, rob_full_adv, search_src1_data, search_src2_data, retire_rob_tag, commit_npc);
    end

    // Monitor ROB state
    initial begin
        $monitor("Time: %0t, rob_curr: %p, rob_next: %p",
                 $time, rob_curr, rob_next);
    end

endmodule
