module CSA_MUX #(
    parameter   N = 128)(
    input [N-1:0] a,
    input [N-1:0] b,
    input cin,
    output [N-1:0] sum,
    output cout
    );
    
    // N = 512, M = 32, N/M = 16 = m blocks of M-bit CLA
    // in total (N/M -1) = 15 = m-1 MUX each for sum and carry
    localparam  M = 128;
    localparam  m = N/M;
    
    // respectively the intermediate mux_c and mux_sum
    // for each i in m, there are a pair of adders that generates carry out, and one input carry from previous carry multiplexer, in total three carries per i.
    // for each i in m, there are a pair of adders that generates sum, each adder 512-bit sum excludes 32 bit which was addressed in the first alone adder. hence 480 bits.
    // in total aggregated to 480*2 bits sum buffer.
    
    wire    [3*(m-1):0]         mux_c;
    wire    [M-1:0] mux_sum_0[(m-2):0];
    wire    [M-1:0] mux_sum_1[(m-2):0];
    
    // instantiate the first adder, i = 0, for special cin input and sum output.
    // CLA_16b_EXP#(M) cla_inst(a[M-1:0], b[M-1:0], cin, sum[M-1:0], mux_c[0]);
//    two_CLA_16b_EXP#(M) cla_inst(a[M-1:0], b[M-1:0], cin, sum[M-1:0], mux_c[0]);
    // CLA_32b_LOOP#(M) cla_inst(a[M-1:0], b[M-1:0], cin, sum[M-1:0], mux_c[0]);
    //  CLA_32b_EXP#(M) cla_inst(a[M-1:0], b[M-1:0], cin, sum[M-1:0], mux_c[0]);
    carry_chain_adder#(M) carry_chain_adder_inst (a[M-1:0], b[M-1:0], cin, sum[M-1:0], mux_c[0]);


    // Group of 32-bit CLA adders with carry and sum outputs
    genvar i;
    generate
        for(i=1; i<m; i=i+1) 
        begin
             // instantiate the remaining (m-1)*2 CLAs
//            CLA_16b_EXP#(M) cla_inst_0( a[M*i +: M], b[M*i +: M], 0, mux_sum_0[i-1], mux_c[(3*i)-2]);
//            CLA_16b_EXP#(M) cla_inst_1( a[M*i +: M], b[M*i +: M], 1, mux_sum_1[i-1], mux_c[(3*i)-1]);
            
//            two_CLA_16b_EXP#(M) cla_inst_0( a[M*i +: M], b[M*i +: M], 0, mux_sum_0[i-1], mux_c[(3*i)-2]);
//            two_CLA_16b_EXP#(M) cla_inst_1( a[M*i +: M], b[M*i +: M], 1, mux_sum_1[i-1], mux_c[(3*i)-1]);

            // CLA_32b_LOOP#(M) cla_inst_0( a[M*i +: M], b[M*i +: M], 0, mux_sum_0[i-1], mux_c[(3*i)-2]);
            // CLA_32b_LOOP#(M) cla_inst_1( a[M*i +: M], b[M*i +: M], 1, mux_sum_1[i-1], mux_c[(3*i)-1]);

            // CLA_32b_EXP#(M) cla_inst_0( a[M*i +: M], b[M*i +: M], 0, mux_sum_0[i-1], mux_c[(3*i)-2]);
            // CLA_32b_EXP#(M) cla_inst_1( a[M*i +: M], b[M*i +: M], 1, mux_sum_1[i-1], mux_c[(3*i)-1]);
            
            carry_chain_adder#(M) carry_chain_adder_inst_0( a[M*i +: M], b[M*i +: M], 0, mux_sum_0[i-1], mux_c[(3*i)-2]);
            carry_chain_adder#(M) carry_chain_adder_inst_1( a[M*i +: M], b[M*i +: M], 1, mux_sum_1[i-1], mux_c[(3*i)-1]);

            // instantiate sum mux and carry mux
            assign sum[M*i +: M] = (mux_c[3*(i-1)] == 0)? mux_sum_0[i-1] : mux_sum_1[i-1];
            assign mux_c[3*i] = (mux_c[3*(i-1)] == 0)? mux_c[(3*i)-2] : mux_c[(3*i)-1];
        end
    endgenerate
    
    assign cout = mux_c[3*(m-1)];

endmodule