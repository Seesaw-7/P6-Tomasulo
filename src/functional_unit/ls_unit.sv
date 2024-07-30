`timescale 1ns / 100ps

`include "sys_defs.svh"
`include "ls_unit.svh"

module ls_unit(
    // input [`XLEN-1:0] opa,
    // input [`XLEN-1:0] opb, //Iimm for LW, Simm for SW
    input LS_UNIT_PACK insn_in, 
    input logic en, 
    input logic mem_hit, // from mem; hit or miss
    input [`XLEN-1:0] load_data, // load from mem

    output logic mem_read,
    output logic mem_write, 
    output [`XLEN-1:0] mem_addr, 
    output [2:0] mem_size,
    output [`XLEN-1:0] proc2Dmem_data,
    output [`XLEN-1:0] wb_data, // load from mem
    output [`ROB_TAG_LEN-1:0] inst_tag, 
    output logic done
);
   
    wire [`XLEN-1:0] data_from_mem, unsigned_result;  
    wire signed signed_result;
    
    always_comb begin
        if (en == 1'b1) begin
            mem_addr = insn_in.value_src1 + insn_in.imm;
            mem_size = insn_in.func3; 
            
            // load
            if (insn_in.read_write == 1'b1) begin
                mem_read = 1'b1;
                mem_write = 1'b0;
                if (mem_hit == 1'b1) begin
                    data_from_mem = load_data; 
                    signed_result = $signed(data_from_mem); // 32'(signed'(data_from_mem)) 
                    unsigned_result = data_from_mem;
                    if (insn_in.func == LS_LOAD) begin
                        wb_data = signed_result;
                    end
                    else if (insn_in.func == LS_LOADU) begin
                        wb_data = unsigned_result;
                    end
                    else begin
                        wb_data = {`XLEN{1'b0}};
                    end
                end
            end
            // store
            else begin
                mem_read = 1'b0;
                mem_write = 1'b1;
                proc2Dmem_data = insn_in.value_src2; 
            end
            done = mem_hit;
            inst_tag = insn_in.insn.insn_tag;
        end
    end
    
endmodule
