`timescale 1ns / 1ps


module mont_exp( 
  input           clk,
  input           resetn,
  input           start,
  input  [1023:0] in_x,  // message
  input  [1023:0] in_e,  // encrytion exponent
  input  [1023:0] in_m,  // modulus
  input  [1023:0] in_R_mod_M,  
  input  [1023:0] in_R2_mod_M,  
  input  [9:0]    in_e_length,   
  output wire [1023:0] result,
  output          done
    );

// Intermediate register         
reg [1023:0]  e, x_tilde, A;
reg [9:0]     i, tao;              // Loop index (since n = 1024, we need 10 bits to count to 1024)
reg           e_index_bit;


// integer k;
// always @(*) begin
//     tao = 0;
//     for (k = 1023; k >= 0; k = k - 1) begin
//         if (in_e[k] == 1'b1 && tao == 0) begin
//             tao = k;  // Found the highest bit that is set
//         end
//     end
// end


reg mont_start1;
reg [1023:0] mont_in_a1, mont_in_b1;
wire [1023:0] mont_result1;
wire mont_done1;

reg mont_start2;
reg [1023:0] mont_in_a2, mont_in_b2;
wire [1023:0] mont_result2;
wire mont_done2;


// mont module instance
montgomery mont_instance_1(
.clk(clk),
.resetn(resetn),
.start(mont_start1),
.in_a(mont_in_a1),
.in_b(mont_in_b1),
.in_m(in_m),
.result(mont_result1),
.done(mont_done1)
);

montgomery mont_instance_2(
.clk(clk),
.resetn(resetn),
.start(mont_start2),
.in_a(mont_in_a2),
.in_b(mont_in_b2),
.in_m(in_m),
.result(mont_result2),
.done(mont_done2)
);


// State Definition
localparam IDLE                = 4'd0;
localparam INITIALIZE          = 4'd1;
localparam REG_TO_MONT         = 4'd2;
localparam WAIT_REG_TO_MONT    = 4'd3;
localparam ITERATION           = 4'd4;
localparam WAIT_ITERATION      = 4'd5;
localparam UPDATE_INDEX_BIT    = 4'd6;
localparam MONT_TO_REG         = 4'd7;
localparam WAIT_MONT_TO_REG    = 4'd8;
localparam DONE                = 4'd9;



// State Register
reg [3:0] current_state, next_state;

always @(posedge clk)
begin
    if(~resetn)
        current_state <= IDLE;
    else
        current_state <= next_state;
end



// Completion flags for montgomery operations
reg mont_done1_flag;
reg mont_done2_flag;



// Next State Logic
always @(*) begin
    case (current_state)
        IDLE: begin
            if(start)
                next_state = INITIALIZE; 
            else
                next_state = IDLE; // !!! just to avoid latches (which is a memory element), should never appear in combinational logic block           
        end
        INITIALIZE: next_state = REG_TO_MONT;
        REG_TO_MONT: begin 
            next_state = WAIT_REG_TO_MONT;
        end       
        WAIT_REG_TO_MONT:begin 
            if(mont_done1_flag && mont_done2_flag)
                next_state = ITERATION;
            else
                next_state = WAIT_REG_TO_MONT;
        end
        ITERATION: begin 
            next_state = WAIT_ITERATION;
        end
        WAIT_ITERATION: begin 
            if(mont_done1_flag && mont_done2_flag && i == tao + 1)
                next_state = MONT_TO_REG;
            else if (mont_done1_flag && mont_done2_flag)
                    next_state = UPDATE_INDEX_BIT;
                else 
                    next_state = WAIT_ITERATION;
        end   
        UPDATE_INDEX_BIT: begin 
            next_state = ITERATION;
        end
        MONT_TO_REG: begin 
            next_state = WAIT_MONT_TO_REG;
        end  
        WAIT_MONT_TO_REG: begin 
            if(mont_done1)
                next_state = DONE;
            else
                next_state = WAIT_MONT_TO_REG;
        end     
        DONE: 
            next_state = IDLE;
        default: next_state = IDLE;
    endcase
end


// State Output and Logic Operations
always @(posedge clk) begin 
    if (~resetn) begin
        i <= 0;
        tao <= 0;
        mont_in_a1 <= 0;
        mont_in_b1 <= 0;
        mont_start1 <= 0;
        mont_in_a2 <= 0;
        mont_in_b2 <= 0;
        mont_start2 <= 0;
        e <= 0;
        e_index_bit <= 0;
        x_tilde <= 0;
        A <= 0;
        mont_done1_flag <= 0;
        mont_done2_flag <= 0;
    end
    else begin
        case (current_state)
            IDLE: begin
                i <= 0;
                tao <= 0;
                mont_in_a1 <= 0;
                mont_in_b1 <= 0;
                mont_start1 <= 0;
                mont_in_a2 <= 0;
                mont_in_b2 <= 0;
                mont_start2 <= 0;
                e <= 0;
                e_index_bit <= 0;
                x_tilde <= 0;
                A <= 0;
                mont_done1_flag <= 0;
                mont_done2_flag <= 0;
            end
            INITIALIZE: begin 
                e <= in_e;
                tao <= in_e_length - 1;
            end
            REG_TO_MONT: begin 
                e_index_bit <= e[tao];
                mont_in_a1 <= in_x;
                mont_in_b1 <= in_R2_mod_M;
                mont_start1 <= 1;
                mont_in_a2 <= 1;
                mont_in_b2 <= in_R2_mod_M;
                mont_start2 <= 1;
            end
            WAIT_REG_TO_MONT: begin 
                mont_start1 <= 0;
                mont_start2 <= 0;
                if(mont_done1)begin
                    x_tilde <= mont_result1;
                    mont_done1_flag <= 1;
                end
                if(mont_done2)begin
                    A <= mont_result2;
                    mont_done2_flag <= 1;
                end
            end          
            ITERATION: begin 
                mont_in_a1 <= A;
                mont_in_b1 <= x_tilde;
                mont_start1 <= 1;
                mont_done1_flag <= 0;
                mont_done2_flag <= 0;
                if(e_index_bit == 1) begin
                    mont_in_a2 <= x_tilde;
                    mont_in_b2 <= x_tilde;
                    mont_start2 <= 1;
                end
                else begin
                    mont_in_a2 <= A;
                    mont_in_b2 <= A;
                    mont_start2 <= 1;
                end
                i <= i + 1;
                e <= e << 1;                
            end   
            WAIT_ITERATION: begin
                mont_start1 <= 0;
                mont_start2 <= 0;
                if(e_index_bit == 1) begin
                    if(mont_done1) begin
                        A <= mont_result1;
                        mont_done1_flag <= 1;
                    end
                    if(mont_done2) begin
                        x_tilde <= mont_result2;
                        mont_done2_flag <= 1;
                    end
                end
                else begin 
                    if(mont_done1) begin
                        x_tilde <= mont_result1;
                        mont_done1_flag <= 1;
                    end
                    if(mont_done2) begin
                        A <= mont_result2;
                        mont_done2_flag <= 1;
                    end
                end 
            end
            UPDATE_INDEX_BIT: begin 
                e_index_bit <= e[tao];
            end
            MONT_TO_REG: begin 
                mont_in_a1 <= A;
                mont_in_b1 <= 1;
                mont_start1 <= 1;
            end       
            WAIT_MONT_TO_REG: begin 
                mont_start1 <= 0;
                if(mont_done1)
                    A <= mont_result1;
            end
            DONE: begin end
        endcase
    end
end


// Output Logic
assign result = (current_state == DONE)? A : 1024'b0;  
assign done = (current_state == DONE)? 1'b1 : 1'b0; 


endmodule
