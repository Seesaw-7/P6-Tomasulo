`timescale 1ns/100ps
`define HALF_CYCLE 25

`include "Renaming.svh"

module test_Renaming();

	logic clk, reset, commit_flag, assign_flag;
  logic ARCH_REG arch_reg;
  logic [4:0] commit_phys_reg;
  logic PHYS_REG phys_reg;

    // wire correct = ((result*result <= {1'b0, value}) && ((result+1)*(result+1) > {1'b0, value}))|~done;

  RegisterRenaming rr (.*);

  always @(posedge clk)
        #(`HALF_CYCLE-5) if(!correct) begin 
            $display("Incorrect at time %4.0f",$time);
            // $display("value = %h",value);
            // $display("result = %h",result);
            $finish;
        end
    
	always begin
		#`HALF_CYCLE;
		clk=~clk;
	end

  task wait_until_done;
    // forever begin : wait_loop
    //   @(posedge done);
    //   @(negedge clk);
    //   if (done) disable wait_until_done;
    // end
    @(negedge clk);
  endtask

  // Test task for commit operation
  task test_on_commit(input logic task_commit_flag, input logic [4:0] task_commit_phys_reg);
    reset = 1'b1;
    assign_flag = 1'b0;
    commit_flag = task_commit_flag;
    arch_reg = '{src1: 5'b0, src2: 5'b0, dest: 5'b0};
    commit_phys_reg = task_commit_phys_reg;
    @(negedge clk);
    reset = 1'b0;
    wait_until_done();
  endtask

  task test_on_arch(input ARCH_REG task_arch_reg)
    reset = 1'b1;
    assign_flag = 1'b0;
    commit_flag = 1'b0;
    arch_reg = task_arch_reg;
    commit_phys_reg = 0;
    @(negedge clk);
    reset = 1'b0;
    wait_until_done();
  endtask

  task test_on_assign(input logic test_assign)
    reset = 1'b1;
    assign_flag = test_assign;
    commit_flag = 1'b0;
    arch_reg = 0;
    commit_phys_reg = 0;
    @(negedge clk);
    reset = 1'b0;
    wait_until_done();
  endtask

  initial begin
		// $monitor("Time:%4.0f done:%b value: %d, result:%d",$time, done, value, result);
    reset = 1'b1;
    clk=0;

    test_on_commit(1, 5'b1);

    @(negedge clk);
    reset = 1'b0;

    @(negedge clk);
    #1000 reset = 1'b1;
    
    // Test committing physical registers back to the free list
    test_on_commit(1'b1, 5'd1);
    test_on_commit(1'b1, 5'd2);


    // Test assigning physical registers to architectural registers
    // Read after write (true dependency)
    test_on_arch('{src1: 5'd1, src2: 5'd2, dest: 5'd3});
    test_on_arch('{src1: 5'd3, src2: 5'd4, dest: 5'd5});

    // Write after write (false dependency)
    test_on_arch('{src1: 5'd1, src2: 5'd2, dest: 5'd3});
    test_on_arch('{src1: 5'd4, src2: 5'd5, dest: 5'd3});

    // Write after read (false dependency)
    test_on_arch('{src1: 5'd1, src2: 5'd2, dest: 5'd3});
    test_on_arch('{src1: 5'd4, src2: 5'd5, dest: 5'd1});

    @(negedge clk);
    #1000 reset = 1'b1;

    // Randomized testing, free list empty and full
    for (int i = 0; i < 33; i++) begin
        ARCH_REG rand_arch_reg = '{src1: $urandom_range(0, 31), src2: $urandom_range(0, 31), dest: $urandom_range(0, 31)};
        test_on_arch(rand_arch_reg);
    end

    
    reset = 1'b1;
    quit  = 1'b0;
    // while (~quit) begin
    //   test_on_case({$random, $random});
    // end
    $finish;
  end
endmodule
