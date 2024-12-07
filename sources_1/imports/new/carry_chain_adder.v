`timescale 1ns / 1ps

module carry_chain_adder #(
    parameter M = 32)
    (
    input    [M-1:0] a,
    input    [M-1:0] b,
    input            cin,
    output   [M-1:0] sum,
    output           cout 
    );

    assign {cout, sum} = a + b + cin;
endmodule
