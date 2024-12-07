`timescale 1ns / 1ps

`define HUGE_WAIT   300
`define LONG_WAIT   100
`define RESET_TIME   25
`define CLK_PERIOD   10
`define CLK_HALF      5

module tb_rsa_wrapper();
    
  reg           clk         ;
  reg           resetn      ;
  wire          leds        ;

  // Memory Interface Signals (DMA: enable 1024-bit data transfers between memory and FPGA)
  reg  [16:0]   mem_addr    = 'b0 ; // Memory address.
  reg  [1023:0] mem_din     = 'b0 ; // Data input to memory
  wire [1023:0] mem_dout    ;       // Data output from memory
  reg  [127:0]  mem_we      = 'b0 ; // write enable signals from memory  

  // AXI Interface Signals (CSR registers writing and reading 32-bit data to and from FPGA)
  reg  [ 11:0] axil_araddr  ;
  wire         axil_arready ;
  reg          axil_arvalid ;
  reg  [ 11:0] axil_awaddr  ;
  wire         axil_awready ;
  reg          axil_awvalid ;
  reg          axil_bready  ;
  wire [  1:0] axil_bresp   ;
  wire         axil_bvalid  ;
  wire [ 31:0] axil_rdata   ;
  reg          axil_rready  ;
  wire [  1:0] axil_rresp   ;
  wire         axil_rvalid  ;
  reg  [ 31:0] axil_wdata   ;
  wire         axil_wready  ;
  reg  [  3:0] axil_wstrb   ;
  reg          axil_wvalid  ;
      
  tb_rsa_project_wrapper dut (
    .clk                 ( clk           ),
    .leds                ( leds          ),
    .resetn              ( resetn        ),
    .s_axi_csrs_araddr   ( axil_araddr   ),
    .s_axi_csrs_arready  ( axil_arready  ),
    .s_axi_csrs_arvalid  ( axil_arvalid  ),
    .s_axi_csrs_awaddr   ( axil_awaddr   ),
    .s_axi_csrs_awready  ( axil_awready  ),
    .s_axi_csrs_awvalid  ( axil_awvalid  ),
    .s_axi_csrs_bready   ( axil_bready   ),
    .s_axi_csrs_bresp    ( axil_bresp    ),
    .s_axi_csrs_bvalid   ( axil_bvalid   ),
    .s_axi_csrs_rdata    ( axil_rdata    ),
    .s_axi_csrs_rready   ( axil_rready   ),
    .s_axi_csrs_rresp    ( axil_rresp    ),
    .s_axi_csrs_rvalid   ( axil_rvalid   ),
    .s_axi_csrs_wdata    ( axil_wdata    ),
    .s_axi_csrs_wready   ( axil_wready   ),
    .s_axi_csrs_wstrb    ( axil_wstrb    ),
    .s_axi_csrs_wvalid   ( axil_wvalid   ),
    .mem_clk             ( clk           ), 
    .mem_addr            ( mem_addr      ),     
    .mem_din             ( mem_din       ), 
    .mem_dout            ( mem_dout      ), 
    .mem_en              ( 1'b1          ), 
    .mem_rst             (~resetn        ), 
    .mem_we              ( mem_we        ));
      
  // Generate Clock
  initial begin
      clk = 0;
      forever #`CLK_HALF clk = ~clk;
  end

  // Initialize signals to zero
  initial begin
    axil_araddr  <= 'b0;
    axil_arvalid <= 'b0;
    axil_awaddr  <= 'b0;
    axil_awvalid <= 'b0;
    axil_bready  <= 'b0;
    axil_rready  <= 'b0;
    axil_wdata   <= 'b0;
    axil_wstrb   <= 'b0;
    axil_wvalid  <= 'b0;
  end

  // Reset the circuit
  initial begin
      resetn = 0;
      #`RESET_TIME
      resetn = 1;
  end
  
// Tasks for Register and Memory Operations:
  
  // Read from specified register
  task reg_read;
    input [11:0] reg_address;
    output [31:0] reg_data;
    begin
      // Channel AR
      axil_araddr  <= reg_address;
      axil_arvalid <= 1'b1;
      wait (axil_arready);
      #`CLK_PERIOD;
      axil_arvalid <= 1'b0;
      // Channel R
      axil_rready  <= 1'b1;
      wait (axil_rvalid);
      reg_data <= axil_rdata;
      #`CLK_PERIOD;
      axil_rready  <= 1'b0;
      $display("reg[%x] <= %x", reg_address, reg_data);
      #`CLK_PERIOD;
      #`RESET_TIME;
    end
  endtask

  // Write to specified register
  task reg_write;
    input [11:0] reg_address;
    input [31:0] reg_data;
    begin
      // Channel AW
      axil_awaddr <= reg_address;
      axil_awvalid <= 1'b1;
      // Channel W
      axil_wdata  <= reg_data;
      axil_wstrb  <= 4'b1111;
      axil_wvalid <= 1'b1;
      // Channel AW
      wait (axil_awready);
      #`CLK_PERIOD;
      axil_awvalid <= 1'b0;
      // Channel W
      wait (axil_wready);
      #`CLK_PERIOD;
      axil_wvalid <= 1'b0;
      // Channel B
      axil_bready <= 1'b1;
      wait (axil_bvalid);
      #`CLK_PERIOD;
      axil_bready <= 1'b0;
      $display("reg[%x] <= %x", reg_address, reg_data);
      #`CLK_PERIOD;
      #`RESET_TIME;
    end
  endtask

  // Read at given address in memory
  task mem_write;
    input [  16:0] address;
    input [1024:0] data;
    begin
      mem_addr <= address;
      mem_din  <= data;
      mem_we   <= {128{1'b1}}; // Sets mem_we to all ones to enable writing to all 128 chunks (assuming 8-bit bytes in 1024 bits).
      #`CLK_PERIOD;
      mem_we   <= {128{1'b0}};
      $display("mem[%x] <= %x", address, data);
      #`CLK_PERIOD;
    end
  endtask

  // Write to given address in memory
  task mem_read;
    input [  16:0] address;
    begin
      mem_addr <= address;
      #`CLK_PERIOD;
      #`CLK_PERIOD;
      $display("mem[%x] => %x", address, mem_dout);
    end
  endtask
  
  
  // Byte Addresses of 32-bit registers
  localparam  COMMAND       = 0,  // r0
              TXADDR        = 4,  // r1
              RX_ADDR_MES   = 8,  // r2
              RX_ADDR_KEY   = 12, // r3
              RX_ADDR_MOD   = 16, // r4
              RX_ADDR_RN    = 20, // r5
              RX_ADDR_R2N   = 24, // r6
              RX_ADDR_KEY_LENGTH   = 28, // r7
              STATUS  = 0;

  // Byte Addresses of 1024-bit distant memory locations, assuming 1024 bits per address, so addresses increment by 0x80
  localparam  MEM0_ADDR  = 16'h000, // TX
              MEM1_ADDR  = 16'h080, // message
              MEM2_ADDR  = 16'h100, // key
              MEM3_ADDR  = 16'h180, // modulus
              MEM4_ADDR  = 16'h200, // RN
              MEM5_ADDR  = 16'h280, // R2N
              MEM6_ADDR  = 16'h300; // key length
              
              
  reg [31:0] reg_status;
  

  initial begin

    #`LONG_WAIT
    
    reg_write(TXADDR, MEM0_ADDR); // TXADDER register write the output data to MEM1_ADDR

    mem_write(MEM1_ADDR, 1024'hd54dcf1a625cc46db236454e6e2f0299fc708cd4b0733053988f40e8958a609fac0781e6dda52c14766d3b1f11f7268d978319468e778dce4245c0036d4daeaf9f7093d40a0a664669706771e393c555bbe64002c90e48f17250812ff4e66e251e7fcbff0ca4b1c9d302eac8e55a20cca7f3e05eac6d240cc74454141058b5f8);
    reg_write(RX_ADDR_MES, MEM1_ADDR); // RX_ADDR_MES register read the input data from MEM1_ADDER

    mem_write(MEM2_ADDR, 1024'h87);
    reg_write(RX_ADDR_KEY, MEM2_ADDR); 
    
    mem_write(MEM3_ADDR, 1024'h82cacc71f7fb3b0cfa7c79aec0bf4dd3137b7adb982effb67f777613df633fcfab6752e09b516fb8a73949b491d01ff02d25bde2ebc07d227133b39b7fee3c3bce9ca9375872f49eec5c117514cdd3672dd5b66dba1a1a4f23fd95c234b29c8ea3764ca4e76708e694e296305400f9c9ff2711920bcac1cbca917bbaba51032b);
    reg_write(RX_ADDR_MOD, MEM3_ADDR); 
    
    mem_write(MEM4_ADDR, 1024'h7cf8e7c5c18605dc0b32bec29860f0db5f811d3afd9576f1682e510419e0fab0786c7f32536f95c78f6ec0731b4e1547b6a3366f0bdcf2cd16b7df221f457fab9c06c5f52a0bb2ae531721ea2a9d25fdba2402efcf1a1ef813cca87bc2e07e88e42bfac18a7886cb6883be7b5dc24e13225de52af567584690c0c37222f9f85d);
    reg_write(RX_ADDR_RN, MEM4_ADDR); 
    
    mem_write(MEM5_ADDR, 1024'h45ad36828a6643d659013c0965cf09a0c3341fe487eec34c12e9ce389d27b7b39d666e06dd7e78e7aad753bdda15f8384a71081aaf8e3313bd1079bb57898188cadfc9b9d255d74be362eeee311e9c1a5ee4e94fd083e10d06e93a87a0d15d20b2349d6b82ebc293a933c09329c029ef9a06c268ede4f11350c791bb59e882c5);
    reg_write(RX_ADDR_R2N, MEM5_ADDR); 

    mem_write(MEM6_ADDR, 10'h8);
    reg_write(RX_ADDR_KEY_LENGTH, MEM6_ADDR); 
    
   
    reg_write(COMMAND, 32'h00000001);
    $display("Command starts");
    
    // Poll Done Signal
    reg_read(COMMAND, reg_status); // Reads the COMMAND register into reg_status
    while (reg_status[0]==1'b0)
    begin
      #`LONG_WAIT;
      reg_read(COMMAND, reg_status);
    end
    
    reg_write(COMMAND, 32'h00000000);

    mem_read(MEM0_ADDR); // result of the RSA operation

    $finish;

  end

endmodule

// NOTES: How the TB realize the Data Transfer:
//You write input data to a memory location using mem_write.
//You set the RXADDR register to point to the input data in memory.
//You set the TXADDR register to point to the output data location in memory.
//You write to the COMMAND register to start the operation.
//You poll the COMMAND register to detect when the operation is complete.
//After completion, you read the output data from memory.