// note: 
// the outside logic (issue unit) will need to decide whether to issue one instruction
// when the issue signal == 1, it will begin to find a ready instruction
// when it is found, it will output the insn and set the issue_ready to 1
// thus, the issue signal should hold until issue_ready == 1 to avoid issuing twice without output 

// load signal is set by dispatcher
// when the issue queue is not full && load == 1, it will load in one packet of input and set loaded to 1
// thus, the load signal should be set (for one clock cycle) only if is_full signal is not equal to 1
// otherwise, the input will be discarded

// TODO: import issue_queue.svh

module issue_queue #(
    parameter NUM_ENTRIES = 4, // #entries in the reservation station
    parameter REG_ADDR_WIDTH = 5,
)(
    // control signals
    input logic clk,
    input logic reset,
    input logic load, // whether we load in the instruction (assigned by dispatcher)
    input logic issue, // whether the issue queue should output one instruction (assigned by issue unit)

    // input data
    input ALU1_FUNC insn, 
    input logic [REG_ADDR_WIDTH-1:0] inp1, inp2, dst,

    // output signals
    output logic issue_ready, // indicates if an instruction is ready to be executed
    output logic is_full, // all entries of the reservation station is occupied, cannot load in more inputs

    // output data
    output logic [NUM_ENTRIES:0] insn_out,
    output logic [REG_ADDR_WIDTH-1:0] inp1_out, inp2_out
);

    issue_queue_entry_t1 entries [NUM_ENTRIES]; // TODO: check syntax

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
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
