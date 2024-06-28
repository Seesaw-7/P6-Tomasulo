// note: 
// the outside logic (issue unit) will need to decide whether to issue one instruction
// when the issue signal == 1, it will begin to find a ready instruction
// when it is found, it will output the insn and set the issue_ready to 1
// thus, the issue signal should hold until issue_ready == 1 to avoid issuing twice without output 

// wakeup will be done the same time as the insn is output, namely we assume dst will be ready within one clock cycle
// TODO: revise wakeup if necessary (after other components are done)
// revise method: add a new entry to the entry_t so that it records how many clock cycles it will be ready 

// load signal is set by dispatcher
// when the issue queue is not full && load == 1, it will load in one packet of input and set loaded to 1
// thus, the load signal should be set (for one clock cycle) only if is_full signal is not equal to 1
// otherwise, the input will be discarded
// with this design, when the issue queue is full and one insn can be output, while another insn wants to be loaded in,
// it will delay loading for one clock 

// if immi is used, then inp2 should be 5'b0, which is always ready

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
    input logic [REG_ADDR_WIDTH-1:0] inp1, inp2, dst, // previous renaming unit ensures that dst != inp1 and dst != inp2

    // output signals
    output logic issue_ready, // indicates if an instruction is ready to be executed
    output logic is_full, // all entries of the reservation station is occupied, cannot load in more inputs

    // output data
    output logic [NUM_ENTRIES-1:0] insn_out,
    output logic [REG_ADDR_WIDTH-1:0] inp1_out, inp2_out, dst_out
);


    // the only two internal storages that need to be updated with sequential logic
    issue_queue_entry_t1 entries [NUM_ENTRIES]; // TODO: check syntax
    logic [REG_NUM-1:0] ready_table;


    // internal signals below are all updated with combinational logic
    logic [ENTRY_WIDTH:0] num_entry_used; // can be 0,1,2,3,4, so ENTRY_WIDTH do not need to be decremented by 1
    // TODO: check syntax
    always_comb begin
        num_entry_used = 0;
        for (int i = 0; i < NUM_ENTRIES; i++) begin
            if (entries[i].valid) begin
                num_entry_used++;
            end else
                ;
        end
    end

    assign is_full = num_entry_used == NUM_ENTRIES;

    logic [NUM_ENTRIES-1:0] ready_flags; // if this insn is ready
    // TODO: check syntax
    generate
        genvar i;
        for (i = 0; i < NUM_ENTRIES; i++) begin : check_ready
        assign ready_flags[i] = entries[i].valid && entries[i].ready1 && entries[i].ready2;
        end
    endgenerate

    logic exist_ready_out;
    // TODO: check syntax
    assign exist_ready_out = |ready_flags; // reduction OR to check if any entry is ready  

    logic [ENTRY_WIDTH-1:0] min_Bday, min_idx; // min Bday of ready entries and its corresponding index  
    //TODO: check syntax
    always_comb begin
        min_Bday = {ENTRY_WIDTH{1'b1}}; // initialize to maximum value
        min_idx = 0; // Initialize to 0
        for (int i = 0; i < NUM_ENTRIES; i++) begin
            if (ready_flags[i] && (entries[i].Bday <= min_Bday)) begin
                min_Bday = Bday[i];
                min_idx = i;
            end else
                ;
        end
    end


    always_ff @(posedge clk) begin
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
            dst_out <= 0;
        end else begin
            // add new instruction to reservation station
            if (load && ~is_full) begin //TODO: add else
                for (int i = 0; i < NUM_ENTRIES; i++) begin // it's for sure that an empty entry exists
                    if (!entries[i].valid) begin
                        entries[i].insn <= insn;
                        entries[i].inp1 <= inp1;
                        entries[i].inp2 <= inp2;
                        entries[i].ready1 <= ready_table[inp1];
                        entries[i].ready2 <= ready_table[inp2];
                        entries[i].dst <= dst;
                        if (issue && exist_ready_out)
                            entries[i].Bday <= num_entry_used - 1;
                        else 
                            entries[i].Bday <= num_entry_used;
                        entries[i].valid <= 1;
                        break;
                    end else
                        ;
                end

                // update ready table
                if (dst == 0) // reg0 should always be 0, so always ready
                    ready_table[dst] <= 1;
                else 
                    ready_table[dst] <= 0;

                // we do not need to update exsiting valid entries whose inp1 == dst or inp2 ==dst
                // namely ready1 and ready2 for existing entries do not need to be updated
                // because earlier insns must not depend on later insns

            end else begin
                ;
            end

            // issue insn
            if (issue) begin
                if (exist_ready_out) begin

                    //output insn
                    insn_out <= entries[min_idx].insn;
                    inp1_out <= entries[min_idx].inp1;
                    inp2_out <= entries[min_idx].inp2;
                    dst_out <= entries[min_idx].dst;
                    entries[min_idx].valid <= 0; 
                    issue_ready <= 1;

                    // update Bday if it is younger than the output insn
                    for (int i = 0; i < NUM_ENTRIES; i++) begin
                        if (entries[i].valid && entries[i].Bday > min_Bday) begin
                            entries[i].Bday <= entries[i].Bday - 1; // Bday: the smallest, the oldes
                        end
                    end      

                    // wakeup other insns if their inp is equal to the dst of the output insn
                    ready_table[entries[min_idx].dst] <= 1; // No two entries with the same dst would exist in issue queue
                    for (int i = 0; i < NUM_ENTRIES; i++) begin
                        if (entries[i].valid && entries[i].inp1 == entries[min_idx].dst) begin
                            entries[i].ready1 <= 1; // Bday: the smallest, the oldest
                        end else if (entries[i].valid && entries[i].inp2 == entries[min_idx].dst) begin
                            entries[i].ready2 <= 1;
                        end
                        else
                            ;
                    end                    
                end else begin
                    issue_ready <= 0;
                end
            end else begin
                issue_ready <= 0;
            end
        end
    end


endmodule
