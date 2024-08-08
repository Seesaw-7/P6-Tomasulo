`timescale 1ns / 100ps

`include "sys_defs.svh"
`include "ls_unit.svh"
`include "ls_queue.svh"


// TODO: edit sign extension
// TODO: check hit/miss logic

module ls_unit(
    input LS_UNIT_PACK insn_in, 
    input logic en, 
    input logic mem_hit, // from mem; hit or miss
    input [`XLEN-1:0] load_data, // load from mem

    output logic mem_read,
    output logic mem_write, 
    output logic [`XLEN-1:0] mem_addr, 
    output logic [2:0] func3,
    output logic [`XLEN-1:0] proc2Dmem_data,
    output logic [`XLEN-1:0] wb_data, // load from mem
    output logic [`ROB_TAG_LEN-1:0] inst_tag, 
    output logic done
);
    
    logic [`XLEN-1:0] data_from_mem, unsigned_result;  
    logic signed [`XLEN-1:0] signed_result;
    
    always_comb begin
        // Default values
        mem_command = BUS_NONE;
        mem_addr = '0;
        func3 = 3'b0;
        proc2Dmem_data = '0;
        wb_data = '0;
        inst_tag = '0;
        done = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;

        if (en == 1'b1) begin
            mem_addr = insn_in.insn.value_src1 + insn_in.insn.imm;
            func3 = insn_in.insn.func3; 
            mem_command = insn_in.mem_command; // Use the mem_command from insn_in
            
            // load
            if (insn_in.read_write == 1'b1) begin
                mem_read = 1'b1;
                mem_write = 1'b0;
                if (mem_hit == 1'b1) begin
                    wb_data = load_data; 
                end
            end
            // store
            else begin
                mem_read = 1'b0;
                mem_write = 1'b1;
                proc2Dmem_data = insn_in.insn.value_src2; 
            end
            done = mem_hit;
            inst_tag = insn_in.insn.insn_tag;
        end
    end
    
endmodule
