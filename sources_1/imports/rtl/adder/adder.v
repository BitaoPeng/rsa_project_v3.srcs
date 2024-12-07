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

    reg [1026:0]    regA_Q;
    reg [1026:0]    regB_Q;
    reg             muxA_sel;
    reg             muxB_sel;

    always@(posedge clk)begin
        if(~resetn) begin
            regA_Q <= 1027'd0;
            regB_Q <= 1027'd0;
        end
        else begin
            regA_Q <= (muxA_sel == 0) ? in_a : {350'b0,regA_Q[1026:350]};
            regB_Q <= (muxB_sel == 0) ? in_b : {350'b0,regB_Q[1026:350]};
        end
    end 


    reg [349:0]     adder_a;
    reg [349:0]     adder_b;
    reg             adder_cin;
    wire[349:0]     adder_sum;
    wire            adder_cout;
    
//       CSA_MUX #(350) CSA_MUX_inst (
//        .a(adder_a),
//        .b(adder_b),
//        .cin(adder_cin),
//        .sum(adder_sum),
//        .cout(adder_cout)
//    );
    
        carry_chain_adder #(350) carry_chain_adder (
        .a(adder_a),
        .b(adder_b),
        .cin(adder_cin),
        .sum(adder_sum),
        .cout(adder_cout)
    );

//    N_bit_inner_adder #(350) N_bit_inner_adder_inst (
//        .a(adder_a),
//        .b(adder_b),
//        .cin(adder_cin),
//        .sum(adder_sum),
//        .cout(adder_cout)
//    );

    reg [349:0]     result_tmp;
    reg             carry_out;  
    wire            carry_in; 
    
    // State Logic
    reg [2:0]       state, nextstate;

    always@(*)begin
        if(~resetn || start == 1)begin
                result_tmp <= 0;
                carry_out <= 0;
                adder_a    <= 0;
                adder_b    <= 0;
                adder_cin  <= 0;
            end
        else begin
                if (subtract == 0) begin 
                    adder_a   <= regA_Q[349:0];
                    adder_b   <= regB_Q[349:0];
                    adder_cin <= carry_in;
                end 
                else begin
                    adder_a   <= regA_Q[349:0];
                    adder_b   <= ~regB_Q[349:0];
                    if(state == 3'd1) 
                        adder_cin <= 1'd1;
                    else 
                        adder_cin <= carry_in;
                end
                result_tmp <= adder_sum;
                carry_out  <= adder_cout;
             end
    end


    reg             regResult_en;
    reg [1027:0]    regResult;
    reg             regDone;

    always @(posedge clk)begin
            if(~resetn || start == 1)begin
                regResult <= 1028'b0;
                regDone <= 1'd0;
            end
            else begin
                if (state == 3'd3) begin
                    regDone <= 1;
                    regResult <= {result_tmp[327:0], regResult[1027:328]}; 
                end
                else begin
                    regDone <= 0;
                    if (regResult_en)  regResult <= {result_tmp, regResult[1027:350]};
                    else regResult <= regResult;
                end
            end
    end


    reg  regCout_en;
    reg  regCout;
    reg  muxCarryIn_sel;
    wire muxCarryIn;
    
    always @(posedge clk)
    begin
        if(~resetn)           regCout <= 1'b0;
        else if (regCout_en)  regCout <= carry_out;
    end
    assign muxCarryIn = (muxCarryIn_sel == 0) ? 1'b0 : regCout;
    assign carry_in = muxCarryIn;


    reg             regCnt_en; 
    reg [4:0]       regCnt_Q;  // counter ???????????????not necessary this bit length

    always @(posedge clk)
    begin
        if(~resetn)          regCnt_Q <= 0;
        else begin
            if (state == 3'd3) regCnt_Q <= 0;
            else if (start) regCnt_Q <= 1;
                else regCnt_Q <= regCnt_Q + 1;
         end
    end



    always @(posedge clk)
    begin
        if(~resetn)	state <= 2'd0;
        else        state <= nextstate;
    end

    // Define Outputs of Each State
    always @(*)
    begin
        case(state)
            3'd0: begin
                regResult_en   <= 1'b0;
                regCout_en     <= 1'b0;
                regCnt_en      <= 1'b0;
                muxA_sel       <= 1'b0;
                muxB_sel       <= 1'b0;
                muxCarryIn_sel <= 1'b0;
            end
            3'd1: begin
                regResult_en   <= 1'b1;
                regCout_en     <= 1'b1;
                regCnt_en      <= 1'b1;
                muxA_sel       <= 1'b1;
                muxB_sel       <= 1'b1;
                muxCarryIn_sel <= 1'b0;
            end
            3'd2: begin
                regResult_en   <= 1'b1;
                regCout_en     <= 1'b1;
                regCnt_en      <= 1'b1;
                muxA_sel       <= 1'b1;
                regCnt_en      <= 1'b1;
                muxB_sel       <= 1'b1;
                muxCarryIn_sel <= 1'b1;
            end
            3'd3: begin
                regResult_en   <= 1'b1;
                regCout_en     <= 1'b1;
                regCnt_en      <= 1'b1;
                muxA_sel       <= 1'b1;
                regCnt_en      <= 1'b1;
                muxB_sel       <= 1'b1;
                muxCarryIn_sel <= 1'b1;
            end
            default: begin
                regResult_en   <= 1'b1;
                regCout_en     <= 1'b0;
                regCnt_en      <= 1'b0;
                muxA_sel       <= 1'b0;
                muxB_sel       <= 1'b0;
                muxCarryIn_sel <= 1'b0;
            end
        endcase
    end
    
    // Next State Logic
    always @(*)
    begin
        case(state)
            3'd0: // idle state
            begin
                if(start)
                    nextstate <= 3'd1;
                else
                    nextstate <= 3'd0;
            end

            3'd1: // Add_First state
                nextstate <= 3'd2;
            
            3'd2: // Add_Lower state
            begin
                if(regCnt_Q == 2)  // floor(1024/350)=2  !!!!!!!!!!!!!!!!!!!!!!!!!!!NEED TO BE CHANGED EVERY TIME WHEN MODIFY THE SIZE OF INNDER ADDER!!!!!!!
                    nextstate <= 3'd3;
                else
                    nextstate <= 3'd2;  
            end
            3'd3 : // Add_Last state
                nextstate <= 3'd0;

            default: nextstate <= 3'd0;
        endcase
    end


    // Output Logic
     assign done = regDone;
     assign result = (subtract == 0) ? {regCout, regResult} : {~regCout, regResult}; 

endmodule