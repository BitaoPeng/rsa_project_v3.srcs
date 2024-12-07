`timescale 1ns / 1ps


module montgomery(
  input           clk,
  input           resetn,
  input           start,
  input  [1023:0] in_a,
  input  [1023:0] in_b,
  input  [1023:0] in_m,
  output [1023:0] result,
  output          done
    );

  // Student tasks:
  // 1. Instantiate an Adder
  // 2. Use the Adder to implement the Montgomery multiplier in hardware.
  // 3. Use tb_montgomery.v to simulate your design.

  // Dear Students: This always block was added to ensure the tool doesn't
  // trim away the montgomery module. Feel free to remove this block.

// Intermediate register   
reg [1027:0] A, C; 
reg [1027:0] twoB, threeB, twoM, threeM; 
reg [10:0] i;              // Loop index (since n = 1024, we need 11 bits to count to 1024)
reg [1:0] A_index_bits;


reg adder_start, subtract;
reg [1026:0] adder_in_a, adder_in_b;
wire [1027:0] adder_result;
wire adder_done;

// reg [1:0] multi_step; 

parameter n = 1024;


// Adder module instance
mpadder mpadder_instance(
.clk(clk),
.resetn(resetn),
.start(adder_start),
.subtract(subtract),
.in_a(adder_in_a),
.in_b(adder_in_b),
.result(adder_result),
.done(adder_done)
);


// State Definition
localparam IDLE                = 5'd0;
localparam INITIALIZE          = 5'd1;
localparam INIT_MULT_B0        = 5'd2;
localparam WAIT_MULT_B0        = 5'd3;
localparam INIT_MULT_B1        = 5'd4;
localparam WAIT_MULT_B1        = 5'd5;
localparam INIT_MULT_M0        = 5'd6;
localparam WAIT_MULT_M0        = 5'd7;
localparam INIT_MULT_M1        = 5'd8;
localparam WAIT_MULT_M1        = 5'd9;
localparam ACCUMULATE          = 5'd10;
localparam INIT_ADDER          = 5'd11;
localparam WAIT_MULTIPLIER     = 5'd12;
localparam CONDITIONAL_UPDATE  = 5'd13;
localparam INIT_CONST_MULTIPLIER = 5'd14;
localparam WAIT_CONST_MULTIPLIER = 5'd15;
localparam DIVIDE_BY_4         = 5'd16;
localparam CHECK_LOOP          = 5'd17;
localparam COMPARE             = 5'd18;
localparam NORMALIZE           = 5'd19;
localparam WAIT_ADDER          = 5'd20;
localparam DONE                = 5'd21;



// State Register
reg [4:0] current_state, next_state;

always @(posedge clk)
begin
    if(~resetn)
        current_state <= IDLE;
    else
        current_state <= next_state;
end



// Next State Logic
always @(*) begin
    case (current_state)
        IDLE: begin
            if(start)
                next_state = INITIALIZE; 
            else
                next_state = IDLE; // !!! just to avoid latches (which is a memory element), should never appear in combinational logic block           
        end
        INITIALIZE: next_state = INIT_MULT_B0;
        INIT_MULT_B0: next_state = WAIT_MULT_B0;
        WAIT_MULT_B0: next_state = INIT_MULT_M0;
        INIT_MULT_M0: next_state = WAIT_MULT_M0;
        WAIT_MULT_M0: next_state = WAIT_MULT_M1;
        WAIT_MULT_M1: next_state = ACCUMULATE;
        ACCUMULATE:   next_state = WAIT_MULTIPLIER;
        WAIT_MULTIPLIER: next_state = CONDITIONAL_UPDATE;
        CONDITIONAL_UPDATE: begin       
            next_state = WAIT_CONST_MULTIPLIER;
        end
        WAIT_CONST_MULTIPLIER: begin 
            next_state = DIVIDE_BY_4;
        end
        DIVIDE_BY_4: begin
            if(i < n-3)
                next_state = ACCUMULATE;
            else                
                next_state = COMPARE;
        end
        COMPARE: begin 
            next_state = NORMALIZE;
        end
        NORMALIZE: begin
            if (adder_result[1027] == 0)
                next_state = WAIT_ADDER;
            else                     
                next_state = DONE;

        end
        WAIT_ADDER: begin 
            next_state = COMPARE;
        end
        DONE: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end


// State Output and Logic Operations
always @(posedge clk) begin 
    if (~resetn) begin
        A <= 0;
        A_index_bits <= 0;
        C <= 0;
        i <= 0;
        adder_in_a <= 0;
        adder_in_b <= 0;
        subtract <= 0;
        twoB <= 0;
        threeB <= 0;
        twoM <= 0;
        threeM <= 0;
    end
    else begin
        case (current_state)
            IDLE: begin
                A <= 0;
                A_index_bits <= 0;
                C <= 0;
                i <= 0;
                adder_in_a <= 0;
                adder_in_b <= 0;
                subtract <= 0;
                twoB <= 0;
                threeB <= 0;
                twoM <= 0;
                threeM <= 0;
            end
            INITIALIZE: begin 
                A <= in_a;                
            end
            INIT_MULT_B0: begin 
                subtract <= 0;
                adder_in_a <= in_b;
                adder_in_b <= in_b;
            end
            WAIT_MULT_B0: begin
                twoB <= adder_result;
                adder_in_a <= adder_result;
                adder_in_b <= in_b;
                subtract <= 0;
            end
            INIT_MULT_M0: begin 
                threeB <= adder_result;
                subtract <= 0;
                adder_in_a <= in_m;
                adder_in_b <= in_m;
            end
            WAIT_MULT_M0: begin
                twoM <= adder_result;
                adder_in_a <= adder_result;
                adder_in_b <= in_m;
                subtract <= 0;
                
                A_index_bits <= A[1:0];
            end
            WAIT_MULT_M1: threeM <= adder_result;
            ACCUMULATE: begin               
                subtract <= 0;
                adder_in_a <= C;
                A <= A >> 2;
                if (A_index_bits == 0) adder_in_b <= 0;
                else begin 
                    if (A_index_bits == 1) adder_in_b <= in_b;
                    else if (A_index_bits == 2) adder_in_b <= twoB;
                    else if (A_index_bits == 3) adder_in_b <= threeB;
                end   
            end
            WAIT_MULTIPLIER:  C <= adder_result;
            CONDITIONAL_UPDATE: begin
                subtract <= 0;
                adder_in_a <= C[1026:0];
                if ((C[1:0] == 2'b01 && in_m[1:0] == 2'b01) || (C[1:0] == 2'b11 && in_m[1:0] == 2'b11)) begin
                    adder_in_b <= threeM;
                end
                else if ((C[1:0] == 2'b10 && in_m[1:0] == 2'b01) || (C[1:0] == 2'b10 && in_m[1:0] == 2'b11)) begin
                        adder_in_b <= twoM;
                    end
                    else if ((C[1:0] == 2'b11 && in_m[1:0] == 2'b01) || (C[1:0] == 2'b01 && in_m[1:0] == 2'b11)) begin
                            adder_in_b <= in_m;
                        end
                         else 
                             adder_in_b <= 0; 
            end
            WAIT_CONST_MULTIPLIER: begin 
                C <= adder_result;
            end
            DIVIDE_BY_4: begin
                C <= C >> 2;    
                i <= i + 2;
                A_index_bits <= A[1:0];
            end
            COMPARE: begin 
                subtract <= 1;
                adder_in_a <= C;
                adder_in_b <= in_m;
            end
            NORMALIZE: begin
                if (adder_result[1027] == 0) begin 
                    subtract <= 1;
                    adder_in_a <= C;
                    adder_in_b <= in_m;
                end
            end
            WAIT_ADDER: begin 
                C <= adder_result;
            end
            DONE: begin 
            end
        endcase
    end
end


// Output Logic
assign result = (current_state == DONE)? C[1023:0] : 1024'b0;
assign done = (current_state == DONE)? 1'b1 : 1'b0; 


endmodule
