`timescale 1ns / 1ps

module interfacer#(
  parameter integer C_SAXIL_ADDR_WIDTH =    12,
  parameter integer C_SAXIL_DATA_WIDTH =    32,
  parameter integer C_MAXI_ADDR_WIDTH  =    32,
  parameter integer C_MAXI_DATA_WIDTH  =  1024
  ) (
  input  wire aclk    ,
  input  wire aresetn ,
  
  // Connection to ARM Mem Controller
  output wire                             m_axi_dma_awvalid  ,
  input  wire                             m_axi_dma_awready  ,
  output wire [C_MAXI_ADDR_WIDTH-1:0]     m_axi_dma_awaddr   ,
  output wire [8-1:0]                     m_axi_dma_awlen    ,
  output wire [1:0]                       m_axi_dma_awburst  ,
  output wire                             m_axi_dma_wvalid   ,
  input  wire                             m_axi_dma_wready   ,
  output wire [C_MAXI_DATA_WIDTH-1:0]     m_axi_dma_wdata    ,
  output wire                             m_axi_dma_wlast    ,
  input  wire                             m_axi_dma_bvalid   ,
  output wire                             m_axi_dma_bready   ,
  output wire                             m_axi_dma_arvalid  ,
  input  wire                             m_axi_dma_arready  ,
  output wire [C_MAXI_ADDR_WIDTH-1:0]     m_axi_dma_araddr   ,
  output wire [8-1:0]                     m_axi_dma_arlen    ,
  output wire [1:0]                       m_axi_dma_arburst  ,
  input  wire                             m_axi_dma_rvalid   ,
  output wire                             m_axi_dma_rready   ,
  input  wire [C_MAXI_DATA_WIDTH-1:0]     m_axi_dma_rdata    ,
  input  wire                             m_axi_dma_rlast    ,
  
  // Connection to Memory-Mapped Register Interface
  input  wire                             s_axi_csrs_awvalid ,
  output wire                             s_axi_csrs_awready ,
  input  wire [C_SAXIL_ADDR_WIDTH-1:0]    s_axi_csrs_awaddr  ,
  input  wire                             s_axi_csrs_wvalid  ,
  output wire                             s_axi_csrs_wready  ,
  input  wire [C_SAXIL_DATA_WIDTH-1:0]    s_axi_csrs_wdata   ,
  input  wire [C_SAXIL_DATA_WIDTH/8-1:0]  s_axi_csrs_wstrb   ,
  output wire                             s_axi_csrs_bvalid  ,
  input  wire                             s_axi_csrs_bready  ,
  output wire [2-1:0]                     s_axi_csrs_bresp   ,
  input  wire                             s_axi_csrs_arvalid ,
  output wire                             s_axi_csrs_arready ,
  input  wire [C_SAXIL_ADDR_WIDTH-1:0]    s_axi_csrs_araddr  ,
  output wire                             s_axi_csrs_rvalid  ,
  input  wire                             s_axi_csrs_rready  ,
  output wire [C_SAXIL_DATA_WIDTH-1:0]    s_axi_csrs_rdata   ,
  output wire [2-1:0]                     s_axi_csrs_rresp   ,

  // Memory-Mapped Registers
  // CPU -> FPGA                          FPGA -> CPU
  output wire [  31:0] csr0_c2f      ,    input wire [  31:0] csr0_f2c      ,
  output wire [  31:0] csr1_c2f      ,    input wire [  31:0] csr1_f2c      ,
  output wire [  31:0] csr2_c2f      ,    input wire [  31:0] csr2_f2c      ,
  output wire [  31:0] csr3_c2f      ,    input wire [  31:0] csr3_f2c      ,
  output wire [  31:0] csr4_c2f      ,    input wire [  31:0] csr4_f2c      ,
  output wire [  31:0] csr5_c2f      ,    input wire [  31:0] csr5_f2c      ,
  output wire [  31:0] csr6_c2f      ,    input wire [  31:0] csr6_f2c      ,
  output wire [  31:0] csr7_c2f      ,    input wire [  31:0] csr7_f2c      ,
 
  // The DMA 
  // CPU -> FPGA                          FPGA -> CPU
  input  wire          dma_c2f_start ,    input wire          dma_f2c_start ,
  output wire [1023:0] dma_c2f_data  ,    input wire [1023:0] dma_f2c_data  ,
  input  wire [  31:0] dma_c2f_addr  ,    input wire [  31:0] dma_f2c_addr  ,
  output wire          dma_done      ,
  output wire          dma_idle      ,
  output wire          dma_error    
);

  //////////////////////////////////////////////////////////////////////////////
  // s_axi_csrs
  //////////////////////////////////////////////////////////////////////////////

  // Parameters
  localparam  ADDR_BITS = 5     ,
              ADDR_CSR0 = 5'h00 ,
              ADDR_CSR1 = 5'h04 ,
              ADDR_CSR2 = 5'h08 ,
              ADDR_CSR3 = 5'h0c ,
              ADDR_CSR4 = 5'h10 ,
              ADDR_CSR5 = 5'h14 ,
              ADDR_CSR6 = 5'h18 ,
              ADDR_CSR7 = 5'h1c ;

  // Internal Registers
  reg [31:0] csr0 = 'b0;
  reg [31:0] csr1 = 'b0;
  reg [31:0] csr2 = 'b0;
  reg [31:0] csr3 = 'b0;
  reg [31:0] csr4 = 'b0;
  reg [31:0] csr5 = 'b0;
  reg [31:0] csr6 = 'b0;
  reg [31:0] csr7 = 'b0;


  // The Write FSM -------------------------------------------------------------

  localparam  WRIDLE  = 4'b0001 ,
              WRDATA  = 4'b0010 ,
              WRRESP  = 4'b0100 ,
              WRRESET = 4'b1000 ;
              
  // Local Signal
  reg  [3:0]           wstate = WRRESET;
  reg  [3:0]           wnext;
  reg  [ADDR_BITS-1:0] waddr;

  assign s_axi_csrs_awready = (wstate == WRIDLE);
  assign s_axi_csrs_wready  = (wstate == WRDATA);
  assign s_axi_csrs_bresp   = 2'b00;  // OKAY
  assign s_axi_csrs_bvalid  = (wstate == WRRESP);

  wire [31:0] wmask = { {8{s_axi_csrs_wstrb[3]}} , 
                        {8{s_axi_csrs_wstrb[2]}} , 
                        {8{s_axi_csrs_wstrb[1]}} , 
                        {8{s_axi_csrs_wstrb[0]}} };

  wire aw_hs = s_axi_csrs_awvalid & s_axi_csrs_awready;
  wire w_hs  = s_axi_csrs_wvalid  & s_axi_csrs_wready;

  // wstate
  always @(posedge aclk) begin
    if (~aresetn) wstate <= WRRESET;
    else          wstate <= wnext;
  end

  // wnext
  always @(*)
    case (wstate)
      WRIDLE : wnext = (s_axi_csrs_awvalid) ? WRDATA : WRIDLE;
      WRDATA : wnext = (s_axi_csrs_wvalid ) ? WRRESP : WRDATA;
      WRRESP : wnext = (s_axi_csrs_bready ) ? WRIDLE : WRRESP;
      default: wnext = WRIDLE;
    endcase

  // waddr
  always @(posedge aclk)
    if (aw_hs) waddr <= s_axi_csrs_awaddr[ADDR_BITS-1:0];


  // The Read FSM --------------------------------------------------------------
              
  localparam  RDIDLE  = 3'b001 ,
              RDDATA  = 3'b010 ,
              RDRESET = 3'b100 ;
  
  reg [ 2:0] rstate = RDRESET;
  reg [ 2:0] rnext;
  reg [31:0] rdata;

  assign s_axi_csrs_arready = (rstate == RDIDLE);
  assign s_axi_csrs_rdata   = rdata;
  assign s_axi_csrs_rresp   = 2'b00;
  assign s_axi_csrs_rvalid  = (rstate == RDDATA);

  wire                 ar_hs = s_axi_csrs_arvalid & s_axi_csrs_arready;
  wire [ADDR_BITS-1:0] raddr = s_axi_csrs_araddr[ADDR_BITS-1:0];

  // rstate
  always @(posedge aclk) 
    if (~aresetn) rstate <= RDRESET;
    else          rstate <= rnext;

  // rnext
  always @(*) 
    case (rstate)
      RDIDLE : rnext = (s_axi_csrs_arvalid                   ) ? RDDATA : RDIDLE ; 
      RDDATA : rnext = (s_axi_csrs_rready & s_axi_csrs_rvalid) ? RDIDLE : RDDATA ; 
      default: rnext = RDIDLE;
    endcase

  // rdata
  always @(posedge aclk)
    if (ar_hs) begin
      rdata <= 1'b0;
      case (raddr)
        ADDR_CSR0 : rdata <= csr0_f2c ;
        ADDR_CSR1 : rdata <= csr1_f2c ;
        ADDR_CSR2 : rdata <= csr2_f2c ;
        ADDR_CSR3 : rdata <= csr3_f2c ;
        ADDR_CSR4 : rdata <= csr4_f2c ;
        ADDR_CSR5 : rdata <= csr5_f2c ;
        ADDR_CSR6 : rdata <= csr6_f2c ;
        ADDR_CSR7 : rdata <= csr7_f2c ;
      endcase
    end

  // Register Logic
  always @(posedge aclk) begin
    if (w_hs && waddr == ADDR_CSR0 ) csr0 <= (s_axi_csrs_wdata[31:0] & wmask) | (csr0 & ~wmask);
    if (w_hs && waddr == ADDR_CSR1 ) csr1 <= (s_axi_csrs_wdata[31:0] & wmask) | (csr1 & ~wmask);
    if (w_hs && waddr == ADDR_CSR2 ) csr2 <= (s_axi_csrs_wdata[31:0] & wmask) | (csr2 & ~wmask);
    if (w_hs && waddr == ADDR_CSR3 ) csr3 <= (s_axi_csrs_wdata[31:0] & wmask) | (csr3 & ~wmask);
    if (w_hs && waddr == ADDR_CSR4 ) csr4 <= (s_axi_csrs_wdata[31:0] & wmask) | (csr4 & ~wmask);
    if (w_hs && waddr == ADDR_CSR5 ) csr5 <= (s_axi_csrs_wdata[31:0] & wmask) | (csr5 & ~wmask);
    if (w_hs && waddr == ADDR_CSR6 ) csr6 <= (s_axi_csrs_wdata[31:0] & wmask) | (csr6 & ~wmask);
    if (w_hs && waddr == ADDR_CSR7 ) csr7 <= (s_axi_csrs_wdata[31:0] & wmask) | (csr7 & ~wmask);
  end

  assign csr0_c2f = csr0;
  assign csr1_c2f = csr1;
  assign csr2_c2f = csr2;
  assign csr3_c2f = csr3;
  assign csr4_c2f = csr4;
  assign csr5_c2f = csr5;
  assign csr6_c2f = csr6;
  assign csr7_c2f = csr7;

  //////////////////////////////////////////////////////////////////////////////
  // m_axi_dma
  //////////////////////////////////////////////////////////////////////////////

  localparam
    S_IDLE    = 6'b000001, // Idle       - Waiting for command
    S_WR      = 6'b000010, // Write      - Sending write addr. request (awvalid)
    S_WRDATA  = 6'b000100, // Write Data - Sending write data          ( wvalid)
    S_WRRESP  = 6'b001000, // Write Resp - Waiting for write resp.     ( bvalid)
    S_RD      = 6'b010000, // Read       - Sending read address req.   (arvalid)
    S_RDDATA  = 6'b100000; // Read Data  - Waiting for read data       ( rvalid)

  reg [5:0] state      = S_IDLE;
  reg [5:0] next_state = S_IDLE;
  
  // Check Valid Address
  wire wrong_addr;
  reg dma_error_set = 1'b0;
  assign wrong_addr = ((dma_c2f_start && dma_c2f_addr[6:0]) || (dma_f2c_start && dma_f2c_addr[6:0]));
  always @(posedge aclk) begin
    if (~aresetn)
        dma_error_set <= 1'b0;
    else if (wrong_addr)
        dma_error_set <= 1'b1;
  end
  assign dma_error = dma_error_set;


  always @(*) begin
    case (state)
      S_IDLE   : next_state <= (dma_f2c_start    ) ? S_WR     :
                               (dma_c2f_start    ) ? S_RD     : S_IDLE   ;
      S_WR     : next_state <= (m_axi_dma_awready) ? S_WRDATA : S_WR     ;
      S_WRDATA : next_state <= (m_axi_dma_wready ) ? S_WRRESP : S_WRDATA ;
      S_WRRESP : next_state <= (m_axi_dma_bvalid ) ? S_IDLE   : S_WRRESP ;
      S_RD     : next_state <= (m_axi_dma_arready) ? S_RDDATA : S_RD     ;
      S_RDDATA : next_state <= (m_axi_dma_rvalid ) ? S_IDLE   : S_RDDATA ;
      default  : next_state <=                       S_IDLE;
    endcase
  end

  always @(posedge aclk)
    state <= (~aresetn) ? S_IDLE : next_state;

  // State nets
  wire is_state_idle       = (state == S_IDLE  );
  wire is_state_wr         = (state == S_WR    );
  wire is_state_wr_data    = (state == S_WRDATA);
  wire is_state_wr_resp    = (state == S_WRRESP);
  wire is_state_rd         = (state == S_RD    );
  wire is_state_rd_data    = (state == S_RDDATA);

  // Write Address
  assign m_axi_dma_awaddr  = dma_f2c_addr;
  assign m_axi_dma_awlen   = 8'h00;   // No burst
  assign m_axi_dma_awburst = 2'b01;   // Incremental burst
  assign m_axi_dma_awvalid = is_state_wr;

  // Write Data
  assign m_axi_dma_wdata   = dma_f2c_data;
  assign m_axi_dma_wlast   = is_state_wr_data;
  assign m_axi_dma_wvalid  = is_state_wr_data;

  // Write Response
  assign m_axi_dma_bready  = is_state_wr_resp;

  // Read Address
  assign m_axi_dma_araddr  = dma_c2f_addr;
  assign m_axi_dma_arlen   = 8'h00;   // No burst
  assign m_axi_dma_arburst = 2'b01;   // Incremental burst
  assign m_axi_dma_arvalid = is_state_rd;

  // Read Data
  assign m_axi_dma_rready  = is_state_rd_data;


  // Output
  assign dma_done     = (m_axi_dma_rready & m_axi_dma_rvalid) |
                        (m_axi_dma_wready & m_axi_dma_wvalid) ;
  assign dma_idle     = (state == S_IDLE);
  assign dma_c2f_data = m_axi_dma_rdata;
  

endmodule