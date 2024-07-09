`timescale 1ns/100ps
`ifndef NUM_STAGE
`define NUM_STAGE 8
`endif
// This is an 8 stage (9 depending on how you look at it) pipelined 
// multiplier that multiplies 2 64-bit integers and returns the low 64 bits 
// of the result.  This is not an ideal multiplier but is sufficient to 
// allow a faster clock period than straight *
// This module instantiates 8 pipeline stages as an array of submodules.
module multiplier #(
	parameter N = `NUM_STAGE
) (
				input clock, reset,
				input [63:0] mcand, mplier,
				input start,
				
				output [63:0] product,
				output done
			);

  logic [63:0] mcand_out, mplier_out;
  logic [((N-1)*64)-1:0] internal_products, internal_mcands, internal_mpliers;
  logic [(N-2):0] internal_dones;
  
	mult_stage #(N) mstage [(N-1):0]  (
		.clock(clock),
		.reset(reset),
		.product_in({internal_products,64'h0}),
		.mplier_in({internal_mpliers,mplier}),
		.mcand_in({internal_mcands,mcand}),
		.start({internal_dones,start}),
		.product_out({product,internal_products}),
		.mplier_out({mplier_out,internal_mpliers}),
		.mcand_out({mcand_out,internal_mcands}),
		.done({done,internal_dones})
	);

endmodule

module mult_2(
				input clock, reset,
				input [63:0] mcand, mplier,
				input start,
				
				output [63:0] product,
				output done
			);
	mult #(2) m (.*);
endmodule

module mult_4(
				input clock, reset,
				input [63:0] mcand, mplier,
				input start,
				
				output [63:0] product,
				output done
			);
	mult #(4) m (.*);
endmodule

// This is one stage of an 8 stage (9 depending on how you look at it)
// pipelined multiplier that multiplies 2 64-bit integers and returns
// the low 64 bits of the result.  This is not an ideal multiplier but
// is sufficient to allow a faster clock period than straight *
module mult_stage #(
	parameter N = 8
) (
					input clock, reset, start,
					input [63:0] product_in, mplier_in, mcand_in,

					output logic done,
					output logic [63:0] product_out, mplier_out, mcand_out
				);

	localparam M = 64 / N;
 
	logic [63:0] prod_in_reg, partial_prod_reg;
	logic [63:0] partial_product, next_mplier, next_mcand;

	assign product_out = prod_in_reg + partial_prod_reg;

	assign partial_product = mplier_in[M-1:0] * mcand_in;

	assign next_mplier = mplier_in >> M;
	assign next_mcand = mcand_in << M;

	//synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		prod_in_reg      <= product_in;
		partial_prod_reg <= partial_product;
		mplier_out       <= next_mplier;
		mcand_out        <= next_mcand;
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset)
			done <= 1'b0;
		else
			done <= start;
	end

endmodule

