`timescale 1ns/100ps
`define HALF_CYCLE 25

`include "Renaming.svh"

module test_Renaming();

  logic clk, reset, commit_flag, assign_flag;
  ARCH_REG arch_reg;  // Correct data type for arch_reg
  logic [4:0] commit_phys_reg;
  PHYS_REG phys_reg;  // Correct data type for phys_reg

  // Instance of the RegisterRenaming module
  RegisterRenaming rr (
    .clk(clk),
    .reset(reset),
    .arch_reg(arch_reg),
    .return_flag(commit_flag),
    .assign_flag(assign_flag),
    .commit_phys_reg(commit_phys_reg),
    .phys_reg(phys_reg)
  );

//  always @(posedge clk)
//        #(`HALF_CYCLE-5) 
//        if(!correct) begin 
//            $display("Incorrect at time %4.0f",$time);
//            $finish;
//        end

  always begin
    #`HALF_CYCLE;
    clk = ~clk;
  end

  task wait_until_done;
    @(negedge clk);
  endtask

  task test_on_commit(input logic task_commit_flag, input logic [4:0] task_commit_phys_reg);
    reset = 1'b1;
    assign_flag = 1'b0;
    commit_flag = task_commit_flag;
    arch_reg = '{src1: 5'b0, src2: 5'b0, dest: 5'b0};  // Initialize arch_reg
    commit_phys_reg = task_commit_phys_reg;
    @(negedge clk);
    reset = 1'b0;
    wait_until_done();
  endtask

  task test_on_arch(input ARCH_REG task_arch_reg);
    reset = 1'b1;
    assign_flag = 1'b0;
    commit_flag = 1'b0;
    arch_reg = task_arch_reg;
    commit_phys_reg = 5'b0;
    @(negedge clk);
    reset = 1'b0;
    wait_until_done();
  endtask

  task test_on_assign(input logic test_assign_flag);
    reset = 1'b1;
    assign_flag = test_assign_flag;
    commit_flag = 1'b0;
    arch_reg = '{src1: 5'b0, src2: 5'b0, dest: 5'b0};  // Initialize arch_reg
    commit_phys_reg = 5'b0;
    @(negedge clk);
    reset = 1'b0;
    wait_until_done();
  endtask
  
  task test_add_inst(input ARCH_REG test_arch_reg);
    assign_flag = 1'b1;
    commit_flag = 1'b0;
    arch_reg = test_arch_reg;  // Initialize arch_reg
    commit_phys_reg = 5'b0;
    wait_until_done();
  endtask

  task test_add_commit(input logic [`REG_ADDR_LEN-1:0] task_commit_phys_reg);
    assign_flag = 1'b0;
    commit_flag = 1'b1;
    // arch_reg = test_arch_reg;  // Initialize arch_reg
    commit_phys_reg = task_commit_phys_reg;
    wait_until_done();
  endtask

  task test_add_inst_commit(input ARCH_REG test_arch_reg, logic [`REG_ADDR_LEN-1:0] task_commit_phys_reg);
    assign_flag = 1'b1;
    commit_flag = 1'b1;
    arch_reg = test_arch_reg;
    commit_phys_reg = task_commit_phys_reg;
    wait_until_done();
  endtask

  initial begin
    reset = 1'b1;
    clk = 0;

    @(negedge clk);
    reset = 1'b0;
    
   test_add_inst('{src1: 5'd0, src2: 5'd0, dest: 5'd1});
   test_add_inst('{src1: 5'd0, src2: 5'd1, dest: 5'd2});
   test_add_inst('{src1: 5'd1, src2: 5'd2, dest: 5'd3});

   test_add_commit(5'd1);
   test_add_commit(5'd2);
   
   test_add_inst('{src1: 5'd2, src2: 5'd3, dest: 5'd4});
    
   test_add_inst_commit('{src1: 5'd3, src2: 5'd4, dest: 5'd5}, 5'd3);

   test_add_inst('{src1: 5'd4, src2: 5'd5, dest: 5'd6});
   test_add_inst('{src1: 5'd3, src2: 5'd4, dest: 5'd0});
   test_add_inst('{src1: 5'd5, src2: 5'd6, dest: 5'd7});

   test_add_commit(5'd4);
   test_add_commit(5'd0);

   test_add_inst_commit('{src1: 5'd6, src2: 5'd7, dest: 5'd0}, 5'd0);

   reset = 1'b1;

    // Add more test cases here as needed

    $finish;
  end
endmodule
