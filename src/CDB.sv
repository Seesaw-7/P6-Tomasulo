`timescale 1ns/1ps

module CDB (
    input logic [4:0] ROB_tag,           // ROB tag input
    input INST_DECODED inst,             // Decoded instruction input

    // Results from functional units
    input RESULT [4:0] in_results,       // Array of 5 results from functional units

    // Signals from issue unit
    input logic select_flag,             // Flag to indicate if selection is valid
    input logic [2:0] select,            // Select signal to choose the result

    // Output signals
    output logic out_select_flag,        // Select flag output

    // Output to ROB
    output logic [4:0] out_ROB_tag,      // ROB tag output
    output INST_DECODED out_inst,        // Decoded instruction output
    output RESULT out_result,            // Result output

    // Output to reg file
    output logic [4:0] out_addr,         // Address output to register file
    output logic [`XLEN-1:0] out_value   // Value output to register file
);

    always_comb begin
        // Pass through the ROB tag, instruction, and select flag
        out_ROB_tag = ROB_tag;
        out_inst = inst;
        out_select_flag = select_flag;

        if (select_flag) begin
            // Select the appropriate result based on the select signal
            case (select)
                3'b000: out_result = in_results[0];
                3'b001: out_result = in_results[1];
                3'b010: out_result = in_results[2];
                3'b011: out_result = in_results[3];
                3'b100: out_result = in_results[4];
                default: out_result = in_results[0];
            endcase

            // Assuming RESULT type has addr and value fields
            out_addr = out_result.addr;
            out_value = out_result.value;
        end else begin
            // Default values when select_flag is not set
            out_result = '0;
            out_addr = 5'b0;
            out_value = '0;
        end
    end

endmodule
