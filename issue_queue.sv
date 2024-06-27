// note: 
// the outside logic (issue unit) will need to decide whether to issue one instruction
// when the issue signal == 1, it will begin to find a ready instruction
// when it is found, it will output the insn and set the issue_ready to 1
// thus, the issue signal should hold until issue_ready == 1 to avoid issuing twice without output 

// wakeup will be done the same time as the insn is output, namely we assume dst will be ready within one clock cycle
// TODO: revise wakeup if necessary (after other components are done)

// load signal is set by dispatcher
// when the issue queue is not full && load == 1, it will load in one packet of input and set loaded to 1
// thus, the load signal should be set (for one clock cycle) only if is_full signal is not equal to 1
// otherwise, the input will be discarded
// with this design, when the issue queue is full and one insn can be output, while another insn wants to be loaded in,
// it will delay loading for one clock cycle

// TODO: import issue_queue.svh

module issue_queue #(
    parameter NUM_ENTRIES = 4, // #entries in the reservation station
    parameter ENTRY_WIDTH = 2, // #entries = 2^{ENTRY_WIDTH}
    parameter REG_ADDR_WIDTH = 5,
    parameter REG_NUM = 32
)(
    // control signals
    input logic clk,
    input logic reset,
    input logic load, // whether we load in the instruction (assigned by dispatcher)
    input logic issue, // whether the issue queue should output one instruction (assigned by issue unit)
    // input logic wakeup, // set by outside logic, indicating whether to set the ready bit of previously issued dst reg to Yes

    // input data
    input ALU1_FUNC insn, 
    input logic [REG_ADDR_WIDTH-1:0] inp1, inp2, dst,

    // output signals
    output logic issue_ready, // indicates if an instruction is ready to be executed
    output logic is_full, // all entries of the reservation station is occupied, cannot load in more inputs

    // output data
    output logic [NUM_ENTRIES-1:0] insn_out,
    output logic [REG_ADDR_WIDTH-1:0] inp1_out, inp2_out
);

    issue_queue_entry_t1 entries [NUM_ENTRIES]; // TODO: check syntax
    // ready_bits_t ready_table [REG_NUM];
    logic [REG_NUM-1:0] ready_table;
    logic [ENTRY_WIDTH-1:0] num_entry_used; // internal reg for is_full signal

    assign is_full = num_entry_used == NUM_ENTRIES;

    always_ff @(posedge clk or posedge reset) begin // TODO: check this async reset after other components are done
        if (reset) begin
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                entries[i].insn <= 0;
                entries[i].inp1 <= 0;
                entries[i].inp2 <= 0;
                entries[i].ready1 <= 0;
                entries[i].ready2 <= 0;
                entries[i].dst <= 0;
                entries[i].Bday <= 0;
                entries[i].valid <= 0;
            end
            for (int i = 0; i < REG_NUM; i++) begin
                ready_table[i] <= 1;
            end
            issue_ready <= 0;
            num_entry_used <= 0;
            insn_out <= 0;
            inp1_out <= 0;
            inp2_out <= 0;
        end else begin
            // Add new instruction to reservation station
            // if (load && ~is_full) begin
            //     for (int i = 0; i < NUM_ENTRIES; i++) begin
            //         if (!entries[i].valid) begin
            //             entries[i].instruction <= instruction_in;
            //             entries[i].operand1 <= operand1_in;
            //             entries[i].operand2 <= operand2_in;
            //             entries[i].ready1 <= operand1_ready;
            //             entries[i].ready2 <= operand2_ready;
            //             entries[i].valid <= 1;
            //             break;
            //         end
            //     end
            // end

            // // Check for ready instructions and dispatch
            // dispatch_ready <= 0;
            // for (int i = 0; i < NUM_ENTRIES; i++) begin
            //     if (entries[i].valid && entries[i].ready1 && entries[i].ready2) begin
            //         instruction_out <= entries[i].instruction;
            //         operand1_out <= entries[i].operand1;
            //         operand2_out <= entries[i].operand2;
            //         dispatch_ready <= 1;
            //         entries[i].valid <= 0;  // Clear the entry after dispatch
            //         break;
            //     end
            // end
        end
    end

    // Additional logic to handle operand forwarding, etc., can be added here

endmodule
