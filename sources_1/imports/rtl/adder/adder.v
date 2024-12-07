`timescale 1ns / 1ps



module mpadder(
  input  wire          clk,
  input  wire          resetn,
  input  wire          start,
  input  wire          subtract,
  input  wire [1026:0] in_a,
  input  wire [1026:0] in_b,
  output wire [1027:0] result,
  output wire          done 
  );

wire [1026:0] B;  
wire cin;
assign B   = (subtract == 0) ? in_b : ~in_b;
assign cin = (subtract == 0) ?    0 : 1;

wire [339:0] sum0;
wire [341:0] mux_sum1, sum1_1, sum1_2;
wire [344:0] mux_sum2, sum2_1, sum2_2;
wire cout0;
wire mux_cout1, cout1_1, cout1_2;
wire mux_cout2, cout2_1, cout2_2;

assign {cout0, sum0}      = in_a[339:0]    + B[339:0]    + cin;

assign {cout1_1, sum1_1}  = in_a[681:340]  + B[681:340]  + 0;
assign {cout1_2, sum1_2}  = in_a[681:340]  + B[681:340]  + 1;
assign {cout2_1, sum2_1}  = in_a[1026:682] + B[1026:682] + 0;
assign {cout2_2, sum2_2}  = in_a[1026:682] + B[1026:682] + 1;

assign mux_sum1  = (cout0 == 0)     ?   sum1_1  : sum1_2;
assign mux_cout1 = (cout0 == 0)     ?   cout1_1 : cout1_2;
assign mux_sum2  = (mux_cout1 == 0) ?   sum2_1  : sum2_2;
assign mux_cout2 = (mux_cout1 == 0) ?   cout2_1 : cout2_2;

assign result = (subtract == 0) ? {mux_cout2, mux_sum2, mux_sum1, sum0} : {~mux_cout2, mux_sum2, mux_sum1, sum0};

endmodule
