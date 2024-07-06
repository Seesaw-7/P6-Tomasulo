`timescale 1ns/1ps

module issue_unit #(
    parameter int FU_NUM = 5  // Number of functional units
) (
    input logic clk,
    input logic reset,
    input logic [FU_NUM-1:0] done,           // Functional units' done signals
    output logic select_flag,                // Flag indicating a selection has been made, output to CDB and FU
    output logic [FU_NUM-1:0] select_signal  // One-hot encoded select signal for functional units, output to CDB and FU
);

    // Internal state to keep track of the round-robin pointer
    logic [$clog2(FU_NUM)-1:0] pointer;

    // Initialize the pointer at the start
    initial begin
        pointer = 0;
    end

    // Round-robin selection logic
    always_ff @(posedge clk) begin
        if (reset) begin
            pointer <= 0;
            select_flag <= 0;
            select_signal <= {FU_NUM{1'b0}};
        end else begin
            select_flag <= 0;
            select_signal <= {FU_NUM{1'b0}};

            // Iterate through the requests in a round-robin manner
            for (int i = 0; i < FU_NUM; i++) begin
                // Calculate the index to check
                int idx = (pointer + i) % FU_NUM;

                // Check if the request at the current index is done
                if (done[idx] == 1) begin
                    select_flag <= 1;
                    select_signal[idx] <= 1;  // Set the corresponding bit in select_signal
                    pointer <= (idx + 1) % FU_NUM;  // Update the pointer for the next round
                    break;
                end
            end
        end
    end
endmodule
