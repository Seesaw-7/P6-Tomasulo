module ReservationStation #(
    parameter NUM_ENTRIES = 8,  // Number of entries in the reservation station
    parameter WIDTH = 32        // Width of the data
)(
    input logic clk,
    input logic reset,
    input logic [WIDTH-1:0] instruction_in,
    input logic [WIDTH-1:0] operand1_in,
    input logic [WIDTH-1:0] operand2_in,
    input logic operand1_ready,
    input logic operand2_ready,
    input logic dispatch,  // Signal to dispatch instruction to execution unit
    output logic [WIDTH-1:0] instruction_out,
    output logic [WIDTH-1:0] operand1_out,
    output logic [WIDTH-1:0] operand2_out,
    output logic dispatch_ready  // Indicates if an instruction is ready for dispatch
);

    // Define internal storage for instructions and operands
    typedef struct packed {
        logic [WIDTH-1:0] instruction;
        logic [WIDTH-1:0] operand1;
        logic [WIDTH-1:0] operand2;
        logic ready1;
        logic ready2;
        logic valid;
    } entry_t;

    entry_t entries [NUM_ENTRIES];

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all entries
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                entries[i].instruction <= 0;
                entries[i].operand1 <= 0;
                entries[i].operand2 <= 0;
                entries[i].ready1 <= 0;
                entries[i].ready2 <= 0;
                entries[i].valid <= 0;
            end
            dispatch_ready <= 0;
            instruction_out <= 0;
            operand1_out <= 0;
            operand2_out <= 0;
        end else begin
            // Add new instruction to reservation station
            if (dispatch) begin
                for (int i = 0; i < NUM_ENTRIES; i++) begin
                    if (!entries[i].valid) begin
                        entries[i].instruction <= instruction_in;
                        entries[i].operand1 <= operand1_in;
                        entries[i].operand2 <= operand2_in;
                        entries[i].ready1 <= operand1_ready;
                        entries[i].ready2 <= operand2_ready;
                        entries[i].valid <= 1;
                        break;
                    end
                end
            end

            // Check for ready instructions and dispatch
            dispatch_ready <= 0;
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                if (entries[i].valid && entries[i].ready1 && entries[i].ready2) begin
                    instruction_out <= entries[i].instruction;
                    operand1_out <= entries[i].operand1;
                    operand2_out <= entries[i].operand2;
                    dispatch_ready <= 1;
                    entries[i].valid <= 0;  // Clear the entry after dispatch
                    break;
                end
            end
        end
    end

    // Additional logic to handle operand forwarding, etc., can be added here

endmodule
