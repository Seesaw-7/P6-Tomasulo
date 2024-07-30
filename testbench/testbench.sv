/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  testbench.v                                         //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline;       //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`define CLOCK_PERIOD 10.0

// micro for testing
`define DISPLAY_INTERNAL
`define ASSERTION

`timescale 1ns/100ps

// these link to the pipe_print.c file in this directory, and are used below to print
// detailed output to the pipeline_output_file, initialized by open_pipeline_output_file()
import "DPI-C" function void open_pipeline_output_file(string file_name);
import "DPI-C" function void print_header(string str);
import "DPI-C" function void print_cycles();
import "DPI-C" function void print_stage(string div, int inst, int npc, int valid_inst);
import "DPI-C" function void print_reg(int wb_reg_wr_data_out_hi, int wb_reg_wr_data_out_lo,
                                       int wb_reg_wr_idx_out, int wb_reg_wr_en_out);
import "DPI-C" function void print_membus(int proc2mem_command, int mem2proc_response,
                                          int proc2mem_addr_hi, int proc2mem_addr_lo,
                                          int proc2mem_data_hi, int proc2mem_data_lo);
import "DPI-C" function void print_close();


module testbench;
	// used to parameterize which files are used for memory and writeback/pipeline outputs
	// "./simv" uses program.mem, writeback.out, and pipeline.out
	// but now "./simv +MEMORY=<my_program>.mem" loads <my_program>.mem instead
	// use +WRITEBACK=<my_program>.wb and +PIPELINE=<my_program>.ppln for those outputs as well
	string program_memory_file;
	string writeback_output_file;
	string pipeline_output_file;

	// variables used in the testbench
	logic        clock;
	logic        reset;
	logic [31:0] clock_count;
	logic [31:0] instr_count;
	int          wb_fileno;
	logic [63:0] debug_counter; // counter used for when pipeline infinite loops, forces termination

	logic [1:0]       proc2mem_command;
	logic [`XLEN-1:0] proc2mem_addr;
	logic [63:0]      proc2mem_data;
	logic [3:0]       mem2proc_response;
	logic [63:0]      mem2proc_data;
	logic [3:0]       mem2proc_tag;
`ifndef CACHE_MODE
	MEM_SIZE          proc2mem_size;
`endif

	logic [3:0]       pipeline_completed_insts;
	EXCEPTION_CODE    pipeline_error_status;
	logic [4:0]       pipeline_commit_wr_idx;
	logic [`XLEN-1:0] pipeline_commit_wr_data;
	logic             pipeline_commit_wr_en;
	logic [`XLEN-1:0] pipeline_commit_NPC;

	//debug
	logic [`REG_NUM-1:0] [`XLEN-1:0] pipeline_registers_out;
	logic flush;
	logic stall;

	assign pipeline_error_status = NO_ERROR;

	// logic [`XLEN-1:0] if_NPC_out;
	// logic [31:0]      if_IR_out;
	// logic             if_valid_inst_out;
	// logic [`XLEN-1:0] if_id_NPC;
	// logic [31:0]      if_id_IR;
	// logic             if_id_valid_inst;
	// logic [`XLEN-1:0] id_ex_NPC;
	// logic [31:0]      id_ex_IR;
	// logic             id_ex_valid_inst;
	// logic [`XLEN-1:0] ex_mem_NPC;
	// logic [31:0]      ex_mem_IR;
	// logic             ex_mem_valid_inst;
	// logic [`XLEN-1:0] mem_wb_NPC;
	// logic [31:0]      mem_wb_IR;
	// logic             mem_wb_valid_inst;


	// Instantiate the Pipeline
	pipeline core (
		// Inputs
		.clock             (clock),
		.reset             (reset),
		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag),

		// Outputs
		.proc2mem_command (proc2mem_command),
		.proc2mem_addr    (proc2mem_addr),
		.proc2mem_data    (proc2mem_data),
