`include "map.svh" 

module map_table(
    input logic clk,
    input logic reset,
    input ARCH_REG arch_reg,
    input logic assign_flag,
    input logic return_flag, 
    input logic [`ROB_ADDR_LEN-1:0] assign_rob_tag,
    input logic [`REG_ADDR_LEN-1:0] reg_addr_from_rob, 
    input logic [`ROB_ADDR_LEN-1:0] return_rob_tag,
    output RENAMED_SRC renamed_src
    );
    
    MAP_ENTRY map_table_curr [`REG_LEN-1:0];
    MAP_ENTRY map_table_next [`REG_LEN-1:0];
    MAP_ENTRY map_table_on_reset [`REG_LEN-1:0];
    
    
endmodule
