`timescale 1ns/1ps

// P6 style Description: 
// The CDB (Common Data Bus) module selects and broadcasts results from functional units (FUs) to 
// the reorder buffer (ROB) and reservation station. It takes inputs from functional units and the issue unit, 
// selects the appropriate result based on a select signal, and outputs the result to the reservation station and ROB.

// Inputs:
// - in_values ([`XLEN-1:0] [FU_NUM-1:0]): Array of results from functional units.
// - ROB_tag：bypass to ROB, forward to RS
// - select_flag (logic): Indicates if selection is valid, bypass to ROB
// - select_signal (logic [$clog2(FU_NUM)-1:0]): signal selecting which result to output.

// Outputs:
// - out_select_flag (logic): Passes through the input select flag.
// - out_ROB_tag (logic [4:0]): Passes through the input ROB tag, bypass to ROB, forward to RS
// - out_value (logic [`XLEN-1:0]): Value output to the ROB, forward to RS.

module common_data_bus #(
    parameter int FU_NUM = 4  // Number of functional units
) (

    // Results from functional units
    input logic [`XLEN-1:0] [FU_NUM-1:0] in_values, // Array of results from functional units

    // Signals from issue unit
    input logic select_flag,              // Flag to indicate if selection is valid
    input logic [$clog2(FU_NUM)-1:0] select_signal, // signal to choose the result

    // Data from issue unit
    input logic [`ROB_TAG_LEN-1:0] ROB_tag,           // ROB tag input

    // Output signals
    output logic out_select_flag,         // Select flag output

    // Output to ROB and Forward to RS
    output logic [`ROB_TAG_LEN-1:0] out_ROB_tag,       // ROB tag output, to ROB and RS
    output logic [`XLEN-1:0] out_value,             // Result output
);

    always_comb begin
        // Pass through the ROB tag and select flag
        // out_ROB_tag = ROB_tag;
        out_select_flag = select_flag;
        
        // Default values when select_flag is not set
        out_value = '0;
        out_ROB_tag = '0;

        if (select_flag) begin
            // Select the appropriate result based on the select signal
            for (int i = 0; i < FU_NUM; i++) begin
                if (select_signal == i) begin
                    out_value = in_values[i];
                    out_ROB_tag = ROB_tag; 
                end
            end
        end
    end

endmodule