`ifndef CACHE_MODE
		.proc2mem_size    (proc2mem_size),
`endif

		.pipeline_completed_insts (pipeline_completed_insts),
		// .pipeline_error_status    (pipeline_error_status),
		.pipeline_commit_wr_data  (pipeline_commit_wr_data),
		.pipeline_commit_wr_idx   (pipeline_commit_wr_idx),
		.pipeline_commit_wr_en    (pipeline_commit_wr_en),
		.pipeline_commit_NPC      (pipeline_commit_NPC),

		//debug
		.pipeline_registers_out(pipeline_registers_out)
		// .flush(flush),
		// .stall(stall)

		// .if_NPC_out        (if_NPC_out),
		// .if_IR_out         (if_IR_out),
		// .if_valid_inst_out (if_valid_inst_out),
		// .if_id_NPC         (if_id_NPC),
		// .if_id_IR          (if_id_IR),
		// .if_id_valid_inst  (if_id_valid_inst),
		// .id_ex_NPC         (id_ex_NPC),
		// .id_ex_IR          (id_ex_IR),
		// .id_ex_valid_inst  (id_ex_valid_inst),
		// .ex_mem_NPC        (ex_mem_NPC),
		// .ex_mem_IR         (ex_mem_IR),
		// .ex_mem_valid_inst (ex_mem_valid_inst),
		// .mem_wb_NPC        (mem_wb_NPC),
		// .mem_wb_IR         (mem_wb_IR),
		// .mem_wb_valid_inst (mem_wb_valid_inst)
	);


	// Instantiate the Data Memory
	mem memory (
		// Inputs
		.clk              (clock),
		.proc2mem_command (proc2mem_command),
		.proc2mem_addr    (proc2mem_addr),
		.proc2mem_data    (proc2mem_data),
`ifndef CACHE_MODE
		.proc2mem_size    (proc2mem_size),
`endif

		// Outputs
		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag)
	);


	// Generate System Clock
	always begin
		#(`CLOCK_PERIOD/2.0);
		clock = ~clock;
	end


	// Task to display # of elapsed clock edges
	task show_clk_count;
		real cpi;
		begin
			cpi = (clock_count + 1.0) / instr_count;
			$display("@@  %0d cycles / %0d instrs = %f CPI\n@@",
			          clock_count+1, instr_count, cpi);
			$display("@@  %4.2f ns total time to execute\n@@\n",
			          clock_count*`CLOCK_PERIOD);
		end
	endtask // task show_clk_count


	// Show contents of a range of Unified Memory, in both hex and decimal
	task show_mem_with_decimal;
		input [31:0] start_addr;
		input [31:0] end_addr;
		int showing_data;
		begin
			$display("@@@");
			showing_data=0;
			for(int k=start_addr;k<=end_addr; k=k+1)
				if (memory.unified_memory[k] != 0) begin
					$display("@@@ mem[%5d] = %x : %0d", k*8, memory.unified_memory[k],
					                                         memory.unified_memory[k]);
					showing_data=1;
				end else if(showing_data!=0) begin
					$display("@@@");
					showing_data=0;
				end
			$display("@@@");
		end
	endtask // task show_mem_with_decimal
	
`ifdef DISPLAY_INTERNAL
	task display_time();
		$display(">>>>>>>");
		$display("time: %4.0f", $time);
		$display(" ");
	endtask

	task display_fetch_stage();
		$display("fetch stage output valid: %b", core.fetch_stage_packet.valid);
		$display("fetch stage output inst: %b", core.fetch_stage_packet.inst);
		$display("fetch stage output pc: %d", core.fetch_stage_packet.PC);
		$display("fetch stage output npc: %d", core.fetch_stage_packet.NPC);
		$display(" ");
	endtask
	
	task _display_decoder();
		$display("dispatch stage internal: decoder csr_op: %b", core.decoder_csr_op);
		$display("dispatch stage internal: decoder halt: %b", core.decoder_halt);
		$display("dispatch stage internal: decoder illegal: %b", core.decoder_illegal);
		$display("dispatch stage internal: decoder insn valid: %b", core.decoded_pack.valid);
		$display("dispatch stage internal: decoder insn func unit: %b", core.decoded_pack.fu);
		$display("dispatch stage internal: decoder insn arch reg: %d", core.decoded_pack.arch_reg);
		$display("dispatch stage internal: decoder insn imm: %b", core.decoded_pack.imm);
		$display("dispatch stage internal: decoder insn alu func: %b", core.decoded_pack.alu_func);
		$display("dispatch stage internal: decoder insn pc: %d", core.decoded_pack.pc);
		$display(" ");	
		// rs1 valid, rs2 valid, imm valid, pc valid
	endtask

	task _display_dispatcher();
		$display("dispatch stage internal: dispatch input rob tag: %d", core.dispatcher_0.assign_rob_tag);
		$display("dispatch stage internal: dispatch input RS_is_full: %b", core.dispatcher_0.RS_is_full);
		$display("dispatch stage internal: dispatch output rs_load: %b", core.dispatcher_0.RS_load);
		$display("dispatch stage internal: dispatch output stall: %b", core.dispatcher_0.stall);
		// insn to rs
		$display("dispatch stage internal: dispatch2rs output pc: %d", core.dispatcher_0.inst_rs.fu);
		$display(" ");
	endtask

	task display_dispatch_stage();
		_display_decoder();	
		_display_dispatcher();	

		// display map table
		$display("dispatch stage internal: map table output renamed pack: dest %d, rob tag %d ", core.dispatcher_0.mt.renamed_pack.dest, core.dispatcher_0.mt.renamed_pack.rob_tag);
		for (int i=0; i<`REG_NUM; ++i) begin
			$display("map table[%d]: rob tag %d ready: %b", i, core.dispatcher_0.mt.map_table_curr[i].rob_tag, core.dispatcher_0.mt.map_table_curr[i].ready_in_rob);
		end
		// core.dispatcher_0.mt.renamed_pack

		$display(" ");
	endtask

	task dislplay_reg();
		for (int i=0; i<32; ++i) begin
			$display("reg[%d]: %d", i, core.regfile.registers[i]);
		end
	endtask

	task display_alu_rs();
		for (int i=0; i<8; ++i) begin
			$display("rs[%d]: insn valid %d rob tag %d", i, core.RS_ALU.issue_queue_curr[i].valid, core.RS_ALU.issue_queue_curr[i].insn.insn_tag);
		end
	endtask

`endif 


	initial begin
		//$dumpvars;

		// set paramterized strings, see comment at start of module
		if ($value$plusargs("MEMORY=%s", program_memory_file)) begin
			$display("Loading memory file: %s", program_memory_file);
		end else begin
			$display("Loading default memory file: program.mem");
			program_memory_file = "program.mem";
		end
		if ($value$plusargs("WRITEBACK=%s", writeback_output_file)) begin
			$display("Using writeback output file: %s", writeback_output_file);
		end else begin
			$display("Using default writeback output file: writeback.out");
			writeback_output_file = "writeback.out";
		end
		if ($value$plusargs("PIPELINE=%s", pipeline_output_file)) begin
			$display("Using pipeline output file: %s", pipeline_output_file);
		end else begin
			$display("Using default pipeline output file: pipeline.out");
			pipeline_output_file = "pipeline.out";
		end

		clock = 1'b0;
		reset = 1'b0;

		// Pulse the reset signal
		$display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
		reset = 1'b1;
		@(posedge clock);
		@(posedge clock);

		// store the compiled program's hex data into memory
		$readmemh(program_memory_file, memory.unified_memory);

		@(posedge clock);
		@(posedge clock);
		`SD;
		// This reset is at an odd time to avoid the pos & neg clock edges

		reset = 1'b0;
		$display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);

		wb_fileno = $fopen(writeback_output_file);

		// Open pipeline output file AFTER throwing the reset otherwise the reset state is displayed
		open_pipeline_output_file(pipeline_output_file);
		print_header("                                                                            D-MEM Bus &\n");
		print_header("Cycle:      IF      |     ID      |     EX      |     MEM     |     WB      Reg Result");
	end


	// Count the number of posedges and number of instructions completed
	// till simulation ends
	always @(posedge clock) begin
		if(reset) begin
			clock_count <= `SD 0;
			instr_count <= `SD 0;
		end else begin
			clock_count <= `SD (clock_count + 1);
			instr_count <= `SD (instr_count + 32'(pipeline_completed_insts));
		end
	end

`ifdef DISPLAY_INTERNAL
	always @(negedge clock) begin
		display_time();
		// display_fetch_stage();
		// display_dispatch_stage();
		display_alu_rs();
		// dislplay_reg();
	end
`endif

	always @(negedge clock) begin
		if(reset) begin
			$display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
			         $realtime);
			debug_counter <= 0;
		end else begin
			`SD;
			`SD;

			 // print the piepline stuff via c code to the pipeline output file
			print_cycles();
			//  print_stage(" ", if_IR_out, if_NPC_out[31:0], {31'b0,if_valid_inst_out});
			//  print_stage("|", if_id_IR,  if_id_NPC [31:0], {31'b0,if_id_valid_inst});
			//  print_stage("|", id_ex_IR,  id_ex_NPC [31:0], {31'b0,id_ex_valid_inst});
			//  print_stage("|", ex_mem_IR, ex_mem_NPC[31:0], {31'b0,ex_mem_valid_inst});
			//  print_stage("|", mem_wb_IR, mem_wb_NPC[31:0], {31'b0,mem_wb_valid_inst});
			 print_reg(32'b0, pipeline_commit_wr_data[31:0],
				{27'b0,pipeline_commit_wr_idx}, {31'b0,pipeline_commit_wr_en});
			 print_membus({30'b0,proc2mem_command}, {28'b0,mem2proc_response},
				32'b0, proc2mem_addr[31:0],
				proc2mem_data[63:32], proc2mem_data[31:0]);

			// print the writeback information to writeback output file
			if(pipeline_completed_insts>0) begin
				if(pipeline_commit_wr_en)
					$fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
						pipeline_commit_NPC-4,
						pipeline_commit_wr_idx,
						pipeline_commit_wr_data);
				else
					$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_NPC-4);
			end

			// deal with any halting conditions
			if(pipeline_error_status != NO_ERROR || debug_counter > 5000) begin
			// if(pipeline_error_status != NO_ERROR || debug_counter > 50000000) begin
				$display("@@@ Unified Memory contents hex on left, decimal on right: ");
				show_mem_with_decimal(0,`MEM_64BIT_LINES - 1);
				// 8Bytes per line, 16kB total

				$display("@@  %t : System halted\n@@", $realtime);

				case(pipeline_error_status)
					LOAD_ACCESS_FAULT:
						$display("@@@ System halted on memory error");
					HALTED_ON_WFI:
						$display("@@@ System halted on WFI instruction");
					ILLEGAL_INST:
						$display("@@@ System halted on illegal instruction");
					default:
						$display("@@@ System halted on unknown error code %x",
							pipeline_error_status);
				endcase
				$display("@@@\n@@");
				show_clk_count;
				print_close(); // close the pipe_print output file
				$fclose(wb_fileno);
				#100 $finish;
			end
			debug_counter <= debug_counter + 1;
		end // if(reset)
	end

`ifdef ASSERTION

always @(negedge clock) begin
	assert (1'b0 == 1'b1) else $fatal("It's gone wrong");
end



`endif




endmodule // module testbench
