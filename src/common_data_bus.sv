`timescale 1ns/1ps

// P6 style Description: 
// The CDB (Common Data Bus) module selects and broadcasts results from functional units (FUs) to 
// the reorder buffer (ROB) and reservation station. It takes inputs from functional units and the issue unit, 
// selects the appropriate result based on a select signal, and outputs the result to the reservation station and ROB.

// Inputs:
// - in_results (RESULT [FU_NUM-1:0]): Array of results from functional units.
// - select_flag (logic): Indicates if selection is valid.
// - select_signal (logic [FU_NUM-1:0]): One-hot encoded signal selecting which result to output.

// Outputs:
// - out_select_flag (logic): Passes through the input select flag.
// - out_ROB_tag (logic [4:0]): Passes through the input ROB tag.
// - out_result (RESULT): Selected result output from functional units.
// - out_value (logic [`XLEN-1:0]): Value output to the RS.

module common_data_bus #(
    parameter int FU_NUM = 5  // Number of functional units
) (
    // input logic [FU_NUM:0] ROB_tag,           // ROB tag input

    // Results from functional units
    input RESULT [FU_NUM-1:0] in_results, // Array of results from functional units

    // Signals from issue unit
    input logic select_flag,              // Flag to indicate if selection is valid
    input logic [FU_NUM-1:0] select_signal, // One-hot encoded signal to choose the result

    // Output signals
    output logic out_select_flag,         // Select flag output

    // Output to ROB
    output logic [FU_NUM:0] out_ROB_tag,       // ROB tag output, to ROB and RS
    output RESULT out_result,             // Result output

    // Output to reservation station
    output logic [`XLEN-1:0] out_value    // Value output to register file
);

    always_comb begin
        // Pass through the ROB tag and select flag
        // out_ROB_tag = ROB_tag;
        out_select_flag = select_flag;
        
        // Default values when select_flag is not set
        out_result = '0;
        out_value = '0;
        out_ROB_tag = '0;

        if (select_flag) begin
            // Select the appropriate result based on the select signal
            for (int i = 0; i < FU_NUM; i++) begin
                if (select_signal[i]) begin
                    out_result = in_results[i];
                    out_value = in_results[i].value;  // Assuming RESULT type has a value field
                    out_ROB_tag = in_results[i].ROB_tag; // Assuming RESULT type has a ROB_tag field
                end
            end
        end
    end

endmodule
