`timescale 1ns/100ps
`define HALF_CYCLE 25

`include "Renaming.svh"

module test_Renaming();

	logic clk, reset, commit, done;
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
    forever begin : wait_loop
      @(posedge done);
      @(negedge clk);
      if (done) disable wait_until_done;
    end
  endtask

  task test_on_commit(input task_commit, task_commit_phys_reg)
    reset = 1'b1;
    commit = is_commit;
    arch_reg = 0;
    commit_phys_reg = task_commit_phys_reg;
    @(negedge clk);
    reset = 1'b0;
    wait_until_done();
  endtask

  task test_on_commit(input task_arch_reg)
    reset = 1'b1;
    commit = 1'b0;
    arch_reg = task_arch_reg;
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

    reset = 1'b1;
    quit  = 1'b0;
    while (~quit) begin
      test_on_case({$random, $random});
    end
    $finish;
  end
endmodule
