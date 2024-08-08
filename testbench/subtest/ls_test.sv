`timescale 1ns/100ps
`include "sys_defs.svh"
`include "ls_queue.svh"
`include "ls_unit.svh"
`include "dispatcher.svh"

module load_store_test;

    // Parameters
    parameter CACHE_SIZE = 256;
    parameter MSHR_SIZE = 4; 

    // Common signals
    logic clk;
    logic reset;

    // LS Queue signals
    logic flush;
    logic dispatch;
    INST_RS insn_in;
    logic commit_store;
    logic [`ROB_TAG_LEN-1:0] commit_store_rob_tag;
    logic [`ROB_TAG_LEN-1:0] forwarding_rob_tag;
    logic [`XLEN-1:0] forwarding_data;
    logic done_from_ls_unit;
    logic to_ls_unit;
    LS_UNIT_PACK insn_out_to_ls_unit;

    // LS Unit signals
    LS_UNIT_PACK ls_unit_insn_in;
    logic ls_unit_en;
    logic ls_unit_mem_hit;
    logic [`XLEN-1:0] ls_unit_load_data;
    BUS_COMMAND ls_unit_mem_command;
    logic [`XLEN-1:0] ls_unit_mem_addr;
    MEM_SIZE ls_unit_mem_size;
    logic [`XLEN-1:0] ls_unit_proc2Dmem_data;
    logic [`XLEN-1:0] ls_unit_wb_data;
    logic [`ROB_TAG_LEN-1:0] ls_unit_inst_tag;
    logic ls_unit_done;

    // D-Cache signals
    logic [`XLEN-1:0] dcache_addr;
    logic [`XLEN-1:0] dcache_write_data;
    MEM_SIZE dcache_mem_size;
    BUS_COMMAND dcache_command;
    logic [`XLEN-1:0] dcache_read_data;
    logic dcache_valid;
    logic [`XLEN-1:0] dcache_mem_addr;
    logic [`XLEN-1:0] dcache_mem_write_data;
    BUS_COMMAND dcache_mem_command;
    MEM_SIZE dcache_mem_size_out;

    // Main Memory signals
    logic [3:0] mem_response;
    logic [`XLEN-1:0] mem_read_data;
    logic [3:0] mem_tag;

    // Instantiate modules
    ls_queue ls_queue_inst (
        .clk(clk),
        .reset(reset),
        .flush(flush),
        .dispatch(dispatch),
        .insn_in(insn_in),
        .commit_store(commit_store),
        .commit_store_rob_tag(commit_store_rob_tag),
        .forwarding_rob_tag(forwarding_rob_tag),
        .forwarding_data(forwarding_data),
        .done_from_ls_unit(done_from_ls_unit),
        .to_ls_unit(to_ls_unit),
        .insn_out_to_ls_unit(insn_out_to_ls_unit)
    );

    ls_unit ls_unit_inst (
        .insn_in(ls_unit_insn_in),
        .en(ls_unit_en),
        .mem_hit(ls_unit_mem_hit),
        .load_data(ls_unit_load_data),
        .mem_command(ls_unit_mem_command),
        .mem_addr(ls_unit_mem_addr),
        .mem_size(ls_unit_mem_size),
        .proc2Dmem_data(ls_unit_proc2Dmem_data),
        .wb_data(ls_unit_wb_data),
        .inst_tag(ls_unit_inst_tag),
        .done(ls_unit_done)
    );

    D_Cache #(
        .CACHE_SIZE(CACHE_SIZE),
        .MSHR_SIZE(MSHR_SIZE)
    ) dcache_inst (
        .clk(clk),
        .rst(reset),
        .proc2cache_addr(dcache_addr),
        .proc2cache_data(dcache_write_data),
        .proc2cache_size(dcache_mem_size),
        .proc2cache_command(dcache_command),
        .cache2proc_data(dcache_read_data),
        .cache2proc_valid(dcache_valid),
        .cache2mem_addr(dcache_mem_addr),
        .cache2mem_data(dcache_mem_write_data),
        .cache2mem_command(dcache_mem_command),
        .cache2mem_size(dcache_mem_size_out),
        .mem2cache_response(mem_response),
        .mem2cache_data(mem_read_data),
        .mem2cache_tag(mem_tag)
    );

    // Connect modules
    assign ls_unit_insn_in = insn_out_to_ls_unit;
    assign ls_unit_en = to_ls_unit;
    assign ls_unit_mem_hit = dcache_valid;
    assign ls_unit_load_data = dcache_read_data;

    assign dcache_addr = ls_unit_mem_addr;
    assign dcache_write_data = ls_unit_proc2Dmem_data;
    assign dcache_mem_size = ls_unit_mem_size;
    assign dcache_command = ls_unit_mem_command;
    assign done_from_ls_unit = ls_unit_done;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test procedure
    initial begin
        // Initialize
        reset = 1;
        flush = 0;
        dispatch = 0;
        insn_in = '0;
        commit_store = 0;
        commit_store_rob_tag = '0;
        forwarding_rob_tag = '0;
        forwarding_data = '0;
        mem_response = 0;
        mem_read_data = '0;
        mem_tag = 0;

        // Apply reset
        #20 reset = 0;

        // Test case 1: Load operation
        #10 dispatch = 1;
        insn_in.fu = FU_LSU;
        insn_in.func = LS_LOAD;
        insn_in.insn_tag = 5'd1;
        insn_in.tag_dest = 5'd10;
        insn_in.tag_src1 = 5'd6;
        insn_in.tag_src2 = 5'd7;
        insn_in.ready_src1 = 1;
        insn_in.value_src1 = 32'h1000; // Base address
        insn_in.ready_src2 = 1;
        insn_in.value_src2 = 32'h0;
        insn_in.imm = 32'h4; // Offset
        insn_in.pc = 32'h1000;
        insn_in.func3 = WORD; // Word size
        #10 dispatch = 0;

        // Simulate memory response
        #20 mem_response = 4'd1;
        mem_read_data = 32'h12345678;
        mem_tag = 4'd1;

        // Wait for operation to complete
        wait(ls_unit_done);
        #20;

        // Test case 2: Store operation
        #10 dispatch = 1;
        insn_in.fu = FU_LSU;
        insn_in.func = LS_STORE;
        insn_in.insn_tag = 5'd2;
        insn_in.tag_dest = 5'd11; // No destination for store
        insn_in.tag_src1 = 5'd8;
        insn_in.tag_src2 = 5'd9;
        insn_in.ready_src1 = 1;
        insn_in.value_src1 = 32'h2000; // Base address
        insn_in.ready_src2 = 1;
        insn_in.value_src2 = 32'hDEADBEEF; // Data to store
        insn_in.imm = 32'h8; // Offset
        insn_in.pc = 32'h1004;
        insn_in.func3 = HALF; // Word size
        commit_store = 1;
        commit_store_rob_tag = 5'd2;
        #10 dispatch = 0;

        // Simulate memory response
        #20 mem_response = 4'd2;
        mem_tag = 4'd2;
        #10 commit_store = 0;

        // Wait for operation to complete
        wait(ls_unit_done);
        #20;

        // End simulation
        #100 $finish;
    end

    // Monitor
    always @(posedge clk) begin
        if (ls_unit_done) begin
            if (ls_unit_insn_in.mem_command == BUS_LOAD)
                $display("Load completed: Address = 0x%h, Data = 0x%h, Tag = %d", ls_unit_mem_addr, ls_unit_wb_data, ls_unit_inst_tag);
            else if (ls_unit_insn_in.mem_command == BUS_STORE)
                $display("Store completed: Address = 0x%h, Data = 0x%h, Tag = %d", ls_unit_mem_addr, ls_unit_proc2Dmem_data, ls_unit_inst_tag);
        end
    end

endmodule
