module CDB (
    input logic clk,
    input logic reset,
    // Functional Unit outputs
    input logic [31:0] fu0_data,
    input logic [4:0] fu0_dest,
    input logic fu0_valid,

    input logic [31:0] fu1_data,
    input logic [4:0] fu1_dest,
    input logic fu1_valid,

    input logic [31:0] fu2_data,
    input logic [4:0] fu2_dest,
    input logic fu2_valid,

    input logic [31:0] fu3_data,
    input logic [4:0] fu3_dest,
    input logic fu3_valid,

    // Issue Unit signal indicating which FU to output
    input logic [1:0] issue_fu_select,

    // Outputs to Physical Register File
    output logic [4:0] prf_dest,
    output logic [31:0] prf_data,
    output logic prf_write_enable
);

    // Internal signals
    logic [31:0] selected_data;
    logic [4:0] selected_dest;
    logic selected_valid;

    // Mux to select data and destination from functional units based on issue_fu_select
    always_comb begin
        case (issue_fu_select)
            2'b00: begin
                selected_data = fu0_data;
                selected_dest = fu0_dest;
                selected_valid = fu0_valid;
            end
            2'b01: begin
                selected_data = fu1_data;
                selected_dest = fu1_dest;
                selected_valid = fu1_valid;
            end
            2'b10: begin
                selected_data = fu2_data;
                selected_dest = fu2_dest;
                selected_valid = fu2_valid;
            end
            2'b11: begin
                selected_data = fu3_data;
                selected_dest = fu3_dest;
                selected_valid = fu3_valid;
            end
            default: begin
                selected_data = 32'b0;
                selected_dest = 5'b0;
                selected_valid = 1'b0;
            end
        endcase
    end

    // Assign outputs
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            prf_dest <= 5'b0;
            prf_data <= 32'b0;
            prf_write_enable <= 1'b0;
        end else if (selected_valid) begin
            prf_dest <= selected_dest;
            prf_data <= selected_data;
            prf_write_enable <= 1'b1;
        end else begin
            prf_write_enable <= 1'b0;
        end
    end

endmodule
