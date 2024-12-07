module rsa (
    input  wire          clk,
    input  wire          resetn,
    output wire   [ 3:0] leds,

    // input registers                     // output registers
    input  wire   [31:0] rin0,             output wire   [31:0] rout0,
    input  wire   [31:0] rin1,             output wire   [31:0] rout1,
    input  wire   [31:0] rin2,             output wire   [31:0] rout2,
    input  wire   [31:0] rin3,             output wire   [31:0] rout3,
    input  wire   [31:0] rin4,             output wire   [31:0] rout4,
    input  wire   [31:0] rin5,             output wire   [31:0] rout5,
    input  wire   [31:0] rin6,             output wire   [31:0] rout6,
    input  wire   [31:0] rin7,             output wire   [31:0] rout7,

    // dma signals
    input  wire [1023:0] dma_rx_data,      output wire [1023:0] dma_tx_data,
    output wire [  31:0] dma_rx_address,   output wire [  31:0] dma_tx_address,
    output reg           dma_rx_start,     output reg           dma_tx_start,
    input  wire          dma_done,
    input  wire          dma_idle,
    input  wire          dma_error
  );

  // In this example three input registers are used.
  // The first one is used for giving a command to FPGA.
  // The others are for setting DMA input and output data addresses.
  wire [31:0] command;
  reg  [31:0] addr_rin;
  reg  [2:0] count;
  assign command        = rin0; // use rin0 as command
  assign dma_tx_address = rin1; // use rin1 as output data address
  assign dma_rx_address = addr_rin; // use rin1 as input  data address
  
  always @(*) begin 
       case(state)
        STATE_RX:begin
            if (count == 1)         addr_rin <= rin2;// message
            else if (count == 2)    addr_rin <= rin3;// mey
            else if (count == 3)    addr_rin <= rin4;// modulus
            else if (count == 4)    addr_rin <= rin5;// RN
            else if (count == 5)    addr_rin <= rin6;// R2N
            else if (count == 6)    addr_rin <= rin7;// key length
            else addr_rin <= rin2;
        end
        STATE_RX_WAIT:begin
            if (count == 1)         addr_rin <= rin2;// message
            else if (count == 2)    addr_rin <= rin3;// mey
            else if (count == 3)    addr_rin <= rin4;// modulus
            else if (count == 4)    addr_rin <= rin5;// RN
            else if (count == 5)    addr_rin <= rin6;// R2N
            else if (count == 6)    addr_rin <= rin7;// key length
            else addr_rin <= rin2;
        end
        default: addr_rin <= rin2;
    endcase
  end

  // Only one output register is used. It will the status of FPGA's execution.
  wire [31:0] status;
  assign rout0 = status; // use rout0 as status
  assign rout1 = 32'b0;  // not used
  assign rout2 = 32'b0;  // not used
  assign rout3 = 32'b0;  // not used
  assign rout4 = 32'b0;  // not used
  assign rout5 = 32'b0;  // not used
  assign rout6 = 32'b0;  // not used
  assign rout7 = 32'b0;  // not used


  // In this example we have only one computation command.
  wire isCmdComp = (command == 32'd1);
  wire isCmdIdle = (command == 32'd0);


  // Define state machine's states
  localparam
    STATE_IDLE          = 3'd0,
    STATE_RX            = 3'd1,
    STATE_RX_WAIT       = 3'd2,
    STATE_COMPUTE       = 3'd3,
    STATE_WAIT_COMPUTE  = 3'd4,
    STATE_TX            = 3'd5,
    STATE_TX_WAIT       = 3'd6,
    STATE_DONE          = 3'd7;

  // The state machine
  reg [2:0] state = STATE_IDLE;
  reg [2:0] next_state;

  always@(*) begin
    // defaults
    next_state   <= STATE_IDLE;

    // state defined logic
    case (state)
      // Wait in IDLE state till a compute command
      STATE_IDLE: begin
        next_state <= (isCmdComp) ? STATE_RX : state;
      end

      // Wait, if dma is not idle. Otherwise, start dma operation and go to
      // next state to wait its completion.
      STATE_RX: begin
         next_state <= (~dma_idle) ? STATE_RX_WAIT : state;
      end

      // Wait the completion of dma.
      STATE_RX_WAIT : begin
        if(dma_done) begin
            if(count == 6)
                next_state <= STATE_COMPUTE;
            else 
                next_state <= STATE_RX;
        end
        else 
            next_state <= state;
      end

      // A state for dummy computation for this example. Because this
      // computation takes only single cycle, go to TX state immediately
      STATE_COMPUTE : begin
        next_state <= STATE_WAIT_COMPUTE;
      end

      STATE_WAIT_COMPUTE: begin
        next_state <= (mont_exp_done) ? STATE_TX : state;
      end

      // Wait, if dma is not idle. Otherwise, start dma operation and go to
      // next state to wait its completion.
      STATE_TX : begin
        next_state <= (~dma_idle) ? STATE_TX_WAIT : state;
      end

      // Wait the completion of dma.
      STATE_TX_WAIT : begin
        next_state <= (dma_done) ? STATE_DONE : state;
      end

      // The command register might still be set to compute state. Hence, if
      // we go back immediately to the IDLE state, another computation will
      // start. We might go into a deadlock. So stay in this state, till CPU
      // sets the command to idle. While FPGA is in this state, it will
      // indicate the state with the status register, so that the CPU will know
      // FPGA is done with computation and waiting for the idle command.
      STATE_DONE : begin
        next_state <= (isCmdIdle) ? STATE_IDLE : state;
      end

    endcase
  end

  always@(posedge clk) begin
    dma_rx_start <= 1'b0;
    dma_tx_start <= 1'b0;
    case (state)
      STATE_RX: dma_rx_start <= 1'b1;
      STATE_TX: dma_tx_start <= 1'b1;
    endcase
  end

  always@(posedge clk) begin
    case (state)
      STATE_IDLE: count <= 3'b1;
      STATE_RX_WAIT: 
        if(dma_done)
            count <= count + 1;
    endcase
  end

  // Synchronous state transitions
  always@(posedge clk)
    state <= (~resetn) ? STATE_IDLE : next_state;


  reg            mont_exp_start;
  reg   [1023:0] r_x;
  reg   [1023:0] r_e;
  reg   [1023:0] r_m;
  reg   [1023:0] r_RN;
  reg   [1023:0] r_R2N;
  reg   [9:0]    r_e_length;
  wire  [1023:0] mont_exp_result;   
  wire           mont_exp_done;

  reg   [1023:0] t_data;

//Instantiating montgomery module
mont_exp mont_exp_instance(     .clk        (clk    ),
                                .resetn     (resetn ),
                                .start      (mont_exp_start  ),
                                .in_x       (r_x   ),
                                .in_e       (r_e ),
                                .in_m       (r_m ),
                                .in_R_mod_M (r_RN   ),
                                .in_R2_mod_M(r_R2N   ),
                                .in_e_length(r_e_length   ),
                                .result     (mont_exp_result   ),
                                .done       (mont_exp_done   ));

  always@(posedge clk)
    case (state)
      STATE_RX_WAIT : begin 
        if(count == 1) 
            r_x <= (dma_done) ? dma_rx_data : r_x;
        else if(count == 2) 
            r_e <= (dma_done) ? dma_rx_data : r_e;
        else if(count == 3) 
            r_m <= (dma_done) ? dma_rx_data : r_m;
        else if(count == 4) 
            r_RN <= (dma_done) ? dma_rx_data : r_RN;
        else if(count == 5) 
            r_R2N <= (dma_done) ? dma_rx_data : r_R2N;
        else if(count == 6) 
            r_e_length <= (dma_done) ? dma_rx_data : r_e_length;
      end
      STATE_COMPUTE : begin 
        mont_exp_start <= 1;
      end
      STATE_WAIT_COMPUTE: begin
        mont_exp_start <= 0;
        if(mont_exp_done)
            t_data <= mont_exp_result;
      end
    endcase
    
    assign dma_tx_data = t_data;


  // Status signals to the CPU
  wire isStateIdle = (state == STATE_IDLE);
  wire isStateDone = (state == STATE_DONE);
  assign status = {29'b0, dma_error, isStateIdle, isStateDone};

endmodule
